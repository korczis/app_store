require 'json'
require 'json-schema'
require 'pp'
require 'fileutils'
require 'pathname'

begin
  require 'rspec/core/rake_task'

  RSpec::Core::RakeTask.new(:spec)

  task :default => :spec
rescue LoadError
  # no rspec available
end

# Schema for new Bricks.
brick_info_schema = {
  "type" => "object",
  "required" => ["name","version","language","created"],
  "properties" => {
    "name" => {"type" => "string"},
    "author" => {
        "type" => "object",
        "properties" => {
          "name" => {"type" => "string"},
          "email" => {"type" => "string"}
        }
    },
    "created" => {"type" => "string"},
    "version" => {"type" => "string"},
    "category" => {"type" => "string"},
    "language" => {"type" => "string"},
    "description" => { "type" => "string"},
    "tags" => {"type" => "string"},
    "is_live" => {"type" => "boolean"},
    "parameters" => {
        "type" => "array",
        "properties" => {
          "name" => {"type" => "string"},
          "description" => {"type" => "string"},
          "type" => {"type" => "string"},
          "mandatory" => {"type" => "boolean"},
        }
    }
  },
}

desc 'Gets info.json from /apps/ and validates.'
task :default do
  root = Pathname(__FILE__).expand_path.dirname
  bricks_root = root + "./apps/*/info.json"

  production_bricks = []
  bricks = Dir.glob(bricks_root).map do |path|
    brick = JSON.parse(File.read(path))
    if JSON::Validator.validate!(brick_info_schema, brick)
      production_bricks << brick
    else
      fail JSON::Schema::ValidationError
    end
  end

  task(:write).invoke(production_bricks)
end

desc 'Writes JSON file to location.'
task :write, :file do |w, bricks|

  File.open("./build/bricks.json", 'w') do |f|
    f.puts bricks.file.to_json
  end
end

