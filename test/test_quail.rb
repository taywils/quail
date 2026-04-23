# frozen_string_literal: true

require "test_helper"

class TestQuail < Minitest::Test
  def test_that_it_has_a_version_number
    refute_nil ::Quail::VERSION
  end

  def test_registry_starts_empty
    # Clear any leftover state
    Quail.instance_variable_set(:@registry, nil)
    assert_empty Quail.registry
  end

  def test_extra_mutations_starts_empty
    Quail.instance_variable_set(:@extra_mutations, nil)
    assert_empty Quail.extra_mutations
  end

  def test_extra_queries_starts_empty
    Quail.instance_variable_set(:@extra_queries, nil)
    assert_empty Quail.extra_queries
  end
end
