# frozen_string_literal: true

require "test_helper"

class TestMutationBuilder < Minitest::Test
  # ── Lightweight stubs ───────────────────────────────────────────────
  # Fake model and resource classes that quack enough for MutationBuilder.
  # No Rails boot needed.

  def build_fake_model(name, column_names:)
    Class.new do
      define_singleton_method(:name) { name }
      define_singleton_method(:column_names) { column_names.map(&:to_s) }
    end
  end

  def build_fake_resource(assoc_defs: {})
    Class.new do
      define_singleton_method(:association_definitions) { assoc_defs }
    end
  end

  # ── Property 6: Mutation column exclusion ───────────────────────────
  # Validates: Requirements 5.1, 5.2
  #
  # Polymorphic _type and _id columns are excluded from writable
  # attributes, while non-polymorphic foreign keys remain included.

  def test_excludes_polymorphic_type_and_id_columns
    model = build_fake_model("Comment", column_names: %i[
                               id body commentable_type commentable_id author_id created_at updated_at
                             ])
    resource = build_fake_resource(assoc_defs: {
                                     commentable: { kind: :belongs_to, polymorphic: true, polymorphic_types: [] }
                                   })

    writable = Quail::Resource::MutationBuilder.default_writable(model, resource)

    refute_includes writable, :commentable_type
    refute_includes writable, :commentable_id
    assert_includes writable, :body
    assert_includes writable, :author_id
    assert_equal %i[body author_id], writable
  end

  # Non-polymorphic foreign keys like author_id must NOT be excluded.
  # Validates: Requirements 5.2

  def test_includes_non_polymorphic_foreign_keys
    model = build_fake_model("Comment", column_names: %i[
                               id body author_id created_at updated_at
                             ])
    resource = build_fake_resource(assoc_defs: {
                                     author: { kind: :belongs_to, polymorphic: false }
                                   })

    writable = Quail::Resource::MutationBuilder.default_writable(model, resource)

    assert_includes writable, :author_id
    assert_includes writable, :body
  end

  # ── Backward compatibility: no resource_class ───────────────────────
  # Validates: Requirements 5.1
  #
  # When called without a resource_class, default_writable should return
  # all columns except id, created_at, and updated_at (original behavior).

  def test_default_writable_without_resource_class_returns_all_non_reserved
    model = build_fake_model("Comment", column_names: %i[
                               id body commentable_type commentable_id author_id created_at updated_at
                             ])

    writable = Quail::Resource::MutationBuilder.default_writable(model)

    assert_equal %i[body commentable_type commentable_id author_id], writable
  end
end
