# frozen_string_literal: true

require "test_helper"

class TestDSL < Minitest::Test
  # A throwaway class that includes the DSL so we can test it in isolation.
  # No real ActiveRecord model needed.
  def build_resource_class
    Class.new do
      include Quail::Resource::DSL
    end
  end

  # ── attributes / attribute ──────────────────────────────────────────

  def test_attributes_registers_column_types
    klass = build_resource_class
    klass.attributes :title, :body

    assert_equal({ type: :column }, klass.attribute_definitions[:title])
    assert_equal({ type: :column }, klass.attribute_definitions[:body])
  end

  def test_attribute_registers_computed_type
    blk = lambda(&:to_s)
    klass = build_resource_class
    klass.attribute :full_name, type: GraphQL::Types::String, null: false, &blk

    defn = klass.attribute_definitions[:full_name]
    assert_equal :computed, defn[:type]
    assert_equal GraphQL::Types::String, defn[:graphql_type]
    assert_equal false, defn[:null]
    assert_equal blk, defn[:block]
  end

  # ── associations ────────────────────────────────────────────────────

  def test_has_many
    klass = build_resource_class
    klass.has_many :posts, resource: :post_resource

    defn = klass.association_definitions[:posts]
    assert_equal :has_many, defn[:kind]
    assert_equal :post_resource, defn[:resource]
  end

  def test_has_one
    klass = build_resource_class
    klass.has_one :profile

    defn = klass.association_definitions[:profile]
    assert_equal :has_one, defn[:kind]
  end

  def test_belongs_to
    klass = build_resource_class
    klass.belongs_to :author, resource: :user_resource

    defn = klass.association_definitions[:author]
    assert_equal :belongs_to, defn[:kind]
    assert_equal :user_resource, defn[:resource]
  end

  # ── skip_mutations / mutation overrides ─────────────────────────────

  def test_skip_mutations
    klass = build_resource_class
    klass.skip_mutations :create, :delete

    assert_includes klass.skipped_mutations, :create
    assert_includes klass.skipped_mutations, :delete
    refute_includes klass.skipped_mutations, :update
  end

  def test_skipped_mutations_defaults_to_empty
    klass = build_resource_class
    assert_empty klass.skipped_mutations
  end

  def test_override_mutation
    fake_class = Class.new
    klass = build_resource_class
    klass.override_mutation :create, fake_class

    assert_equal fake_class, klass.mutation_overrides[:create]
  end

  # ── writable_attributes ─────────────────────────────────────────────

  def test_writable_attributes_setter_and_getter
    klass = build_resource_class
    klass.writable_attributes :title, :body

    assert_equal %i[title body], klass.writable_attributes
  end

  def test_writable_attributes_returns_nil_when_unset
    klass = build_resource_class
    assert_nil klass.writable_attributes
  end

  # ── subscribe_on ────────────────────────────────────────────────────

  def test_subscribe_on_registers_events
    klass = build_resource_class
    klass.subscribe_on :create, :update

    assert_includes klass.subscription_definitions.keys, :create
    assert_includes klass.subscription_definitions.keys, :update
  end

  def test_subscribe_on_with_symbol_scope
    klass = build_resource_class
    klass.subscribe_on :create, scope: :team_id

    assert_equal({ scope: :team_id }, klass.subscription_definitions[:create])
  end

  def test_subscribe_on_with_hash_scope
    scope_hash = { team_id: lambda(&:team_id) }
    klass = build_resource_class
    klass.subscribe_on :create, scope: scope_hash

    assert_equal scope_hash, klass.subscription_definitions[:create][:scope]
  end

  def test_subscribe_on_rejects_invalid_scope
    klass = build_resource_class

    assert_raises(ArgumentError) do
      klass.subscribe_on :create, scope: 42
    end
  end

  # ── skip_queries ────────────────────────────────────────────────────

  def test_skip_queries
    klass = build_resource_class
    klass.skip_queries :find

    assert_includes klass.skipped_queries, :find
  end

  def test_skipped_queries_defaults_to_empty
    klass = build_resource_class
    assert_empty klass.skipped_queries
  end

  # ── polymorphic belongs_to ──────────────────────────────────────────

  # Property 1: Polymorphic DSL storage
  # Validates: Requirements 1.1
  def test_polymorphic_belongs_to_stores_correct_definition_shape
    fake_resource_a = Class.new
    fake_resource_b = Class.new

    klass = build_resource_class
    klass.belongs_to :commentable, polymorphic: { types: [fake_resource_a, fake_resource_b] }

    defn = klass.association_definitions[:commentable]
    assert_equal :belongs_to, defn[:kind]
    assert_equal true, defn[:polymorphic]
    assert_equal [fake_resource_a, fake_resource_b], defn[:polymorphic_types]
  end

  # Validates: Requirements 1.3
  def test_polymorphic_bare_boolean_raises_argument_error
    klass = build_resource_class

    assert_raises(ArgumentError) do
      klass.belongs_to :commentable, polymorphic: true
    end
  end

  # Validates: Requirements 1.2
  def test_polymorphic_empty_types_raises_argument_error
    klass = build_resource_class

    assert_raises(ArgumentError) do
      klass.belongs_to :commentable, polymorphic: { types: [] }
    end
  end

  # Property 2: Non-polymorphic backward compatibility
  # Validates: Requirements 1.4
  def test_non_polymorphic_belongs_to_unchanged
    klass = build_resource_class
    klass.belongs_to :author, resource: :user_resource

    defn = klass.association_definitions[:author]
    assert_equal :belongs_to, defn[:kind]
    assert_equal :user_resource, defn[:resource]
    refute defn.key?(:polymorphic_types), "non-polymorphic belongs_to should not have :polymorphic_types"
    refute defn[:polymorphic], "non-polymorphic belongs_to should not have polymorphic set to true"
  end

  # Property 7: Custom union_name override
  # Validates: Requirements 7.2
  def test_polymorphic_union_name_stored_when_provided
    fake_resource = Class.new

    klass = build_resource_class
    klass.belongs_to :commentable, polymorphic: { types: [fake_resource], union_name: "MediaUnion" }

    defn = klass.association_definitions[:commentable]
    assert_equal "MediaUnion", defn[:union_name]
  end

  # Validates: Requirements 7.2 (absence case)
  def test_polymorphic_without_union_name_does_not_store_key
    fake_resource = Class.new

    klass = build_resource_class
    klass.belongs_to :commentable, polymorphic: { types: [fake_resource] }

    defn = klass.association_definitions[:commentable]
    refute defn.key?(:union_name), "union_name should not be present when not provided"
  end
end
