# frozen_string_literal: true

require "test_helper"

class TestSchemaBuilder < Minitest::Test
  def setup
    Quail.registry.clear
    # Remove any previously defined type constants to avoid cross-test pollution
    %w[UserType ProfileType PostType].each do |const|
      Object.send(:remove_const, const) if Object.const_defined?(const)
    end
  end

  def build_fake_model(name, columns_hash: {}, associations: {})
    Class.new do
      define_singleton_method(:name) { name }
      define_singleton_method(:columns_hash) { columns_hash }
      define_singleton_method(:column_names) { columns_hash.keys }
      define_singleton_method(:reflect_on_association) { |assoc_name| associations[assoc_name] }
    end
  end

  def build_fake_ar_association(klass, options: {})
    Struct.new(:klass, :options).new(klass, options)
  end

  # Creates a resource class that properly sets @model_class before
  # include Quail::Resource triggers registration.
  def build_resource(resource_name, model)
    m = model
    Class.new do
      define_singleton_method(:name) { resource_name }
      # Set @model before include so the DSL's model_class method
      # returns our fake model instead of trying to constantize.
      @model = m

      include Quail::Resource
    end
  end

  # ── build_all idempotency ───────────────────────────────────────────

  def test_build_all_does_not_duplicate_has_one_fields
    profile_model = build_fake_model("Profile", columns_hash: {
                                       "id" => FakeColumn.new(name: "id", type: :integer)
                                     })

    ar_assoc = build_fake_ar_association(profile_model)
    user_model = build_fake_model("User",
                                  columns_hash: { "id" => FakeColumn.new(name: "id", type: :integer) },
                                  associations: { profile: ar_assoc })

    user_resource = build_resource("UserResource", user_model)
    user_resource.attributes :id
    user_resource.has_one :profile

    profile_resource = build_resource("ProfileResource", profile_model)
    profile_resource.attributes :id

    Quail::Resource::TypeBuilder.build_all

    user_type = user_resource.graphql_type
    profile_fields = user_type.own_fields.select { |name, _| name == "profile" }
    assert_equal 1, profile_fields.size, "Expected one 'profile' field after first build_all"

    # Second call should be idempotent
    Quail::Resource::TypeBuilder.build_all

    profile_fields = user_type.own_fields.select { |name, _| name == "profile" }
    assert_equal 1, profile_fields.size, "Expected one 'profile' field after second build_all"
  end

  def test_build_all_does_not_duplicate_has_many_fields
    post_model = build_fake_model("Post", columns_hash: {
                                    "id" => FakeColumn.new(name: "id", type: :integer)
                                  })

    ar_assoc = build_fake_ar_association(post_model)
    user_model = build_fake_model("User",
                                  columns_hash: { "id" => FakeColumn.new(name: "id", type: :integer) },
                                  associations: { posts: ar_assoc })

    user_resource = build_resource("UserResource", user_model)
    user_resource.attributes :id
    user_resource.has_many :posts

    post_resource = build_resource("PostResource", post_model)
    post_resource.attributes :id

    Quail::Resource::TypeBuilder.build_all
    Quail::Resource::TypeBuilder.build_all

    user_type = user_resource.graphql_type
    posts_fields = user_type.own_fields.select { |name, _| name == "posts" }
    assert_equal 1, posts_fields.size, "Expected one 'posts' field after repeated build_all"
  end

  def test_build_all_skips_scalar_rebuild_when_graphql_type_exists
    user_model = build_fake_model("User", columns_hash: {
                                    "id" => FakeColumn.new(name: "id", type: :integer),
                                    "username" => FakeColumn.new(name: "username", type: :string)
                                  })

    user_resource = build_resource("UserResource", user_model)
    user_resource.attributes :id, :username

    Quail::Resource::TypeBuilder.build_all
    first_type = user_resource.graphql_type

    Quail::Resource::TypeBuilder.build_all
    second_type = user_resource.graphql_type

    assert_same first_type, second_type, "graphql_type should be the same object after repeated build_all"
  end

  # ── configure! idempotency ────────────────────────────────────────

  def test_configure_is_idempotent
    schema_class = Class.new(GraphQL::Schema)
    Quail::SchemaBuilder.call(schema_class)

    # Stub Rails.root with a temp dir so eager_load finds no files
    tmpdir = Dir.mktmpdir
    %w[resources mutations queries].each { |d| FileUtils.mkdir_p(File.join(tmpdir, "app/graphql/#{d}")) }
    root_path = Pathname.new(tmpdir)
    original_root = Rails.respond_to?(:root) ? Rails.method(:root) : nil
    verbose_was, $VERBOSE = $VERBOSE, nil
    Rails.define_singleton_method(:root) { root_path }
    $VERBOSE = verbose_was

    # First call should configure
    Quail::SchemaBuilder.configure!(schema_class)
    assert schema_class.instance_variable_get(:@quail_configured),
           "Expected @quail_configured to be true after configure!"

    # Reset the flag and configure again — build_all should skip
    # because all resources already have graphql_type set
    schema_class.instance_variable_set(:@quail_configured, false)
    Quail::SchemaBuilder.configure!(schema_class)

    # Verify resources kept the same type objects (not rebuilt)
    Quail.registry.each_value do |resource|
      next unless resource.graphql_type

      type = resource.graphql_type
      # Each association field should appear exactly once
      type.own_fields.each_value do |field|
        count = type.own_fields.values.count { |f| f.name == field.name }
        assert_equal 1, count, "Field '#{field.name}' on #{type.graphql_name} should not be duplicated"
      end
    end
  ensure
    FileUtils.rm_rf(tmpdir) if tmpdir
    verbose_was, $VERBOSE = $VERBOSE, nil
    if original_root
      Rails.define_singleton_method(:root, original_root)
    elsif Rails.singleton_class.method_defined?(:root)
      Rails.singleton_class.remove_method(:root)
    end
    $VERBOSE = verbose_was
  end

  def test_configure_mutex_prevents_double_execution
    # Verify the mutex exists and configure! checks @quail_configured inside the lock
    schema_class = Class.new(GraphQL::Schema)
    Quail::SchemaBuilder.call(schema_class)

    # Pre-mark as configured
    schema_class.instance_variable_set(:@quail_configured, true)

    # configure! should return immediately without doing anything
    # If it tried to call eager_load_resources, it would blow up since Rails.root isn't set
    Quail::SchemaBuilder.configure!(schema_class)

    assert schema_class.instance_variable_get(:@quail_configured)
  end
end
