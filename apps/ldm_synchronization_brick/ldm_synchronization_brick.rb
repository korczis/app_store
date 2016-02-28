# utf-8

require 'open-uri'
require 'csv'
require 'gooddata'

module GoodData
  module Bricks
    class LDMSynchronizationBrick < GoodData::Bricks::Brick
      MODES = %w(add_to_organization sync_project sync_domain_and_project sync_multiple_projects_based_on_pid sync_one_project_based_on_pid sync_one_project_based_on_custom_id)

      def version
        '0.0.1'
      end

      def call(params)
        client = params['GDC_GD_CLIENT'] || fail('client needs to be passed into a brick as "GDC_GD_CLIENT"')
        domain_name = params['organization'] || params['domain']
        fail 'organization has to be defined' unless domain_name
        domain = client.domain(domain_name)

        segment_id = params[:segment] || :all
        segments = Array(domain.segments(segment_id))
        segment_blueprint = segments.pmap { |s| [s, s.master_project.blueprint] }

        results = segment_blueprint.pmapcat do |segment, blueprint|
          segment.clients.pmap(&:project).compact.pmap do |project|
            begin
              project.update_from_blueprint(blueprint)
              {
                result: :success,
                project: project
              }
            rescue RuntimError => e
              {
                result: :failure,
                reason: e.message,
                project: project
              }
            end
          end
        end

        results.group_by { |x| x[:result] }.each do |type, results|
          puts "There are #{results.count} of type #{type}"
          puts "Printing first 10"
          table = Terminal::Table.new do |t|
            t << ['Project ID', 'Reason']
            t << :separator
            results.take(10).each { |r| t.add_row([r[:project].pid, r[:reason]]) }
          end
          puts table
        end

        if results.any? { |x| x[:result] == :failure }
          fail "Some LDM migrations have failed"
        end
      end
    end
  end
end
