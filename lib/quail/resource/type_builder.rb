# frozen_string_literal: true

module Quail
  module Resource
    # Generates GraphQL object types from resource attribute and association definitions.
    module TypeBuilder
      def self.build_all
        Quail.registry.each_value do |resource_class|
          build_scalar_fields(resource_class)
          add_association_fields(resource_class)
        end
      end

      def self.build_scalar_fields(resource_class)
        model = resource_class.model_class
        attrs = resource_class.attribute_definitions
        base = Quail.base_object_class || GraphQL::Schema::Object

        type_class = Class.new(base) do
          graphql_name "#{model.name}Type"
          description "Auto-generated type for #{model.name}"
        end

        define_column_fields(type_class, model, attrs)
        define_computed_fields(type_class, attrs)
        resource_class.instance_variable_set(:@graphql_type, type_class)
      end

      def self.define_column_fields(type_class, model, attrs)
        attrs.each do |name, config|
          next unless config[:type] == :column

          col = model.columns_hash[name.to_s]
          if col
            type_class.field name, TypeMap.graphql_types(col), null: TypeMap.nullable?(col)
          else
            type_class.field name, GraphQL::Types::String, null: true
          end
        end
      end

      def self.define_computed_fields(type_class, attrs)
        attrs.each do |name, config|
          next unless config[:types] == :computed

          gql_type = config[:graphql_type] || GraphQL::Types::String
          nullable = config[:null].nil? || config[:null]
          blk = config[:block]
          type_class.field name, gql_type, null: nullable
          type_class.define_method(name) { blk.call(object) }
        end
      end

      def self.add_association_fields(resource_class)
        model = resource_class.model_class
        type_class = resource_class.graphql_type
        assocs = resource_class.association_definitions

        assocs.each do |name, config|
          add_single_association(type_class, model, name, config)
        end
      end

      def self.add_single_association(type_class, model, name, config)
        if config[:polymorphic]
          add_polymorphic_field(type_class, name, config)
          return
        end

        ar_assoc = model.reflect_on_association(name)
        return unless ar_assoc

        assoc_type = Quail.resource_for(ar_assoc.klass)&.graphql_type
        return unless assoc_type

        add_association_field(type_class, name, config[:kind], assoc_type, ar_assoc)
      end

      def self.add_polymorphic_field(type_class, name, config)
        union_type = build_union_type(name, config)
        type_class.field name, union_type, null: true
      end

      def self.build_union_type(name, config)
        gql_name = config[:union_name] || "#{name.to_s.camelize}Union"
        types = config[:polymorphic_types].map(&:graphql_type)
        assoc_name = name

        Class.new(GraphQL::Schema::Union) do
          graphql_name gql_name
          description "Union type for polymorphic association #{assoc_name}"
          possible_types(*types)
          define_method(:resolve_type) { |obj, _ctx| TypeBuilder.resolve_polymorphic_type(obj, assoc_name) }
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

      def self.add_association_field(type_class, name, kind, assoc_type, ar_assoc)
        case kind
        when :has_many
          type_class.field name, [assoc_type], null: false
        when :has_one, :belongs_to
          nullable = kind == :belongs_to ? ar_assoc.options[:optional] != false : true
          type_class.field name, assoc_type, null: nullable
        end
      end
    end
  end
end
