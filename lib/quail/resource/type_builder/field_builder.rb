# frozen_string_literal: true

module Quail
  module Resource
    module TypeBuilder
      # Defines scalar (column-backed) and computed fields on a GraphQL type.
      module FieldBuilder
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

            define_single_computed_field(type_class, name, config)
          end
        end

        def self.define_single_computed_field(type_class, name, config)
          gql_type = config[:graphql_type] || GraphQL::Types::String
          nullable = config[:null].nil? || config[:null]
          blk = config[:block]
          type_class.field name, gql_type, null: nullable
          if blk.arity.abs >= 3
            type_class.define_method(name) { blk.call(object, nil, context) }
          else
            type_class.define_method(name) { blk.call(object) }
          end
        end
      end
    end
  end
end
