module PrintLib
  @current_indent = 0

  def self.newline
    self.puts("\n")
  end

  def self.h(string, h_char: "#", h_level: 1, h_newlines: 1)
    indent_for_h = h_level.to_i - 1

    self.puts(h_char * h_level.to_i + " " + string, indent: indent_for_h).tap do
      @current_indent = h_level.to_i
    end

    h_newlines.times{ self.newline }
  end

  #def self.puts_with_label(value)
  #  self.puts [
  #    value.var_name,
  #     ": ",
  #    value,
  #  ]
  #end

  def self.puts(string_or_array, indent: nil, indent_size: 2, indent_char: " ")
    return unless Config.print_lib_enabled

    string = if string_or_array.is_a? Array
      string_or_array.join
    else
      string_or_array
    end

    if indent_match = indent.to_s.match(/^\+\d+/)
      indent = @current_indent + indent_match[1].to_i
    end

    Kernel::puts(indent_char * indent_size.to_i * (indent || @current_indent) + string.to_s)
  end

  def self.method_missing(*args)
    if h_level_match = args[0].match(/^h(\d+)$/)
      h(args[1], h_level: h_level_match[1])
    else
      super
    end
  end
end
