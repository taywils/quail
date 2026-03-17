# frozen_string_literal: true

require "test_helper"

class TestTypeBuilder < Minitest::Test # rubocop:disable Metrics/ClassLength
  # ── Lightweight stubs ───────────────────────────────────────────────
  # Fake model classes that quack enough like ActiveRecord models for
  # TypeBuilder and the registry to work. No Rails boot needed.

  def setup
    # Clear registry between tests to avoid cross-contamination
    Quail.registry.clear
  end

  def build_fake_model(name, columns_hash: {}, associations: {})
    Class.new do
      define_singleton_method(:name) { name }
      define_singleton_method(:columns_hash) { columns_hash }
      define_singleton_method(:column_names) { columns_hash.keys }
      define_singleton_method(:reflect_on_association) { |assoc_name| associations[assoc_name] }
    end
  end

  def build_fake_resource(model, assoc_defs: {}, graphql_type: nil) # rubocop:disable Metrics/MethodLength
    gql_type = graphql_type || Class.new(GraphQL::Schema::Object) do
      graphql_name "#{model.name}Type"
    end

    resource = Class.new do
      include Quail::Resource::DSL

      define_singleton_method(:model_class) { model }
      define_singleton_method(:graphql_type) { gql_type }
      define_singleton_method(:attribute_definitions) { {} }
      define_singleton_method(:association_definitions) { assoc_defs }
    end

    Quail.registry[model] = resource
    resource
  end

  def build_fake_ar_association(klass)
    Struct.new(:klass, :options).new(klass, {})
  end

  # ── Property 3: Union naming convention ─────────────────────────────
  # Validates: Requirements 2.1, 6.3, 7.1

  def test_union_type_graphql_name_follows_convention
    model = build_fake_model("Post")
    resource = build_fake_resource(model)

    config = { polymorphic_types: [resource], union_name: nil }
    union = Quail::Resource::TypeBuilder.build_union_type(:commentable, config)

    assert_equal "CommentableUnion", union.graphql_name
  end

  def test_union_type_graphql_name_camelizes_underscored_names
    model = build_fake_model("Post")
    resource = build_fake_resource(model)

    config = { polymorphic_types: [resource], union_name: nil }
    union = Quail::Resource::TypeBuilder.build_union_type(:taggable_item, config)

    assert_equal "TaggableItemUnion", union.graphql_name
  end

  # ── Property 7: Custom union_name override ──────────────────────────
  # Validates: Requirements 7.2

  def test_custom_union_name_overrides_convention
    model = build_fake_model("Post")
    resource = build_fake_resource(model)

    config = { polymorphic_types: [resource], union_name: "MediaUnion" }
    union = Quail::Resource::TypeBuilder.build_union_type(:commentable, config)

    assert_equal "MediaUnion", union.graphql_name
  end

  # ── Property 4: Union possible_types matches declared types ─────────
  # Validates: Requirements 2.2, 2.3

  def test_possible_types_contains_correct_graphql_types
    post_model = build_fake_model("Post")
    image_model = build_fake_model("Image")
    post_resource = build_fake_resource(post_model)
    image_resource = build_fake_resource(image_model)

    config = { polymorphic_types: [post_resource, image_resource], union_name: nil }
    union = Quail::Resource::TypeBuilder.build_union_type(:commentable, config)

    resolved_types = union.possible_types
    assert_includes resolved_types, post_resource.graphql_type
    assert_includes resolved_types, image_resource.graphql_type
    assert_equal 2, resolved_types.size
  end

  # ── Parent type gets a nullable field of the union type ─────────────
  # Validates: Requirements 2.3

  def test_add_polymorphic_field_adds_nullable_union_field # rubocop:disable Metrics/MethodLength
    post_model = build_fake_model("Post")
    post_resource = build_fake_resource(post_model)

    parent_type = Class.new(GraphQL::Schema::Object) do
      graphql_name "CommentType"
    end

    config = { polymorphic_types: [post_resource], union_name: nil }
    Quail::Resource::TypeBuilder.add_polymorphic_field(parent_type, :commentable, config)

    field = parent_type.fields["commentable"]
    refute_nil field, "Expected parent type to have a :commentable field"

    field_type = field.type
    assert !field_type.respond_to?(:of_type),
           "Polymorphic field should be nullable (not wrapped in NonNull)"
  end

  # ── Property 5: resolve_type correctness ────────────────────────────
  # Validates: Requirements 3.1

  def test_resolve_type_returns_correct_type_for_registered_model
    post_model = build_fake_model("Post")
    image_model = build_fake_model("Image")
    post_resource = build_fake_resource(post_model)
    image_resource = build_fake_resource(image_model)

    config = { polymorphic_types: [post_resource, image_resource], union_name: nil }
    union = Quail::Resource::TypeBuilder.build_union_type(:commentable, config)

    # Create a fake object whose class is the post_model
    fake_post = post_model.new

    # resolve_type is an instance method on the union; instantiate and call it
    union_instance = union.new
    resolved = union_instance.resolve_type(fake_post, nil)

    assert_equal post_resource.graphql_type, resolved
  end

  def test_resolve_type_returns_correct_type_for_second_model
    post_model = build_fake_model("Post")
    image_model = build_fake_model("Image")
    post_resource = build_fake_resource(post_model)
    image_resource = build_fake_resource(image_model)

    config = { polymorphic_types: [post_resource, image_resource], union_name: nil }
    union = Quail::Resource::TypeBuilder.build_union_type(:commentable, config)

    fake_image = image_model.new
    union_instance = union.new
    resolved = union_instance.resolve_type(fake_image, nil)

    assert_equal image_resource.graphql_type, resolved
  end

  # ── resolve_type raises for unregistered model ──────────────────────
  # Validates: Requirements 3.2

  def test_resolve_type_raises_execution_error_for_unregistered_model # rubocop:disable Metrics/MethodLength
    post_model = build_fake_model("Post")
    post_resource = build_fake_resource(post_model)

    config = { polymorphic_types: [post_resource], union_name: nil }
    union = Quail::Resource::TypeBuilder.build_union_type(:commentable, config)

    unknown_model = build_fake_model("Unknown")
    fake_unknown = unknown_model.new

    union_instance = union.new
    error = assert_raises(GraphQL::ExecutionError) do
      union_instance.resolve_type(fake_unknown, nil)
    end

    assert_match(/Unknown/, error.message)
    assert_match(/commentable/, error.message)
  end

  # ── Non-polymorphic associations still use ar_assoc.klass path ──────
  # Validates: Requirements 4.1, 4.2

  def test_non_polymorphic_association_uses_existing_path # rubocop:disable Metrics/MethodLength
    author_model = build_fake_model("Author", columns_hash: {})
    _author_resource = build_fake_resource(author_model)

    ar_assoc = build_fake_ar_association(author_model)
    comment_model = build_fake_model("Comment", associations: { author: ar_assoc })

    parent_type = Class.new(GraphQL::Schema::Object) do
      graphql_name "CommentType"
    end

    config = { kind: :belongs_to }
    Quail::Resource::TypeBuilder.add_single_association(parent_type, comment_model, :author, config)

    field = parent_type.fields["author"]
    refute_nil field, "Expected parent type to have an :author field via non-polymorphic path"
  end

  def test_polymorphic_association_skips_ar_assoc_klass_path
    post_model = build_fake_model("Post")
    post_resource = build_fake_resource(post_model)

    # Model that has no reflect_on_association (would blow up if called)
    comment_model = build_fake_model("Comment", associations: {})

    parent_type = Class.new(GraphQL::Schema::Object) do
      graphql_name "Comment2Type"
    end

    config = { kind: :belongs_to, polymorphic: true, polymorphic_types: [post_resource], union_name: nil }
    # This should NOT call reflect_on_association — it should take the polymorphic path
    Quail::Resource::TypeBuilder.add_single_association(parent_type, comment_model, :commentable, config)

    field = parent_type.fields["commentable"]
    refute_nil field, "Expected polymorphic field to be added without calling ar_assoc.klass"
  end
end
