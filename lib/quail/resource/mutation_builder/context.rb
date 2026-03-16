# frozen_string_literal: true

module Quail
  module Resource
    module MutationBuilder
      # Holds the shared context needed by all mutation builders.
      MutationContext = Struct.new(:resource_class) do
        def model          = resource_class.model_class
        def type_class     = resource_class.graphql_type
        def underscore_name = model.name.underscore
        def writable       = resource_class.writable_attributes || MutationBuilder.default_writable(model)
        def subscriptions  = resource_class.subscription_definitions
        def base           = Quail.base_mutation_class || GraphQL::Schema::RelayClassicMutation
      end
    end
  end
end
