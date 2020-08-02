require "minitest/autorun"

require "math_lib"

require "pry"

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

  class MonotonicDecrease < MathLibTest
    def test_works
      [
        (10..-10),
        (-10..-20),
        (60..30),
        [9, 8, 5, -4],
      ].each do |sequence|
        assert MathLib.monotonic_decrease?(sequence.to_a)
      end

      [
        (-10..10),
        (10..20),
        (30..60),
        [9, -8, 5, -4],
      ].each do |sequence|
        refute MathLib.monotonic_decrease?(sequence.to_a)
      end
    end
  end

  class CompoundInterest < MathLibTest
    def test_works
      [
        [100, -10, 10, 34.867],
        [50, 3, 500, 131_093_861.71],
        [3000, 15, 30, 198_635.315],
        [10, -3, 50, 2.18],
      ].each do |initial_value, percent, n_periods, expected_result|
        assert_in_delta(
          MathLib.compound_interest(initial_value, percent, n_periods),
          expected_result,
          1e-3,
        )
      end
    end
  end

  class Combinations < MathLibTest
    def test_works
      Array.new(4) do |i|
        (start = (10**i))..start + rand(10**(i + 1) - 1)
      end.then do |ranges|
        assert(
          MathLib
            .combinations(ranges)
            .transpose
            .each_with_index
            .all? { |values_in_range, i| values_in_range.all?(ranges[i]) },
        )
      end
    end

    def test_limit
      range = 1..100

      assert MathLib.combinations([range], limit: nil).size == range.size

      (1..20).each do |limit|
        assert(MathLib.combinations([range], limit: limit).size == limit)
      end
    end
  end
end
