require "minitest/autorun"
require "./math_lib"

class MathLibTest < Minitest::Test
  class Percentage < MathLibTest
    def test_works
      [
        [50, [50, 100]],
        [10, [10, 100]],
        [0, [0, 100]],
        [100, [1, 1]],
        [100, [100, 100]],
      ].each do |expected_result, arguments|
        assert_equal expected_result, MathLib.percentage(*arguments)
      end
    end

    def test_returns_floats
      [
        [50, [1, 2]],
        [25, [1, 4]],
      ].each do |expected_result, arguments|
        assert_equal expected_result, MathLib.percentage(*arguments)
      end
    end
  end

  class PercentDifference < MathLibTest
    def test_works
      [
        [0, [10, 10]],
        [10, [10, 11]],
        [50, [10, 15]],
        [900, [10, 100]],
      ].each do |expected_result, arguments|
        assert_equal expected_result, MathLib.percent_difference(*arguments)
      end
    end

    def test_returns_floats
      [
        [1, [100, 101]],
      ].each do |expected_result, arguments|
        assert_equal expected_result, MathLib.percent_difference(*arguments)
      end
    end

    # Ensure method returns Infinity
    def test_infinity
      assert_equal Float::INFINITY, MathLib.percent_difference(0, 100)
    end

    def test_zero
      assert_equal 0, MathLib.percent_difference(0, 0)
    end
  end

  class Average < MathLibTest
    def test_works
      [
        [2, [1, 2, 3]],
        [0, [0]],
        [1, [1, 1, 1]],
        [50, [0, 25, 75, 100]],
        [50, [-50, 100, 100]],
      ].each do |expected_result, argument|
        assert_equal expected_result, MathLib.average(argument)
      end
    end

    def test_empty
      assert_equal 0, MathLib.average([])
    end
  end
end
