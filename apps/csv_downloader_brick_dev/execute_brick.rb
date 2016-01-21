# encoding: utf-8

module GoodData::Bricks
  class ExecuteBrick < GoodData::Bricks::Brick
    def call(params)
      puts "Inside ExecuteBrick"
      logger = params['GDC_LOGGER']
      metadata = params["metadata_wrapper"]
      downloader = params["csv_downloader_wrapper"]
      raise Exception, "The schedule parameters must contain ID of the downloader" if !params.include?("ID")
      metadata.set_source_context(params["ID"], {}, downloader)
      downloader.connect
      downloader.load_data_structure_file
      downloader.number_of_manifest_in_one_run.times do |i|
        puts "Starting processing number #{i + 1}"
        downloader.load_last_unprocessed_manifest
        entities = metadata.get_downloader_entities_ids
        entities.each do |entity|
          downloader.load_metadata(entity)
          downloader.download_entity_data(entity)
        end
        previous_batch = downloader.finish_load
        if (!previous_batch.nil?)
          downloader.prepare_next_load(previous_batch)
        else
          trigger_event_manifest_missing(params) if i == 0
          break
        end
      end
    end


    def trigger_event_manifest_missing(params)
      process = GoodData::Process[$SCRIPT_PARAMS["PROCESS_ID"],{:project => params["gdc_project"],:client => params["GDC_GD_CLIENT"]}]
      process.trigger_event("manifestMissing",{"downloader_id" => params["ID"],"account_id" => params["account_id"],"token" => params["token"]})
    end

  end


  class GoodDataCustomMiddleware < GoodData::Bricks::Middleware
    def call(params)
      logger = params['GDC_LOGGER']
      token_name = 'GDC_SST'
      protocol_name = 'CLIENT_GDC_PROTOCOL'
      server_name = 'CLIENT_GDC_HOSTNAME'
      project_id = params['GDC_PROJECT_ID']

      server = if params[protocol_name] && params[server_name]
                 "#{params[protocol_name]}://#{params[server_name]}"
               end

      client = if params['GDC_USERNAME'].nil? && params['GDC_PASSWORD'].nil?
                 puts "Connecting with SST to server #{server}"
                 fail 'SST (SuperSecureToken) not present in params' if params[token_name].nil?
                 GoodData.connect(sst_token: params[token_name], server: server)
               else
                 puts "Connecting as #{params['GDC_USERNAME']} to server #{server}"
                 GoodData.connect(params['GDC_USERNAME'], params['GDC_PASSWORD'], server: server)
               end
      project = client.projects(project_id)
      GoodData.project = project
      GoodData.logger = logger
      @app.call(params.merge!('GDC_GD_CLIENT' => client, 'gdc_project' => project))
    end
  end

end
