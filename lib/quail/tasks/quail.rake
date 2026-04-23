# frozen_string_literal: true

namespace :quail do
  desc "Export the GraphQL schema to SDL (schema.graphql)"
  task dump: :environment do
    schema_class = Rails.application.config.quail.schema_class
    abort "Set config.quail.schema_class in your config/initializer" unless schema_class

    path = ENV.fetch("SCHEMA_PATH", "schema.graphql")
    File.write(path, schema_class.to_definition)
    puts "GraphQL Schema written to #{path}"
  end

  desc "Export the GraphQL schema to JSON (schema.json)"
  task dump_json: :environment do
    schema_class = Rails.application.config.quail.schema_class
    abort "Set config.quail.schema_class in your config/initializer" unless schema_class

    path = ENV.fetch("SCHEMA_PATH", "schema.json")
    File.write(path, schema_class.to_definition)
    result = schema_class.execute(GraphQL::Introspection::INTROSPECTION_QUERY)
    File.write(path, JSON.pretty_generate(result.to_h))
    puts "GraphQL JSON Schema written to #{path}"
  end
end
