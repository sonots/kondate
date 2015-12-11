require 'thor'
require 'yaml'
require 'net/ssh'
require 'rspec/core/rake_task'
require "highline/import"
require_relative '../kondate'
require 'fileutils'
require 'shellwords'
require 'find'

module Kondate
  class CLI < Thor
   # cf. http://qiita.com/KitaitiMakoto/items/c6b9d6311c20a3cc21f9
    def self.exit_on_failure?
      true
    end

    class_option :config, :aliases => ["-c"], :type => :string,  :default => nil
    class_option :dry_run,                    :type => :boolean, :default => false
    # default_command :itamae

    def initialize(args = [], opts = [], config = {})
      super
      Config.configure(@options)
    end

    desc "init [target_dir = .]", "Initialize kondate directory tree"
    def init(target_dir = '.')
      Config.kondate_directories.each do |_, dir|
        $stdout.puts "mkdir -p #{File.join(target_dir, dir)}"
        FileUtils.mkdir_p(File.join(target_dir, dir)) unless @options[:dry_run]
      end

      templates_dir = File.join(Kondate::ROOT, 'lib', 'kondate', 'templates')
      templates_dir_length = templates_dir.length
      Find.find(templates_dir).select {|f| File.file?(f) }.each do |src|
        next if File.basename(src) == '.gitkeep'
        dst = File.join(target_dir, src[templates_dir_length+1 .. -1])
        dst_dir = File.dirname(dst)
        unless Dir.exist?(dst_dir)
          $stdout.puts "mkdir -p #{dst_dir}"
          FileUtils.mkdir_p(dst_dir) unless @options[:dry_run]
        end
        $stdout.puts "cp #{src} #{dst}"
        FileUtils.copy(src, dst) unless @options[:dry_run]
      end
    end

    desc "itamae <host>", "Execute itamae"
    option :role,                        :type => :array,   :default => []
    option :recipe,                      :type => :array,   :default => []
    option :debug,   :aliases => ["-d"], :type => :boolean, :default => false
    option :confirm,                     :type => :boolean, :default => true
    option :vagrant,                     :type => :boolean, :default => false
    option :profile,                     :type => :string,  :default => nil, :desc => "[EXPERIMENTAL] Save profiling data", :banner => "PATH"
    option :recipe_graph,                :type => :string,  :default => nil, :desc => "[EXPERIMENTAL] Write recipe dependency graph in DOT", :banner => "PATH"
    def itamae(host)
      builder, property_files = build_property_files(host)

      property_files.each do |role, property_file|
        ENV['TARGET_HOST'] = host
        ENV['RUBYOPT'] = "-I #{Config.plugin_dir} -r bundler/setup -r ext/itamae/kondate"
        command = "bundle exec itamae ssh"
        command << " -h #{host}"

        properties = YAML.load_file(property_file)

        if @options[:vagrant]
          command << " --vagrant"
        else
          config = Net::SSH::Config.for(host)
          command << " -u #{properties['ssh_user'] || config[:user] || ENV['USER']}"
          command << " -i #{(properties['ssh_keys'] || []).first || (config[:ssh_keys] || []).first || (File.exist?(File.expand_path('~/.ssh/id_dsa')) ? '~/.ssh/id_dsa' : '~/.ssh/id_rsa')}"
          command << " -p #{properties['ssh_port'] || config[:port] || 22}"
        end

        command << " -y #{property_file}"
        command << " -l=debug" if @options[:debug]
        command << " --dry-run" if @options[:dry_run]
        command << " --profile=#{@options[:profile]}" if @options[:profile]
        command << " --recipe-graph=#{@options[:recipe_graph]}" if @options[:recipe_graph]
        command << " bootstrap.rb"
        $stdout.puts command
        exit(-1) unless system(command)
      end
    end

    desc "serverspec <host>", "Execute serverspec"
    option :role,                        :type => :array,   :default => []
    option :recipe,                      :type => :array,   :default => []
    option :debug,   :aliases => ["-d"], :type => :boolean, :default => false
    option :confirm,                     :type => :boolean, :default => true
    option :vagrant,                     :type => :boolean, :default => false
    def serverspec(host)
      builder, property_files = build_property_files(host)

      ENV['RUBYOPT'] = "-I #{Config.plugin_dir} -r bundler/setup -r ext/serverspec/kondate"
      ENV['TARGET_VAGRANT'] = '1' if @options[:vagrant]
      property_files.each do |role, property_file|
        RSpec::Core::RakeTask.new([host, role].join(':'), :recipe) do |t, args|
          ENV['TARGET_HOST'] = host

          ENV['TARGET_NODE_FILE'] = property_file
          recipes = YAML.load_file(property_file)['attributes'].keys.map {|recipe|
            File.join(Config.middleware_recipes_serverspec_dir, recipe)
          }.compact
          recipes << File.join(Config.roles_recipes_serverspec_dir, role)
          t.pattern = '{' + recipes.join(',') + '}_spec.rb'
        end

        Rake::Task["#{host}:#{role}"].invoke(@options[:recipe])
      end
    end

    private

    def build_property_files(host)
      builder = PropertyBuilder.new(host)
      roles   = builder.filter_roles(@options[:role])
      if roles.nil? or roles.empty?
        $stderr.puts 'No role'
        exit(1)
      end
      $stdout.puts "roles: [#{roles.join(', ')}]"

      property_files = {}
      roles.each do |role|
        if path = builder.install(role, @options[:recipe])
          property_files[role] = path
          $stdout.puts "# #{role}"
          $stdout.puts mask_secrets(File.read(path))
        else
          $stdout.puts "# #{role} (no attribute, skipped)"
        end
      end

      if property_files.empty?
        $stderr.puts "Nothing to run"
        exit(1)
      end

      if @options[:confirm]
        prompt = ask "Proceed? (y/n):"
        exit(0) unless prompt == 'y'
      end

      [builder, property_files]
    end

    def mask_secrets(str)
      str.gsub(/(.*key[^:]*): (.*)$/, '\1: *******').
        gsub(/(.*password[^:]*): (.*)$/, '\1: *******')
    end
  end
end
