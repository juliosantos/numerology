module Cache
  CACHE_DIR = "cache/"

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
    CACHE_DIR + ticker
  end
end
