module CoreExtensions
  module Array
    def stagger(interval)
      self.select.with_index { |_, index| (index % (interval + 1)).zero? }
    end
  end
end
