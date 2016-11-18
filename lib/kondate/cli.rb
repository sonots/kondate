require 'thor'
require 'yaml'
require 'net/ssh'
require "highline/import"
require_relative '../kondate'
require 'fileutils'
require 'shellwords'
require 'find'
require 'facter'
require 'parallel'

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
      property_files = build_property_files(host)
      begin
        if proceed?(property_files)
          exit(-1) unless do_itamae(host, property_files)
        end
      ensure
        clean_property_files(property_files)
      end
    end

    desc "itamae-role <role>", "Execute itamae for multiple hosts in the role"
    option :role,                         :type => :array,   :default => []
    option :recipe,                       :type => :array,   :default => []
    option :debug,   :aliases => ["-d"],  :type => :boolean, :default => false
    option :confirm,                      :type => :boolean, :default => true
    option :vagrant,                      :type => :boolean, :default => false
    option :profile,                      :type => :string,  :default => nil, :desc => "[EXPERIMENTAL] Save profiling data", :banner => "PATH"
    option :recipe_graph,                 :type => :string,  :default => nil, :desc => "[EXPERIMENTAL] Write recipe dependency graph in DOT", :banner => "PATH"
    option :parallel, :aliases => ["-p"], :type => :numeric, :default => Facter['processorcount'].value.to_i 
    def itamae_role(role)
      $stdout.puts "Number of parallels is #{@options[:parallel]}"
      hosts = Kondate::Config.host_plugin.get_hosts(role)
      if hosts.nil? or hosts.empty?
        $stderr.puts 'No host'
        exit(1)
      end
      $stdout.puts "Target hosts are [#{hosts.join(", ")}]"

      property_files_of_hosts, summarized_property_files, hosts_of_roles = build_property_files_of_hosts(hosts)
      begin
        if proceed?(summarized_property_files, hosts_of_roles)
          successes = Parallel.map(hosts, in_processes: @options[:parallel]) do |host|
            do_itamae(host, property_files_of_hosts[host])
          end
          exit(-1) unless successes.all?
        end
      ensure
        clean_property_files_of_hosts(property_files_of_hosts)
      end
    end

    desc "serverspec <host>", "Execute serverspec"
    option :role,                        :type => :array,   :default => []
    option :recipe,                      :type => :array,   :default => []
    option :debug,   :aliases => ["-d"], :type => :boolean, :default => false
    option :confirm,                     :type => :boolean, :default => true
    option :vagrant,                     :type => :boolean, :default => false
    def serverspec(host)
      property_files = build_property_files(host)
      begin
        if proceed?(property_files)
          exit(-1) unless do_serverspec(host, property_files)
        end
      ensure
        clean_property_files(property_files)
      end
    end

    desc "serverspec-role <role>", "Execute serverspec for multiple hosts in the role"
    option :role,                         :type => :array,   :default => []
    option :recipe,                       :type => :array,   :default => []
    option :debug,   :aliases => ["-d"],  :type => :boolean, :default => false
    option :confirm,                      :type => :boolean, :default => true
    option :vagrant,                      :type => :boolean, :default => false
    option :parallel, :aliases => ["-p"], :type => :numeric, :default => Facter['processorcount'].value.to_i 
    def serverspec_role(role)
      $stdout.puts "Number of parallels is #{@options[:parallel]}"
      hosts = Kondate::Config.host_plugin.get_hosts(role)
      if hosts.nil? or hosts.empty?
        $stderr.puts 'No host'
        exit(1)
      end
      $stdout.puts "Target hosts are [#{hosts.join(", ")}]"

      property_files_of_hosts, summarized_property_files, hosts_of_roles = build_property_files_of_hosts(hosts)
      begin
        if proceed?(summarized_property_files, hosts_of_roles)
          successes = Parallel.map(hosts, in_processes: @options[:parallel]) do |host|
            do_serverspec(host, property_files_of_hosts[host])
          end
          exit(-1) unless successes.all?
        end
      ensure
        clean_property_files_of_hosts(property_files_of_hosts)
      end
    end

    private

    def do_itamae(host, property_files)
      ENV['RUBYOPT'] = "-I #{Config.plugin_dir} -r bundler/setup -r ext/itamae/kondate"
      property_files.each do |role, property_file|
        next if property_file.nil?
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
        return false unless system(command)
      end
      true
    end

    def do_serverspec(host, property_files)
      ENV['RUBYOPT'] = "-I #{Config.plugin_dir} -r bundler/setup -r ext/serverspec/kondate"
      ENV['TARGET_VAGRANT'] = '1' if @options[:vagrant]
      property_files.each do |role, property_file|
        next if property_file.nil?
        recipes = YAML.load_file(property_file)['attributes'].keys.map {|recipe|
          File.join(Config.middleware_recipes_serverspec_dir, recipe)
        }.compact
        recipes << File.join(Config.roles_recipes_serverspec_dir, role)
        spec_files = recipes.map {|recipe| "#{recipe}_spec.rb"}.select! {|spec| File.exist?(spec) }

        command = "TARGET_HOST=#{host.shellescape} TARGET_NODE_FILE=#{property_file.shellescape} bundle exec rspec"
        command << " #{spec_files.map{|f| f.shellescape }.join(' ')}"
        $stdout.puts command
        return false unless system(command)
      end
      true
    end

    def proceed?(property_files, hosts_of_roles = {})
      print_property_files(property_files, hosts_of_roles)
      if property_files.values.compact.empty?
        $stderr.puts "Nothing to run"
        false
      elsif @options[:confirm]
        prompt = ask "Proceed? (y/n):"
        prompt == 'y'
      else
        true
      end
    end

    def print_property_files(property_files, hosts_of_roles = {})
      roles = property_files.keys
      if roles.nil? or roles.empty?
        $stderr.puts 'No role'
        return
      end
      $stdout.puts "Show property files for roles: [#{roles.join(", ")}]"

      property_files.each do |role, property_file|
        hosts = hosts_of_roles[role]
        if hosts.nil? # itamae
          $stdout.print "Show property file for role: #{role}"
        else # itamae_role
          $stdout.print "Show representative property file for role: #{role}"
          $stdout.print " [#{hosts.join(", ")}]"
        end

        if property_file
          $stdout.puts
          $stdout.puts mask_secrets(File.read(property_file))
        else
          $stdout.puts " (does not exist, skipped)"
        end
      end
    end

    def clean_property_files(property_files)
      property_files.values.each do |file|
        File.unlink(file) rescue nil
      end
    end

    def clean_property_files_of_hosts(property_files_of_hosts)
      property_files_of_hosts.values.each do |property_files|
        clean_property_files(property_files)
      end
    end

    # @return [Hash] key value pairs whoses keys are roles and values are path (or nil)
    def build_property_files(host)
      builder = PropertyBuilder.new(host)
      roles = builder.filter_roles(@options[:role])

      property_files = {}
      roles.each do |role|
        if path = builder.install(role, @options[:recipe])
          property_files[role] = path
        else
          property_files[role] = nil
        end
      end

      property_files
    end

    def build_property_files_of_hosts(hosts)
      summarized_property_files = {}
      property_files_of_hosts = {}
      hosts_of_roles = {}
      hosts.each do |host|
        property_files = build_property_files(host)
        property_files_of_hosts[host] = property_files
        property_files.each {|role, path| summarized_property_files[role] ||= path }
        property_files.each {|role, path| (hosts_of_roles[role] ||= []) << host }
      end
      [property_files_of_hosts, summarized_property_files, hosts_of_roles]
    end

    def mask_secrets(str)
      str.gsub(/(.*key[^:]*): (.*)$/, '\1: *******').
        gsub(/(.*password[^:]*): (.*)$/, '\1: *******')
    end
  end
end
