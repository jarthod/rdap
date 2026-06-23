require_relative 'lib/rdap'

Gem::Specification.new do |spec|
  spec.name          = "rdap"
  spec.version       = RDAP::VERSION
  spec.authors       = ["Adrien Rey-Jarthon"]
  spec.email         = ["jobs@adrienjarthon.com"]

  spec.summary       = %q{A minimal Ruby client to query RDAP APIs though a bootstrap server}
  spec.homepage      = "https://github.com/jarthod/rdap"
  spec.required_ruby_version = Gem::Requirement.new(">= 2.3.0")

  spec.files         = ["lib/rdap.rb"]
  spec.require_paths = ["lib"]
end
