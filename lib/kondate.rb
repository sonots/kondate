module Kondate
  ROOT = File.expand_path('../..', __FILE__)
end

require "kondate/version"
require "kondate/config"
require "kondate/property_builder"
require "ext/hash/deep_merge"
require "kondate/string_util"
require "kondate/error"
