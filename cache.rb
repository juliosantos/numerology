module Cache
  def self.get(key, &block)
    if File.exist?(file_path(key))
      JSON.parse(File.read(file_path(key)))
    else
      yield(block).tap do |result|
        File.write(file_path(key), result.to_json)
      end
    end
  end

  def self.file_path(ticker)
    Config.api_cache_path + ticker
  end
end
