# Quail

A Rails-first GraphQL library with a declarative, [Alba](https://github.com/okuramasafumi/alba)-inspired DSL built on top of [graphql-ruby](https://github.com/rmosolgo/graphql-ruby).

Quail exists because working with GraphQL in Rails shouldn't feel like leaving Rails. The philosophy is straightforward:

- Convention over configuration. Define a resource, get types, queries, mutations, and subscriptions generated for you.
- Bring Your Own Auth. Quail never touches authentication. Plug in Devise, JWT, or whatever you use.
- Real-time via ActionCable. Subscriptions are powered by ActionCable out of the box — declare `subscribe_on` in a resource and Quail wires up the GraphQL subscription fields, triggers, and the ActionCable channel automatically.
- A Rails-style wrapper DSL for graphql-ruby. Generators, rake tasks, and patterns that feel familiar.
- Alba-style separate resources via `include Quail::Resource`. Your ActiveRecord models stay clean. Your GraphQL layer lives in its own space.

## Installation

Add Quail to your Gemfile:

```bash
bundle add quail
```

Or install it directly:

```bash
gem install quail
```

## Quick Start

Run the install generator to scaffold your schema, controller, initializer, and resource directory:

```bash
rails generate quail:install
```

This creates:

- `app/graphql/app_schema.rb` — your GraphQL schema
- `app/graphql/resources/` — where your resource files live
- `app/graphql/mutations/` — for custom mutation classes
- `app/graphql/queries/` — for custom query resolvers
- `app/graphql/types/` — for custom GraphQL types
- `app/controllers/graphql_controller.rb` — a ready-to-go controller
- `app/channels/graphql_channel.rb` — ActionCable channel for subscriptions
- `config/initializers/quail.rb` — configuration
- A `POST /graphql` route

### Generator Options

```bash
rails generate quail:install --schema-name=MySchema   # custom schema class name
rails generate quail:install --skip-controller         # skip controller generation
rails generate quail:install --skip-channel            # skip ActionCable channel
```

## Usage

### Defining a Resource

Generate a resource for an existing model:

```bash
rails generate quail:resource Article
```

Or write one by hand in `app/graphql/resources/`:

```ruby
class ArticleResource
  include Quail::Resource

  attributes :id, :title, :body, :published_at

  has_many :comments
  belongs_to :author

  writable_attributes :title, :body
end
```

That single file gives you:

- A `ArticleType` GraphQL type with all declared fields and associations
- `article(id: ID!)` and `articles` queries (with Relay connection pagination)
- `articleCreate`, `articleUpdate`, `articleDelete` mutations
- Writable attributes scoped to only what you allow

### Associations

```ruby
class ArticleResource
  include Quail::Resource

  attributes :id, :title

  has_many :comments
  has_one :featured_image
  belongs_to :author, resource: AuthorResource
end
```

Associations resolve through the Quail resource registry. If a resource exists for the associated model, the type is wired up automatically.

### Computed Attributes

```ruby
class ArticleResource
  include Quail::Resource

  attributes :id, :title

  attribute :excerpt, type: GraphQL::Types::String, null: true do |article|
    article.body&.truncate(200)
  end
end
```

### Controlling Mutations

Skip mutations you don't need:

```ruby
class ArticleResource
  include Quail::Resource

  attributes :id, :title, :body
  writable_attributes :title, :body

  skip_mutations :delete
end
```

Override a mutation with your own class:

```ruby
class ArticleResource
  include Quail::Resource

  attributes :id, :title, :body

  override_mutation :create, Mutations::CreateArticle
end
```

```ruby
# app/graphql/mutations/create_article.rb
class Mutations::CreateArticle < Quail::Mutation
  graphql_name "CreateArticle"

  argument :title, String, required: true
  argument :body, String, required: true

  field :article, ArticleResource.graphql_type, null: true
  field :errors, [String], null: false

  def resolve(title:, body:)
    article = Article.new(title: title, body: body)
    if article.save
      { article: article, errors: [] }
    else
      { article: nil, errors: article.errors.full_messages }
    end
  end
end
```

### Controlling Queries

```ruby
class ArticleResource
  include Quail::Resource

  attributes :id, :title

  skip_queries :list  # only expose find, not the collection
end
```

### Subscriptions

```ruby
class ArticleResource
  include Quail::Resource

  attributes :id, :title

  subscribe_on :create, :update, :delete
end
```

Scoped subscriptions are supported too:

```ruby
subscribe_on :update, scope: :author_id
subscribe_on :create, scope: { team_id: ->(record) { record.team.id } }
```

Mutations automatically trigger the corresponding subscription events.

### Resource Generator Options

```bash
rails generate quail:resource Article \
  --attributes=id title body \
  --skip-mutations=delete \
  --subscribe-on=create update
```

## Custom Types

For types that don't map directly to a resource (enums, inputs, value objects, etc.), drop them in `app/graphql/types/`:

Quail provides `Quail::Object` (aliased to `GraphQL::Schema::Object`) and `Quail::Mutation` (aliased to `GraphQL::Schema::RelayClassicMutation`) so you don't need to reference graphql-ruby base classes directly.

```ruby
# app/graphql/types/address_type.rb
class Types::AddressType < Quail::Object
  graphql_name "Address"

  field :street, String, null: false
  field :city, String, null: false
  field :state, String, null: true
  field :zip, String, null: false
end
```

You can then reference these types in your resources via computed attributes:

```ruby
class UserResource
  include Quail::Resource

  attributes :id, :name

  attribute :address, type: Types::AddressType, null: true do |user|
    user.address # returns an object that responds to street, city, etc.
  end
end
```

If you want all auto-generated Quail types to inherit from a custom base class, set it in the initializer:

```ruby
# app/graphql/types/base_object.rb
class Types::BaseObject < Quail::Object
end
```

```ruby
# config/initializers/quail.rb
Quail.base_object_class = Types::BaseObject
```

## Schema

The generated schema uses lazy configuration. Quail hooks into `execute`, `multiplex`, and `to_definition` so resources are loaded and wired up on first use:

```ruby
class AppSchema < GraphQL::Schema
  Quail::SchemaBuilder.call(self)
end
```

## Configuration

In `config/initializers/quail.rb`:

```ruby
Rails.application.config.quail.schema_class = "AppSchema"

# Use custom base classes from your app:
# Quail.base_object_class = Types::BaseObject
# Quail.base_mutation_class = Mutations::BaseMutation
```

## Rake Tasks

Dump your schema to SDL or JSON for tooling and CI:

```bash
rails quail:dump                          # => schema.graphql
rails quail:dump_json                     # => schema.json
SCHEMA_PATH=tmp/schema.graphql rails quail:dump  # custom output path
```

## Type Mapping

Quail maps ActiveRecord column types to GraphQL types automatically:

| ActiveRecord | GraphQL |
|---|---|
| `integer` | `Int` |
| `bigint` | `BigInt` |
| `float`, `decimal` | `Float` |
| `string`, `text` | `String` |
| `boolean` | `Boolean` |
| `date` | `ISO8601Date` |
| `datetime`, `time` | `ISO8601DateTime` |
| `json`, `jsonb` | `JSON` |
| `id` column | `ID` |

## Development

```bash
bin/setup        # install dependencies
rake test        # run tests
bin/console      # interactive prompt
```

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/taywils/quail.

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
