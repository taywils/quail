# frozen_string_literal: true

require "rails/generators/base"

module Quail
  module Generators
    # Generates a customizable GraphQL ActionCable channel for subscriptions.
    class ChannelGenerator < Rails::Generators::Base
      desc "Generate a customizable GraphQL ActionCable channel"
      source_root File.expand_path("templates", __dir__)

      def create_channel
        template "graphql_channel_custom.rb.tt", "app/channels/graphql_channel.rb"
      end
    end
  end
end
