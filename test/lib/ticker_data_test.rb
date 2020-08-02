require "minitest/autorun"

require "math_lib"
require "test_helper"
require "ticker_data"

class TickerDataTest < Minitest::Test
  include TestHelper::TickerData

  DAYS_IN_YEAR = {
    total: 365,
    h1: 181,
    h2: 184,
  }.freeze

  def setup
    @ticker_data = TickerData.new("DERP")
    @ticker_data.days = make_days

    super
  end

  class Clamp < TickerDataTest
    def test_works
      @ticker_data.days = make_days("2009-01-01", "2011-12-31")

      assert_equal(3 * DAYS_IN_YEAR[:total], @ticker_data.days.size)

      [
        %w[2009-07-01 2011-06-30],
        %w[2010-01-01 2011-06-30],
        %w[2010-07-01 2011-06-30],
        %w[2009-07-01 2011-06-30],
      ].each do |start_date, end_date|
        @ticker_data.days = make_days("2009-01-01", "2011-12-31")
        @ticker_data.clamp!(start_date: start_date, end_date: end_date)

        assert_equal(
          (Date.parse(start_date)..Date.parse(end_date)).count,
          @ticker_data.days.size,
        )
        assert_equal(start_date, @ticker_data.days.first["date"])
        assert_equal(end_date, @ticker_data.days.last["date"])
      end
    end

    def test_nils
      @ticker_data.days = make_days("2009-01-01", "2011-12-31")

      assert_equal(3 * DAYS_IN_YEAR[:total], @ticker_data.days.size)

      @ticker_data.clamp!
      assert_equal(3 * DAYS_IN_YEAR[:total], @ticker_data.days.size)

      @ticker_data.clamp!(start_date: "2010-01-01")
      assert_equal(2 * DAYS_IN_YEAR[:total], @ticker_data.days.size)

      @ticker_data.clamp!(end_date: "2011-06-30")
      assert_equal(
        DAYS_IN_YEAR[:total] + DAYS_IN_YEAR[:h1],
        @ticker_data.days.size,
      )
    end
  end

  class CalculatePercentageChange < TickerDataTest
    def setup_prices(prices)
      @ticker_data.days.each_with_index do |day, index|
        day["close"] = prices[index].to_f
      end
    end

    def test_works
      @ticker_data.days = make_days("2010.01.01", "2010.01.05")
      prices_and_expected_changes = {
        "100" => nil,
        "150" => 50,
        "300" => 100,
        "1200" => 300,
        "600" => -50,
      }
      setup_prices(prices_and_expected_changes.keys)

      @ticker_data.calculate_percentage_change(1)

      assert_equal(
        prices_and_expected_changes.values,
        @ticker_data.days.map { |d| d["1_day_percentage_change"] },
      )

      @ticker_data.days = make_days("2010.01.01", "2010.01.05")
      prices_and_expected_changes = {
        "100" => nil,
        "150" => nil,
        "300" => 200,
        "1200" => 700,
        "90" => -70,
      }
      setup_prices(prices_and_expected_changes.keys)

      @ticker_data.calculate_percentage_change(2)

      assert_equal(
        prices_and_expected_changes.values,
        @ticker_data.days.map { |d| d["2_day_percentage_change"] },
      )
    end
  end

  class AvgStreakChange < TickerDataTest
    def test_works
      (1..5).each do |n|
        n_day_changes = Array.new(10) { rand(100) }
        streak_days = Array.new(10) do |index|
          { "#{n}_day_percentage_change" => n_day_changes[index] }
        end

        assert(
          MathLib.average(n_day_changes),
          @ticker_data.avg_streak_change(streak_days, n),
        )
      end
    end

    def test_raises_when_n_lookback_days_not_calculated
      assert_raises NoMethodError do
        n_lookback_days = rand(10)

        @ticker_data.avg_streak_change(
          [{ "#{n_lookback_days}_day_percentage_change" => n_lookback_days }],
          n_lookback_days + 1,
        )
      end
    end
  end

  class MonotonicDecrease < TickerDataTest
    def test_works
      100.times do
        sequence = Array.new(2) { rand(-10..10) }
        streak_days = Array.new(sequence.size) { |i| { "close" => sequence[i] } }

        assert_equal(
          MathLib.monotonic_decrease?(sequence),
          @ticker_data.monotonic_decrease?(streak_days),
        )

        if MathLib.monotonic_decrease?(sequence)
          streak_days.push({ "close" => Float::INFINITY })
        else
          streak_days.push({ "close" => -Float::INFINITY })
        end

        refute @ticker_data.monotonic_decrease?(streak_days)
      end
    end
  end

  class Streaks < TickerDataTest
    def test_works
      days = (1..100).to_a
      @ticker_data.days = days

      MathLib.combinations([1..30, 1..30])
        .each do |n_lookback_days, n_streak_days|
          streaks = @ticker_data
            .streaks(n_lookback_days, n_streak_days)
            .map
            .with_index do |(*streak_days, next_day), index|
              assert_equal(days[n_lookback_days + index, n_streak_days], streak_days)
              assert_equal(streak_days.last + 1, next_day)
            end

          assert_equal(
            @ticker_data.days.size - n_lookback_days - n_streak_days,
            streaks.size,
          )
        end
    end
  end

  class TagPanicDays < TickerDataTest
    def test_works
      n_lookback_days = 1
      n_streak_days = 1

      (-99..-1).each do |target_avg_change|
        change_between_days = target_avg_change - 20
        @ticker_data.days = Array.new(5, change_between_days)
          .map
          .with_index do |n_day_percentage_change, index|
            {
              "#{n_lookback_days}_day_percentage_change" => n_day_percentage_change,
              "close" => -index,
            }
          end

        @ticker_data.tag_panic_days(
          n_lookback_days,
          n_streak_days,
          target_avg_change,
        )

        assert_equal(
          @ticker_data.days.size - n_lookback_days - n_streak_days,
          @ticker_data.panic_days.size,
        )
      end
    end

    def test_integration
      # FIXME i'm still not convinced; let's roll out a couple of fixtures
      MathLib.combinations(
        [1..60, 1..60, -99..-1, 1..1000],
        limit: 100,
      ).each do |n_lookback_days, n_streak_days, target_avg_change, initial_price|
        @ticker_data.days =
          Array.new(100) do |i|
            MathLib.compound_interest(initial_price, 10, i)
          end.then do |prices|
            last_price = prices[-n_lookback_days - 1]
            prices.concat(Array.new(100) do |i|
              MathLib.compound_interest(last_price, target_avg_change - 1, i)
            end)
          end.then do |prices|
            last_price = prices[-n_lookback_days - 1]

            prices.concat(Array.new(100) do |i|
              MathLib.compound_interest(last_price, -1, i)
            end)
          end.map do |price|
            { "close" => price }
          end

        @ticker_data.calculate_percentage_change(n_lookback_days)

        @ticker_data.tag_panic_days(
          n_lookback_days,
          n_streak_days,
          target_avg_change,
        )

        @ticker_data.panic_days.each do |panic_day|
          panic_day_index = @ticker_data.days.index(panic_day)

          assert(
            MathLib.average(
              @ticker_data
                .days[panic_day_index - n_streak_days...panic_day_index]
                .map { |d| d["#{n_lookback_days}_day_percentage_change"] },
            ) < target_avg_change,
          )

          assert(
            MathLib.monotonic_decrease?(
              @ticker_data
                .days[panic_day_index - n_streak_days...panic_day_index]
                .map { |day| day["close"] },
            ),
          )
        end
      end
    end
  end

  class PanicDays < TickerDataTest
    def test_works
      panic_dates = @ticker_data.days.map { |d| d["date"] }.sample(5)

      @ticker_data.days.select do |day|
        panic_dates.include?(day["date"])
      end.map do |day|
        day["panic"] = true
      end

      assert_equal(
        [true],
        @ticker_data.panic_days.map { |day| day["panic"] }.uniq,
      )

      assert_equal(
        panic_dates.sort,
        @ticker_data.panic_days.map { |day| day["date"] }.sort,
      )
    end
  end

  class FindGainDay < TickerDataTest
    def test_works
      sell_gain_target = 100

      [
        [10, 20, 30, 20, 40, 60],
        [1, 3, 3, 1, nil, nil],
      ].then do |prices, expected_distances|
        @ticker_data.days = make_days("2000.01.01", "2000.01.06").each_with_index do |day, index|
          day.merge!("close" => prices[index])
        end

        @ticker_data.days.each_with_index do |day, index|
          if expected_distances[index].nil?
            assert_nil(@ticker_data.find_gain_day(day, sell_gain_target))
          else
            assert_equal(
              @ticker_data.days[
                @ticker_data.days.index(day) + expected_distances[index]
              ],
              @ticker_data.find_gain_day(day, sell_gain_target),
            )
          end
        end
      end
    end
  end

  class Baseline < TickerDataTest
    def test_works
      @ticker_data.days = Array.new(100) do |index|
        { "close" => index }
      end

      (0..30).each do |avg_days|
        @ticker_data.baseline(avg_days).then do |baseline|
          avg_start_price = MathLib.average(
            @ticker_data.days.first(avg_days).map { |d| d["close"] },
          )
          avg_end_price = MathLib.average(
            @ticker_data.days.last(avg_days).map { |d| d["close"] },
          )

          assert_equal(
            avg_start_price,
            baseline[:avg_start_price],
          )
          assert_equal(
            avg_end_price,
            baseline[:avg_end_price],
          )
          assert_equal(
            MathLib.percent_difference(avg_start_price, avg_end_price),
            baseline[:performance],
          )
        end
      end
    end
  end

  class AvgTradingDaysPerYear < TickerDataTest
    def test_works
      @ticker_data.days = make_days("2009-01-01", "2011-12-31")
      assert_equal(
        DAYS_IN_YEAR[:total],
        @ticker_data.avg_trading_days_per_year,
      )

      # range includes one leap year (2008)
      @ticker_data.days = make_days("2007-01-01", "2011-12-31")
      assert_equal(
        (3 * DAYS_IN_YEAR[:total] + 1) / 3.to_f,
        @ticker_data.avg_trading_days_per_year,
      )
    end
  end

  class AvgTradingDaysPerMonth < TickerDataTest
    def test_works
      @ticker_data.days = make_days("2009-01-01", "2009-12-31")

      assert_equal(
        (28 + 31 + 30 + 31 + 30 + 31 + 31 + 30 + 31 + 30) / 10.to_f,
        @ticker_data.avg_trading_days_per_month,
      )
    end
  end
end
