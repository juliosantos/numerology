class Report
  REPORT_DISPLAY_OPTIONS = {
    individual: {
      gain_values: true,
      gain_chart: true,
      gain_target_percents: [2, 5, 10, 15, 20, 30, 50, 100],
    },
    aggregate: {
      gain_values: true,
      gain_chart: true,
      gain_target_percents: [
        (1...10).step(1),
        (10...20).step(2),
        (20...50).step(5),
        (50...100).step(10),
        (100..200).step(20),
      ].map(&:to_a).flatten,
    },
  }

  def self.parameters
    PrintLib.h1 "Parameters"

    PrintLib.puts(
      "Tickers: ",
      Config.tickers.map do |ticker|
        [
          ticker,
          ([
            "(",
            HUMAN_TICKERS[ticker],
            ")",
          ].join if Config.verbose_tickers),
        ].compact.join(" ")
      end.compact.join(", ")
    )

    PrintLib.puts "Dates: ", Config.start_date, " -> ", Config.end_date
    PrintLib.newline

    PrintLib.h2 "Panic model:"
    %w|n_lookback_days n_streak_days target_avg_change|.map do |param_name|
      PrintLib.puts param_name, ": ", Config.send(param_name)
    end
    PrintLib.puts "sell_gain_target: ", Config.sell_gain_target.to_s, "%"
    PrintLib.newline
  end

  def initialize(historical_data, gain_target_percents)
    @historical_data = historical_data
    @gain_target_percents = gain_target_percents
  end

  def puts_indent(string, indent, options={indent_size: 2, indent_char: " "})
    PrintLib.puts_indent(string, indent)
  end

  def oddities
    PrintLib.h1 "Oddities"

    PrintLib.puts(
      "Avg trading days per year: ",
      MathLib.average(@historical_data.map do |ticker, ticker_data|
        ticker_data["historical_data"].avg_trading_days_per_year
      end),
    )
    PrintLib.newline

    PrintLib.puts(
      "Avg trading days per month: ",
      MathLib.average(@historical_data.map do |ticker, ticker_data|
        ticker_data["historical_data"].avg_trading_days_per_month
        end),
    )
    PrintLib.newline
  end

  def gnuplot(formatted_plot_data)
    puts `echo '#{formatted_plot_data}' | gnuplot -e "set terminal dumb enhanced size 160,30; set logscale y; set yrange [1:200]; set ytics axis out nomirror (#{GAIN_TARGET_PERCENTS.join(",")}); set xrange [0:600]; set xtics axis out nomirror (5,10,20,50,100,150,300,450,600); plot '-' using 1:2 with points notitle pt '*'"`
    #puts `echo '#{formatted_plot_data}' | gnuplot -e "set terminal dumb enhanced size 180,40; set autoscale; set xdata time; set timefmt '%Y-%m-%d'; plot '-' using 1:2 with lines notitle"`
    #`echo '#{formatted_plot_data}' | gnuplot -e "set terminal png enhanced size 1000,800; set autoscale; set xdata time; set timefmt '%Y-%m-%d'; set output 'derp.png'; plot '-' using 1:2 with lines notitle"`
  end

  def report
    @historical_data.each_with_index do |(ticker, ticker_data), index|
      puts "Calculating gain averages: #{ticker} (#{index} / #{@historical_data.size})"

      ticker_data["historical_data"].calculate_average_gain_horizons(GAIN_TARGET_PERCENTS)
    end

    puts
    puts "REPORT"
    puts

    puts "Individual tickers"
    puts

    @historical_data.each do |ticker, ticker_data|
      puts_indent ticker, 1
      single_stock_report(ticker_data, 2)
    end

    puts "Aggregate data"

    avg = MathLib.average(@historical_data.map do |ticker, ticker_data|
      ticker_data["historical_data"].buy_days.size / (ticker_data["historical_data"].days.size / 365).round(1)
    end)
    puts_indent "Average buy opportunities per year: #{avg}", 1

    puts_indent "Average days to gain", 1
    aggregate_avg_days_to_gain = @gain_target_percents.reduce({}) do |memo, gain_target_percent|
      all_gains = @historical_data.map do |ticker, ticker_data|
        ticker_data.dig("gains", gain_target_percent, "avg_days_to_gain")
      end
      averageable_gains = all_gains - [Float::INFINITY]

      memo[gain_target_percent] = {
        "avg_days_to_gain" => if averageable_gains.any?
          MathLib.average(averageable_gains)
        else
          Float::INFINITY
        end,
        "gain_target_percent_reached_count" => averageable_gains.size,
      }
      memo
    end

    if REPORT_DISPLAY_OPTIONS[:aggregate][:gain_values]
      aggregate_avg_days_to_gain.each do |gain_target_percent, gains|
        next unless REPORT_DISPLAY_OPTIONS[:aggregate][:gain_target_percents].include?(gain_target_percent)
        puts_indent "#{gain_target_percent}%: #{gains["avg_days_to_gain"]} (#{gains["gain_target_percent_reached_count"]} stocks)", 2
      end
    end

    if REPORT_DISPLAY_OPTIONS[:aggregate][:gain_chart]
      gnuplot(aggregate_avg_days_to_gain.map{ |gain_target_percent, gains| [gains["avg_days_to_gain"], gain_target_percent].join("\t") }.join("\n"))
    end
  end

def single_stock_report(ticker_data, indent)
    n_days = ticker_data["historical_data"].days.size
    n_years = (n_days / 365).round(1)
    puts_indent "Start: #{ticker_data["historical_data"].start_date}", indent
    puts_indent "Number of days: #{n_days} (#{(n_days / 365).round(1)} years)", indent

    n_buy_days = ticker_data["historical_data"].buy_days.size
    puts_indent "Number of buy days: #{n_buy_days} (#{(n_buy_days / n_years)} / year)", indent

    puts_indent "Average days to gain", indent

    if REPORT_DISPLAY_OPTIONS[:individual][:gain_values]
      ticker_data["historical_data"].gains.each do |gain_target_percent, gains|
        next unless REPORT_DISPLAY_OPTIONS[:aggregate][:gain_target_percents].include?(gain_target_percent)
        gain_target_percent_reached_percentage = ((gains["gain_target_percent_reached_count"] / n_buy_days.to_f) * 100)
        gain_target_percent_reached_percentage = gain_target_percent_reached_percentage.nan? ? 0 : gain_target_percent_reached_percentage
        puts_indent "#{gain_target_percent}%: #{gains["avg_days_to_gain"]} (#{gains["gain_target_percent_reached_count"]} buy days / #{gain_target_percent_reached_percentage.round}%)", indent + 1
      end
    end

    if REPORT_DISPLAY_OPTIONS[:individual][:gain_chart]
      gnuplot(ticker_data["historical_data"].gains.map{ |gain_target_percent, gains| [gains["avg_days_to_gain"], gain_target_percent].join("\t") }.join("\n"))
    end

    puts
  end

  def baseline_performance
    PrintLib.h1 "Baseline performance"

    PrintLib.puts(
      "Aggregate: ",
      number_with_delimiter(MathLib.average(@historical_data.map do |ticker, ticker_data|
        baseline = ticker_data["historical_data"].baseline
        PrintLib.puts(
          ticker,
          ": ",
          number_with_delimiter(baseline["performance"].round(1)),
          "% (",
          number_with_delimiter(baseline["avg_start_price"].round),
          " -> ",
          number_with_delimiter(baseline["avg_end_price"].round),
          ")",
        )

        baseline["performance"]
      end).round),
      "%"
    )

    PrintLib.newline
  end
end
