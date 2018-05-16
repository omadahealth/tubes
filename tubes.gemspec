# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'tubes/version'

Gem::Specification.new do |spec|
  spec.name          = "tubes"
  spec.version       = Tubes::VERSION
  spec.authors       = ["cconstantine"]
  spec.email         = ["cconstan@gmail.com"]

  spec.summary       = %q{Consul service lookup request router.}
  spec.description   = %q{Routes requests based on consul services.}
  spec.homepage      = "https://github.com/cconstantine/tubes"
  spec.license       = "MIT"

  # Prevent pushing this gem to RubyGems.org by setting 'allowed_push_host', or
  # delete this section to allow pushing this gem to any host.
  if spec.respond_to?(:metadata)
    spec.metadata['allowed_push_host'] = "TODO: Set to 'http://mygemserver.com'"
  else
    raise "RubyGems 2.0 or newer is required to protect against public gem pushes."
  end

  spec.files         = `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(test|spec|features)/}) }
  spec.bindir        = "exec"
  spec.executables   = spec.files.grep(%r{^exec/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_dependency "diplomat"
  spec.add_dependency "em-proxy"
	spec.add_dependency "http_parser.rb"
	spec.add_dependency "uuid"

  spec.add_development_dependency "bundler", "~> 1.10"
  spec.add_development_dependency "rake", "~> 10.0"
  spec.add_development_dependency "rspec"
  spec.add_development_dependency "byebug"
end
