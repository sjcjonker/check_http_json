require_relative 'test_helper'

class TestUtilityFunctions < Minitest::Test
  include TestHelpers

  def setup
    reset_nagios
  end

  # Tests for hash_flatten
  def test_hash_flatten_simple_hash
    input = {'foo' => 'bar', 'baz' => 'qux'}
    result = hash_flatten(input, '.')
    assert_equal({'foo' => 'bar', 'baz' => 'qux'}, result)
  end

  def test_hash_flatten_nested_hash
    input = {'foo' => {'bar' => 'value1', 'baz' => 'value2'}}
    result = hash_flatten(input, '.')
    assert_equal({'foo.bar' => 'value1', 'foo.baz' => 'value2'}, result)
  end

  def test_hash_flatten_deeply_nested_hash
    input = {'a' => {'b' => {'c' => 'deep'}}}
    result = hash_flatten(input, '.')
    assert_equal({'a.b.c' => 'deep'}, result)
  end

  def test_hash_flatten_with_array
    input = {'items' => ['first', 'second', 'third']}
    result = hash_flatten(input, '.')
    expected = {
      'items.0' => 'first',
      'items.1' => 'second',
      'items.2' => 'third'
    }
    assert_equal(expected, result)
  end

  def test_hash_flatten_mixed_nested_structure
    input = {
      'status' => 'ok',
      'data' => {
        'users' => ['alice', 'bob'],
        'count' => 2
      }
    }
    result = hash_flatten(input, '.')
    expected = {
      'status' => 'ok',
      'data.users.0' => 'alice',
      'data.users.1' => 'bob',
      'data.count' => 2
    }
    assert_equal(expected, result)
  end

  def test_hash_flatten_custom_delimiter
    input = {'foo' => {'bar' => 'value'}}
    result = hash_flatten(input, '_')
    assert_equal({'foo_bar' => 'value'}, result)
  end

  # Tests for nutty_parse (Nagios range syntax)
  def test_nutty_parse_simple_threshold
    result = nutty_parse('Warning', '10', 5, false, 'test_element')
    assert_equal 'OK', result

    result = nutty_parse('Warning', '10', 15, false, 'test_element')
    assert_equal 'test_element is above threshold value 10 (15)', result
  end

  def test_nutty_parse_below_threshold
    # Format: 10: means alert if value < 10
    result = nutty_parse('Warning', '10:', 15, false, 'test_element')
    assert_equal 'OK', result

    result = nutty_parse('Warning', '10:', 5, false, 'test_element')
    assert_equal 'test_element is below threshold value 10 (5)', result
  end

  def test_nutty_parse_above_threshold
    # Format: ~:10 means alert if value > 10
    result = nutty_parse('Warning', '~:10', 5, false, 'test_element')
    assert_equal 'OK', result

    result = nutty_parse('Warning', '~:10', 15, false, 'test_element')
    assert_equal 'test_element is above threshold value 10 (15)', result
  end

  def test_nutty_parse_outside_range
    # Format: 10:20 means alert if value < 10 or value > 20
    result = nutty_parse('Warning', '10:20', 15, false, 'test_element')
    assert_equal 'OK', result

    result = nutty_parse('Warning', '10:20', 5, false, 'test_element')
    assert_equal 'test_element is outside expected range [10:20] (5)', result

    result = nutty_parse('Warning', '10:20', 25, false, 'test_element')
    assert_equal 'test_element is outside expected range [10:20] (25)', result
  end

  def test_nutty_parse_inside_range
    # Format: @10:20 means alert if 10 <= value <= 20
    result = nutty_parse('Warning', '@10:20', 5, false, 'test_element')
    assert_equal 'OK', result

    result = nutty_parse('Warning', '@10:20', 15, false, 'test_element')
    assert_equal 'test_element is in value range [10:20] (15)', result
  end

  def test_nutty_parse_negative_values
    result = nutty_parse('Warning', '-5:5', 0, false, 'test_element')
    assert_equal 'OK', result

    result = nutty_parse('Warning', '-5:5', -10, false, 'test_element')
    assert_equal 'test_element is outside expected range [-5:5] (-10)', result
  end

  def test_nutty_parse_below_zero
    result = nutty_parse('Warning', '10', -5, false, 'test_element')
    assert_equal 'test_element is below 0 (-5)', result
  end

  # Tests for say function (verbose output)
  def test_say_verbose_true
    stdout, _ = capture_output do
      say(true, 'test message')
    end
    assert_match(/\+ test message/, stdout)
  end

  def test_say_verbose_false
    stdout, _ = capture_output do
      say(false, 'test message')
    end
    assert_equal '', stdout
  end
end
