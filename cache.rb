module Cache
  def self.get(key, &block)
    if File.exists?(file_path(key))
      JSON.parse(File.read(file_path(key)))
    else
      cache = yield block
      File.write(file_path(key), cache.to_json)
      return cache
    end
  end

  def self.file_path(ticker)
    Config.api_cache_path + ticker
  end
end
