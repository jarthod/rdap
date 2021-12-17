require "rdap"
require "vcr"
require 'webmock/rspec'

VCR.configure do |config|
  config.cassette_library_dir = "spec/fixtures"
  config.hook_into :webmock
  config.configure_rspec_metadata!
end
