class Report
  def initialize(tickers_data)
    @historical_data = tickers_data
  end

  def self.parameters
    PrintLib.h1 "Parameters"

    PrintLib.puts "Dates: ", Config.start_date, " -> ", Config.end_date
    PrintLib.newline

    PrintLib.puts(
      "Tickers: ",
      Config.tickers.map do |ticker|
        PrintLib.ticker(ticker)
      end.compact.join(", ")
    )
    PrintLib.newline

    PrintLib.h2 "Panic model:"
    %w|n_lookback_days n_streak_days target_avg_change|.map do |param_name|
      PrintLib.puts param_name, ": ", Config.send(param_name)
    end
    PrintLib.newline

    PrintLib.h2 "Selling model:"
    PrintLib.puts "sell_gain_target: ", Config.sell_gain_target.to_s, "%"
    PrintLib.newline
  end

  def baseline_performance
    PrintLib.h1 "Baseline performance"

    ticker_performances = @historical_data.map do |ticker_data|
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
end
