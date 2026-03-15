module Quail
  module SchemaBuilder
    def self.call(schema_class, &block)
      schema_class.instance_variable_set(:@quail_configured, false)

      schema_class.define_singleton_method(:multiplex) do |*args, **kwargs|
        Quail::SchemaBuilder.configure!(self) unless @quail_configured
        super(*args, **kwargs)
      end

      schema_class.define_singleton_method(:execute) do |*args, **kwargs|
        Quail::SchemaBuilder.configure!(self) unless @quail_configured
        super(*args, **kwargs)
      end

      schema_class.define_singleton_method(:to_definition) do |*args, **kwargs|
        Quail::SchemaBuilder.configure!(self) unless @quail_configured
        super(*args, **kwargs)
      end

      block&.call(schema_class)
    end

    def self.configure!(schema_class)
      if defined?(Rails)
        Dir[Rails.root.join("app/graphql/resources/**/*.rb")].each { |f| require f }
        Dir[Rails.root.join("app/graphql/mutations/**/*.rb")].each { |f| require f }
        Dir[Rails.root.join("app/graphql/queries/**/*.rb")].each { |f| require f }
      end

      Resource::TypeBuilder.build_all

      query_type = build_query_type
      mutation_type = build_mutation_type
      subscription_type = build_subscription_type

      schema_class.query(query_type) if query_type
      schema_class.mutation(mutation_type) if mutation_type
      schema_class.subscription(subscription_type) if subscription_type

      schema_class.use GraphQL::Dataloader unless schema_class.dataloader_class
      schema_class.use GraphQL::Subscriptions::ActionCableSubscriptions unless schema_class.subscriptions

      schema_class.instance_variable_set(:@quail_configured, true)
    end

    def self.build_query_type
      fields = {}
      Quail.registry.each_value { |r| fields.merge!(r.query_fields) }

      custom_queries = discover_custom_queries
      extra_query_fields = Quail.extra_queries
      return nil if fields.empty? && extra_query_fields.empty? && custom_queries.empty?

      base = Quail.base_object_class || Quail::Schema::Object

      Class.new(base) do
        graphql_name "Query"

        fields.each do |name, config|
          f = field name, config[:type], null: config[:null]

          config[:arguments]&.each do |arg_name, arg_config|
            f.argument arg_name, arg_config[:type], required: arg_config[:required]
          end

          if config[:resolve]
            define_method(name) do |**args|
              config[:resolve].call(object, args, context)
            end
          end
        end

        custom_queries.each do |name, klass|
          field name, resolver: klass
        end

        extra_query_fields.each do |name, config|
          f = field name,  config[:type], null: config[:null]

          config[:arguments]&.each do |arg_name, arg_config|
            f.argument arg_name, arg_config[:type], required: arg_config[:required]
          end

          resolver = config[:resolver]
          define_method(name) do |**args|
            resolver.new(object, args, context).call
          end
        end
      end
    end

    def self.build_mutation_type
      mutations = {}
      Quail.registry.each_value do |r|
        r.mutations.each { |action, klass| mutations[:"#{r.model_class.name.underscore}_#{action}"] = klass }
      end

      discover_custom_mutations.each { |name, klass| mutations[name] = klass }

      Quail.extra_mutations.each { |name, klass| mutations[name.to_sym] = klass }
      return nil if mutations.empty?

      base = Quail.base_object_class || GraphQL::Schema::Object

      Class.new(base) do
        graphql_name "Mutation"
        mutations.each { |name, klass| field name, mutation: klass }
      end
    end

    def self.discover_custom_mutations
      return {} unless defined?(Rails)

      mutations {}

      Dir[Rails.root.join("app/graphql/mutations/**/*.rb")].each do |f|
        relative = Pathname.new(f).relative_path_from(Rails.root.join("app/graphql/mutations"))
        class_name = "Mutations::#{relative.to_s.delete_suffix(".rb").camelize}"
        klass = class_name.constantize
        next unless klass < Quail::Mutation

        name = klass.name.demodulize.camelize(:lower).to_sym
        mutations[name] = klass
      end
      mutations
    end

    def self.discover_custom_queries
      return {} unless defined?(Rails)

      queries = {}

      Dir[Rails.root.join("app/graphql/queries/**/*.rb")].each do |f|
        relative = Pathname.new(f).relative_path_from(Rails.root.join("app/graphql/queries"))
        class_name = "Queries::#{relative.to_s.delete_suffix(".rb").camelize}"
        klass = class_name.constantize
        next unless klass < Quail::Query

        name = klass.name.demodulize.camelize(:lower).to_sym
        queries[name] = klass
      end
      queries
    end

    def self.build_subscription_type
      fields = {}
      Quail.registry.each_value { |r| fields.merge!(r.subscription_fields) }
      return nil if fields.empty?

      base = Quail.base_object_class || GraphQL::Schema::Object

      Class.new(base) do
        graphql_name "Subscription"

        fields.each do |name, config|
          f = field name, config[:type],
            null: config[:null],
            description: config[:description],
            subscription_scope: config[:subscription_scope]

          config[:arguments]&.each do |arg_name, arg_config|
            f.argument arg_name, arg_config[:type], required: arg_config[:required]
          end
        end
      end
    end
  end
end