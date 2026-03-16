# frozen_string_literal: true

module Quail
  module SchemaBuilder
    # Helpers for defining fields and arguments on dynamically-built GraphQL types.
    module TypeDefinitions
      def self.define_query_fields(type_class, fields)
        fields.each do |name, config|
          f = type_class.field name, config[:type], null: config[:null]
          add_arguments(f, config[:arguments])
          next unless config[:resolve]

          type_class.define_method(name) do |**args|
            config[:resolve].call(object, args, context)
          end
        end
      end

      def self.define_extra_query_fields(type_class, extra_fields)
        extra_fields.each do |name, config|
          f = type_class.field name, config[:type], null: config[:null]
          add_arguments(f, config[:arguments])

          resolver = config[:resolver]
          type_class.define_method(name) do |**args|
            resolver.new(object, args, context).call
          end
        end
      end

      def self.define_subscription_fields(type_class, fields)
        fields.each do |name, config|
          f = type_class.field name, config[:type],
                               null: config[:null],
                               description: config[:description],
                               subscription_scope: config[:subscription_scope]
          add_arguments(f, config[:arguments])
        end
      end

      def self.add_arguments(field, arguments)
        arguments&.each do |arg_name, arg_config|
          field.argument arg_name, arg_config[:type], required: arg_config[:required]
        end
      end
    end
  end
end
