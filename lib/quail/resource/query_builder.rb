module Quail
  module Resource
    module QueryBuilder
      def self.call(resource_class)
        return {} if resource_class.skipped_queries.include?(:all)

        model = resource_class.model_class
        model_name = model.name
        type_class = resource_class.graphql_type
        fields = {}

        unless resource_class.skipped_queries.include?(:find)
          fields[:"#{model_name.underscore}"] = {
            type: type_class,
            null: true,
            arguments: { id: { type: GraphQL::Types::ID, required: true } },
            resolve: ->(obj, args, ctx) { model.find_by(id: args[:id]) }
          }
        end

        unless resource_class.skipped_queries.include?(:list)
          fields[:"#{model_name.underscore.pluralize}"] = {
            type: type_class.connection_type,
            null: false,
            resolve: ->(obj, args, ctx) { model.all }
          }
        end

        fields
      end
    end
  end
end