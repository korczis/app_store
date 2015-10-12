# encoding: utf-8
require 'bundler/cli'
Bundler::CLI.new.invoke(:install, [], path: 'gems', verbose: true, :retry => 3, :jobs => 4)
require 'bundler/setup'
require 'gooddata'

require_relative 'user_filters_brick'
require_relative 'vendor/dwh_middleware'

include GoodData::Bricks

p = GoodData::Bricks::Pipeline.prepare([
  DecodeParamsMiddleware,
  LoggerMiddleware,
  BenchMiddleware,
  GoodDataMiddleware,
  AWSMiddleware,
  FsProjectDownloadMiddleware.new(:source => :staging),
  FsProjectUploadMiddleware.new(:destination => :staging),
  WarehouseMiddleware,
  UserFiltersBrick])

p.call($SCRIPT_PARAMS.to_hash)
