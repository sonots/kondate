module Kondate
  module HostPlugin
    class Base
      attr_reader :config

      # @param [HashWithIndifferentAccess] config
      def initialize(config)
        @config = config
      end

      # @param [String] host hostname
      # @return [String] environment name
      def get_environment(host)
        ENV['ENVIRONMENT'] || 'development'
      end

      # @param [String] host hostname
      # @return [Array] array of roles
      def get_roles(host)
        raise NotImplementedError
      end
    end
  end
end
