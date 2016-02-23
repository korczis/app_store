require 'gooddata'

require_relative '../../../apps/segment_synchronization_brick/segment_synchronization_brick'

include GoodData::Bricks

describe GoodData::Bricks::SegmentSynchronizationBrick do
  before(:all) do
    @project_part_name = 'SegmentSynchronizationBrick Test Project'
    @project_name = Time.now.strftime("%Y%m%d-%H%M%s #{@project_part_name}")
    @segment_name = 'test_segment'
    @client_names = %w(client-1 client-2 client-3 client-4 client-5)

    @client = GoodData.connect('mustang@gooddata.com', 'jindrisska', server: 'https://mustangs.intgdc.com', verify_ssl: false)
    @domain = @client.domain('mustangs')

    old_projects = @client.projects.select do |project|
      project.title.include?(@project_part_name)
    end

    old_projects.each(&:delete)

    begin
      @segment = @domain.segments(@segment_name)
      @segment.clients.each do |client|
        client.delete
      end
      @segment.delete
    rescue
      # Segment already deleted
    end

    # @project = @client.create_project(title: @project_name, auth_token: 'mustangs')

    blueprint = GoodData::Model::ProjectBlueprint.build(@project_name) do |p|
      p.add_date_dimension('committed_on')
      p.add_dataset('devs') do |d|
        d.add_anchor('attr.dev')
        d.add_label('label.dev_id', :reference => 'attr.dev')
        d.add_label('label.dev_email', :reference => 'attr.dev')
      end
      p.add_dataset('commits') do |d|
        d.add_anchor('attr.commits_id')
        d.add_fact('fact.lines_changed')
        d.add_date('committed_on')
        d.add_reference('devs')
      end
    end
    @project = GoodData::Project.create_from_blueprint(blueprint, auth_token: 'mustangs')
    puts "Created project #{@project.pid}"

    @segment = @domain.create_segment(segment_id: @segment_name, master_project: @project)

    @clients = @client_names.map do |client|
      @segment.create_client({id: client})
    end

    # Initial synchronization of clients
    @segment.synchronize_clients
    @domain.provision_client_projects

    # Load data
    commits_data = [
      ['fact.lines_changed', 'committed_on', 'devs'],
      [1, '01/01/2014', 1],
      [3, '01/02/2014', 2],
      [5, '05/02/2014', 3]]
    @project.upload(commits_data, blueprint, 'commits')

    devs_data = [
      ['label.dev_id', 'label.dev_email'],
      [1, 'tomas@gooddata.com'],
      [2, 'petr@gooddata.com'],
      [3, 'jirka@gooddata.com']]
    @project.upload(devs_data, blueprint, 'devs')

    # create a metric
    @metric = @project.facts('fact.lines_changed').create_metric
    @metric.lock
    @metric.save

    @report = @project.create_report(title: 'Awesome_report', top: [@metric], left: ['label.dev_email'])
    @report.lock
    @report.save

    ########################
    # Create new dashboard #
    ########################
    @dashboard = @project.create_dashboard(:title => 'Test Dashboard')

    @tab = @dashboard.create_tab(:title => 'Tab Title #1')
    @tab.title = 'Test #42'

    @item = @tab.add_report_item(:report => @report, :position_x => 10, :position_y => 20)
    @item.position_x = 400
    @item.position_y = 300
    @dashboard.lock
    @dashboard.save
  end

  after(:all) do
    @segment.delete
    @project.delete
  end

  it 'should be able to synchronize projects' do
    stack = [
      DecodeParamsMiddleware,
      SegmentSynchronizationBrick
    ]

    pipeline = GoodData::Bricks::Pipeline.prepare(stack)

    params = {
      'GDC_GD_CLIENT' => @client,
      'gdc_project' => @project,
      'organization' => 'mustangs',
      'segment' => @segment_name
    }

    res = pipeline.call(params)
    expect(res[0].details.items.length).to eql(@client_names.length)
    res[0].details.items.each do |item|
      expect(@client_names.include?(item['id'])).to eql(true)
      expect(item['status']).to eql('OK')
    end
  end
end
