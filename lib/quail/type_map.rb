# frozen_string_literal: true

module Quail
  # Maps ActiveRecord column types to their corresponding GraphQL type classes.
  module TypeMap
    MAPPING = {
      integer: GraphQL::Types::Int,
      bigint: GraphQL::Types::BigInt,
      float: GraphQL::Types::Float,
      decimal: GraphQL::Types::Float,
      string: GraphQL::Types::String,
      text: GraphQL::Types::String,
      boolean: GraphQL::Types::Boolean,
      date: GraphQL::Types::ISO8601Date,
      datetime: GraphQL::Types::ISO8601DateTime,
      time: GraphQL::Types::ISO8601DateTime,
      json: GraphQL::Types::JSON,
      jsonb: GraphQL::Types::JSON
    }.freeze

    def self.graphql_types(column)
      return GraphQL::Types::ID if column.name == "id"

      MAPPING[column.type] || GraphQL::Types::String
    end

    def self.nullable?(column)
      column.null
    end
  end
end
