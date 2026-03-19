# frozen_string_literal: true

module Quail
  module Resource
    module TypeBuilder
      # Wires up association fields (belongs_to, has_one, has_many, polymorphic)
      # on a GraphQL type.
      module AssociationBuilder
        def self.add_fields(resource_class)
          model = resource_class.model_class
          type_class = resource_class.graphql_type

          resource_class.association_definitions.each do |name, config|
            add_single(type_class, model, name, config)
          end
        end

        def self.add_single(type_class, model, name, config)
          if config[:polymorphic]
            add_polymorphic_field(type_class, name, config)
          elsif config[:resource]
            add_explicit_resource_field(type_class, model, name, config)
          else
            add_reflected_field(type_class, model, name, config)
          end
        end

        def self.add_polymorphic_field(type_class, name, config)
          union_type = build_union_type(name, config)
          type_class.field name, union_type, null: true
        end

        def self.add_explicit_resource_field(type_class, model, name, config)
          resource_class = TypeBuilder.resolve_resource_ref(config[:resource])
          assoc_type = resource_class&.graphql_type
          return unless assoc_type

          ar_assoc = model.reflect_on_association(name)
          add_association_field(type_class, name, config[:kind], assoc_type, ar_assoc)
        end

        def self.add_reflected_field(type_class, model, name, config)
          ar_assoc = model.reflect_on_association(name)
          return unless ar_assoc

          assoc_type = Quail.resource_for(ar_assoc.klass)&.graphql_type
          return unless assoc_type

          add_association_field(type_class, name, config[:kind], assoc_type, ar_assoc)
        end

        def self.build_union_type(name, config)
          gql_name = config[:union_name] || "#{name.to_s.camelize}Union"
          resolved_types = config[:polymorphic_types].map do |t|
            resource = TypeBuilder.resolve_resource_ref(t)
            gql_type = resource.graphql_type
            unless gql_type
              raise ArgumentError,
                    "Polymorphic type #{t.inspect} resolved to #{resource.name} but its graphql_type is nil. " \
                    "Ensure the resource is registered before building associations."
            end
            gql_type
          end
          assoc_name = name

          Class.new(GraphQL::Schema::Union) do
            graphql_name gql_name
            description "Union type for polymorphic association #{assoc_name}"
            possible_types(*resolved_types)
            define_method(:resolve_type) { |obj, _ctx| TypeBuilder.resolve_polymorphic_type(obj, assoc_name) }
          end
        end

        def self.add_association_field(type_class, name, kind, assoc_type, ar_assoc)
          case kind
          when :has_many
            type_class.field name, [assoc_type], null: false
          when :has_one, :belongs_to
            nullable = kind != :belongs_to || !ar_assoc || ar_assoc.options[:optional] != false
            type_class.field name, assoc_type, null: nullable
          end
        end
      end
    end
  end
end
