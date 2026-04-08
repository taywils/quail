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
          fields[field_name] = build_subscription_class(type_class, model_name, event, config)
        end

        fields
      end

      def self.build_subscription_class(type_class, model_name, event, config)
        model_class = model_name.constantize
        sub_class = Class.new(GraphQL::Schema::Subscription) do
          graphql_name "#{model_name}#{event.to_s.capitalize}d"
          description "Triggered when a #{model_name} is #{event}d"
          payload_type type_class

          # Rehydrate Hash payloads (e.g. from delete snapshots) into model
          # instances so computed attributes that call associations still work.
          define_method(:update) do |**_args|
            return object unless object.is_a?(Hash)

            model_class.new(object).tap(&:readonly!)
          end
        end

        apply_scope(sub_class, config[:scope])
        sub_class
      end

      def self.apply_scope(sub_class, scope)
        return unless scope

        scope_key = scope.is_a?(Hash) ? scope.keys.first.to_sym : scope.to_sym
        sub_class.argument scope_key, GraphQL::Types::ID, required: true
      end
    end
  end
end
