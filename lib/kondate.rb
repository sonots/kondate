module Kondate
  ROOT = File.expand_path('../..', __FILE__)
end

require "kondate/version"
require "kondate/config"
require "kondate/role_file"
require "kondate/property_file"
require "kondate/property_builder"
require "kondate/hash_ext"
require "kondate/string_util"
require "kondate/error"
require "kondate/host_plugin/base"
