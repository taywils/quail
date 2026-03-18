# frozen_string_literal: true

module Quail
  # Rails integration for Quail: configures eager loading and schema resolution.
  class Railtie < Rails::Railtie
    config.quail = ActiveSupport::OrderedOptions.new
    config.quail.schema_class = nil

    initializer "quail.autoload_paths", before: :set_autoload_paths do |app|
      # These subdirectories define top-level constants (e.g. UserResource, not Resources::UserResource)
      # Note: types/ is excluded because custom types use the Types:: namespace by convention
      %w[resources queries mutations].each do |subdir|
        path = Rails.root.join("app/graphql/#{subdir}").to_s
        next unless Dir.exist?(path)

        app.config.autoload_paths << path
        app.config.eager_load_paths << path
      end
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
