include ActionView::Helpers::NumberHelper

module MathLib
  def self.percentage(x, y)
    x.to_f / y.to_f * 100
  end

  def self.percent_difference (x, y)
    (y.to_f - x.to_f) / x.to_f.abs * 100
  end

  def self.average (array)
    return 0 if array.empty?

    array.reduce(&:+) / array.size.to_f
  end
end
