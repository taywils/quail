# frozen_string_literal: true

require_relative "lib/quail/version"

Gem::Specification.new do |spec|
  spec.name = "quail"
  spec.version = Quail::VERSION
  spec.authors = ["Demetrious Wilson"]
  spec.email = ["demetriouswilson@gmail.com"]

  spec.summary = "Rails-first GraphQL with an Alba-inspired declarative DSL"
  spec.description = "Wraps graphql-ruby with a convention-over-configuration approach. " \
                     "Declare resources with a simple DSL and get types, queries, mutations, " \
                     "and subscriptions auto-generated from your ActiveRecord models."
  spec.homepage = "https://github.com/taywils/quail"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.2.0"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = "https://github.com/taywils/quail"
  spec.metadata["rubygems_mfa_required"] = "true"

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  gemspec = File.basename(__FILE__)
  spec.files = IO.popen(%w[git ls-files -z], chdir: __dir__, err: IO::NULL) do |ls|
    ls.readlines("\x0", chomp: true).reject do |f|
      (f == gemspec) ||
        f.start_with?(*%w[bin/ Gemfile .gitignore test/ .github/ .rubocop.yml])
    end
  end

  spec.require_paths = ["lib"]

  # Gem Dependencies
  spec.add_dependency "activerecord", ">= 7.0"
  spec.add_dependency "graphql", ">= 2.0"
  spec.add_dependency "railties", ">= 7.0"

  # For more information and examples about making a new gem, check out our
  # guide at: https://bundler.io/guides/creating_gem.html
end
