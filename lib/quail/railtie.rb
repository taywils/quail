# frozen_string_literal: true

module Quail
  # Rails integration for Quail: configures eager loading and schema resolution.
  class Railtie < Rails::Railtie
    config.quail = ActiveSupport::OrderedOptions.new
    config.quail.schema_class = nil

    initializer "quail.autoload_paths", before: :set_autoload_paths do |app|
      # These subdirectories define top-level constants (e.g. UserResource, not Resources::UserResource)
      # Note: types/ is excluded because custom types use the Types:: namespace by convention
      paths = %w[resources queries mutations subscriptions].filter_map do |subdir|
        path = Rails.root.join("app/graphql/#{subdir}").to_s
        path if Dir.exist?(path)
      end

      app.config.autoload_paths += paths
      app.config.eager_load_paths += paths
    end

    # Tell Zeitwerk to ignore these subdirectories from the parent app/graphql/ root
    # so they are only loaded as top-level autoload roots (no module namespace).
    initializer "quail.zeitwerk_ignore", before: :setup_main_autoloader do
      Rails.autoloaders.main.ignore(
        Rails.root.join("app/graphql/resources"),
        Rails.root.join("app/graphql/queries"),
        Rails.root.join("app/graphql/mutations"),
        Rails.root.join("app/graphql/subscriptions")
      )
    end

    config.after_initialize do |app|
      schema = app.config.quail.schema_class
      app.config.quail.schema_class = schema.constantize if schema.is_a?(String)
    end

    rake_tasks do
      load File.expand_path("tasks/quail.rake", __dir__)
    end
  end
end
