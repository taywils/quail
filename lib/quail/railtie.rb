module Quail
  class Railtie < Rails::Railtie
    config.quail = ActiveSupport::OrderedOptions.new
    config.quail.schema_class = nil

    initializer "quail.eager_load_resources" do |app|
      app.config.eager_load_paths += Dir[Rails.root.join("app/graphql/resources")]
      app.config.eager_load_paths += Dir[Rails.root.join("app/graphql/queries")]
    end

    config.after_initialize do |app|
      schema = app.config.quail.schema_class
      if schema.is_a?(String)
        app.config.quail.schema_class = schema.constantize
      end
    end

    rake_tasks do
      load File.expand_path("tasks/quail.rake", __dir__)
    end
  end
end