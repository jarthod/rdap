require "bundler/gem_tasks"
require "rspec/core/rake_task"

RSpec::Core::RakeTask.new(:spec)

task default: :spec

namespace :bootstrap do
  desc "Update the bundled IANA RDAP bootstrap files in data/"
  task :update do
    require "open-uri"
    require "fileutils"
    FileUtils.mkdir_p("data")
    %w[dns ipv4 ipv6 asn].each do |registry|
      url = "https://data.iana.org/rdap/#{registry}.json"
      print "Fetching #{url}... "
      URI.open(url) { |remote| File.write("data/#{registry}.json", remote.read) }
      puts "done"
    end
  end
end
