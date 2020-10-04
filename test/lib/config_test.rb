require "minitest/autorun"

require "config"

class ConfigTest < Minitest::Test
  class Tickers < ConfigTest
    def test_works
      [
        [%w[A], "A"],
        [%w[A BB C], "BB C A"],
      ].each do |expected_result, env|
        ENV["TICKERS"] = env

        assert_equal(expected_result, Config.tickers)
      end
    end

    def test_uniq
      ENV["TICKERS"] = "A A B A"
      assert_equal(%w[A B], Config.tickers)
    end
  end

  class MethodMissing < ConfigTest
    def test_nils
      ENV.delete("DERP")

      assert_raises NoMethodError do
        Config.derp
      end
    end

    def test_trues
      ENV["DERP"] = "true"
      assert Config.derp

      ENV["DERP"] = "TRUE"
      assert Config.derp

      ENV["DERP"] = "untrue"
      refute_equal true, Config.derp
    end

    def test_falses
      ENV["DERP"] = "false"
      refute Config.derp

      ENV["DERP"] = "FALSE"
      refute Config.derp

      ENV["DERP"] = "unfalse"
      refute_equal false, Config.derp
    end

    def test_ints
      [
        [1, "1"],
        [100, "100"],
        [10, "+10"],
        [-10, "-10"],
      ].each do |expected_result, env|
        ENV["DERP"] = env

        assert_equal expected_result, Config.derp
      end

      ENV["DERP"] = "1e3"
      refute_equal 1000, Config.derp

      ENV["DERP"] = "0x1"
      refute_equal 1, Config.derp
    end

    def test_floats
      [
        [1, "1.0"],
        [0.5, "0.5"],
        [0.5, "+0.5"],
        [-0.5, "-0.5"],
        [0.6, ".6"],
        [-0.6, "-.6"],
        [0.7, ".700000"],
      ].each do |expected_result, env|
        ENV["DERP"] = env

        assert_equal expected_result, Config.derp
      end
    end

    def test_generic
      ENV["DERP"] = "herp"

      assert_equal "herp", Config.derp
    end
  end
end
