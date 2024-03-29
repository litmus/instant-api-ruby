# coding: utf-8
lib = File.expand_path("../lib", __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require "litmus/instant/version"

Gem::Specification.new do |spec|
  spec.name          = "litmus-instant"
  spec.version       = Litmus::Instant::VERSION
  spec.authors       = ["Rahim Packir Saibo"]
  spec.email         = ["rahim@litmus.com"]

  spec.summary       = %q{Ruby client library for Litmus Instant API}
  spec.description   = %q{Ruby client library for Litmus Instant API, provides the simplest way to capture instant email previews in real clients from Ruby.}
  spec.homepage      = "https://github.com/litmus/instant-api-ruby"
  spec.license       = "MIT"

  # Prevent pushing this gem to RubyGems.org by setting 'allowed_push_host', or
  # delete this section to allow pushing this gem to any host.
  if spec.respond_to?(:metadata)
    # spec.metadata['allowed_push_host'] = "TODO: Set to 'http://mygemserver.com'"
  else
    raise "RubyGems 2.0 or newer is required to protect against public gem pushes."
  end

  spec.files         = `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(test|spec|features)/}) }
  spec.bindir        = "exe"
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_dependency "httparty", ">= 0.13.5", "< 1.0.0"

  spec.add_development_dependency "bundler"
  spec.add_development_dependency "rake"
  spec.add_development_dependency "rspec"
  spec.add_development_dependency "guard-rspec"
  spec.add_development_dependency "webmock"
  spec.add_development_dependency "vcr"
  spec.add_development_dependency "rack"
end
