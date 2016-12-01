require 'yaml'

module Kondate
  class PropertyFile
    attr_reader :path, :source_files

    def initialize(path, source_files)
      @path = path
      @source_files = source_files
    end

    def read
      mask_secrets(File.read(path))
    end

    def load
      YAML.load_file(path)
    end

    private

    def mask_secrets(str)
      str.gsub(/(.*key[^:]*): (.*)$/, '\1: *******').
        gsub(/(.*password[^:]*): (.*)$/, '\1: *******')
    end
  end
end
