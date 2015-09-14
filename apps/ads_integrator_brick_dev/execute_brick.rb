module GoodData::Bricks

  class ExecuteBrick < GoodData::Bricks::Brick

    def call(params)
      logger = params['GDC_LOGGER']
      metadata = params['metadata_wrapper']
      ads_wrapper = params['ads_storage_wrapper']
      raise Exception, "The schedule ID parameter need to be filled" if !params.include?("ID")
      metadata.set_integrator_context(params["ID"])
      begin
        ads_wrapper.connect
        # Lets check if the ADS gem is in batch mode or in entity mode
        integration_mode = ads_wrapper.get_mode
        if (integration_mode == :entity)
          entities = metadata.get_integrator_entities_ids
          entities.each do |entity_name|
            ads_wrapper.load_entity(entity_name)
          end
        elsif (integration_mode == :batch)
          batches = ads_wrapper.get_integration_batches
          batches.each do |batch_identification|
            ads_wrapper.load_batch(batch_identification)
          end
        else
          fail "Unknown integration mode"
        end
        # Set notification metadata key to TRUE in case that work was done by ADS integrator
        if (params.include?("NOTIFICATION_METADATA") and ads_wrapper.work_done?)
          logger.info "Setting #{params["NOTIFICATION_METADATA"]} to true"
          GoodData.project.set_metadata(params["NOTIFICATION_METADATA"],"true")
        end
        ads_wrapper.finish
      rescue => e
        ads_wrapper.finish
        fail e
      end
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

      client = if params['GDC_USERNAME'].nil? || params['GDC_PASSWORD'].nil?
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