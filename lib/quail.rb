# frozen_string_literal: true

require "graphql"
require "rails"

require_relative "quail/version"
require_relative "quail/type_map"
require_relative "quail/resource/dsl"
require_relative "quail/resource/type_builder"
require_relative "quail/resource/query_builder"
require_relative "quail/resource/mutation_builder"
require_relative "quail/resource/subscription_builder"
require_relative "quail/resource"
require_relative "quail/schema_builder"
require_relative "quail/controller_helpers"
require_relative "quail/channel"
require_relative "quail/railtie"

# Top-level namespace for the Quail GraphQL resource framework.
module Quail
  class Error < StandardError; end

  # TODO: Add more alias to better encapsulate the underlying GraphQL
  # TODO: Move these into a concern/mixin
  Mutation = GraphQL::Schema::RelayClassicMutation
  Object = GraphQL::Schema::Object

  # Base resolver class for custom Quail queries with symbol-based type resolution.
  class Query < GraphQL::Schema::Resolver
    # Allows symbol-based type references that resolve to resource graphql types.
    #
    # type :user, null: true        # resolves to UserResource.graphql_type
    # type [:article], null: false  # resolves to [ArticleResource.graphql_type]
    # type Types::SessionType, null: false # pass-through, works as normal
    #
    def self.type(type_arg = nil, **)
      if type_arg.is_a?(Symbol)
        resource_name = type_arg
        super(-> { resolve_resource_type(resource_name) }, **)
      elsif type_arg.is_a?(Array) && type_arg.length == 1 && type_arg.first.is_a?(Symbol)
        resource_name = type_arg.first
        super(-> { [resolve_resource_type(resource_name)] }, **)
      else
        super
      end
    end

    def self.resolve_resource_type(name)
      klass = "#{name.to_s.camelize}Resource".constantize
      klass.graphql_type
    end
  end

  class << self
    attr_accessor :base_object_class, :base_mutation_class, :base_input_class

    def registry
      @registry ||= {}
    end

    def extra_mutations
      @extra_mutations ||= {}
    end

    def extra_queries
      @extra_queries ||= {}
    end

    # Register a resource class, keyed by its inferred model
    def register(resource_class)
      registry[resource_class.model_class] = resource_class
    end

    # Lookup resource for a given model class
    def resource_for(model_class)
      registry[model_class]
    end
  end
end
