# frozen_string_literal: true

module Quail
  module Resource
    # Generates GraphQL object types from resource attribute and association definitions.
    module TypeBuilder
      def self.build_all
        # Two-pass build: first create all scalar types so every resource has a
        # graphql_type, then wire up associations (which may reference other resources).
        Quail.registry.each_value { |rc| build_scalar_fields(rc) }
        Quail.registry.each_value { |rc| add_association_fields(rc) }
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
          next unless config[:type] == :computed

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

        # Support explicit resource: option (string or class) for associations
        # where the AR association class name differs from the resource name
        if config[:resource]
          resource_class = resolve_resource_ref(config[:resource])
          assoc_type = resource_class&.graphql_type
          if assoc_type
            ar_assoc = model.reflect_on_association(name)
            add_association_field(type_class, name, config[:kind], assoc_type, ar_assoc)
          end
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
        resolved_types = config[:polymorphic_types].map do |t|
          resolve_resource_ref(t).graphql_type
        end
        assoc_name = name

        Class.new(GraphQL::Schema::Union) do
          graphql_name gql_name
          description "Union type for polymorphic association #{assoc_name}"
          possible_types(*resolved_types)
          define_method(:resolve_type) { |obj, _ctx| TypeBuilder.resolve_polymorphic_type(obj, assoc_name) }
        end
      end

      # Resolve a resource reference that can be a Class or a String class name.
      def self.resolve_resource_ref(ref)
        case ref
        when Class
          ref
        when String
          ref.constantize
        else
          raise ArgumentError, "Expected a resource class or string class name, got #{ref.inspect}"
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
          nullable = kind == :belongs_to ? (ar_assoc ? ar_assoc.options[:optional] != false : true) : true
          type_class.field name, assoc_type, null: nullable
        end
      end
    end
  end
end
