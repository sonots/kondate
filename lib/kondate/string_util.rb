module Kondate
  class StringUtil
    def self.camelize(string)
      string = string.sub(/^[a-z\d]*/) { $&.capitalize }
      string.gsub!(/(?:_|(\/))([a-z\d]*)/i) { $2.capitalize }
      string.gsub!(/\//, '::')
      string
    end
  end
end
