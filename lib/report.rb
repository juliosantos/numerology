require "action_view"

require_relative "config"
require_relative "math_lib"
require_relative "print_lib"

module Report
  extend ActionView::Helpers::NumberHelper

  def self.parameters
    PrintLib.h1 "Parameters"

    PrintLib.puts "Dates: ", Config.start_date, " -> ", Config.end_date
    PrintLib.newline

    PrintLib.puts(
      "Tickers: ",
      Config.tickers.map do |ticker|
        PrintLib.ticker(ticker)
      end.compact.join(", "),
    )
    PrintLib.newline

    PrintLib.h2 "Panic model:"
    %w[n_lookback_days n_streak_days target_avg_change].map do |param_name|
      PrintLib.puts param_name, ": ", Config.send(param_name)
    end
    PrintLib.newline

    PrintLib.h2 "Selling model:"
    PrintLib.puts "sell_gain_target: ", Config.sell_gain_target.to_s, "%"
    PrintLib.newline
  end

  def self.baseline_performance(history_by_ticker)
    PrintLib.h1 "Baseline performance"

    ticker_performances = history_by_ticker.map do |ticker_data|
      ticker_data.baseline.tap do |baseline|
        PrintLib.puts(
          ticker_data.ticker,
          ": ",
          number_with_delimiter(baseline[:performance].round(1)),
          "% (",
          number_with_delimiter(baseline[:avg_start_price].round),
          " -> ",
          number_with_delimiter(baseline[:avg_end_price].round),
          ")",
        )
      end[:performance]
    end
    PrintLib.newline

    PrintLib.puts(
      "Aggregate: ",
      number_with_delimiter(MathLib.average(ticker_performances).round),
      "%",
    )
    PrintLib.newline
  end

  module TradingStrategies
    extend ActionView::Helpers::NumberHelper

    def self.print(
      strategy:,
      strategy_options:,
      trades_by_ticker:,
      result_by_ticker:,
      result_aggregate:,
      options: {}
    )
      options[:show_trades] ||= false
      options[:show_individual_results] ||= false

      PrintLib.h1(
        strategy.to_s.tr("_", " "),
        " (",
        strategy_options.to_a.map do |option|
          option.join(": ")
        end.join(", "),
        ")",
      )

      if options[:show_individual_results]
        # FIXME this is derpy, refactor
        result_by_ticker.each_key do |ticker|
          print_ticker(
            ticker: ticker,
            trades: trades_by_ticker[ticker],
            result: result_by_ticker[ticker],
            options: options,
          )
        end
      end

      PrintLib.h2("Aggregate")
      PrintLib.puts("Number of buys: ", result_aggregate[:n_buys][:sum])
      PrintLib.puts(
        "Cash spent: ",
        number_with_delimiter(result_aggregate[:cash_spent][:sum].round),
      )
      PrintLib.puts(
        "Cash earned: ",
        number_with_delimiter(result_aggregate[:cash_earned][:sum].round),
      )
      PrintLib.puts(
        "Stock value: ",
        number_with_delimiter(result_aggregate[:stock_value][:sum].round),
      )
      PrintLib.puts(
        "Total value: ",
        number_with_delimiter(result_aggregate[:total_value][:sum].round),
      )
      PrintLib.puts(
        "Total profit: ",
        number_with_delimiter(result_aggregate[:total_profit][:sum].round),
        " (",
        number_with_delimiter(result_aggregate[:total_profit_percent][:avg].round),
        "%)",
      )
      PrintLib.newline
    end

    def self.print_ticker(ticker:, trades:, result:, options: {})
      PrintLib.h2(PrintLib.ticker(ticker))

      if options[:show_trades]
        PrintLib.h3 "Trades"
        print_trades(trades: trades)
        PrintLib.newline
      end

      PrintLib.h3 "Result"
      PrintLib.puts "Number of buys: ", result[:n_buys]
      PrintLib.puts(
        "Cash spent: ",
        number_with_delimiter(result[:cash_spent].round),
      )
      PrintLib.puts(
        "Cash earned: ",
        number_with_delimiter(result[:cash_earned].round),
      )
      PrintLib.puts(
        "Stock value: ",
        number_with_delimiter(result[:stock_value].round),
      )
      PrintLib.puts(
        "Total value: ",
        number_with_delimiter(result[:total_value].round),
      )
      PrintLib.puts(
        "Total profit: ",
        number_with_delimiter(result[:total_profit].round),
        " (",
        number_with_delimiter(result[:total_profit_percent].round),
        "%)",
      )
      PrintLib.newline
    end

    def self.print_trades(trades:)
      trades.sort_by { |t| t[:date] }.each_with_index do |trade, index|
        PrintLib.puts(
          (index + 1).to_s.rjust(trades.size.to_s.size),
          ". ",
          trade[:type].to_s.upcase,
          " ",
          trade[:date],
          " @ ",
          number_with_delimiter(trade[:stock_price]),
        )
      end || PrintLib.puts("(no trades)")
    end
  end
end
