Dir[File.join(File.dirname(__FILE__), 'recipes/**/*.rb')].each { |file| load file }