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
$ bundle exec kondate generate [target_dir .]
```

Run itamae:

```
$ bundle exec kondate itamae <host>
```

Run serverspec:

```
$ bundle exec kondate serverspec <host>
```

## Configuration

`kondate generate` provides a template directory tree such as:

```
.
├── .kondate.conf     # kondate configuration
├── bootstrap.rb    # itamae bootstrap
├── hosts.yml       # manages hostnames and its roles
├── properties      # manages run_lists and attributes
│   ├── nodes       # host specific properties
│   └── roles       # role properties
│       └── sample.yml
├── secrets         # manages secrets attributes such as passwords
│   └── properties
│       ├── nodes
│       └── roles
├── recipes         # itamae recipes
│   ├── middleware  # middleware recipes
│   │   └── base
│   │       └── default.rb
│   └── roles       # role recipes
└── spec            # serverspec specs
    ├── middleware  # middleware recipes specs
    │   └── base_spec.rb
    ├─  roles       # role recipes specs
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
secret_nodes_properties_dir: secrets/properties/nodes
secret_roles_properties_dir: secrets/properties/roles
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
├── properties      # manages run_lists and attributes
│   ├── nodes       # host specific properties
│   └── roles       # role properties
│       └── sample.yml
```

An example looks like below:

properties/roles/#{role}.yml

```
attributes:
  rbenv:
    versions: [2.2.3]
    gems:
      2.2.3: [bundler]
  ndenv:
    versions: [v0.12.2]
    global: v0.12.2
  nginx:
```

The attributes variables are accessible like `attrs['rbenv']['versions']` in recipes, which is equivalent and short version of `node['attributes']['rbenv']['versions']`.

You can also prepare a host-specific property file such as:

properties/nodes/#{host}.yml

```
attributes:
  nginx:
    worker_processes: 8
```

These files are merged on kondate execution in order of `role` + `node` (`node` file overwrites `role` file).

### secret properties

Secret properties are places to write confidential attributes.

```
├── secrets         # manages secrets attributes such as passwords
│   └── properties
│       ├── nodes
│       └── roles
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

See [templates/spec/spec_helper.rb](./lib/kondate/templates/spec/spec_helper.rb) for an example.

## Host Plugin

The default reads `hosts.yml` to resolve roles of a host, but 
you may want to resolve roles from AWS EC2 `roles` tag, or
you may want to resolve roles from your own host resolver API application.

Thus, `kondate` provides a plugin system to reolve hosts' roles.

### Naming Convention

You must follow the below naming conventions:

* gem name: kondate-host_plugin-xxx (xxx_yyy)
* file name: lib/kondate/host_plugin/xxx.rb (xxx_yyy.rb)
* class name: Kondate::HostPlugin::Xxx (XxxYyy)

### Interface

What you have to implement is `#initialize` and `#get_roles` methods. Here is an example of file plugin:

```ruby
require 'yaml'

module Kondate
  module HostPlugin
    class File
      # @param [HashWithIndifferentAccess] config
      def initialize(config)
        raise ConfigError.new('file: path is not configured') unless config.path
        @path = config.path
      end

      # @param [String] host hostname
      # @return [Array] array of roles
      def get_roles(host)
        # YAML format
        #
        # host1: [role1, role2]
        # host2: [role1, role2]
        YAML.load_file(@path)[host]
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

## Development

```
bundle exec exe/kondate generate
vagrant up
```

```
bundle exec exe/kondate itamae vagrant-centos --role sample
bundle exec exe/kondate serverspec vagrant-centos --role sample
```

## ToDo

write tests

## License

The gem is available as open source under the terms of the [MIT License](http://opensource.org/licenses/MIT).
