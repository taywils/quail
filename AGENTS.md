# AGENTS.md

Instructions for AI coding agents contributing to the Quail gem.

## Overview

Quail is a Ruby gem that provides a Rails-first GraphQL layer with a declarative DSL built on top of graphql-ruby. Define a resource class with `include Quail::Resource` and Quail auto-generates GraphQL types, queries, mutations, and subscriptions from ActiveRecord models.

## Setup

```bash
bin/setup    # Install dependencies
```

## Running Tests & Linting

```bash
rake test    # Run minitest suite
rake rubocop # Run RuboCop linter
rake         # Run both (default task)
```

Always run `rake` before submitting changes to ensure tests pass and code style is clean.

## Code Style

- `frozen_string_literal: true` magic comment is required at the top of every Ruby file.
- Double quotes for all strings (enforced by RuboCop).
- Target Ruby version: 3.2.
- All new RuboCop cops are enabled (`NewCops: enable`).
- `Style/ParallelAssignment` is disabled.

## Project Structure

```
lib/
  quail.rb                        # Entry point, requires all modules
  quail/
    version.rb                    # Gem version constant
    type_map.rb                   # AR column type → GraphQL type mapping
    resource.rb                   # Quail::Resource mixin
    resource/
      dsl.rb                      # DSL class methods (attributes, associations, mutations, subscriptions)
      type_builder.rb             # Generates GraphQL object types
      query_builder.rb            # Generates find/list query fields
      mutation_builder.rb         # Generates create/update/delete mutations
      mutation_builder/
        context.rb                # Value object for mutation build context
        resolvers.rb              # Resolve methods for generated mutations
      subscription_builder.rb     # Generates subscription fields
    schema_builder.rb             # Assembles full schema from registry
    schema_builder/
      discovery.rb                # Discovers custom queries/mutations in app/graphql/
      type_definitions.rb         # Helpers for defining query/subscription fields
    controller_helpers.rb         # Concern for GraphQL controllers
    channel.rb                    # ActionCable channel base class
    railtie.rb                    # Rails integration (eager load, config, rake tasks)
    tasks/
      quail.rake                  # Rake tasks for schema dumping

lib/generators/quail/
  install_generator.rb            # rails g quail:install
  resource_generator.rb           # rails g quail:resource
  channel_generator.rb            # rails g quail:channel
  templates/                      # ERB templates for generators (.rb.tt)

test/
  test_helper.rb                  # Minitest setup with lightweight stubs
  test_*.rb                       # Unit tests
```

## Architecture

- `Quail.registry` maps ActiveRecord model classes to their resource classes. Resources self-register on `include Quail::Resource`.
- `SchemaBuilder` uses lazy hooks — it patches `execute`, `multiplex`, and `to_definition` on the schema class so resources are wired up on first use, not at boot.
- Builders (`TypeBuilder`, `QueryBuilder`, `MutationBuilder`, `SubscriptionBuilder`) are stateless modules that operate on resource class metadata.

## Testing Conventions

- Tests use lightweight stubs for Rails, ActiveRecord, and ActionCable (no full Rails boot).
- `FakeColumn` (a `Data.define` struct) stands in for AR column objects.
- Test files live in `test/` and follow the naming pattern `test_<module>.rb`.
- Use `minitest` assertions (`assert_equal`, `assert_includes`, `refute_nil`, etc.).

## Adding a New Feature

1. Implement the feature in the appropriate module under `lib/quail/`.
2. Add or update tests in `test/`.
3. Run `rake` to verify tests pass and linting is clean.
4. Update the README if the feature affects the public API or user-facing behavior.

## Dependencies

- `graphql` (>= 2.0) — underlying GraphQL implementation
- `activerecord` (>= 7.0) — ORM integration
- `railties` (>= 7.0) — Railtie, generators, rake tasks

Do not add new runtime dependencies without discussion.

## Documentation Site

Quail has a documentation site with LLMs.txt endpoints for additional context:

- `https://quail.taywils.me/llms.txt` — index of all documentation pages
- `https://quail.taywils.me/llms-full.txt` — full content of all pages
- `https://quail.taywils.me/llms-small.txt` — condensed version
