# frozen_string_literal: true

require_relative "mutation_builder/context"
require_relative "mutation_builder/resolvers"

module Quail
  module Resource
    # Builds create, update, and delete GraphQL mutations for a resource.
    module MutationBuilder
      def self.call(resource_class)
        skipped = resource_class.skipped_mutations
        overrides = resource_class.mutation_overrides
        ctx = MutationContext.new(resource_class)
        mutations = {}

        %i[create update delete].each do |action|
          next if skipped.include?(action)

          mutations[action] = overrides[action] || build_mutation(action, ctx)
        end
        mutations
      end

      def self.build_mutation(action, ctx)
        case action
        when :create then build_create(ctx)
        when :update then build_update(ctx)
        when :delete then build_delete(ctx)
        end
      end

      def self.default_writable(model, resource_class = nil)
        excluded = %i[id created_at updated_at]
        excluded += polymorphic_columns(resource_class) if resource_class
        model.column_names.map(&:to_sym).reject { |c| excluded.include?(c) }
      end

      def self.polymorphic_columns(resource_class)
        return [] unless resource_class

        resource_class.association_definitions
                      .select { |_, config| config[:polymorphic] }
                      .flat_map do |name, _|
          [
            :"#{name}_type", :"#{name}_id"
          ]
        end
      end

      def self.resolve_scope(scope_config, record)
        return {} unless scope_config

        case scope_config
        when Symbol then { scope_config => record.public_send(scope_config) }
        when Hash
          key, value_proc = scope_config.first
          { key.to_sym => value_proc.call(record) }
        else {}
        end
      end

      def self.add_writable_arguments(klass, model, writable, required:)
        writable.each do |attr|
          col = model.columns_hash[attr.to_s]
          next unless col

          klass.argument attr, TypeMap.graphql_types(col), required: required ? !TypeMap.nullable?(col) : false
        end
      end

      def self.add_result_fields(klass, underscore_name, type_class)
        klass.field underscore_name.to_sym, type_class, null: true
        klass.field :errors, [GraphQL::Types::String], null: false
      end

      def self.trigger_subscription(gql_context, subs, event, underscore_name, record)
        sub_config = subs[event]
        return unless sub_config

        scope_args = resolve_scope(sub_config[:scope], record)
        gql_context.schema.subscriptions&.trigger(:"#{underscore_name}_#{event}d", scope_args, record)
      end

      def self.capture_delete_snapshot(subs, record)
        return nil unless subs[:delete]

        { attributes: record.attributes, scope_args: resolve_scope(subs[:delete][:scope], record) }
      end

      def self.trigger_delete_event(gql_context, name, snapshot)
        return unless snapshot

        gql_context.schema.subscriptions&.trigger(:"#{name}_deleted", snapshot[:scope_args], snapshot[:attributes])
      end

      def self.build_create(ctx)
        model = ctx.model
        name = ctx.underscore_name
        subs = ctx.subscriptions
        klass = new_mutation_class(ctx, "Create", model)
        add_writable_arguments(klass, model, ctx.writable, required: true)
        add_result_fields(klass, name, ctx.type_class)
        klass.define_method(:resolve) { |**attrs| Resolvers.create(model, name, subs, context, attrs) }
        klass
      end

      def self.build_update(ctx)
        model, name, subs = ctx.model, ctx.underscore_name, ctx.subscriptions
        klass = new_mutation_class(ctx, "Update", model)
        klass.argument :id, GraphQL::Types::ID, required: true
        add_writable_arguments(klass, model, ctx.writable, required: false)
        add_result_fields(klass, name, ctx.type_class)
        klass.define_method(:resolve) do |id:, **attrs|
          Resolvers.update(model, name, subs, context, { id: id, attrs: attrs })
        end
        klass
      end

      def self.build_delete(ctx)
        model = ctx.model
        name = ctx.underscore_name
        subs = ctx.subscriptions
        klass = new_mutation_class(ctx, "Delete", model)
        klass.argument :id, GraphQL::Types::ID, required: true
        klass.field :success, GraphQL::Types::Boolean, null: false
        klass.field :errors, [GraphQL::Types::String], null: false
        klass.define_method(:resolve) { |id:| Resolvers.delete(model, name, subs, context, id) }
        klass
      end

      def self.new_mutation_class(ctx, prefix, model)
        Class.new(ctx.base) do
          graphql_name "#{prefix}#{model.name}"
          description "#{prefix}s a #{model.name}"
        end
      end
    end
  end
end
