# frozen_string_literal: true

module Quail
  module Resource
    module MutationBuilder
      def self.call(resource_class)
        skipped = resource_class.skipped_mutations
        overrides = resource_class.mutation_overrides
        model = resource_class.model_class
        type_class = resource_class.graphql_type
        mutations = {}

        %i[create update delete].each do |action|
          next if skipped.include?(action)

          mutations[action] = (overrides[action] || build_mutation(action, resource_class, model, type_class))
        end

        mutations
      end

      def self.build_mutation(action, resource_class, model, type_class)
        model_name = model.name
        writable = resource_class.writable_attributes || default_writable(model)
        subscriptions = resource_class.subscription_definitions

        base = Quail.base_mutation_class || GraphQL::Schema::RelayClassicMutation

        case action
        when :create then build_create(base, model, model_name, type_class, writable, subscriptions)
        when :update then build_update(base, model, model_name, type_class, writable, subscriptions)
        when :delete then build_delete(base, model, model_name, type_class, subscriptions)
        end
      end

      def self.default_writable(model)
        model.column_names.map(&:to_sym).reject { |column| %i[id created_at updated_at].include?(column) }
      end

      def self.resolve_scope(scope_config, record)
        return {} unless scope_config

        case scope_config
        when Symbol
          { scope_config => record.public_send(scope_config) }
        when Hash
          key, value_proc = scope_config.first
          { key.to_sym => value_proc.call(record) }
        else
          {}
        end
      end

      def self.build_create(base, model, model_name, type_class, writable, subscriptions)
        Class.new(base) do
          graphql_name "Create#{model_name}"
          description "Creates a #{model_name}"

          writable.each do |attr|
            col = model.columns_hash[attr.to_s]
            next unless col

            argument attr, TypeMap.graphql_types(col), required: !TypeMap.nullable?(col)
          end

          field model_name.underscore.to_sym, type_class, null: true
          field :errors, [GraphQL::Types::String], null: false

          define_method(:resolve) do |**attrs|
            record = model.new(attrs)
            if record.save
              if (sub_config = subscriptions[:create])
                scope_args = MutationBuilder.resolve_scope(sub_config[:scope], record)
                context.schema.subscriptions&.trigger(:"#{model_name.underscore}_created", scope_args, record)
              end
              { model_name.underscore.to_sym => record, errors: [] }
            else
              { model_name.underscore.to_sym => nil, errors: record.errors.full_messages }
            end
          end
        end
      end

      def self.build_update(base, model, model_name, type_class, writable, subscriptions)
        Class.new(base) do
          graphql_name "Update#{model_name}"
          description "Updates a #{model_name}"

          argument :id, GraphQL::Types::ID, required: true

          writable.each do |attr|
            col = model.columns_hash[attr.to_s]
            next unless col

            argument attr, TypeMap.graphql_types(col), required: false
          end

          field model_name.underscore.to_sym, type_class, null: true
          field :errors, [GraphQL::Types::String], null: false

          define_method(:resolve) do |id:, **attrs|
            record = model.find_by(id: id)
            return { model_name.underscore.to_sym => nil, errors: ["#{model_name} not found"] } unless record

            if record.update(attrs.compact)
              if (sub_config = subscriptions[:update])
                scope_args = MutationBuilder.resolve_scope(sub_config[:scope], record)
                context.schema.subscriptions&.trigger(:"#{model_name.underscore}_updated", scope_args, record)
              end
              { model_name.underscore.to_sym => record, errors: [] }
            else
              { model_name.underscore.to_sym => nil, errors: record.errors.full_messages }
            end
          end
        end
      end

      def self.build_delete(base, model, model_name, _type_class, subscriptions)
        Class.new(base) do
          graphql_name "Delete#{model_name}"
          description "Delete a #{model_name}"

          argument :id, GraphQL::Types::ID, required: true

          field :success, GraphQL::Types::Boolean, null: false
          field :errors, [GraphQL::Types::String], null: false

          define_method(:resolve) do |id:|
            record = model.find_by(id: id)
            return { success: false, errors: ["#{model_name} not found"] } unless record

            if (sub_config = subscriptions[:delete])
              snapshot = record.attributes
              scope_args = MutationBuilder.resolve_scope(sub_config[:scope], record)
            end

            if record.destroy
              if snapshot
                context.schema.subscriptions&.trigger(:"#{model_name.underscore}_deleted", scope_args, snapshot)
              end
              { success: true, errors: [] }
            else
              { success: false, errors: record.errors.full_messages }
            end
          end
        end
      end
    end
  end
end
