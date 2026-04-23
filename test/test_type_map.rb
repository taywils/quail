# frozen_string_literal: true

require "test_helper"

class TestTypeMap < Minitest::Test
  def test_id_column_returns_id_type
    col = FakeColumn.new(name: "id", type: :integer, null: false)
    assert_equal GraphQL::Types::ID, Quail::TypeMap.graphql_types(col)
  end

  def test_integer_column
    col = FakeColumn.new(name: "age", type: :integer, null: false)
    assert_equal GraphQL::Types::Int, Quail::TypeMap.graphql_types(col)
  end

  def test_string_column
    col = FakeColumn.new(name: "title", type: :string)
    assert_equal GraphQL::Types::String, Quail::TypeMap.graphql_types(col)
  end

  def test_boolean_column
    col = FakeColumn.new(name: "active", type: :boolean)
    assert_equal GraphQL::Types::Boolean, Quail::TypeMap.graphql_types(col)
  end

  def test_datetime_column
    col = FakeColumn.new(name: "created_at", type: :datetime)
    assert_equal GraphQL::Types::ISO8601DateTime, Quail::TypeMap.graphql_types(col)
  end

  def test_date_column
    col = FakeColumn.new(name: "born_on", type: :date)
    assert_equal GraphQL::Types::ISO8601Date, Quail::TypeMap.graphql_types(col)
  end

  def test_float_column
    col = FakeColumn.new(name: "score", type: :float)
    assert_equal GraphQL::Types::Float, Quail::TypeMap.graphql_types(col)
  end

  def test_decimal_maps_to_float
    col = FakeColumn.new(name: "price", type: :decimal)
    assert_equal GraphQL::Types::Float, Quail::TypeMap.graphql_types(col)
  end

  def test_json_column
    col = FakeColumn.new(name: "metadata", type: :json)
    assert_equal GraphQL::Types::JSON, Quail::TypeMap.graphql_types(col)
  end

  def test_jsonb_column
    col = FakeColumn.new(name: "settings", type: :jsonb)
    assert_equal GraphQL::Types::JSON, Quail::TypeMap.graphql_types(col)
  end

  def test_text_maps_to_string
    col = FakeColumn.new(name: "body", type: :text)
    assert_equal GraphQL::Types::String, Quail::TypeMap.graphql_types(col)
  end

  def test_unknown_type_falls_back_to_string
    col = FakeColumn.new(name: "weird", type: :binary)
    assert_equal GraphQL::Types::String, Quail::TypeMap.graphql_types(col)
  end

  def test_nullable_returns_column_null_value
    nullable_col = FakeColumn.new(name: "bio", type: :text, null: true)
    non_null_col = FakeColumn.new(name: "name", type: :string, null: false)

    assert_equal true,  Quail::TypeMap.nullable?(nullable_col)
    assert_equal false, Quail::TypeMap.nullable?(non_null_col)
  end

  def test_bigint_column
    col = FakeColumn.new(name: "big_number", type: :bigint)
    assert_equal GraphQL::Types::BigInt, Quail::TypeMap.graphql_types(col)
  end

  def test_time_maps_to_datetime
    col = FakeColumn.new(name: "alarm_at", type: :time)
    assert_equal GraphQL::Types::ISO8601DateTime, Quail::TypeMap.graphql_types(col)
  end
end
