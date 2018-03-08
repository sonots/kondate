require 'thor/core_ext/hash_with_indifferent_access'

module Kondate
  class Config
    class << self
      def configure(opts = {})
        @opts = opts
        reset
        self
      end

      def opts
        @opts ||= {}
      end

      def reset
        @config_path = nil
        @config = nil
      end

      DEFAULT_CONFIG_PATH = '.kondate.conf'

      def config
        return @config if @config
        if config_path == DEFAULT_CONFIG_PATH && !File.exist?(config_path)
          @config = Thor::CoreExt::HashWithIndifferentAccess.new({})
        else
          @config = Thor::CoreExt::HashWithIndifferentAccess.new(YAML.load_file(config_path))
        end
      end

      def config_path
        @config_path ||= opts[:config] || ENV['KONDATE_CONFIG_PATH'] || DEFAULT_CONFIG_PATH
      end

      def itamae_options
        @itamae_options ||= Thor::CoreExt::HashWithIndifferentAccess.new(config[:itamae_options] || {})
      end

      def serverspec_options
        @serverspec_options ||= Thor::CoreExt::HashWithIndifferentAccess.new(config[:serverspec_options] || {})
      end

      def kondate_directories
        {
          'middleware_recipes_dir' => middleware_recipes_dir,
          'roles_recipes_dir' => roles_recipes_dir,
          'middleware_recipes_serverspec_dir' => middleware_recipes_serverspec_dir,
          'roles_recipes_serverspec_dir' => roles_recipes_serverspec_dir,
          'nodes_properties_dir' => nodes_properties_dir,
          'roles_properties_dir' => roles_properties_dir,
          'environments_properties_dir' => environments_properties_dir,
          'secret_middleware_recipes_dir' => secret_middleware_recipes_dir,
          'secret_roles_recipes_dir' => secret_roles_recipes_dir,
          'secret_middleware_recipes_serverspec_dir' => secret_middleware_recipes_serverspec_dir,
          'secret_roles_recipes_serverspec_dir' => secret_roles_recipes_serverspec_dir,
          'secret_nodes_properties_dir' => secret_nodes_properties_dir,
          'secret_roles_properties_dir' => secret_roles_properties_dir,
          'secret_environments_properties_dir' => secret_environments_properties_dir,
        }
      end

      def middleware_recipes_dir
        config[:middleware_recipes_dir] || 'recipes/middleware'
      end

      def roles_recipes_dir
        config[:roles_recipes_dir] || 'recipes/roles'
      end

      def middleware_recipes_serverspec_dir
        config[:middleware_recipes_serverspec_dir] || 'spec/middleware'
      end

      def roles_recipes_serverspec_dir
        config[:roles_recipes_serverspec_dir] || 'spec/roles'
      end

      def nodes_properties_dir
        config[:nodes_properties_dir] || 'properties/nodes'
      end

      def roles_properties_dir
        config[:roles_properties_dir] || 'properties/roles'
      end

      def environments_properties_dir
        config[:environments_properties_dir] || 'properties/environments'
      end

      def secret_middleware_recipes_dir
        config[:secret_middleware_recipes_dir] || 'secrets/recipes/middleware'
      end

      def secret_roles_recipes_dir
        config[:secret_roles_recipes_dir] || 'secrets/recipes/roles'
      end

      def secret_middleware_recipes_serverspec_dir
        config[:secret_middleware_recipes_serverspec_dir] || 'secrets/spec/middleware'
      end

      def secret_roles_recipes_serverspec_dir
        config[:secret_roles_recipes_serverspec_dir] || 'secrets/spec/roles'
      end

      def secret_nodes_properties_dir
        config[:secret_nodes_properties_dir] || 'secrets/properties/nodes'
      end

      def secret_roles_properties_dir
        config[:secret_roles_properties_dir] || 'secrets/properties/roles'
      end

      def secret_environments_properties_dir
        config[:secret_environments_properties_dir] || 'secrets/properties/environments'
      end

      def explore_role_files?
        !config[:explore_role_files].nil?
      end

      def role_delimiter
        config[:role_delimiter] || '-'
      end

      def plugin_dir
        File.expand_path(config[:plugin_dir] || 'lib')
      end

      def host_plugin
        return @host_plugin if @host_plugin
        plugin = Thor::CoreExt::HashWithIndifferentAccess.new(config[:host_plugin] || {
          'type' => 'file',
          'path' => 'hosts.yml'
        })
        begin
          require File.join(Config.plugin_dir, "kondate/host_plugin/#{plugin.type}")
        rescue LoadError => e
          require "kondate/host_plugin/#{plugin.type}"
        end
        class_name = "Kondate::HostPlugin::#{StringUtil.camelize(plugin.type)}" 
        @host_plugin = Object.const_get(class_name).new(plugin)
      end
    end
  end
end
