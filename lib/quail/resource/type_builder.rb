module Quail
  module Resource
    module TypeBuilder
      def self.build_all
        Quail.registry.each_value do |resource_class|
          build_scalar_fields(resource_class)
        end

        Quail.registry.each_value do |resource_class|
          add_association_fields(resource_class)
        end
      end

      def self.build_scalar_fields(resource_class)
        model = resource_class.model_class
        attrs = resource_class.attribute_definitions
        type_name = "#{model.name}Type"

        base = Quail.base_object_class || GraphQL::Schema::Object

        type_class = Class.new(base) do
          graphql_name type_name
          description "Auto-generated type for #{model.name}"

          attrs.each do |name, config|
            if config[:type] == :column
              col = model.columns_hash[name.to_s]
              if col
                field name, TypeMap.graphql_type(col), null: TypeMap.nullable?(col)
              else
                field name, GraphQL::Types::String, null: true
              end
            elsif config[:types] == :computed
              gql_type = config[:graphql_type] || GraphQL::Types::String
              nullable = config[:null].nil? ? true : config[:null]
              blk = config[:block]
              field name, gql_type, null: nullable
              define_method(name) { blk.call(object) }
            end
          end
        end

        resource_class.instance_variable_set(:@graphql_type, type_class)
      end

      def self.add_association_fields(resource_class)
        model = resource_class.model_class
        type_class = resource_class.graphql_type
        assocs = resource_class.association_definitions

        assocs.each do |name, config|
          ar_assoc = model.reflect_on_association(name)
          next unless ar_assoc

          assoc_model = ar_assoc.klass
          assoc_type = Quail.resource_for(assoc_model)&.graphql_type
          next unless assoc_type

          case config[:kind]
          when :has_many
            type_class.field name, [assoc_type], null: false
          when :has_one, :belongs_to
            nullable = config[:kind] == :belongs_to ? ar_assoc.options[:optional] != false : true
            type_class.field name, assoc_type, null: nullable
          end
        end
      end
    end
  end
end