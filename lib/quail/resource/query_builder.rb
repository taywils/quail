# frozen_string_literal: true

module Quail
  module Resource
    # Builds find and list GraphQL query fields for a resource.
    module QueryBuilder
      def self.call(resource_class)
        return {} if resource_class.skipped_queries.include?(:all)

        model = resource_class.model_class
        type_class = resource_class.graphql_type
        skipped = resource_class.skipped_queries
        fields = {}

        fields.merge!(build_find_field(model, type_class)) unless skipped.include?(:find)
        fields.merge!(build_list_field(model, type_class)) unless skipped.include?(:list)
        fields
      end

      def self.build_find_field(model, type_class)
        {
          model.name.underscore.to_sym => {
            type: type_class,
            null: true,
            arguments: { id: { type: GraphQL::Types::ID, required: true } },
            resolve: ->(_obj, args, _ctx) { model.find_by(id: args[:id]) }
          }
        }
      end

      def self.build_list_field(model, type_class)
        {
          model.name.underscore.pluralize.to_sym => {
            type: type_class.connection_type,
            null: false,
            resolve: ->(_obj, _args, _ctx) { model.all }
          }
        }
      end
    end
  end
end
