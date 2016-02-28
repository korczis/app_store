require 'gooddata'

require_relative '../../../apps/segment_provisioning_brick/segment_provisioning_brick'

include GoodData::Bricks

describe GoodData::Bricks::SegmentProvisioningBrick do
  before(:all) do
    @project_part_name = 'SegmentProvisioningBrick Test Project'
    @project_name = Time.now.strftime("%Y%m%d-%H%M%s #{@project_part_name}")
    @client_names = %w(client-1 client-2 client-3 client-4 client-5)
    @segment_name = 'test_segment'

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

    @project = @client.create_project(title: @project_name, auth_token: 'mustangs')
    @segment = @domain.create_segment(segment_id: @segment_name, master_project: @project)

    @clients = @client_names.map do |client|
      @segment.create_client({id: client})
    end

    # Initial synchronization of clients
    @segment.synchronize_clients
  end

  after(:all) do
    @clients.map do |client|
      client.delete
    end

    @segment.delete
    @project.delete
  end

  it 'should be able to provision projects' do
    stack = [
      DecodeParamsMiddleware,
      SegmentProvisioningBrick
    ]

    pipeline = GoodData::Bricks::Pipeline.prepare(stack)

    params = {
      'GDC_GD_CLIENT' => @client,
      'gdc_project' => @project,
      'organization' => 'mustangs'
    }

    # Do initial provisioning
    res = pipeline.call(params)
    expect(res['CREATED'] && res['CREATED'].length).to eql(@clients.length)
  end
end
