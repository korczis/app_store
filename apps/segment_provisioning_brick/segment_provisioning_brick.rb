# encoding: utf-8

require 'gooddata'

require 'terminal-table'

module GoodData::Bricks
  class SegmentProvisioningBrick < GoodData::Bricks::Brick
    def version
      '0.0.1'
    end

    def call(params)
      # Connect to GD
      client = params['GDC_GD_CLIENT'] || fail('client needs to be passed into a brick as "GDC_GD_CLIENT"')

      # Get domain name
      domain_name = params['organization'] || params['domain'] || fail('No "organization" or "domain" specified')

      domain = client.domain(domain_name)

      res = domain.provision_client_projects.group_by { |r| r[:status] }

      rows = res.keys.map do |result|
        [result, res[result].length]
      end

      table = Terminal::Table.new :title => 'Summary', :headings => %w(status count), :rows => rows
      puts table
      puts

      if res['ERROR']
        rows = res['ERROR'].map do |row|
          [row[:id], row[:error]['message']]
        end

        table = Terminal::Table.new :title => 'Errors', :headings => %w(client reason), :rows => rows
        puts table
      end

      res
    end
  end
end
