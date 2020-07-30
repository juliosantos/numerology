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
end
