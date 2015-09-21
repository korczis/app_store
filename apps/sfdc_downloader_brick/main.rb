#encoding: utf-8

require 'fileutils'

fetch_gems = true

repo_gems = [
    'https://github.com/gooddata/salesforce_bulk_query/archive/master.zip',
    'https://gdc-ms-ruby-packages.s3.amazonaws.com/gooddata_connectors_base/s3.zip',
    'https://gdc-ms-ruby-packages.s3.amazonaws.com/gooddata_connectors_metadata/v0.0.4.zip',
    'https://gdc-ms-ruby-packages.s3.amazonaws.com/gooddata_connectors_downloader_salesforce/gse.zip'
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

#Create output folder
require 'fileutils'
FileUtils.mkdir_p('output')

# Bundler hack
require 'bundler/cli'
Bundler::CLI.new.invoke(:install, [],:path => "gems",:jobs => 4,:retry => 3,:deployment => true)

# Required gems
require 'bundler/setup'
require 'gooddata'
require 'gooddata_connectors_metadata'
require 'gooddata_connectors_downloader_salesforce'

# Require executive brick
require_relative 'execute_brick'

include GoodData::Bricks

# Prepare stack
stack = [
    LoggerMiddleware,
    BenchMiddleware,
    GoodData::Connectors::Metadata::MetadataMiddleware,
    GoodData::Connectors::DownloaderSalesforce::SalesForceDownloaderMiddleWare,
    ExecuteBrick
]

# Create pipeline
p = GoodData::Bricks::Pipeline.prepare(stack)

$SCRIPT_PARAMS = {} if $SCRIPT_PARAMS.nil?

# Execute pipeline
p.call($SCRIPT_PARAMS)
