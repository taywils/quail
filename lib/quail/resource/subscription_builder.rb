# frozen_string_literal: true

module Quail
  module Resource
    # Builds GraphQL subscription fields for a resource based on its subscription definitions.
    module SubscriptionBuilder
      def self.call(resource_class)
        subs = resource_class.subscription_definitions
        return {} if subs.empty?

        model_name = resource_class.model_class.name
        type_class = resource_class.graphql_type
        fields = {}

        subs.each do |event, config|
          field_name = :"#{model_name.underscore}_#{event}d"
          fields[field_name] = build_field_config(type_class, model_name, event, config)
        end

        fields
      end

      def self.build_field_config(type_class, model_name, event, config)
        field_config = { type: type_class, null: false, description: "Triggered when a #{model_name} is #{event}d" }
        apply_scope(field_config, config[:scope])
        field_config
      end

      def self.apply_scope(field_config, scope)
        return unless scope

        scope_key = scope.is_a?(Hash) ? scope.keys.first.to_sym : scope.to_sym
        field_config[:subscription_scope] = scope_key
        field_config[:arguments] = { scope_key => { type: GraphQL::Types::ID, required: true } }
      end
    end
  end
end
