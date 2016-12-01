require 'yaml'
require 'tempfile'
require_relative 'property_file'

module Kondate
  class PropertyBuilder
    attr_reader :host

    def initialize(host)
      @host = host
    end

    def environment
      @environment ||=
        begin
          Config.host_plugin.get_environment(@host) || ''
        rescue => e
          $stderr.puts "cannot get environment for host:#{@host}, #{e.class} #{e.message}"
          ''
        end
    end

    def roles
      @roles ||=
        begin
          Config.host_plugin.get_roles(@host) || []
        rescue => e
          $stderr.puts "cannot get roles for host:#{@host}, #{e.class} #{e.message}"
          []
        end
    end

    def hostinfo
      @hostinfo ||=
        begin
          if Config.host_plugin.respond_to?(:get_hostinfo)
            Config.host_plugin.get_hostinfo(@host) || {}
          else
            {}
          end
        rescue => e
          $stderr.puts "cannot get hostinfo for host:#{@host}, #{e.class} #{e.message}"
          {}
        end
    end

    def filter_roles(filters)
      return self.roles if filters.nil? or filters.empty?
      filters = Array(filters).map {|filter| filter.gsub(':', '-') }
      if roles.empty? # maybe, development (vagrant) env
        @roles = filters # append specified roles
        @roles.each do |role|
          file = role_file(role)
          unless File.exist?(file)
            $stderr.puts "#{file} does not exist, possibly typo?"
            exit(1)
          end
        end
      else
        if (filters - roles).size > 0
          $stderr.puts "cannot specify #{(filters - roles).first}"
          exit(1)
        end
        unless filters.empty?
          # filter out for production env
          @roles = self.roles & filters
        end
      end
      @roles
    end

    def node_file
      File.join(Config.nodes_properties_dir, "#{@host}.yml")
    end

    def secret_node_file
      File.join(Config.secret_nodes_properties_dir, "#{@host}.yml")
    end

    def role_file(role)
      RoleFile.explore(Config.roles_properties_dir, role, ".yml")
    end

    def secret_role_file(role)
      RoleFile.explore(Config.secret_roles_properties_dir, role, ".yml")
    end

    def environment_file(environment)
      File.join(Config.environments_properties_dir, "#{environment}.yml")
    end

    def secret_environment_file(environment)
      File.join(Config.secret_environments_properties_dir, "#{environment}.yml")
    end

    def get_content(yaml_file)
      content = File.exist?(yaml_file) ? YAML.load_file(yaml_file) : {}
      content.is_a?(Hash) ? content : {}
    end

    # Generate tmp node file (for each role)
    #
    #   { environment: environment, role: role, roles: roles } +
    #   environment_file + secret_environment_file +
    #   role_file + secret_role_file +
    #   node_file + node_secret_file
    #
    # This file is automatically created and removed
    def install(role, filter_recipes = nil)
      files = [
        environment_file(environment),
        secret_environment_file(environment),
        role_file(role),
        secret_role_file(role),
        node_file,
        secret_node_file,
      ].compact.select {|f| File.readable?(f) }

      property = HashExt.new.deep_merge!({
        'environment' => environment,
        'role'        => role,
        'roles'       => roles,
        'hostinfo'    => hostinfo,
      })
      files.each do |file|
        property.deep_merge!(get_content(file))
      end
      property['attributes'] ||= {}

      # filter out the recipe
      if filter_recipes and !filter_recipes.empty?
        property['attributes'].keys.each do |key|
          property['attributes'].delete(key) unless filter_recipes.include?(key)
        end
      end

      if property['attributes'].empty?
        nil
      else
        fp = Tempfile.create("kondate_")
        YAML.dump(property.to_h, fp)
        fp.close
        PropertyFile.new(fp.path, files)
      end
    end
  end
end
