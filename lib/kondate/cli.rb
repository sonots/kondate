require 'thor'
require 'yaml'
require 'net/ssh'
require "highline/import"
require_relative '../kondate'
require 'fileutils'
require 'shellwords'
require 'find'
require 'parallel'
require 'parallel/processor_count'

module Kondate
  class CLI < Thor
    extend Parallel::ProcessorCount

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

    desc "init [target_dir]", "Initialize kondate directory tree"
    def init(target_dir)
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
      with_host(host) {|property_files| do_itamae(host, property_files) }
    end

    desc "itamae-role <role>", "Execute itamae for multiple hosts in the role"
    option :role,                         :type => :array,   :default => []
    option :recipe,                       :type => :array,   :default => []
    option :debug,   :aliases => ["-d"],  :type => :boolean, :default => false
    option :confirm,                      :type => :boolean, :default => true
    option :vagrant,                      :type => :boolean, :default => false
    option :profile,                      :type => :string,  :default => nil, :desc => "[EXPERIMENTAL] Save profiling data", :banner => "PATH"
    option :recipe_graph,                 :type => :string,  :default => nil, :desc => "[EXPERIMENTAL] Write recipe dependency graph in DOT", :banner => "PATH"
    option :parallel, :aliases => ["-p"], :type => :numeric, :default => processor_count
    def itamae_role(role)
      with_role(role) {|host, property_files| do_itamae(host, property_files) }
    end

    desc "serverspec <host>", "Execute serverspec"
    option :role,                        :type => :array,   :default => []
    option :recipe,                      :type => :array,   :default => []
    option :debug,   :aliases => ["-d"], :type => :boolean, :default => false
    option :confirm,                     :type => :boolean, :default => true
    option :vagrant,                     :type => :boolean, :default => false
    def serverspec(host)
      with_host(host) {|property_files| do_serverspec(host, property_files) }
    end

    desc "serverspec-role <role>", "Execute serverspec for multiple hosts in the role"
    option :role,                         :type => :array,   :default => []
    option :recipe,                       :type => :array,   :default => []
    option :debug,   :aliases => ["-d"],  :type => :boolean, :default => false
    option :confirm,                      :type => :boolean, :default => true
    option :vagrant,                      :type => :boolean, :default => false
    option :parallel, :aliases => ["-p"], :type => :numeric, :default => processor_count
    def serverspec_role(role)
      with_role(role) {|host, property_files| do_serverspec(host, property_files) }
    end

    private

    def with_host(host, &block)
      property_files = build_property_files(host)
      begin
        print_property_files(property_files)
        if proceed?(property_files)
          exit(-1) unless yield(property_files)
        end
      ensure
        clean_property_files(property_files)
      end
    end

    def with_role(role, &block)
      $stdout.puts "Number of parallels is #{@options[:parallel]}"
      hosts = Kondate::Config.host_plugin.get_hosts(role)
      if hosts.nil? or hosts.empty?
        $stderr.puts 'No host'
        exit(1)
      end
      $stdout.puts "Target hosts are [#{hosts.join(", ")}]"

      property_files_of_host, summarized_property_files, hosts_of_role = build_property_files_of_host(hosts)
      begin
        print_property_files(summarized_property_files, hosts_of_role)
        if proceed?(summarized_property_files)
          successes = Parallel.map(hosts, in_processes: @options[:parallel]) do |host|
            yield(host, property_files_of_host[host])
          end
          exit(-1) unless successes.all?
        end
      ensure
        property_files_of_host.values.each {|property_files| clean_property_files(property_files) }
      end
    end

    def do_itamae(host, property_files)
      env = {}
      env['RUBYOPT'] = "-I #{Config.plugin_dir} -r bundler/setup -r ext/itamae/kondate"
      property_files.each do |role, property_file|
        next if property_file.empty?
        command = "bundle exec itamae ssh"
        command << " -h #{host}"

        properties = property_file.load

        if @options[:vagrant]
          command << " --vagrant"
        else
          # itamae itself sees Net:SSH::Config.for(host)
          # here, we set ssh config if property file specially specifies
          config = Net::SSH::Config.for(host, Net::SSH::Config.default_files)
          # itamae fallbacks to Etc.getlogin, but we prefer to fallback to ENV['USER'], then Etc.getlogin
          command << " -u #{properties['ssh_user'] || config[:user] || ENV['USER'] || ENV['LOGNAME'] || Etc.getlogin || Etc.getpwuid.name}"
          command << " -i #{(Array(properties['ssh_keys']) || []).first}" if properties['ssh_keys']
          command << " -p #{properties['ssh_port']}" if properties['ssh_port']
        end

        command << " -y #{property_file.path}"
        command << " -l=debug" if @options[:debug]
        command << " --dry-run" if @options[:dry_run]
        command << " --profile=#{@options[:profile]}" if @options[:profile]
        command << " --recipe-graph=#{@options[:recipe_graph]}" if @options[:recipe_graph]
        command << " bootstrap.rb"
        $stdout.puts "env #{env.map {|k, v| "#{k}=#{v.shellescape}" }.join(' ')} #{command}"

        return false unless system(env, command)
      end
      true
    end

    def do_serverspec(host, property_files)
      env = {}
      env['TARGET_VAGRANT'] = '1' if @options[:vagrant]
      env['RUBYOPT'] = "-I #{Config.plugin_dir} -r bundler/setup -r ext/serverspec/kondate"
      property_files.each do |role, property_file|
        next if property_file.empty?
        spec_files = property_file.load['attributes'].keys.map {|recipe|
          secret_spec_file = File.join(Config.secret_middleware_recipes_serverspec_dir, "#{recipe}_spec.rb")
          spec_file = File.join(Config.middleware_recipes_serverspec_dir, "#{recipe}_spec.rb")
          File.exist?(secret_spec_file) ? secret_spec_file : spec_file
        }.compact
        secret_role_spec_file = RoleFile.explore(Config.secret_roles_recipes_serverspec_dir, role, "_spec.rb")
        role_spec_file = RoleFile.explore(Config.roles_recipes_serverspec_dir, role, "_spec.rb")
        spec_files << (File.exist?(secret_role_spec_file) ? secret_role_spec_file : role_spec_file)
        spec_files.select! {|spec| File.exist?(spec) }

        env['TARGET_HOST'] = host
        env['TARGET_NODE_FILE'] = property_file.path
        command = "bundle exec rspec #{spec_files.map{|f| f.shellescape }.join(' ')}"
        $stdout.puts "env #{env.map {|k, v| "#{k}=#{v.shellescape}" }.join(' ')} #{command}"

        return false unless system(env, command)
      end
      true
    end

    def proceed?(property_files)
      if property_files.values.compact.reject(&:empty?).empty?
        $stderr.puts "Nothing to run"
        false
      elsif @options[:confirm]
        prompt = ask "Proceed? (y/n):"
        prompt == 'y'
      else
        true
      end
    end

    def print_property_files(property_files, hosts_of_role = {})
      roles = property_files.keys
      if roles.nil? or roles.empty?
        $stderr.puts 'No role'
        return
      end
      $stdout.puts "Show property files for roles: [#{roles.join(", ")}]"

      property_files.each do |role, property_file|
        hosts = hosts_of_role[role]
        if hosts.nil? # itamae
          $stdout.print "Show property file for role: #{role}"
        else # itamae_role
          $stdout.print "Show representative property file for role: #{role}"
          $stdout.print " hosts: [#{hosts.join(", ")}]"
        end
        $stdout.print ", sources: #{property_file.source_files}"

        if property_file.empty?
          $stdout.puts " (no attribute, skipped)"
        else
          $stdout.puts
          $stdout.puts property_file.read
        end
      end
    end

    def clean_property_files(property_files)
      property_files.values.each do |file|
        File.unlink(file) rescue nil
      end
    end

    # @return [Hash] key value pairs whoses keys are roles and values are path (or nil)
    def build_property_files(host)
      builder = PropertyBuilder.new(host)
      roles = builder.filter_roles(@options[:role])

      property_files = {}
      roles.each do |role|
        property_files[role] = builder.install(role, @options[:recipe])
      end

      property_files
    end

    def build_property_files_of_host(hosts)
      summarized_property_files = {}
      property_files_of_host = {}
      hosts_of_role = {}
      hosts.each do |host|
        property_files = build_property_files(host)
        property_files_of_host[host] = property_files
        property_files.each {|role, property_file| summarized_property_files[role] ||= property_file }
        property_files.each {|role, property_file| (hosts_of_role[role] ||= []) << host }
      end
      [property_files_of_host, summarized_property_files, hosts_of_role]
    end
  end
end
