# Kondate

Kondate is yet another nodes management framework for Itamae/Serverspec.

Kondate provides nodes/roles/attributes/run_lists management feature for Itamae/Serverspec.

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'kondate'
```

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install kondate

## Usage

Generate a template directory tree:

```
$ bundle exec kondate init .
```

Run itamae:

```
$ bundle exec kondate itamae <host>
```

Run serverspec:

```
$ bundle exec kondate serverspec <host>
```

Run itamae for multiple hosts of a given role in parallel:

```
$ bundle exec kondate itamae-role <role>
```

Run serverspec for multiple hosts of a given role in parallel:

```
$ bundle exec kondate serverspec-role <role>
```

## Configuration

`kondate init` provides a template directory tree such as:

```
.
├── .kondate.conf     # kondate configuration
├── bootstrap.rb      # itamae bootstrap
├── hosts.yml         # manages hostnames and its roles
├── properties        # manages run_lists and attributes
│   ├── nodes         # host specific properties
│   ├── roles         # role properties
│   └── environments  # environment properties
├── secrets           # manages secrets attributes such as passwords
│   └── properties
│       ├── nodes
│       ├── roles
│       └── environments
├── recipes           # itamae recipes
│   ├── middleware    # middleware recipes
│   │   └── base
│   │       └── default.rb
│   └── roles         # role recipes
└── spec              # serverspec specs
    ├── middleware    # middleware recipes specs
    │   └── base_spec.rb
    ├─  roles         # role recipes specs
    └── spec_helper.rb
```

### .kondate.conf

The default .kondate.conf looks like below:

```
middlware_recipes_dir: recipes/middleware
roles_recipes_dir: recipes/roles
middleware_recipes_serverspec_dir: spec/middleware
roles_recipes_serverspec_dir: spec/roles
nodes_properties_dir: properties/nodes
roles_properties_dir: properties/roles
environments_properties_dir: properties/environments
secret_nodes_properties_dir: secrets/properties/nodes
secret_roles_properties_dir: secrets/properties/roles
secret_environments_properties_dir: secrets/properties/environments
plugin_dir: lib
host_plugin:
  type: file
  path: hosts.yml
```

You can customize the directory tree with this conf.

### hosts.yml

The default uses `file` host plugin, and `hosts.yml`. The contents of `hosts.yml` look like below:

```
localhost: [sample]
```

where keys are host names, and values are array of roles.

```
$ bundle exec kondate itamae <host>
```

works as follows:

1. obtains a role list from `hosts.yml`
2. reads `properties/roles/#{role}.yml`, and find recipes and its attributes
3. runs recipes

You can create your own host plugin. See `Host Plugin` section for more details.

### properties

Property files are places to write recipes to run and attributes values.

```
├── properties        # manages run_lists and attributes
│   ├── nodes         # host specific properties
│   ├── roles         # role properties
│   └── environments  # environment properties
```

An example looks like below:

properties/roles/#{role}.yml

```
attributes:
  ruby:
    versions: [2.2.3]
    gems:
      2.2.3: [bundler]
  node:
    versions: [v0.12.2]
    global: v0.12.2
  nginx:
```

The attributes variables are accessible like `attrs['ruby']['versions']`, which is equivalent and short version of `node['attributes']['ruby']['versions']` in recipes.

You can also prepare host-specific property files such as:

properties/nodes/#{host}.yml

```
attributes:
  nginx:
    worker_processes: 8
```

In addition, you can also prepare environment property files such as:

properties/environments/development.yml

```
global_attributes:
  aws_region: ap-northeast-1
```

where `global_attributes` is accessible like `global_attrs['aws_region']`, which is equivalent and short version of `node['global_attributes']['aws_region']` in recipes.

These files are merged on kondate execution in order of `environment` + `role` + `node` (`node` > `role` > `environment` in the strong order).

### secret properties

Secret properties are places to write confidential attributes.

```
├── secrets         # manages secrets attributes such as passwords
│   └── properties
│       ├── nodes
│       ├── roles
│       └── environments
```

An example looks like below:

secrets/properties/roles/sample.yml

```
attributes:
  base:
    password: xxxxxxxx
```

These files are merged with property files on kondate execution.

Hint: I manage secret property files on github private repository. ToDo: support encryption.

### recipes

Put you itamae recipes:

```
├── recipes         # itamae recipes
│   ├── middleware  # middleware recipes
│   │   └── base
│   │       └── default.rb
│   └── roles       # role recipes
```

`middleware recipes` are usual recipes to write how to install middleware such as `nginx`, `mysql`.

`role recipes` are places to write role-specific provisioning. I often write recipes to create log directories for my app (role), for example.

recipes/roles/myapp/default.rb

```ruby
directory "/var/log/myapp" do
  owner myapp
  group myapp
  mode 0755
end
```

#### spec

Put your serverspec specs.

```
└── spec            # serverspec specs
    ├── middleware  # middleware recipes specs
    └── roles       # role recipes specs
```

It is required that `spec/spec_helper` has lines:

```ruby
set :host, ENV['TARGET_HOST']
set :set_property, YAML.load_file(ENV['TARGET_NODE_FILE'])
```

because these ENVs are passed by `kondate serverspec`.

Configuring following lines for vagrant is also recommended:

```
  if ENV['TARGET_VAGRANT']
    `vagrant up #{host}`

    config = Tempfile.new('', Dir.tmpdir)
    config.write(`vagrant ssh-config #{host}`)
    config.close

    Net::SSH::Config.for(host, [config.path])
  else
```

`ENV['TARGET_VAGRANT']` is turned on if `kondate serverspec` is executed with `--vagrant` option.

See [templates/spec/spec_helper.rb](./lib/kondate/templates/spec/spec_helper.rb) for an example.

### Exploring role files

Available version: >= v0.4.0

Assume `role` is delimited with `-` (you can configure the delimiter) such as `myapp-web-staging`, this feature explores role files in order of:

1. myapp-web-staging.yml
1. myapp-web-base.yml
1. myapp-web.yml
1. myapp-base.yml
1. myapp.yml
1. base.yml

This makes it possible to share a property file, for example, `myapp-web.yml` among `myapp-web-staging` and `myapp-web-production` roles.

To enable this feature, you need to configure .kondate.conf as:

```
explore_role_files: true # default is false
role_delimiter: "-" # default is -
```

## Host Plugin

The default reads `hosts.yml` to resolve roles of a host, but
you may want to resolve roles from AWS EC2 `roles` tag, or
you may want to resolve roles from your own host resolver API application.

Thus, `kondate` provides a plugin system to resolve hosts' roles.

### Naming Convention

You must follow the below naming conventions:

* gem name: kondate-host_plugin-xxx (xxx_yyy) (if you want to make a gem)
* file name: lib/kondate/host_plugin/xxx.rb (xxx_yyy.rb)
* class name: Kondate::HostPlugin::Xxx (XxxYyy)

If you want to put your own host plugin locally without publishing a gem, you can configure the location with .kondate.conf as:

```
plugin_dir: lib
```

### Interface

What you have to implement are `#initialize`, `#get_environment`, and `#get_roles` methods.
`get_hostinfo` method is an optional method to return arbitrary hostinfo of the host (available from kondate 0.2.0).
Here is an example of file plugin:

```ruby
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

      # Optional
      #
      # @param [String] host hostname
      # @return [Hash] arbitrary hostinfo
      def get_hostinfo(host)
        {}
      end
    end
  end
end
```

### Config

`config` parameter of `#initialize` is created from the configuration file (.kondate.conf):

```
host_plugin:
  type: file
  path: hosts.yml
```

`config.type` and `config.path` is available in the above config.

## See Also

* [Itamae meetup #1 で「ぼくのかんがえた Itamae/Serverspec 構成フレームワーク 〜 板前の献立 〜」というトークをしてきた](http://blog.livedoor.jp/sonots/archives/46245484.html) (Japanese)

## Development

```
bundle exec exe/kondate init .
vagrant up
```

```
bundle exec exe/kondate itamae vagrant-centos --vagrant --role sample
bundle exec exe/kondate serverspec vagrant-centos --vagrant --role sample
```

## ToDo

write tests

## License

The gem is available as open source under the terms of the [MIT License](http://opensource.org/licenses/MIT).
