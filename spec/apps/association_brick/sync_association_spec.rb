require 'gooddata'
APP_STORE_ROOT = File.expand_path('../../../..', __FILE__)
$LOAD_PATH.unshift(APP_STORE_ROOT)
require 'apps/segments_workspace_association_brick/association_brick'

include GoodData::Bricks

describe 'Association brick' do

  before(:all) do
    @client = GoodData.connect('mustang@gooddata.com', 'jindrisska', server: 'https://mustangs.intgdc.com', verify_ssl: false )
    @domain = @client.domain('mustangs')
    unless (@domain.segments('segment_test_brick') rescue nil)
      @project = @client.create_project(title: 'Project for schedule testing', auth_token: 'mustangs')
      @segment = @domain.create_segment(segment_id: 'segment_test_brick', master_project: @project)
    else
      @segment = @domain.segments('segment_test_brick')
      @project = @segment.master_project
    end
    @tempfile = Tempfile.new('association_sync')

    headers = [:segment_id, :client_id]
    CSV.open(@tempfile.path, 'w') do |csv|
      csv << headers
      csv << ['segment_test_brick', 'client_890']
      csv << ['segment_test_brick', 'client_891']
      csv << ['segment_test_brick', 'client_892']
    end

    @project.upload_file(@tempfile.path)
  end
  
  after(:all) do
    # @segment && @segment.delete
    # @project && @project.delete
  end

  it 'should create an association' do

    p = GoodData::Bricks::Pipeline.prepare([
      DecodeParamsMiddleware,
      SegmentAssociationBrick
    ])
    p.call({
      'GDC_GD_CLIENT' => @client,
      'gdc_project' => @project,
      'organization' => 'mustangs',
      'input_source' => Pathname(@tempfile.path).basename.to_s
    })
    expect(@domain.segments.pmapcat { |s| s.clients.to_a }.map(&:client_id)).to eq ['client_890', 'client_891', 'client_892']
  end

  it 'should create an association with custom headers' do
    tempfile = Tempfile.new('association_sync')

    headers = ['a', 'b']
    CSV.open(tempfile.path, 'w') do |csv|
      csv << headers
      csv << ['segment_test_brick', 'client_890']
      csv << ['segment_test_brick', 'client_891']
      csv << ['segment_test_brick', 'client_892']
    end

    @project.upload_file(tempfile.path)

    p = GoodData::Bricks::Pipeline.prepare([
      DecodeParamsMiddleware,
      SegmentAssociationBrick
    ])
    p.call({
      'GDC_GD_CLIENT' => @client,
      'gdc_project' => @project,
      'organization' => 'mustangs',
      'segment_id_column' => 'a',
      'client_id_column' => 'b',
      'input_source' => Pathname(tempfile.path).basename.to_s
    })
    expect(@domain.segments.pmapcat { |s| s.clients.to_a }.map(&:client_id)).to eq ['client_890', 'client_891', 'client_892']
  end

  it 'should fail if any value is empty' do

    p = GoodData::Bricks::Pipeline.prepare([
      DecodeParamsMiddleware,
      SegmentAssociationBrick
    ])
    expect do
      p.call({
        'GDC_GD_CLIENT' => @client,
        'gdc_project' => @project,
        'organization' => 'mustangs',
        'segment_id_column' => 'e',
        'client_id_column' => 'd',
        'input_source' => Pathname(@tempfile.path).basename.to_s
      })
    end.to raise_error
  end

  it 'should create an association with technical client included' do
    p = GoodData::Bricks::Pipeline.prepare([
      DecodeParamsMiddleware,
      SegmentAssociationBrick
    ])
    p.call({
      'GDC_GD_CLIENT' => @client,
      'gdc_project' => @project,
      'organization' => 'mustangs',
      'input_source' => Pathname(@tempfile.path).basename.to_s,
      'technical_client' => { segment_id: 'segment_test_brick', client_id: 'gd_technical_client' }
    })
    expect(@domain.segments.pmapcat { |s| s.clients.to_a }.map(&:client_id)).to eq ['client_890', 'client_891', 'client_892', 'gd_technical_client']
  end

  it 'should be able to remove client with technical client included' do
    tempfile = Tempfile.new('association_sync')

    headers = [:segment_id, :client_id]
    CSV.open(tempfile.path, 'w') do |csv|
      csv << headers
      csv << ['segment_test_brick', 'client_890']
      csv << ['segment_test_brick', 'client_892']
    end

    @project.upload_file(tempfile.path)

    p = GoodData::Bricks::Pipeline.prepare([
      DecodeParamsMiddleware,
      SegmentAssociationBrick
    ])
    p.call({
      'GDC_GD_CLIENT' => @client,
      'gdc_project' => @project,
      'organization' => 'mustangs',
      'input_source' => Pathname(tempfile.path).basename.to_s,
      'technical_client' => { segment_id: 'segment_test_brick', client_id: 'gd_technical_client' }
    })
    expect(@domain.segments.pmapcat { |s| s.clients.to_a }.map(&:client_id)).to eq ['client_890', 'client_892', 'gd_technical_client']
  end
end
