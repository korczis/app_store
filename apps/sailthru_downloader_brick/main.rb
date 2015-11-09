# encoding: utf-8

require 'fileutils'

fetch_gems = true

repo_gems = [
    'https://gdc-ms-ruby-packages.s3.amazonaws.com/gooddata_connectors_base/s3.zip',
    'https://gdc-ms-ruby-packages.s3.amazonaws.com/gooddata_connectors_metadata/bds_implementation.zip',
    'https://github.com/adriantoman/gooddata_connectors_downloader_sailthru/archive/master.zip'
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
Bundler::CLI.new.invoke(:install, [],:path => "gems",:jobs => 4,:deployment => true)

# # Required gems
require 'bundler/setup'
require 'gooddata'
require 'gooddata_connectors_metadata'
require 'gooddata_connectors_downloader_sailthru'

# Require executive brick
require_relative 'execute_brick'

include GoodData::Bricks

# Prepare stack
stack = [
    LoggerMiddleware,
    BenchMiddleware,
    GoodData::Connectors::Metadata::MetadataMiddleware,
    GoodData::Connectors::SailThruDownloader::SailThruDownloaderMiddleWare,
    ExecuteBrick
]

# Create pipeline
p = GoodData::Bricks::Pipeline.prepare(stack)

# Default script params
$SCRIPT_PARAMS = {} if $SCRIPT_PARAMS.nil?

# Setup params
$SCRIPT_PARAMS['GDC_LOGGER'] = Logger.new(STDOUT)

# Delete previous batches from S3
s3 = AWS::S3.new(:server => 's3.amazonaws.com', :access_key_id => $SCRIPT_PARAMS['bds_access_key'], :secret_access_key => $SCRIPT_PARAMS['bds_secret_key'] )
bucket = s3.buckets[$SCRIPT_PARAMS['bds_bucket']]
prefix = [$SCRIPT_PARAMS['bds_folder'],$SCRIPT_PARAMS['account_id'],$SCRIPT_PARAMS['token'],'batches',$SCRIPT_PARAMS['ID']].join("/")
puts "[SAILTHRU_LOG][INFO] Deleting all files in folder #{prefix}."
bucket.objects.with_prefix(prefix).delete_all

# Execute pipeline
p.call($SCRIPT_PARAMS)