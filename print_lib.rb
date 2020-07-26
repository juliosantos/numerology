module PrintLib
  @current_indent = 0

  def self.newline
    self.puts("\n")
  end

  def self.h(
      string,
      h_char: "#",
      h_level: 1,
      h_newlines: 1
  )
    h_indent_level = h_level - 1
    next_indent_level = h_level

    self.puts(
      h_char * h_level,
      " ",
      string,
      indent_count: h_indent_level
    )

    h_newlines.times{ newline }
      
    @current_indent = next_indent_level
  end

  def self.puts_filename
    @puts_filename ||= Config.print_lib_file_path + [
      Config.n_lookback_days,
      Config.n_streak_days,
      Config.target_avg_change,
      Config.sell_gain_target,
      [
        Config.start_date,
        Config.end_date,
      ].map{ |date| date.strftime("%Y%m%d") },
      Config.tickers.join("+"),
      Time.now.to_i,
    ].flatten.join(":").gsub(/\./, "_")
  end

  def self.puts(*content, indent_count: nil, indent_size: 2, indent_char: " ")
    if indent_change = indent_count.to_s.match(/^\+\d+/)&.send(:[], 1)
      indent_count = @current_indent + indent_change[1].to_i
    else
      indent_count ||= @current_indent
    end

    string = [
      indent_char * indent_count.to_i * indent_size.to_i,
      content,
    ].join

    Kernel.puts(string) if Config.print_lib_stdout

    if Config.print_lib_file
      File.open(puts_filename, "a") do |file|
        file.puts string
      end
    end
  end

  def self.init
    if Config.print_lib_file && (dir = Config.print_lib_file_path) && Config.print_lib_file
      Dir.mkdir(dir) unless Dir.exists?(dir)
    end
  end

  def self.end
    if Config.print_lib_file
      Kernel.puts "\n*** written to #{puts_filename}"
    end
  end

  def self.method_missing(*args)
    if h_level_match = args[0].match(/^h([1-9]+)$/)
      h(args[1], h_level: h_level_match[1].to_i)
    else
      super
    end
  end
end
