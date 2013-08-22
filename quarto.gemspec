# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'quarto/version'

Gem::Specification.new do |spec|
  spec.name          = "quarto"
  spec.version       = Quarto::VERSION
  spec.authors       = ["Avdi Grimm"]
  spec.email         = ["avdi@avdi.org"]
  spec.description   = %q{Yet another ebook publishing toolchain}
  spec.summary       = %q{Yet another ebook publishing toolchain}
  spec.homepage      = ""
  spec.license       = "MIT"

  spec.files         = `git ls-files`.split($/)
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ["lib"]

  spec.add_dependency "rake", "~> 10.0"
  spec.add_dependency "nokogiri", "~> 1.6"
  spec.add_dependency "fattr", "~> 2.2"
  spec.add_dependency "sass",  "3.2"
  spec.add_dependency "mime-types", "~> 1.24"
  spec.add_dependency "doc_raptor", "~> 0.3.2"

  spec.add_development_dependency "bundler", "~> 1.3"
  spec.add_development_dependency "rake", "~> 10.0"
  spec.add_development_dependency "rspec", "~> 2.14"
  spec.add_development_dependency "rspec-given", "~> 3.1"
  spec.add_development_dependency "test-construct", "~> 1.2"
  spec.add_development_dependency "debugger"
end
