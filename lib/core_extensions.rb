Dir.glob("./lib/core_extensions/**/*.rb").sort.each(&method(:require))

Array.include CoreExtensions::Array
