HOKKE_GEM_ROOT = File.expand_path('..', File.dirname(__FILE__)) unless defined?(HOKKE_GEM_ROOT)

require "kondate/version"
require "kondate/config"
require "kondate/property_builder"
require "ext/hash/deep_merge"
require "kondate/string_util"
require "kondate/error"
