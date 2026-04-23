# frozen_string_literal: true

module Quail
  module SchemaBuilder
    # Discovers custom mutation and query classes from the app/graphql directory.
    module Discovery
      def self.custom_mutations
        discover_classes("mutations", Quail::Mutation)
      end

      def self.custom_queries
        discover_classes("queries", Quail::Query)
      end

      def self.discover_classes(dir, base_class)
        return {} unless defined?(Rails)

        result = {}
        Dir[Rails.root.join("app/graphql/#{dir}/**/*.rb")].each do |f|
          name, klass = resolve_class(f, dir, base_class)
          result[name] = klass if klass
        end
        result
      end

      def self.resolve_class(file, dir, base_class)
        relative = Pathname.new(file).relative_path_from(Rails.root.join("app/graphql/#{dir}"))
        class_name = "#{dir.camelize}::#{relative.to_s.delete_suffix(".rb").camelize}"
        klass = class_name.constantize
        return nil unless klass < base_class

        [klass.name.demodulize.camelize(:lower).to_sym, klass]
      end
    end
  end
end
