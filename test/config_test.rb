require "minitest/autorun"
require "./config"

class ConfigTest < Minitest::Test
  class Tickers < ConfigTest
    def test_works
      [
        [%w[A], "A"],
        [%w[A BB C], "BB C A"],
      ].each do |expected_result, env|
        ENV["TICKERS"] = env

        assert_equal expected_result, Config.tickers
      end
    end
  end

  class StartDate < ConfigTest
    def test_works
      ENV["START_DATE"] = "2010.01.01"

      assert_equal(
        Date.parse("2010.01.01").to_time.to_i,
        Config.start_date.to_time.to_i,
      )
    end

    def test_empty
      ENV.delete("START_DATE")

      assert_nil Config.start_date

      ENV["START_DATE"] = ""
      assert_nil Config.start_date
    end
  end

  class EndDate < ConfigTest
    def test_works
      ENV["END_DATE"] = "2010.01.01"

      assert_equal(
        Date.parse("2010.01.01").to_time.to_i,
        Config.end_date.to_time.to_i,
      )
    end

    def test_empty
      ENV.delete("END_DATE")
      assert_nil Config.end_date

      ENV["END_DATE"] = ""
      assert_nil Config.end_date
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
      assert_equal true, Config.derp

      ENV["DERP"] = "TRUE"
      assert_equal true, Config.derp

      ENV["DERP"] = "untrue"
      refute_equal true, Config.derp
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
