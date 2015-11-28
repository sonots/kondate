require 'yaml'

module Kondate
  module HostPlugin
    # YAML format
    #
    # host1: [role1, role2]
    # host2: [role1, role2]
    class File < Base
      # @param [HashWithIndifferentAccess] config
      def initialize(config)
        super
        raise ConfigError.new('file: path is not configured') unless config.path
        @path = config.path
      end

      # @param [String] host hostname
      # @return [String] environment name
      def get_environment(host)
        ENV['ENVIRONMENT'] || 'development'
      end

      # @param [String] host hostname
      # @return [Array] array of roles
      def get_roles(host)
        YAML.load_file(@path)[host]
      end
    end
  end
end
