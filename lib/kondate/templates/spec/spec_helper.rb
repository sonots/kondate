require 'serverspec'
require 'net/ssh'
require 'tempfile'
require 'yaml'

### required for kondate #####
host = ENV['TARGET_HOST']
set :set_property, YAML.load_file(ENV['TARGET_NODE_FILE'])
$stdout.sync = true
$stderr.sync = true
############################

set :backend, :ssh

if ENV['ASK_SUDO_PASSWORD']
  begin
    require 'highline/import'
  rescue LoadError
    fail "highline is not available. Try installing it."
  end
  set :sudo_password, ask("Enter sudo password: ") { |q| q.echo = false }
else
  set :sudo_password, ENV['SUDO_PASSWORD']
end

options =
  if ENV['TARGET_VAGRANT']
    `vagrant up #{host}`

    config = Tempfile.new('', Dir.tmpdir)
    config.write(`vagrant ssh-config #{host}`)
    config.close

    Net::SSH::Config.for(host, [config.path])
  else
    o = Net::SSH::Config.for(host)
    ssh_config_options =
      %w(encryption compression compression_level
         timeout forward_agent global_known_hosts_file
         auth_methods host_key host_key_alias host_name
         keys keys_only hmac auth_methods port proxy
         rekey_limit user user_known_hosts_file)

    ssh_config_options.map do |option|
      if property[option]
        o[option.to_sym] = property[option]
      end
    end
    o
  end

options[:user] ||= Etc.getlogin

set :host,        options[:host_name] || host
set :ssh_options, options

# Disable sudo
# set :disable_sudo, true


# Set environment variables
# set :env, :LANG => 'C', :LC_MESSAGES => 'C'

# Set PATH
# set :path, '/sbin:/usr/local/sbin:$PATH'
