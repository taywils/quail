# frozen_string_literal: true

module Quail
  # Mixin that turns a class into a Quail resource with auto-generated GraphQL types,
  # queries, mutations, and subscriptions.
  module Resource
    def self.included(base)
      base.include DSL
      base.extend Lookup

      Quail.register(base)
    end

    # Class-level accessors for the generated GraphQL type, mutations, queries, and subscriptions.
    module Lookup
      def graphql_type
        @graphql_type
      end

      def mutations
        @mutations ||= MutationBuilder.call(self)
      end

      def query_fields
        @query_fields ||= QueryBuilder.call(self)
      end

      def subscription_fields
        @subscription_fields ||= SubscriptionBuilder.call(self)
      end
    end
  end
end
