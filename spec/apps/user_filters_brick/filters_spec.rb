require 'gooddata'
APP_STORE_ROOT = File.expand_path('../../../..', __FILE__)
$LOAD_PATH.unshift(APP_STORE_ROOT)
require './apps/user_filters_brick/user_filters_brick'

include GoodData::Bricks

describe GoodData::Bricks::UserFiltersBrick do

  before(:all) do
    logger = Logger.new(STDOUT)
    logger.level = Logger::DEBUG
    GoodData.logger = logger
    @client = GoodData.connect('svarovsky+gem_tester@gooddata.com', ENV['GDC_PASSWORD'])
    @blueprint = GoodData::Model::ProjectBlueprint.build('Test project') do |p|
      p.add_dataset('dataset.things') do |d|
        d.add_anchor('attr.things.id')
        d.add_label('label.things.id', reference: 'attr.things.id')
        d.add_attribute('attr.things.name')
        d.add_label('label.things.name', reference: 'attr.things.name')
      end
    end

    @project_1 = @client.create_project_from_blueprint(@blueprint, auth_token: ENV['GDC_TOKEN'])
    @project_2 = @client.create_project_from_blueprint(@blueprint, auth_token: ENV['GDC_TOKEN'])

    @project_1.set_metadata('GOODOT_CUSTOM_PROJECT_ID', 'A')
    @project_2.set_metadata('GOODOT_CUSTOM_PROJECT_ID', 'B')

    test_users = 10
    users_into_first = rand(test_users - 1 ) + 1
    users_into_second = 10 - users_into_first
    
    @domain = @client.domain('gooddata-tomas-svarovsky')
    @users = @domain.users.reject { |u| u == @client.user }.sample(test_users)
    @users_into_1 = @users.sample(users_into_first)
    @hashed_users_into_1 = @users_into_1.map { |r| r.to_hash.merge(role: 'admin') }

    @users_into_2 = @users - @users_into_1
    @hashed_users_into_2 = @users_into_2.map { |r| r.to_hash.merge(role: 'admin') }

    @project_1.import_users(@hashed_users_into_1, domain: @domain, whitelists: [@client.user.login])
    data = [
      ['label.things.id', 'label.things.name']
    ].concat(@users_into_1.each_with_index.map { |u, i| [i, u.login] })
    @project_1.upload(data, @blueprint, 'dataset.things')

    @project_2.import_users(@hashed_users_into_2, domain: @domain, whitelists: [@client.user.login])
    data = [
      ['label.things.id', 'label.things.name']
    ].concat(@users_into_2.each_with_index.map { |u, i| [i, u.login] })
    @project_2.upload(data, @blueprint, 'dataset.things')

    @expected_data_perms_in_1 = @users_into_1.map { |u| [u.login, "[Attr.Things.Name] IN ([#{u.login}])"] }
    @expected_data_perms_in_2 = @users_into_2.map { |u| [u.login, "[Attr.Things.Name] IN ([#{u.login}])"] }
  end

  after(:each) do
    @project_1.data_permissions.peach(&:delete)
    @project_2.data_permissions.peach(&:delete)
  end

  after(:all) do
    # @project_1 && @project_1.delete
    # @project_2 && @project_2.delete
  end

  it 'should be able to add filters to existing users' do
    begin
      tempfile = Tempfile.new('filters_sync')
      CSV.open(tempfile.path, 'w') do |csv|
        csv << [:login, :value]
        @users_into_1.each do |u|
          csv << [u.login, u.login]
        end
      end
      @project_1.upload_file(tempfile.path)
      user_process = @project_1.deploy_process(Pathname.new(APP_STORE_ROOT) + 'apps/user_filters_brick', name: 'user_filters_brick_example', type: :ruby)
      user_process.execute('main.rb', params: {
        'input_source'  => Pathname(tempfile.path).basename.to_s,
        'sync_mode'     => 'sync_project',
        'filters_config' => {
          'user_column' => 'login',
          'labels' => [{ 'label' => 'label.things.name', 'column' => 'value' }]
        }
      })
      expected_data_perms = @users_into_1.map { |u| [u.login, "[Attr.Things.Name] IN ([#{u.login}])"] }

      data_permissions = @project_1.data_permissions.pmap { |p| [p.related.login, p.pretty_expression] }
      expect(expected_data_perms.to_set).to eq data_permissions.to_set
    ensure
      tempfile.unlink
    end
  end

  it 'should sync one project based on PID' do
    begin
      tempfile = Tempfile.new('filters_sync')
      CSV.open(tempfile.path, 'w') do |csv|
        csv << [:login, :value, :pid]
        @users.each do |u|
          csv << [u.login, u.login, @users_into_1.include?(u) ? @project_1.pid : @project_2.pid]
        end
      end
      @project_1.upload_file(tempfile.path)
      user_process = @project_1.deploy_process(Pathname.new(APP_STORE_ROOT) + 'apps/user_filters_brick', name: 'user_filters_brick_example', type: :ruby)
      user_process.execute('main.rb', params: {
        'input_source'  => Pathname(tempfile.path).basename.to_s,
        'sync_mode'     => 'sync_one_project_based_on_pid',
        'filters_config' => {
          'user_column' => 'login',
          'labels' => [{ 'label' => 'label.things.name', 'column' => 'value' }]
        }
      })

      data_permissions = @project_1.data_permissions.pmap { |p| [p.related.login, p.pretty_expression] }
      expect(@expected_data_perms_in_1.to_set).to eq data_permissions.to_set
      expect(@expected_data_perms_in_2.to_set - data_permissions.to_set).to eq @expected_data_perms_in_2.to_set
    ensure
      tempfile.unlink
    end
  end

  it 'should fail if PID is not filled out' do
    begin
      tempfile = Tempfile.new('filters_sync')
      CSV.open(tempfile.path, 'w') do |csv|
        csv << [:login, :value, :pid]
        @users.each do |u|
          csv << [u.login, u.login, '']
        end
      end
      @project_1.upload_file(tempfile.path)
      user_process = @project_1.deploy_process(Pathname.new(APP_STORE_ROOT) + 'apps/user_filters_brick', name: 'user_filters_brick_example', type: :ruby)
      result = nil
      expect {
        result = user_process.execute('main.rb', params: {
          'input_source'  => Pathname(tempfile.path).basename.to_s,
          'sync_mode'     => 'sync_multiple_projects_based_on_pid',
          'filters_config' => {
            'user_column' => 'login',
            'labels' => [{ 'label' => 'label.things.name', 'column' => 'value' }]
          }
        })
      }.to raise_exception
      binding.pry
    ensure
      tempfile.unlink
    end
  end

  it 'should sync multiple projects based on CUSTOM_ID' do
    begin
      tempfile = Tempfile.new('filters_sync')
      CSV.open(tempfile.path, 'w') do |csv|
        csv << [:login, :value, :pid]
        @users.each do |u|
          csv << [u.login, u.login, @users_into_1.include?(u) ? 'A' : 'B']
        end
      end
      @project_1.upload_file(tempfile.path)
      user_process = @project_1.deploy_process(Pathname.new(APP_STORE_ROOT) + 'apps/user_filters_brick', name: 'user_filters_brick_example', type: :ruby)
      user_process.execute('main.rb', params: {
        'input_source'  => Pathname(tempfile.path).basename.to_s,
        'sync_mode'     => 'sync_one_project_based_on_custom_id',
        'filters_config' => {
          'user_column' => 'login',
          'labels' => [{ 'label' => 'label.things.name', 'column' => 'value' }]
        }
      })
      data_permissions_in_1 = @project_1.data_permissions.pmap { |p| [p.related.login, p.pretty_expression] }
      expect(@expected_data_perms_in_1.to_set).to eq data_permissions_in_1.to_set
      expect(@expected_data_perms_in_2.to_set - data_permissions_in_1.to_set).to eq @expected_data_perms_in_2.to_set
    ensure
      tempfile.unlink
    end
  end
end
