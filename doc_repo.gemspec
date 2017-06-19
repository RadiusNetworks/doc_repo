# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'doc_repo/version'

Gem::Specification.new do |spec|
  spec.name          = "doc_repo"
  spec.version       = DocRepo::VERSION
  spec.authors       = ["Christopher Sexton"]
  spec.email         = ["github@codeography.com"]
  spec.summary       = "Doc Repo: Load in app documentation via an external Github repo"
  spec.description   = "Doc Repo: Load in app documentation via an external Github repo"
  spec.homepage      = "https://github.com/RadiusNetworks/doc_repo"
  spec.license       = "MIT"

  spec.files         = `git ls-files -z`.split("\x0")
  spec.executables   = %w[ ]
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ["lib"]

  spec.required_ruby_version = '~> 2.3'

  spec.add_dependency "rouge", "~> 2.1"
  spec.add_dependency "redcarpet", "~> 3.2"

  spec.add_development_dependency "bundler", "~> 1.6"
  spec.add_development_dependency "rake", "~> 12.0"
  spec.add_development_dependency "rspec", "~> 3.0"
  spec.add_development_dependency "webmock", "~> 3.0"
end
