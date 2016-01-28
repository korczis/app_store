ADS Downloader Brick
==================
The brick is used for integrating data, which were downloaded by connectors, to ADS

## Description

This part of documentation is covering only the ADS Integrator. The overall information about the connectors structure can be found in connectors metadata gem documentation [link](https://github.com/gooddata/gooddata_connectors_metadata/tree/bds_implementation).


## Deployment

The deployment on Ruby Executor infrastructure can be done manually or by the Goodot tool.

### Manual deployment

1. Pack the app store folder apps/ads_integrator_brick. The zip should contain only files, not the directory itself.
2. Deploy the ZIP on the gooddata platform by Data Admin Console [link] (https://secure.gooddata.com/admin/disc/)
3. Create the schedule and put mandatory configuration options to schedule parameters. Mandatory parameters are specified in info.json file.
4. Run the schedule

### Gooddot deployment

The deployment configuration for Gooddot could look like this:

    {
      "processes" : [
        {
            "deployment_type": "app_store",
            "app_id": "ads_integrator_brick",
            "process_type": "ruby",
            "name" : "ADS Integrator - Goodot",
            "schedules" : [
                {
                  "name" : "Batch A",
                  "when" : "0 2 2 2 *",
                  "params": {
                  "{{bds_params}}": null,
                  "ID":"ads_integrator_1"
                  },
                  "hidden_params" : {
                    "{{bds_secret_params}}" : null,
                    "ads_storage|password":"{{customer_secret}}"
                  }
                }

            ]
        }
      ],
     "params": {
        "bds_params":{
            "bds_bucket": "bds_bucket",
            "bds_folder":"bds_folder",
            "bds_access_key":"access_key",
            "account_id":"AccountName",
            "token":"Token"
        },
        "bds_secret_params":{
            "bds_secret_key":"bds_secret_key"
        },
        "password":"password"
      }
    }

After running the Gooddot sync command, you only need to run the schedule on platform

## Integration modes

In current version of ASD integrator, there are two possible integration modes.

### Data Vault approach

This strategy is default right now. In this strategy data are split up to 3 different tables.

 * Hub table
 * SCD1 table
 * SCD2 table

The hub table will contain all the primary keys for given entity. The SCD1 table is dedicated for data, where only the last value of the data is interesting from business point of view. The SCD2 table is dedicated for data, where the history of data is interesting from bussiness point of view.

#### Configuration

There are few mandatory configurations needed at the entity level. The ADS integrator need to know, which fields should be put in which table. This is configured on custom settings of the entity.

In next example we have entity Account. This entity will have field ID in the HUB table and fields Name and Address in SCD1 table. The second example is for entity Opportunity. In this case the field ID will be in HUB table and all other fields will be automatically put in SCD1 table.

    "entities": {
            "Account": {
                "global": {
                    "fields":[
                        "Id",
                        "Name",
                        "Address"
                    ]
                    "custom": {
                        "hub": [
                            "Id"
                        ],
                        "scd1":[
                            "Name","Address"
                        ]
                    }
                }
            },
            "Opportunity": {
                "global": {
                    "fields":[
                        "Id",
                        "Name",
                        "Stage",
                        "Amount"
                    ]
                    "custom": {
                        "hub": [
                            "Id"
                        ]
                    }
                }
            }
    }

#### Table tables

There are few types of objects created in ADS after the execution of ADS integrator. The user should always use the VIEWs to access data.

 * **Source tables** - The name of the table can look like this: src_{source}_{entity_name}_dv. The source is shortcut of downloader, which downloaded the entity. The entity name is name of the entity. (src_csv_Opportunity_dv)
 * **Stage tables** - The name of the tables can look like this: stg_{source}_{entity_name}_{dv_type}. The source is shortcut of downloader, which downloaded the entity. The entity name is name of the entity. The dv_type is type of the Data Vault table (hub,scd1,scd2). (stg_csv_Opportunity_hub)
 * **Views** - The name of the view can look like this: ls_{entity_name}. The ADS integrator will create views for user. This view will give user access to data without knowledge about the integration process. (ls_Opportunity)

### Merge approach

In merge approach there is only one stage table. The data are merge from source tables to stage tables.

#### Configuration

There are few mandatory configurations needed at the entity level. The ADS integrator need to know, which fields should be used as primary keys.

In next example we have entity Account. This entity will have field ID used as primary key.

    "entities": {
            "Account": {
                "global": {
                    "fields":[
                        "Id",
                        "Name",
                        "Address"
                    ]
                    "custom": {
                        "hub": [
                            "Id"
                        ]
                    }
                }
            }
    }

#### Table tables

There are few types of objects created in ADS after the execution of ADS integrator. The user should always use the VIEWs to access data.

 * **Source tables** - The name of the table can look like this: src_{source}_{entity_name}_merge. The source is shortcut of downloader, which downloaded the entity. The entity name is name of the entity. (src_csv_Opportunity_merge)
 * **Stage tables** - The name of the tables can look like this: stg_{source}_{entity_name}_merge. The source is shortcut of downloader, which downloaded the entity. The entity name is name of the entity. The dv_type is type of the Data Vault table (hub,scd1,scd2). (stg_csv_Opportunity_merge)
 * **Views** - The name of the view can look like this: ls_{entity_name}. The ADS integrator will create views for user. This view will give user access to data without knowledge about the integration process. (ls_Opportunity)

## Global integration settings

This options are applied right after the configuration change 

 * **instance_id** - the ID of the ADS instance
 * **username** - the username of user which have access to given ADS instance
 * **password** - the password of user which have access to given ADS instance
 * **server** - (optional) (default -> secure.gooddata.com) server setting for whitelabel instance
 * **options** - this section of the configuration for specific ads integration settings
    * **default_strategy** (optional) (default -> data_vault) (options -> data_vault/merge) - this settings specified which strategy should be used for data integration. This cannot be change after first integration without full ADS wipe.
    * **number_of_batches_in_one_run** (optional) (default -> 1) - the number of batches which should be processed in one run of ADS integrator. In case, that you have lot of small batches it is faster to integrate them in one run.
    * **number_of_paraller_queries** (optional) (default -> 8) - the max number of parallel executions of COPY command.
    * **number_of_paraller_integrations** (optional) (default -> 1) - the number of parallel integrations to stage tables. This option is controlling how many merge commands from source to stage will be executed in same time. 
    * **integration_group_size** (optional) (default -> 1) - the max number of files integrated by one COPY command. In case of lot of small files, this number should be bigger then 1.
    * **join_files** (optional) (default -> false) - this option will take number of files specified in integration_group_size and compact them in to the one file. Then only this one file is copied by vertica Copy Command. 
    * **finish_in_source** (optional) (default -> false) - then this options is set to true, the stage (stg) tables are not populated. The integration process will finish in source tables. Each run of ADS integrator will purge the source tables and load new data there.
    * **recreate_source_tables** (optional) (default -> false) - when this option is set to true, the source tables are dropped and recreated in each run. Can be used with option source_projection in entity level configuration.
    * **abort_on_error** (optional) (default -> true) - specify if the copy command is executed with abort_on_error option. If this option is false, the tool will put the errors to exception files and after the execution has finished the files are uploaded to BDS Error folder. Also the tool will fire notification event named "error-in-data-processing". This event can be consumed by notification functionality in DISC console.
    * **ignored_system_fields** (optional) (default -> []) - the list of system fields, which should be ignored by during the integration. The fields will not be created in any tables.
    * **remote** (optional) - this options must be set, if the linked files need to be processed by this tool. The linked files are described in CSV Downloader Brick documentation.
        * **type** - (s3) - specify the type of the linked file source. Right now only s3 is supported. 
        * **access_key** - specify the access key for the linked file source.
        * **secret_key** - specify the secret key for the linked file source.
        * **bucket** - specify the bucket for the linked file source.
    * **computed_fields** (optional) - you can specify additional metadata fields, which will be attached to each entity - more info in computed fields section




       
     
### Example

    "ads_storage": {
        "instance_id": "instance_id",
        "username": "my_user_at@gooddata.com",
        "password": "password",
        "server":"whitelabel.com",
        "options":{
            "default_strategy" : "merge",
            "number_of_batches_in_one_run": 1,
            "number_of_paraller_queries":8,
            "integration_group_size": 25,
        }
    }

## Entity level settings

This options are saved in downloader execution. Options are applied on all files downloaded after the configuration change. **All previously downloaded files will not be affected by this change**

There is possibility to provide some configuration for ASD integration tool on the entity level of the configuration. All options should be present in custom part of the entity configuration.

 * **hub** - the list of fields, which are creating primary key for the current entity. This is mandatory setting for ASD integrator to work. 
 * **fields_to_clean** - (optional) (default -> []) You can name fields here which will be cleaned inside of the copy command. For example if there is DECIMAL(30,15) in data and you have DECIMAL(30,10) in DB, the default copy command will fail. With clean on this field enabled, the DECIMAL in data will be trucanted to fit to DECIMAL in database. (Currently it works only on DECIMAL types) 
 * **source_projection** (optional) - works only when the finish_in_source parameter is used. This enabled you to create your default projection when creating source tables. If this option is not used, the ASD Integrator is creating projection optimized for data integration.  
    **order_by**  
    **segmented_by** 
	
###Example
				
    "hub": [
		"client_id",
		"blast_msg_id",
		"label_id"
	],
	"source_projection": {
		"order_by": [
			"client_id",
			"blast_msg_id"
			],
	    "segmented_by":[
		    "client_id"
		]
	},

## Computed fields

The computed fields settings have this options:
 
 * **name** - name of the computed field
 * **type** - type of of the metadata field
 * **table_type** (src,stg) - which type of tables should have this specific settings
 * **function** - function defining how the value will be populated
 
Possible functions:

 * **now** - (possible in src and stg) - the field will be populated with database now() function    
 * **runtime_metadata** - (possible in src) - the field will be populated from file runtime metadata. In this metadata are for example store aditional metadata from manifest or sequence number. If you want to full the value with field custom_date from manifest, you will write the function runtime_metadata|custom_date
 * **value** - (possible in stg) - the field will be populated from value of source table. For example if you want to populate the field with _sys_custom from src table you will use function like this value|_sys_custom

### Example

    "computed_fields":[
        {
        "name" : "sys_sequence",
        "type" : "string-255",
        "table_type" : ["src"],
        "function": "runtime_metadata|sequence"
        }



