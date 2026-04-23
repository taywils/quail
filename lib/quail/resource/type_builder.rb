# frozen_string_literal: true

require_relative "type_builder/field_builder"
require_relative "type_builder/association_builder"

module Quail
  module Resource
    # Generates GraphQL object types from resource attribute and association definitions.
    module TypeBuilder
      def self.build_all
        # Two-pass build: first create all GraphQL types so that @graphql_type
        # is available on every resource, then wire up associations (which may
        # reference other resources' types, e.g. polymorphic unions).
        Quail.registry.each_value { |rc| build_scalar_fields(rc) unless rc.graphql_type }
        Quail.registry.each_value { |rc| AssociationBuilder.add_fields(rc) } # rubocop:disable Style/CombinableLoops
      end

      def self.build_scalar_fields(resource_class)
        model = resource_class.model_class
        attrs = resource_class.attribute_definitions
        type_class = create_type_class(model)

        FieldBuilder.define_column_fields(type_class, model, attrs)
        FieldBuilder.define_computed_fields(type_class, attrs)
        resource_class.instance_variable_set(:@graphql_type, type_class)
        register_type_constant(model, type_class)
      end

      def self.create_type_class(model)
        base = Quail.base_object_class || GraphQL::Schema::Object
        Class.new(base) do
          graphql_name "#{model.name}Type"
          description "Auto-generated type for #{model.name}"
        end
      end

      def self.register_type_constant(model, type_class)
        const_name = "#{model.name}Type"
        Object.const_set(const_name, type_class) unless Object.const_defined?(const_name)
      end

      # Resolve a resource reference that can be a Class or a String class name.
      def self.resolve_resource_ref(ref)
        case ref
        when Class  then ref
        when String then ref.constantize
        else raise ArgumentError, "Expected a resource class or string class name, got #{ref.inspect}"
        end
      end

      def self.resolve_polymorphic_type(obj, assoc_name)
        resource = Quail.resource_for(obj.class)
        unless resource
          raise GraphQL::ExecutionError,
                "Cannot resolve polymorphic type '#{obj.class.name}' " \
                "for association :#{assoc_name} — no resource registered"
        end
        resource.graphql_type
      end

      # Delegate public API so existing callers (and tests) still work.
      def self.add_association_fields(resource_class) = AssociationBuilder.add_fields(resource_class)
      def self.add_single_association(...) = AssociationBuilder.add_single(...)
      def self.add_polymorphic_field(...) = AssociationBuilder.add_polymorphic_field(...)
      def self.build_union_type(...) = AssociationBuilder.build_union_type(...)
    end
  end
end
