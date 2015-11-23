require 'yaml'
require 'tempfile'

module Kondate
  class PropertyBuilder
    attr_reader :host

    def initialize(host)
      @host = host
    end

    def roles
      @roles ||=
        begin
          vagrant? ? [] : Config.host_plugin.get_roles(@host)
        rescue => e
          $stderr.puts "cannot get roles from host:#{@host}, #{e.class} #{e.message}"
          []
        end
    end

    def filter_roles(filters)
      filters = Array(filters).map {|role| role.gsub(':', '-') }
      if roles.empty? # maybe, development (vagrant) env
        @roles = filters # append specified roles
        @roles.each do |role|
          unless File.exist?(role_file(role))
            $stderr.puts "#{role_file(role)} does not exist, possibly typo?"
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
          @roles = roles & filters
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
      File.join(Config.roles_properties_dir, "#{role}.yml")
    end

    def secret_role_file(role)
      File.join(Config.secret_roles_properties_dir, "#{role}.yml")
    end

    def get_content(yaml_file)
      content = File.exist?(yaml_file) ? YAML.load_file(yaml_file) : {}
      content.is_a?(Hash) ? content : {}
    end

    # Generate tmp node file (for each role)
    #
    #   role_file + secret_role_file + nod_file + node_secret_file + roles: @roles
    #
    # This file is automatically created and removed
    def install(role, filter_recipes = nil)
      node_property        = get_content(node_file)
      secret_node_property = get_content(secret_node_file)
      role_property        = get_content(role_file(role))
      secret_role_property = get_content(secret_role_file(role))

      property = {
        'role'  => role,
        'roles' => roles,
        'attributes' => {},
      }.deep_merge!(role_property).
      deep_merge!(secret_role_property).
      deep_merge!(node_property).
      deep_merge!(secret_node_property)

      # filter out the recipe
      if filter_recipes and !filter_recipes.empty?
        property['attributes'].keys.each do |key|
          property['attributes'].delete(key) unless filter_recipes.include?(key)
        end
      end

      if property['attributes'].empty?
        nil
      else
        Tempfile.open("provisioning_") do |fp|
          YAML.dump(property, fp)
        end.path
      end
    end

    def vagrant?
      %r{\Avagrant} === @host
    end
  end
end
