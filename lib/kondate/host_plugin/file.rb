require 'yaml'

module Kondate
  module HostPlugin
    class File
      def initialize(config)
        raise ConfigError.new('file: path is not configured') unless config.path
        @path = config.path
      end

      def get_roles(host)
        # YAML format
        #
        # host1: [role1, role2]
        # host2: [role1, role2]
        YAML.load_file(@path)[host]
      end
    end
  end
end
