require_relative 'lib/rdap'

Gem::Specification.new do |spec|
  spec.name          = "rdap"
  spec.version       = RDAP::VERSION
  spec.authors       = ["Adrien Rey-Jarthon"]
  spec.email         = ["jobs@adrienjarthon.com"]

  spec.summary       = %q{A minimal Ruby client to query RDAP APIs though a bootstrap server}
  spec.homepage      = "https://github.com/jarthod/rdap"
  spec.required_ruby_version = Gem::Requirement.new(">= 2.3.0")

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  spec.files         = Dir.chdir(File.expand_path('..', __FILE__)) do
    `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(test|spec|features)/}) }
  end
  spec.require_paths = ["lib"]
end
