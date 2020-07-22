module MathLib
  def self.percent_difference (x, y)
    (y.to_f - x.to_f) / x.to_f.abs * 100
  end

  def self.average (array)
    array.reduce(&:+) / array.size
  end
end
