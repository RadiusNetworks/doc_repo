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
  spec.description   = ""
  spec.homepage      = ""
  spec.license       = "MIT"

  spec.files         = `git ls-files -z`.split("\x0")
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ["lib"]

  spec.add_dependency "rouge", "~> 1.6"
  spec.add_dependency "redcarpet", "~> 3.1"

  spec.add_development_dependency "bundler", "~> 1.6"
  spec.add_development_dependency "rake", "~> 10.0"
  spec.add_development_dependency "webmock", "~> 1.0"
  spec.add_development_dependency "rspec", "~> 3.0"
  spec.add_development_dependency "pry"
end
