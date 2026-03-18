# frozen_string_literal: true

require "rails/generators/base"

module Quail
  module Generators
    # Sets up Quail in a Rails app: schema, controller, channel, initializer, and directories.
    class InstallGenerator < Rails::Generators::Base
      desc "Set up Quail: schema, controller, route, initializer, and resource directory"
      source_root File.expand_path("templates", __dir__)

      class_option :schema_name,
                   type: :string,
                   default: nil,
                   desc: "Name for the schema class (default: AppSchema)"

      class_option :skip_controller,
                   type: :boolean,
                   default: nil,
                   desc: "Skip generating the GraphQL controller"

      class_option :skip_channel,
                   type: :boolean,
                   default: false,
                   desc: "Skip generating the ActionCable channel"

      def create_graphql_directories
        %w[resources mutations queries subscriptions types].each do |dir|
          empty_directory "app/graphql/#{dir}"
          create_file "app/graphql/#{dir}/.keep"
        end
      end

      def create_schema
        template "schema.rb.tt", "app/graphql/#{schema_name.underscore}.rb"
      end

      def create_controller
        return if options[:skip_controller]

        template "graphql_controller.rb.tt", "app/controllers/graphql_controller.rb"
      end

      def create_channel
        return if options[:skip_channel]

        template "graphql_channel.rb.tt", "app/channels/graphql_channel.rb"
      end

      def create_initializer
        template "initializer.rb.tt", "config/initializers/quail.rb"
      end

      def add_route
        return if options[:skip_controller]

        route 'post "/graphql", to: "graphql#execute"'
      end

      private

      def schema_name
        options[:schema_name] || "AppSchema"
      end

      def app_name
        if Rails.application.class.respond_to?(:module_parent_name)
          Rails.application.class.module_parent_name
        else
          Rails.application.class.parent_name
        end
      end
    end
  end
end
