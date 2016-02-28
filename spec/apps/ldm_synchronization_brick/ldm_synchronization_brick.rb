require 'gooddata'
APP_STORE_ROOT = File.expand_path('../../../..', __FILE__)
$LOAD_PATH.unshift(APP_STORE_ROOT)
require 'apps/ldm_synchronization_brick/ldm_synchronization_brick'

TOKEN = ENV['token']
PASS = ENV['password']

include GoodData::Bricks

describe 'Association brick' do

  before(:all) do

    @client = GoodData.connect('mustang@gooddata.com', PASS, server: 'https://mustangs.intgdc.com', verify_ssl: false )
    @domain = @client.domain('mustangs')

    @blueprint = GoodData::Model::ProjectBlueprint.build('HR Demo Project') do |p|
      p.add_dataset('dataset.department', title: 'Department', folder: 'Department & Employee') do |d|
        d.add_anchor('attr.department.id', title: 'Department ID')
        d.add_label('label.department.id', reference:'attr.department.id', title: 'Department ID')
        d.add_label('label.department.name', reference: 'attr.department.id', title: 'Department Name')
        d.add_attribute('attr.department.region', title: 'Department Region')
        d.add_label('label.department.region', reference: 'attr.department.region', title: 'Department Region')
      end
    end

    @master_project = @client.create_project_from_blueprint(@blueprint, auth_token: TOKEN)
    @segment = @domain.create_segment(segment_id: "segment_ldm_sync", master_project: @master_project)
    @segment.synchronize_clients

    # Let's provision 2 projects with LDM
    @segment.create_client(id: "client_ldm_sync_1")
    @domain.provision_client_projects
    # And one without project
    @segment.create_client(id: "client_ldm_sync_3")
  end
  
  after(:all) do
    @domain.segments.pmapcat { |s| s.clients.to_a }.peach(&:delete)
    @domain.segments.peach(&:delete)
    @master_project && @master_project.delete
  end

  it 'should be equal to LDM in master when nothings changes' do

    p = GoodData::Bricks::Pipeline.prepare([
      DecodeParamsMiddleware,
      LDMSynchronizationBrick
    ])
    p.call({
      'GDC_GD_CLIENT' => @client,
      'organization' => 'mustangs'
    })
    client_1_blueprint = @segment.clients.find { |c| c.id == 'client_ldm_sync_1'}.project.blueprint
    client_1_fields = client_1_blueprint.datasets.flat_map {|d| d.fields.map { |f| [d.id, f.id || f.reference]}}
    master_fields = @segment.master_project.blueprint.datasets.flat_map {|d| d.fields.map { |f| [d.id, f.id || f.reference]}}
    
    expect(client_1_fields).to eq master_fields
    expect(@segment.clients.find { |c| c.id == 'client_ldm_sync_3'}.project).to eq nil
  end

  it 'should be equal to LDM in master when we change stuff (add a column)' do
    updated_blueprint = GoodData::Model::ProjectBlueprint.build('HR Demo Project') do |p|
      p.add_dataset('dataset.department', title: 'Department', folder: 'Department & Employee') do |d|
        d.add_anchor('attr.department.id', title: 'Department ID')
        d.add_fact('fact.department.number', title: 'Number')
        d.add_label('label.department.id', reference:'attr.department.id', title: 'Department ID')
        d.add_label('label.department.name', reference: 'attr.department.id', title: 'Department Name')
        d.add_attribute('attr.department.region', title: 'Department Region')
        d.add_label('label.department.region', reference: 'attr.department.region', title: 'Department Region')
      end
    end

    @segment.master_project.update_from_blueprint(updated_blueprint)

    p = GoodData::Bricks::Pipeline.prepare([
      DecodeParamsMiddleware,
      LDMSynchronizationBrick
    ])
    p.call({
      'GDC_GD_CLIENT' => @client,
      'organization' => 'mustangs'
    })

    client_1_blueprint = @segment.clients.find { |c| c.id == 'client_ldm_sync_1'}.project.blueprint
    client_1_fields = client_1_blueprint.datasets.flat_map {|d| d.fields.map { |f| [d.id, f.id || f.reference]}}
    master_fields = @segment.master_project.blueprint.datasets.flat_map {|d| d.fields.map { |f| [d.id, f.id || f.reference]}}
    
    expect(client_1_fields).to eq master_fields
    expect(@segment.clients.find { |c| c.id == 'client_ldm_sync_3'}.project).to eq nil
  end
end
