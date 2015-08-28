require 'gooddata'
APP_STORE_ROOT = File.expand_path('../../../..', __FILE__)
$LOAD_PATH.unshift(APP_STORE_ROOT)
require './apps/users_brick/users_brick'

include GoodData::Bricks

def find_unused_domain_name(domain)
  loop do
    name = "brick_test_#{rand(1000000)}@gooddata.com"
    break name unless domain.member?(name)
  end
end

describe GoodData::Bricks::UsersBrick do

  before(:all) do
    @client = GoodData.connect('svarovsky+gem_tester@gooddata.com', ENV['GDC_PASSWORD'])

    @project_1 = @client.create_project(title: 'Project app_store testing 1', auth_token: ENV['GDC_TOKEN'])
    @project_2 = @client.create_project(title: 'Project app_store testing 2', auth_token: ENV['GDC_TOKEN'])
    @domain = @client.domain('gooddata-tomas-svarovsky')
  end

  after(:each) do
    @project_1.users.reject { |u| u.login == @client.user.login }.pmap(&:disable)
  end

  after(:all) do
    @project_1 && @project_1.delete
    @project_2 && @project_2.delete
  end

  it 'should be able to add users to domain' do
    domain = @client.domain('gooddata-tomas-svarovsky')
    user_name = find_unused_domain_name(@domain)
    begin
      tempfile = Tempfile.new('domain_sync')
      CSV.open(tempfile.path, 'w') do |csv|
        csv << [:login]
        csv << [user_name]
      end

      @project_1.upload_file(tempfile.path)
      user_process = @project_1.deploy_process(Pathname.new(APP_STORE_ROOT) + 'apps/users_brick', name: 'users_brick_example', type: :ruby)
      user_process.execute('main.rb', params: {
        'domain'        => @domain.name,
        'input_source'  => Pathname(tempfile.path).basename.to_s,
        'sync_mode'     => 'add_to_organization'
      })
    ensure
      tempfile.unlink
    end
    expect(@domain.member?(user_name)).to be_truthy
    expect(@project_1.member?(user_name)).to be_falsey
  end

  describe 'adding to project' do

    it 'should be able to add users to domain AND project' do
      domain = @client.domain('gooddata-tomas-svarovsky')
      unused_user_name = find_unused_domain_name(@domain)
      used_user = domain.users.sample
      begin
        tempfile = Tempfile.new('domain_sync')
        CSV.open(tempfile.path, 'w') do |csv|
          csv << [:login, :role]
          csv << [unused_user_name, :admin]
          csv << [used_user.login, :editor]
        end

        @project_1.upload_file(tempfile.path)
        user_process = @project_1.deploy_process(Pathname.new(APP_STORE_ROOT) + 'apps/users_brick', name: 'users_brick_example', type: :ruby)
        user_process.execute('main.rb', params: {
          'domain'        => @domain.name,
          'input_source'  => Pathname(tempfile.path).basename.to_s,
          'sync_mode'     => 'sync_domain_and_project'
        })
      ensure
        tempfile.unlink
      end
      expect(@domain.member?(used_user)).to be_truthy
      expect(@domain.member?(unused_user_name)).to be_truthy
      expect(@project_1.member?(used_user)).to be_truthy
      expect(@project_1.member?(unused_user_name)).to be_truthy
    end

    it 'should add users to project from domain' do
      users = @domain.users.sample(10)
      begin
        tempfile = Tempfile.new('project_sync')

        headers = [:first_name, :last_name, :login, :password, :email, :role, :sso_provider]
        CSV.open(tempfile.path, 'w') do |csv|
          csv << headers
          users.each do |u|
            csv << u.to_hash.merge({role: 'admin'}).values_at(*headers)
          end
        end

        @project_1.upload_file(tempfile.path)

        user_process = @project_1.deploy_process(Pathname.new(APP_STORE_ROOT) + 'apps/users_brick', name: 'users_brick_example', type: :ruby)
        user_process.execute('main.rb', params: {
          'domain'        => @domain.name,
          'input_source'  => Pathname(tempfile.path).basename.to_s,
          'sync_mode'     => 'sync_project'
        })
      ensure
        tempfile.unlink
      end
      users = @project_1.users
      expect(users.count).to eq 11
      expect(users.all?(&:enabled?)).to be_truthy
      expect(users.pmap(&:role).map(&:identifier).uniq.count).to eq 1
    end

    it 'should add users to project from domain' do
      users = @domain.users.sample(10)
      begin
        tempfile = Tempfile.new('project_sync')

        headers = [:first_name, :last_name, :login, :password, :email, :role, :sso_provider]
        CSV.open(tempfile.path, 'w') do |csv|
          csv << headers
          users.each do |u|
            csv << u.to_hash.merge({role: 'admin'}).values_at(*headers)
          end
        end

        @project_1.upload_file(tempfile.path)

        user_process = @project_1.deploy_process(Pathname.new(APP_STORE_ROOT) + 'apps/users_brick', name: 'users_brick_example', type: :ruby)

        # Users should be added
        user_process.execute('main.rb', params: {
          'domain'        => @domain.name,
          'input_source'  => Pathname(tempfile.path).basename.to_s,
          'sync_mode'     => 'sync_project'
        })
        users = @project_1.users
        expect(users.count).to eq 11
        expect(users.all?(&:enabled?)).to be_truthy
        expect(users.pmap(&:role).map(&:identifier).uniq.count).to eq 1

        # remove a user and put him to whitelist
        user = (@project_1.users - [@client.user]).sample
        user.disable
        user_process.execute('main.rb', params: {
          'domain'        => @domain.name,
          'input_source'  => Pathname(tempfile.path).basename.to_s,
          'sync_mode'     => 'sync_project',
          'whitelists'   => [user.login]
        })
        expect(@project_1.users.count).to eq 10

        user_process.execute('main.rb', params: {
          'domain'            => @domain.name,
          'input_source'      => Pathname(tempfile.path).basename.to_s,
          'sync_mode'         => 'sync_project',
          'regexp_whitelists' => ['gooddata\.com']
        })
        expect(@project_1.users.count).to eq 10
        user_process.execute('main.rb', params: {
          'domain'            => @domain.name,
          'input_source'      => Pathname(tempfile.path).basename.to_s,
          'sync_mode'         => 'sync_project'
        })
        expect(@project_1.users.count).to eq 11
      ensure
        tempfile.unlink
      end
    end
  end

  it 'should be able to add users to multiple projects' do
    users = @domain.users.sample(10)
    headers = [:pid, :first_name, :last_name, :login, :password, :email, :role, :sso_provider]
    projects = [@project_1, @project_2]
    users_data = users.map { |u| u.to_hash.merge(pid: projects.sample.pid, role: ['admin', 'editor'].sample) }
    
    begin
      tempfile = Tempfile.new('sync_multiple_projects_based_on_pid')
      CSV.open(tempfile.path, 'w') do |csv|
        csv << headers
        users_data.each do |u|
          csv << u.values_at(*headers)
        end
      end

      @project_2.upload_file(tempfile.path)
      user_process = @project_2.deploy_process(Pathname.new(APP_STORE_ROOT) + 'apps/users_brick', name: 'users_brick_example', type: :ruby)
      user_process.execute('main.rb', params: {
        'domain'        => @domain.name,
        'input_source'  => Pathname(tempfile.path).basename.to_s,
        'sync_mode'     => 'sync_multiple_projects_based_on_pid',
        'multiple_projects_column' => 'pid'
      })

      test_data = users_data.group_by { |u| u[:pid] }.map { |pid, u| [pid, u.count] }
      test_data.each do |pid, count|
        expect(@client.projects(pid).users.count).to eq (count + 1)
      end
    ensure
      tempfile.unlink
    end
  end

  it 'should be able to add users to multiple projects through per project ETL' do
    users = @domain.users.sample(10)
    headers = [:pid, :first_name, :last_name, :login, :password, :email, :role, :sso_provider]
    projects = [@project_1, @project_2]
    users_data = users.map { |u| u.to_hash.merge(pid: projects.sample.pid, role: ['admin', 'editor'].sample) }
    
    begin
      tempfile = Tempfile.new('sync_on_with_pid')
      CSV.open(tempfile.path, 'w') do |csv|
        csv << headers
        users_data.each do |u|
          csv << u.values_at(*headers)
        end
      end
      projects.peach do |project|
        project.upload_file(tempfile.path)
        user_process = project.deploy_process(Pathname.new(APP_STORE_ROOT) + 'apps/users_brick', name: 'users_brick_example', type: :ruby)
        user_process.execute('main.rb', params: {
          'domain'        => @domain.name,
          'input_source'  => Pathname(tempfile.path).basename.to_s,
          'sync_mode'     => 'sync_one_project_based_on_pid',
          'multiple_projects_column' => 'pid'
        })
      end      

      test_data = users_data.group_by { |u| u[:pid] }.map { |pid, u| [pid, u.count] }
      test_data.each do |pid, count|
        expect(@client.projects(pid).users.count).to eq (count + 1)
      end
    ensure
      tempfile.unlink
    end
  end
end
