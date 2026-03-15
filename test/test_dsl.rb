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
end
