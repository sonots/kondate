require_relative 'config'

module Kondate
  class RoleFile
    attr_reader :dir, :role, :ext

    def self.explore(dir, role, ext = nil)
      self.new(dir, role, ext).explore
    end

    def initialize(dir, role, ext = nil)
      @dir = dir
      @role = role
      @ext = ext
    end

    # Returns readable role file exploring possible role files. For example,
    # if `role` is `myapp-web-staging`, this method explores files as
    #
    # 1. myapp-web-staging.yml
    # 1. myapp-web-base.yml
    # 1. myapp-web.yml
    # 1. myapp-base.yml
    # 1. myapp.yml
    # 1. base.yml
    #
    # @return [String] detected file path or last candidate path
    def explore
      paths = if Config.explore_role_files?
                possible_paths
              else
                [get_path]
              end
      paths.find {|path| File.readable?(path) } || paths.last
    end

    private

    def get_path(role = nil)
      "#{File.join(dir, role || @role)}#{ext}"
    end

    def possible_paths
      possible_roles.map {|role| get_path(role) }
    end

    def possible_roles
      parts = role.split('-')
      roles = []
      roles << 'base'
      roles << parts.shift
      parts.each do |part|
        last = roles.last
        roles << "#{last}-base"
        roles << "#{last}-#{part}"
      end
      roles.reverse!
    end
  end
end
