#encoding: utf-8

require 'fileutils'

fetch_gems = true

repo_gems = [
  'https://gdc-ms-ruby-packages.s3.amazonaws.com/gooddata_connectors_base/s3.zip',
  'https://gdc-ms-ruby-packages.s3.amazonaws.com/gooddata_connectors_metadata/v0.0.4.zip',
  'https://gdc-ms-ruby-packages.s3.amazonaws.com/gooddata_connectors_ads/v0.0.9.zip'
]

if fetch_gems
  repo_gems.each do |repo_gem|
    cmd = "curl -LOk --retry 3 #{repo_gem} 2>&1"
    puts cmd
    system(cmd)

    repo_gem_file = repo_gem.split('/').last

    cmd = "unzip -o #{repo_gem_file} 2>&1"
    puts cmd
    system(cmd)

    FileUtils.rm repo_gem_file
  end
end

# Bundler hack
require 'bundler/cli'
Bundler::CLI.new.invoke(:install, [],:path => "gems", :retry => 3, :jobs => 4,:deployment => false)
