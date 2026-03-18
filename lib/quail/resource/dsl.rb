# frozen_string_literal: true

module Quail
  module Resource
    # DSL for declaring attributes, associations, mutations, and subscriptions on a resource.
    module DSL
      def self.included(base)
        base.extend ClassMethods
      end

      # Class-level DSL methods mixed into resource classes.
      module ClassMethods
        def model(klass = nil)
          if klass
            @model_class = klass
          else
            @model ||= name.delete_suffix("Resource").constantize
          end
        end
        alias model_class model

        def attribute_definitions
          @attribute_definitions ||= {}
        end

        def attributes(*names)
          names.each { |name| attribute_definitions[name] = { type: :column } }
        end

        def attribute(name, type: nil, null: nil, &block)
          attribute_definitions[name] = { type: :computed, graphql_type: type, null: null, block: block }
        end

        def association_definitions
          @association_definitions ||= {}
        end

        def has_many(name, resource: nil, **options)
          association_definitions[name] = { kind: :has_many, resource: resource, **options }
        end

        def has_one(name, resource: nil, **options)
          association_definitions[name] = { kind: :has_one, resource: resource, **options }
        end

        def belongs_to(name, resource: nil, **options)
          if options[:polymorphic]
            validate_polymorphic_options!(options[:polymorphic])
            options[:polymorphic_types] = options[:polymorphic][:types]
            options[:union_name] = options[:polymorphic][:union_name] if options[:polymorphic][:union_name]
            options[:polymorphic] = true
          end
          association_definitions[name] = { kind: :belongs_to, resource: resource, **options }
        end

        def skip_mutations(*actions)
          @skipped_mutations = actions.map(&:to_sym)
        end

        def skipped_mutations
          @skipped_mutations || []
        end

        def override_mutation(action, klass)
          mutation_overrides[action.to_sym] = klass
        end

        def mutation_overrides
          @mutation_overrides ||= {}
        end

        def writable_attributes(*names)
          if names.any?
            @writable_attributes = names.map(&:to_sym)
          else
            @writable_attributes
          end
        end

        def subscription_definitions
          @subscription_definitions ||= {}
        end

        def subscribe_on(*events, scope: nil)
          if scope && !scope.is_a?(Symbol) && !scope.is_a?(Hash)
            raise ArgumentError, "subscribe_on scope: must be a Symbol or Hash { key: proc }, got #{scope.class}"
          end

          events.each { |event| subscription_definitions[event.to_sym] = { scope: scope } }
        end

        def skip_queries(*actions)
          @skipped_queries = actions.map(&:to_sym)
        end

        def skipped_queries
          @skipped_queries || []
        end

        private

        def validate_polymorphic_options!(poly_opt)
          unless poly_opt.is_a?(Hash) && poly_opt.key?(:types)
            raise ArgumentError,
                  "polymorphic requires a Hash with a :types key, e.g. polymorphic: { types: [FooResource] }"
          end
          return unless poly_opt[:types].empty?

          raise ArgumentError, "polymorphic :types must contain at least one resource class or class name string"
        end
      end
    end
  end
end
