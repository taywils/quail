# frozen_string_literal: true

module Quail
  module Resource
    module SubscriptionBuilder
      def self.call(resource_class)
        subs = resource_class.subscription_definitions
        return {} if subs.empty?

        model_name = resource_class.model_class.name
        type_class = resource_class.graphql_type
        fields = {}

        subs.each do |event, config|
          field_name = :"{model_name.underscore}_#{event}d"
          field_config = {
            type: type_class,
            null: false,
            description: "Triggered when a #{model_name} is #{event}d"
          }

          if (scope = config[:scope])
            scope_key = scope.is_a?(Hash) ? scope.keys.first.to_sym : scope.to_sym
            field_config[:subscription_scope] = scope_key
            field_config[:arguments] = { scope_key => { type: GraphQL::Types::ID, required: true } }
          end

          fields[field_name] = field_config
        end

        fields
      end
    end
  end
end
