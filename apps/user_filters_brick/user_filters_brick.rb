# utf-8
require 'gooddata'

module GoodData::Bricks
  class UserFiltersBrick < GoodData::Bricks::Brick
    def version
      "0.0.1"
    end

    def call(params)

      client = params['GDC_GD_CLIENT'] || fail('client needs to be passed into a brick as "GDC_GD_CLIENT"')
      domain_name = params['domain']
      domain = client.domain(domain_name) if domain_name
      project = client.projects(params['gdc_project']) || client.projects(params['GDC_PROJECT_ID'])

      data_source = GoodData::Helpers::DataSource.new(params['input_source'])

      config = params['filters_config']
      fail 'User filters brick requires configuration how the filter should be setup. For this use the param "filters_config"' if config.blank?
      symbolized_config = GoodData::Helpers.deep_dup(config)
      GoodData::Helpers.symbolize_keys!(symbolized_config)
      symbolized_config[:labels].each { |l| GoodData::Helpers.symbolize_keys!(l) }
      headers_in_options = params['csv_headers'] == 'false' || true

      mode = params['sync_mode'] || 'sync_project'
      filters = []

      csv_with_headers = if GoodData::UserFilterBuilder.row_based?(symbolized_config)
        false
      else
        headers_in_options
      end

      puts "Synchronizing in mode \"#{mode}\""
      results = case mode
                when 'sync_project'
                  CSV.foreach(File.open(data_source.realize(params), 'r:UTF-8'), headers: csv_with_headers, return_headers: false, encoding: 'utf-8') do |row|
                    filters << row
                  end
                  filters_to_load = GoodData::UserFilterBuilder::get_filters(filters, symbolized_config)
                  puts "Synchronizing #{filters_to_load.count} filters"
                  project.add_data_permissions(filters_to_load, restrict_if_missing_all_values: true, domain: domain, fail_early: false)
                when 'sync_one_project_based_on_pid'
                  CSV.foreach(File.open(data_source.realize(params), 'r:UTF-8'), headers: csv_with_headers, return_headers: false, encoding: 'utf-8') do |row|
                    filters << row if row['pid'] == project.pid
                  end
                  filters_to_load = GoodData::UserFilterBuilder::get_filters(filters, symbolized_config)
                  puts "Synchronizing #{filters_to_load.count} filters"
                  project.add_data_permissions(filters_to_load, restrict_if_missing_all_values: true, domain: domain, fail_early: false)
                when 'sync_multiple_projects_based_on_pid'
                  CSV.foreach(File.open(data_source.realize(params), 'r:UTF-8'), headers: csv_with_headers, return_headers: false, encoding: 'utf-8') do |row|
                    filters << row.to_hash
                  end
                  filters.group_by { |u| u['pid'] }.flat_map do |project_id, new_filters|
                    fail "Project id cannot be empty" if project_id.blank?
                    project = client.projects(project_id)
                    filters_to_load = GoodData::UserFilterBuilder::get_filters(new_filters, symbolized_config)
                    puts "Synchronizing #{filters_to_load.count} filters in project #{project.pid}"
                    project.add_data_permissions(filters_to_load, restrict_if_missing_all_values: true, domain: domain, fail_early: false)
                  end
                when 'sync_one_project_based_on_custom_id'
                  md = project.metadata
                  if md['GOODOT_CUSTOM_PROJECT_ID']
                    filter_value = md['GOODOT_CUSTOM_PROJECT_ID']
                    CSV.foreach(File.open(data_source.realize(params), 'r:UTF-8'), headers: csv_with_headers, return_headers: false, encoding: 'utf-8') do |row|
                      filters << row if row['pid'] == filter_value
                    end
                    filters_to_load = GoodData::UserFilterBuilder::get_filters(filters, symbolized_config)
                    puts "Synchronizing #{filters_to_load.count} filters"
                    project.add_data_permissions(filters_to_load, restrict_if_missing_all_values: true, domain: domain, fail_early: false)
                  else
                    fail "Project \"#{project.pid}\" metadata does not contain key GOODOT_CUSTOM_PROJECT_ID. We are unable to get the value to filter users."
                  end
                end

      results = results[:results]
      successes = results.select { |r| r[:status] == :successful }
      errors = results.select { |r| r[:status] == :failed }
      headers = errors.flat_map { |e| e.keys }.uniq
      table = Terminal::Table.new :headings => %w(type counts) , :rows => successes.group_by { |r| r[:type] }.map { |g, v| [g, v.count] }
      puts "\n#{table.to_s}"

      return if errors.empty?
      table = Terminal::Table.new :headings => headers , :rows => errors.take(25).map { |e| e.values_at(*headers) }
      puts "\n#{table.to_s}"
      fail 'There was an error syncing user filters.'
      
      # filters_to_load = GoodData::UserFilterBuilder::get_filters(filters, symbolized_config)
      # puts "Synchronizing #{filters_to_load.count} filters"
      # project.add_data_permissions(filters_to_load, restrict_if_missing_all_values: true, domain: domain, dry_run: false)
    end
  end
end
