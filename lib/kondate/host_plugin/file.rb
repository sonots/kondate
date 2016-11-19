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

        @roles_of_host = YAML.load_file(@path)
        @hosts_of_role = {}
        @roles_of_host.each do |host, roles|
          roles.each do |role|
            @hosts_of_role[role] ||= []
            @hosts_of_role[role] << host
          end
        end
      end

      # @param [String] host hostname
      # @return [String] environment name
      def get_environment(host)
        ENV['ENVIRONMENT'] || 'development'
      end

      # @param [String] host hostname
      # @return [Array] array of roles
      def get_roles(host)
        @roles_of_host[host]
      end

      # @param [String] role role
      # @return [Array] array of hosts
      #
      # Available from kondate >= 0.3.0
      def get_hosts(role)
        @hosts_of_role[role]
      end
    end
  end
end
