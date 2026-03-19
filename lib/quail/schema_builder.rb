# frozen_string_literal: true

require_relative "schema_builder/discovery"
require_relative "schema_builder/type_definitions"

module Quail
  # Assembles the full GraphQL schema from registered resources, custom queries, and mutations.
  module SchemaBuilder
    def self.call(schema_class, &block)
      schema_class.instance_variable_set(:@quail_configured, false)
      install_lazy_hooks(schema_class)
      block&.call(schema_class)
    end

    def self.install_lazy_hooks(schema_class)
      %i[multiplex execute to_definition].each do |method_name|
        schema_class.define_singleton_method(method_name) do |*args, **kwargs|
          Quail::SchemaBuilder.configure!(self) unless @quail_configured
          super(*args, **kwargs)
        end
      end
    end

    def self.configure!(schema_class)
      eager_load_resources if defined?(Rails)
      Resource::TypeBuilder.build_all
      eager_load_resolvers if defined?(Rails)
      attach_root_types(schema_class)
      install_defaults(schema_class)
      schema_class.instance_variable_set(:@quail_configured, true)
    end

    def self.eager_load_resources
      Dir[Rails.root.join("app/graphql/resources/**/*.rb")].each { |f| require f }
    end

    def self.eager_load_resolvers
      %w[mutations queries].each do |dir|
        Dir[Rails.root.join("app/graphql/#{dir}/**/*.rb")].each { |f| require f }
      end
    end

    def self.attach_root_types(schema_class)
      query_type = build_query_type
      mutation_type = build_mutation_type
      subscription_type = build_subscription_type

      schema_class.query(query_type) if query_type
      schema_class.mutation(mutation_type) if mutation_type
      schema_class.subscription(subscription_type) if subscription_type
    end

    def self.install_defaults(schema_class)
      schema_class.use GraphQL::Dataloader unless schema_class.dataloader_class
      schema_class.use GraphQL::Subscriptions::ActionCableSubscriptions unless schema_class.subscriptions
    end

    def self.build_query_type
      fields = collect_resource_query_fields
      custom = Discovery.custom_queries
      extra = Quail.extra_queries
      return nil if fields.empty? && extra.empty? && custom.empty?

      create_query_class(fields, custom, extra)
    end

    def self.create_query_class(fields, custom, extra)
      base = Quail.base_object_class || GraphQL::Schema::Object
      Class.new(base) do
        graphql_name "Query"
        TypeDefinitions.define_query_fields(self, fields)
        custom.each { |name, klass| field name, resolver: klass }
        TypeDefinitions.define_extra_query_fields(self, extra)
      end
    end

    def self.collect_resource_query_fields
      fields = {}
      Quail.registry.each_value { |r| fields.merge!(r.query_fields) }
      fields
    end

    def self.build_mutation_type
      mutations = collect_all_mutations
      return nil if mutations.empty?

      base = Quail.base_object_class || GraphQL::Schema::Object
      Class.new(base) do
        graphql_name "Mutation"
        mutations.each { |name, klass| field name, mutation: klass }
      end
    end

    def self.collect_all_mutations
      mutations = collect_resource_mutations
      Discovery.custom_mutations.each { |name, klass| mutations[name] = klass }
      Quail.extra_mutations.each { |name, klass| mutations[name.to_sym] = klass }
      mutations
    end

    def self.collect_resource_mutations
      mutations = {}
      Quail.registry.each_value do |r|
        r.mutations.each { |action, klass| mutations[:"#{r.model_class.name.underscore}_#{action}"] = klass }
      end
      mutations
    end

    def self.build_subscription_type
      fields = {}
      Quail.registry.each_value { |r| fields.merge!(r.subscription_fields) }
      return nil if fields.empty?

      base = Quail.base_object_class || GraphQL::Schema::Object
      Class.new(base) do
        graphql_name "Subscription"
        TypeDefinitions.define_subscription_fields(self, fields)
      end
    end
  end
end
