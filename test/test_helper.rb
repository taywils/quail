# frozen_string_literal: true

$LOAD_PATH.unshift File.expand_path("../lib", __dir__)
<<<<<<< Updated upstream
=======
<<<<<<< Updated upstream
=======
>>>>>>> Stashed changes

# ── Lightweight Rails / ActiveRecord stubs ──────────────────────────────
# These let us load the gem without pulling in a full Rails application.
# We only fake the surface area that Quail touches at require-time.

require "active_support"
require "active_support/concern"
require "active_support/ordered_options"
require "active_support/core_ext/string/inflections"

# Minimal Rails stub so `require "rails"` inside lib/quail.rb doesn't explode.
# graphql-ruby's own Railtie also inherits from Rails::Railtie, so we need
# a config that behaves enough like the real one.
unless defined?(Rails)
  module Rails
    class Railtie
      def self.config
        @config ||= begin
          c = ActiveSupport::OrderedOptions.new
          c.eager_load_namespaces = []
          c
        end
      end

      def self.initializer(*, **); end
      def self.rake_tasks; end
    end
  end
<<<<<<< Updated upstream
=======

>>>>>>> Stashed changes
end

unless defined?(ActionCable)
  module ActionCable
    module Channel
      class Base; end # rubocop:disable Lint/EmptyClass
    end
  end
end

unless defined?(ActionController)
  module ActionController
    class Parameters; end # rubocop:disable Lint/EmptyClass
  end
end

<<<<<<< Updated upstream
require "graphql"
=======
# Suppress method-redefinition warnings when graphql-ruby's Railtie and railties
# re-open the stub Rails::Railtie class defined above.
original_verbose = $VERBOSE
$VERBOSE = nil
require "graphql"
>>>>>>> Stashed changes
>>>>>>> Stashed changes
require "quail"
$VERBOSE = original_verbose

require "minitest/autorun"

# ── Fake ActiveRecord column ────────────────────────────────────────────
# Mimics the interface of ActiveRecord::ConnectionAdapters::Column that
# Quail::TypeMap and the builders rely on.
FakeColumn = Data.define(:name, :type, :null) do
  def initialize(name:, type: :string, null: true)
    super
  end
end
