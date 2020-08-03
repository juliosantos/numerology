module MathLib
  def self.percentage(part, whole)
    part.to_f / whole * 100
  end

  def self.percent_difference(before, after)
    return 0 if before == after

    (after.to_f - before) / before.to_f.abs * 100
  end

  def self.average(array)
    return 0 if array.empty?

    array.reduce(&:+) / array.size.to_f
  end

  def self.monotonic_decrease?(array)
    array
      .each_cons(2)
      .all? { |a, b| a > b }
  end

  def self.compound_interest(initial_value, percent, n_periods)
    initial_value * (1 + percent / 100.to_f)**n_periods
  end

  def self.random_combinations(ranges)
    Enumerator.new do |yielder|
      loop { yielder << ranges.map(&method(:rand)) }
    end
  end
end
