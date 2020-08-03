require "minitest/autorun"

require "test_helper"
require "ticker_data"
require "trading_strategies"
require "pry"

# rubocop:disable Metrics/AbcSize
# rubocop:disable Metrics/BlockLength
# rubocop:disable Metrics/ClassLength
# rubocop:disable Metrics/CyclomaticComplexity
# rubocop:disable Metrics/MethodLength
# rubocop:disable Metrics/ParameterLists
class TradingStrategiesTest < Minitest::Test
  include TestHelper::TickerData

  class BuyEveryNDaysAndHold < TradingStrategiesTest
    def test_works
      cash_amount = 1000

      (1..30).each do |n_days|
        %w[DERP HERP].map do |ticker|
          TickerData.new(ticker).tap do |ticker_data|
            ticker_data.days =
              make_days("2000.01.01", "2000.12.31").each do |day|
                day["close"] = rand(1000)
              end
          end
        end.then do |history_by_ticker|
          TradingStrategies.buy_every_n_days_and_hold(
            history_by_ticker,
            n_days: n_days,
          ).each do |ticker, trades|
            buy_days = history_by_ticker
              .find { |h| h.ticker == ticker }
              .days
              .stagger(n_days)

            assert(trades.map { |t| t[:ticker] }.all?(ticker))

            assert(trades.map { |t| t[:type] }.all?(:buy))

            assert_equal(buy_days, trades.map { |t| t[:day] })

            assert_equal(
              buy_days.map { |d| d["date"] },
              trades.map { |t| t[:date] },
            )

            assert_equal(
              buy_days.map { |d| d["close"] },
              trades.map { |t| t[:stock_price] },
            )

            assert_equal(
              buy_days.map { |d| cash_amount.to_f / d["close"] },
              trades.map { |t| t[:stock_amount] },
            )

            assert(trades.map { |t| t[:cash_spent] }.all?(cash_amount))
          end
        end
      end
    end
  end

  class TickerResult < TradingStrategiesTest
    def test_works
      MathLib.combinations(
        [1..1000, 1..1000, 1..1000, 1..1000],
        limit: 100,
      ).each do |n_trades, stock_amount, cash, last_price|
        %w[DERP HERP].each_with_object({}) do |ticker, memo|
          memo[ticker] = Array.new(n_trades) do
            %i[buy sell].sample.then do |type|
              {
                ticker: ticker,
                type: type,
                stock_amount: stock_amount,
                "cash_#{type == :buy ? "spent" : "earned"}".to_sym => cash,
              }
            end
          end
        end.then do |trades_by_ticker|
          history_by_ticker = trades_by_ticker.keys.map do |ticker|
            TickerData.new(ticker).tap do |ticker_data|
              ticker_data.days = [{ "close" => last_price }]
            end
          end

          TradingStrategies
            .ticker_result(trades_by_ticker, history_by_ticker)
            .each do |ticker, result|
              trades = trades_by_ticker[ticker]
              buy_trades = trades.select { |t| t[:type] == :buy }
              sell_trades = trades.select { |t| t[:type] == :sell }

              cash_spent = buy_trades.sum { |t| t[:cash_spent] }
              cash_earned = sell_trades.sum { |t| t[:cash_earned] }
              cash_profit = cash_earned - cash_spent
              cash_profit_percent = MathLib.percent_difference(cash_spent, cash_earned)

              stock_held = trades.reduce(0) do |memo, trade|
                memo += trade[:stock_amount] if trade[:type] == :buy
                memo -= trade[:stock_amount] if trade[:type] == :sell

                memo
              end
              stock_value = stock_held * history_by_ticker.find do |ticker_data|
                ticker_data.ticker == ticker
              end.days.last["close"]

              total_value = cash_earned + stock_value
              total_profit = total_value - cash_spent
              total_profit_percent = MathLib.percent_difference(cash_spent, total_value)

              assert(trades.all? { |t| %i[buy sell].include?(t[:type]) })

              assert_equal(buy_trades.size, result[:n_buys])
              assert_equal(sell_trades.size, result[:n_sells])

              assert_equal(cash_spent, result[:cash_spent])
              assert_equal(cash_earned, result[:cash_earned])
              assert_equal(cash_profit, result[:cash_profit])
              assert_equal(cash_profit_percent, result[:cash_profit_percent])

              assert_equal(stock_held, result[:stock_held])
              assert_equal(stock_value, result[:stock_value])

              assert_equal(total_value, result[:total_value])
              assert_equal(total_profit, result[:total_profit])
              assert_equal(total_profit_percent, result[:total_profit_percent])
            end
        end
      end
    end

    def test_with_fixture
      trades_by_ticker = {
        "DERP" => [
          { ticker: "DERP", type: :buy, stock_amount: 1, cash_spent: 2 },
          { ticker: "DERP", type: :sell, stock_amount: 3, cash_earned: 4 },
          { ticker: "DERP", type: :buy, stock_amount: 5, cash_spent: 6 },
        ],
        "HERP" => [
          { ticker: "HERP", type: :buy, stock_amount: 7, cash_spent: 8 },
          { ticker: "HERP", type: :sell, stock_amount: 9, cash_earned: 10 },
          { ticker: "HERP", type: :buy, stock_amount: 11, cash_spent: 12 },
          { ticker: "HERP", type: :sell, stock_amount: 3, cash_earned: 14 },
        ],
        "TERP" => [],
      }

      history_by_ticker = [
        TickerData.new("DERP").tap do |ticker_data|
          ticker_data.days = [{ "close" => 101 }]
        end,
        TickerData.new("HERP").tap do |ticker_data|
          ticker_data.days = [{ "close" => 102 }]
        end,
        TickerData.new("TERP").tap do |ticker_data|
          ticker_data.days = [{ "close" => 103 }]
        end,
      ]

      {
        "DERP" => {
          n_buys: 2,
          n_sells: 1,
          cash_spent: 8,
          cash_earned: 4,
          cash_profit: -4,
          cash_profit_percent: -50,
          stock_held: 3,
          stock_value: 303,
          total_value: 307,
          total_profit: 299,
          total_profit_percent: 3737.5,
        },
        "HERP" => {
          n_buys: 2,
          n_sells: 2,
          cash_spent: 20,
          cash_earned: 24,
          cash_profit: 4,
          cash_profit_percent: 20,
          stock_held: 6,
          stock_value: 612,
          total_value: 636,
          total_profit: 616,
          total_profit_percent: 3080,
        },
        "TERP" => {
          n_buys: 0,
          n_sells: 0,
          cash_spent: 0,
          cash_earned: 0,
          cash_profit: 0,
          cash_profit_percent: 0,
          stock_held: 0,
          stock_value: 0,
          total_value: 0,
          total_profit: 0,
          total_profit_percent: 0,
        },
      }.then do |expected_result|
        assert_equal(
          expected_result,
          TradingStrategies.ticker_result(trades_by_ticker, history_by_ticker),
        )
      end
    end
  end

  class AggregateResults < TradingStrategiesTest
    def test_works
      MathLib.combinations(
        [0..100, 0..100, 0..100, 0..100,
         -100..100, -100..100, 0..100, 0..100,
         0..100, 0..100, 0..100],
      ).each do |n_buys, n_sells, cash_spent, cash_earned,
                 cash_profit, cash_profit_percent, stock_held, stock_value,
                 total_value, total_profit, total_profit_percent|
        %w[DERP HERP].each_with_object({}) do |ticker, memo|
          memo[ticker] = {
            n_buys: n_buys,
            n_sells: n_sells,
            cash_spent: cash_spent,
            cash_earned: cash_earned,
            cash_profit: cash_profit,
            cash_profit_percent: cash_profit_percent,
            stock_held: stock_held,
            stock_value: stock_value,
            total_value: total_value,
            total_profit: total_profit,
            total_profit_percent: total_profit_percent,
          }
        end.then do |result_by_ticker|
          TradingStrategies
            .aggregate_result(result_by_ticker)
            .then do |aggregate_result|
              result_by_ticker.values.then do |results|
                [
                  results.sum { |r| r[:n_buys] },
                  MathLib.average(results.map { |r| r[:n_buys] }),
                ]
              end.then do |n_buys_sum, n_buys_avg|
                assert_equal(
                  n_buys_sum,
                  aggregate_result[:n_buys][:sum],
                )
                assert_equal(
                  n_buys_avg,
                  aggregate_result[:n_buys][:avg],
                )
              end

              result_by_ticker.values.then do |results|
                [
                  results.sum { |r| r[:n_sells] },
                  MathLib.average(results.map { |r| r[:n_sells] }),
                ]
              end.then do |n_sells_sum, n_sells_avg|
                assert_equal(
                  n_sells_sum,
                  aggregate_result[:n_sells][:sum],
                )
                assert_equal(
                  n_sells_avg,
                  aggregate_result[:n_sells][:avg],
                )
              end

              result_by_ticker.values.then do |results|
                [
                  results.sum { |r| r[:cash_spent] },
                  MathLib.average(results.map { |r| r[:cash_spent] }),
                ]
              end.then do |cash_spent_sum, cash_spent_avg|
                assert_equal(
                  cash_spent_sum,
                  aggregate_result[:cash_spent][:sum],
                )
                assert_equal(
                  cash_spent_avg,
                  aggregate_result[:cash_spent][:avg],
                )
              end

              result_by_ticker.values.then do |results|
                [
                  results.sum { |r| r[:cash_earned] },
                  MathLib.average(results.map { |r| r[:cash_earned] }),
                ]
              end.then do |cash_earned_sum, cash_earned_avg|
                assert_equal(
                  cash_earned_sum,
                  aggregate_result[:cash_earned][:sum],
                )
                assert_equal(
                  cash_earned_avg,
                  aggregate_result[:cash_earned][:avg],
                )
              end

              result_by_ticker.values.then do |results|
                [
                  results.sum { |r| r[:cash_profit] },
                  MathLib.average(results.map { |r| r[:cash_profit] }),
                ]
              end.then do |cash_profit_sum, cash_profit_avg|
                assert_equal(
                  cash_profit_sum,
                  aggregate_result[:cash_profit][:sum],
                )
                assert_equal(
                  cash_profit_avg,
                  aggregate_result[:cash_profit][:avg],
                )
              end

              result_by_ticker.values.then do |results|
                [
                  results.sum { |r| r[:stock_value] },
                  MathLib.average(results.map { |r| r[:stock_value] }),
                ]
              end.then do |stock_value_sum, stock_value_avg|
                assert_equal(
                  stock_value_sum,
                  aggregate_result[:stock_value][:sum],
                )
                assert_equal(
                  stock_value_avg,
                  aggregate_result[:stock_value][:avg],
                )
              end

              result_by_ticker.values.then do |results|
                [
                  results.sum { |r| r[:total_value] },
                  MathLib.average(results.map { |r| r[:total_value] }),
                ]
              end.then do |total_value_sum, total_value_avg|
                assert_equal(
                  total_value_sum,
                  aggregate_result[:total_value][:sum],
                )
                assert_equal(
                  total_value_avg,
                  aggregate_result[:total_value][:avg],
                )
              end

              result_by_ticker.values.then do |results|
                [
                  results.sum { |r| r[:total_profit] },
                  MathLib.average(results.map { |r| r[:total_profit] }),
                ]
              end.then do |total_profit_sum, total_profit_avg|
                assert_equal(
                  total_profit_sum,
                  aggregate_result[:total_profit][:sum],
                )
                assert_equal(
                  total_profit_avg,
                  aggregate_result[:total_profit][:avg],
                )
              end

              assert_equal(
                MathLib.percent_difference(
                  *result_by_ticker.values.map do |result|
                    [result[:cash_spent], result[:cash_earned]]
                  end.then do |results|
                    results.transpose.map(&:sum)
                  end,
                ),
                aggregate_result[:cash_profit_percent][:avg],
              )

              assert_equal(
                MathLib.percent_difference(
                  *result_by_ticker.values.map do |result|
                    [result[:cash_spent], result[:cash_earned], result[:stock_value]]
                  end.then do |results|
                    results.transpose.map(&:sum)
                  end.then do |expected_cash_spent, expected_cash_earned, expected_stock_value|
                    [expected_cash_spent, expected_cash_earned + expected_stock_value]
                  end,
                ),
                aggregate_result[:total_profit_percent][:avg],
              )
            end
        end
      end
    end

    def test_with_fixture
      {
        "DERP" => {
          n_buys: 2,
          n_sells: 1,
          cash_spent: 8,
          cash_earned: 4,
          cash_profit: -4,
          cash_profit_percent: -50,
          stock_held: 3,
          stock_value: 303,
          total_value: 307,
          total_profit: 299,
          total_profit_percent: 3737.5,
        },
        "HERP" => {
          n_buys: 2,
          n_sells: 2,
          cash_spent: 20,
          cash_earned: 24,
          cash_profit: 4,
          cash_profit_percent: 20,
          stock_held: 6,
          stock_value: 612,
          total_value: 636,
          total_profit: 616,
          total_profit_percent: 3267.86,
        },
        "TERP" => {
          n_buys: 0,
          n_sells: 0,
          cash_spent: 0,
          cash_earned: 0,
          cash_profit: 0,
          cash_profit_percent: 0,
          stock_held: 0,
          stock_value: 0,
          total_value: 0,
          total_profit: 0,
          total_profit_percent: 0,
        },
      }.then do |result_by_ticker|
        {
          n_buys: { sum: 4, avg: 1.333 },
          n_sells: { sum: 3, avg: 1 },
          cash_spent: { sum: 28, avg: 9.333 },
          cash_earned: { sum: 28, avg: 9.333 },
          cash_profit: { sum: 0, avg: 0 },
          stock_value: { sum: 915, avg: 305 },
          total_value: { sum: 943, avg: 314.333 },
          total_profit: { sum: 915, avg: 305 },
          cash_profit_percent: { avg: 0 },
          total_profit_percent: { avg: 3267.857 },
        }.then do |expected_result|
          TradingStrategies
            .aggregate_result(result_by_ticker)
            .then do |aggregate_result|
              %i[
                n_buys
                n_sells
                cash_spent
                cash_earned
                cash_profit
                stock_value
                total_value
                total_profit
              ].each do |calc|
                %i[sum avg].each do |calc_type|
                  assert_in_delta(
                    expected_result[calc][calc_type],
                    aggregate_result[calc][calc_type],
                    1e-3,
                  )
                end
              end

              %i[
                cash_profit_percent
                total_profit_percent
              ].each do |calc|
                assert_in_delta(
                  expected_result[calc][:avg],
                  aggregate_result[calc][:avg],
                  1e-3,
                )
              end
            end
        end
      end
    end
  end
end
# rubocop:enable Metrics/AbcSize
# rubocop:enable Metrics/BlockLength
# rubocop:enable Metrics/ClassLength
# rubocop:enable Metrics/CyclomaticComplexity
# rubocop:enable Metrics/MethodLength
# rubocop:enable Metrics/ParameterLists
