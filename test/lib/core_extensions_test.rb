require "minitest/autorun"
require "core_extensions"
require "math_lib"

class CoreExtensionsTest < Minitest::Test
  class ArrayTest < CoreExtensionsTest
    class Stagger < ArrayTest
      def test_works
        MathLib.random_combinations([1..100, 0..10])
          .take(100)
          .each do |size, interval|
            assert_equal(
              (0...size).to_a.stagger(interval),
              (0...size).step(interval + 1).to_a,
            )
          end
      end
    end
  end
end
