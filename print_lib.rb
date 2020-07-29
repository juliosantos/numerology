module PrintLib
  HUMAN_TICKERS = {
    "AAL" => "American Airlines",
    "AAPL" => "Apple",
    "AMZN" => "Amazon",
    "BRK.A" => "Berkshire Hathaway",
    "CSTM" => "Constellium",
    "DDAIF" => "Daimler",
    "FB" => "Facebook",
    "FSLR" => "First Solar",
    "GOOG" => "Google",
    "HAL" => "Halliburton",
    "INN" => "Summit Hotel Properties",
    "NFLX" => "Netflix",
    "SNAP" => "Snapchat",
    "TSLA" => "Tesla",
    "TWTR" => "Twitter",
    "UNH" => "UnitedHealth Group",
    "WYNN" => "Wynn Resorts",
    "XOM" => "Exxon Mobil",
  }.freeze

  @current_indent_level = 0

  def self.ticker(ticker_symbol)
    [ticker_symbol, " (", HUMAN_TICKERS[ticker_symbol], ")"].join
  end

  def self.newline
    self.puts("\n")
  end

  def self.h(
    *content,
    h_char: "#",
    h_level: 1,
    h_newlines_suffix: 1
  )
    h_indent_level = h_level - 1
    next_indent_level = h_level

    newline if h_level == 1

    self.puts(
      h_char * h_level,
      " ",
      content,
      indent_count: h_indent_level,
    )

    h_newlines_suffix.times { newline }

    @current_indent_level = next_indent_level
  end

  def self.filename
    Config.print_lib_file_path +
      [
        Config.n_lookback_days,
        Config.n_streak_days,
        Config.target_avg_change,
        Config.sell_gain_target,
        [
          Config.start_date,
          Config.end_date,
        ].map { |date| date.strftime("%Y%m%d") },
        Config.tickers.join("+"),
        Time.now.to_i,
      ].flatten.join(":").tr(".", "_")
  end

  # TODO make this return selg to make things e.g. newlines eady to do
  def self.puts(*content, indent_count: nil, indent_size: 2, indent_char: " ")
    if (indent_change = indent_count.to_s.match(/^([+-]\d+)/)&.send(:[], 1))
      indent_count = @current_indent_level + indent_change.to_i
    else
      indent_count ||= @current_indent_level
    end

    indented_string = [
      indent_char * indent_count.to_i * indent_size.to_i,
      content,
    ].join

    Kernel.puts(indented_string) if Config.print_lib_stdout

    if Config.print_lib_file
      File.open(filename, "a") do |file|
        file.puts indented_string
      end
    end
  end

  def self.init
    if Config.print_lib_file && (dir = Config.print_lib_file_path)
      Dir.mkdir(dir) unless Dir.exist?(dir)
    end
  end

  def self.end
    Kernel.puts "\n*** written to #{filename}" if Config.print_lib_file
  end

  def self.method_missing(*args)
    if (h_level_match = args[0].match(/^h([1-9]+)$/))
      h(args[1..], h_level: h_level_match[1].to_i)
    else
      super
    end
  end
end
