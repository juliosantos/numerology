require "minitest/autorun"

require "sp500"

class SP500Test < Minitest::Test
  class Member < MathLibTest
    def test_is_present_in_date
      assert SP500.member?("GHC", "2008-01-31")
      assert SP500.member?("MDP", "2008-01-31")
      refute SP500.member?("DERP", "2008-01-31")
    end

    def test_is_present_after_not_being
      refute SP500.member?("WAB", "2019-02-26")
      assert SP500.member?("WAB", "2019-02-27")
    end

    def test_is_not_present_after_being
      assert SP500.member?("GT", "2019-02-26")
      refute SP500.member?("GT", "2019-02-27")
    end
  end
end
