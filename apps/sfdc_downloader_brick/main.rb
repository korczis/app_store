
# encoding: utf-8

require 'fileutils'

debug_install = true if !$SCRIPT_PARAMS.nil? and $SCRIPT_PARAMS.include?("DEBUG_INSTALL")

postfix = debug_install ? "2>&1": "1>/dev/null"

package = 'https://gdc-ms-ruby-packages.s3.amazonaws.com/sfdc_downloader_brick/v0.0.3.zip'
system("curl -LOk --retry 3 #{package} #{postfix}")

local_package = package.split('/').last
system("unzip -o #{local_package} #{postfix}")

FileUtils.mkdir_p('output')

# Bundler hack
require 'bundler/cli'
Bundler::CLI.new.invoke(:install, [],:path => "gems",:jobs => 4,:deployment => true,:local => true)

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
