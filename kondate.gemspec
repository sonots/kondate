# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'kondate/version'

Gem::Specification.new do |spec|
  spec.name          = "kondate"
  spec.version       = Kondate::VERSION
  spec.authors       = ["sonots"]
  spec.email         = ["sonots@gmail.com"]

  spec.summary       = %q{Kondate is yet another nodes management framework for Itamae/Serverspec.}
  spec.description   = %q{Kondate is yet another nodes management framework for Itamae/Serverspec.}
  spec.homepage      = "https://github.com/sonots/kondate"
  spec.license       = "MIT"

  spec.files         = `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(test|spec|features)/}) }
  spec.bindir        = "exe"
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_dependency 'itamae'
  spec.add_dependency 'serverspec'
  spec.add_dependency 'thor'
  spec.add_dependency 'highline'
  spec.add_dependency 'facter'
  spec.add_dependency 'parallel'

  spec.add_development_dependency "bundler"
  spec.add_development_dependency "test-unit"
  spec.add_development_dependency "rake"
end
