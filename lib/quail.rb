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

  # Wrapper aliases — insulate consuming apps from graphql-ruby internals.
  Object = GraphQL::Schema::Object
  InputObject = GraphQL::Schema::InputObject
  Enum = GraphQL::Schema::Enum

  # Base mutation class with subscription trigger helper.
  class Mutation < GraphQL::Schema::RelayClassicMutation
    # Trigger a Quail subscription event from a custom mutation.
    #
    #   trigger_subscription(:link_created, { user_id: user.id }, link)
    #
    # The arguments must match the subscription's scope declared via subscribe_on.
    def trigger_subscription(event, scope_args, record)
      context.schema.subscriptions&.trigger(event, scope_args, record)
    end
  end

  # Base resolver class for custom Quail queries with symbol-based type resolution.
  class Query < GraphQL::Schema::Resolver
    # Allows symbol-based type references that resolve to resource graphql types.
    #
    # type :user, null: true              # resolves to UserResource.graphql_type
    # type [:article], null: false        # resolves to [ArticleResource.graphql_type]
    # type :subscription, connection: true, null: false  # resolves to SubscriptionType.connection_type
    # type Types::SessionType, null: false # pass-through, works as normal
    #
    def self.type(type_arg = nil, null: nil, connection: false)
      resolved = resolve_type_arg(type_arg, connection: connection)
      super(resolved, null: null)
    end

    def self.resolve_type_arg(type_arg, connection: false)
      if type_arg.is_a?(Symbol)
        name = type_arg
        connection ? -> { resolve_resource_type(name).connection_type } : -> { resolve_resource_type(name) }
      elsif type_arg.is_a?(Array) && type_arg.length == 1 && type_arg.first.is_a?(Symbol)
        name = type_arg.first
        -> { [resolve_resource_type(name)] }
      else
        type_arg
      end
    end
    private_class_method :resolve_type_arg

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
