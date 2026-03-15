module Quail
  module Resource
    def self.include(base)
      base.include DSL
      base.include Lookup

      Quail.register(base)
    end

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