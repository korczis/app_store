Salesforce Downloader Brick
==================
This brick can be used for downloading data from Salesforce

## Description

This part of documentation is covering only the Salesforce downloader. The overall information about the connectors structure can be found in connectors metadata gem documentation [link](https://github.com/gooddata/gooddata_connectors_metadata/tree/bds_implementation).


## Deployment

The deployment on Ruby Executor infrastructure can be done manually or by the Goodot tool.

### Manual deployment

1. Pack the app store folder apps/sfdc_downloader_brick. The zip should contain only files, not the directory itself.
2. Deploy the ZIP on the gooddata platform by Data Admin Console [link] (https://secure.gooddata.com/admin/disc/)
3. Create the schedule and put mandatory configuration options to schedule parameters. Mandatory parameters are specified in info.json file.
4. Run the schedule

### Gooddot deployment

The deployment configuration for Gooddot could look like this:

    {
      "processes" : [
        {
            "deployment_type": "app_store",
            "app_id": "sfdc_downloader_brick",
            "process_type": "ruby",
            "name" : "SFDC Connector - Goodot",
            "schedules" : [
                {
                  "name" : "Batch A",
                  "when" : "0 2 2 2 *",
                  "params": {
                  "{{bds_params}}": null,
                  "ID":"csv_downloader_2"
                  },
                  "hidden_params" : {
                    "{{bds_secret_params}}" : null,
                    "csv|options|secret_key":"{{customer_secret}}"
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
        "customer_secret":"customer_secret"
      }
    }

After running the Gooddot sync command, you only need to run the schedule on platform


## Configuration

This section is containing information about the Salesforce downloader section of the configuration.json file.

The structure of the configuration file for S3 data source looks like this:

 * **username** - the username for the Salesforce Account
 * **password** - the password for the Salesforce Account
 * **token** - the token for the Salesforce Account
 * **client_id** - client id for Salesforce connected app (more info: [link](https://help.salesforce.com/apex/HTViewHelpDoc?id=connected_app_create.htm). The app need to have access to clients data
 * **client_secret** - client secret for Salesforce connected app (more info: [link](https://help.salesforce.com/apex/HTViewHelpDoc?id=connected_app_create.htm). The app need to have access to clients data
 * **host** (optional) - Salesforce endpoint which should be access by the downloader
 * **version** (optional) - the version of Salesforce Api which should be connected by the downloader
 * **client_logger** (true/false) (optional) - this option enables additional logging
 * **downcase_fields** (true/false) (optional) (default -> false) -  this will automatically downcase all salesforce fields (any reference used in configuration files must then use downcased names
 * **boolean_as_string** (true/false) (optional) (default -> false) - when this is enabled, all boolean values in Salesforce will be converted to string values. The type boolean will not be used internaly.
 * **default_start_date** (date) (optional) (default -> 2015-01-01T00:00:00.000Z ) This date is used during the first download when using the incremental mode. It is also used in full load mode as date from which the data are downloaded.
 * **full** (true/false) (optional) (default -> false) This will switch the downloaded in to the full download mode. The data will be always downloaded from default_start_date. The timestamp entity setting is still used for partitioning data downloaded via the Salesforce Bulk Api.
 * **step_size** (optional) Number of days which should be downloaded during the initial load. This can be used when downloading initial load of data. For some reasons you may not want to download data in one run, but download them in multiple runs of the SFDC downloader
 * **bulk_query_options** (optional) -  this options are propagate to Salesforce Bulk Query gem (https://github.com/gooddata/salesforce_bulk_query) used by this downloader 


### Example

    "sfdc": {
        "username" :"username",
        "password" : "password"
        "token": "token",
        "client_id" : "client_id",
        "client_secret":"client_secret",
        "host":"test.salesforce.com",
        "client_logger": true
    }

More info in example_configuraion.json file in the SFDC Downloader folder.
 
## Entity configuration

There are some special configurations possible for the Salesforce downloader on entity level. The example entity configuration can look like this: 


 * **timestamp** - this value contains name of the field which should be used for incremental download from S3
 * **ignored_fields** - (optional) ([]) - this setting contains collection of fields, which should be ignored when downloading data from Salesforce 
 * **deleted_records** (optional) (true/false) - if this setting is enabled, the SFDC downloader will download the deleted records from Salesforce
 * **fields_to_override** (optional) - for some reasons you could need different type connected to entity field, than it is set by Salesforce downloader. If you need this, please see example bellow
 * **functions** (optional) - for some reasons you sometimes need to aplly function to query downloaded by the SFDC downloader. This option will let you define functions which will be applied on the field during the download. Please se example bellow

### Example
 
    "Account": {
      "global": {
        "custom": {
          "hub": ["Id"],
          "timestamp": "SystemModstamp",
          "ignored_fields":["Description","Other_Address__c"]
        }
      }
    }

In this example, the Salesforce downloader will download the Account entity from Salesforce. It will download all the fields except of (Description, Other_Address__c). The field use as timestamp for incremenetal download is SystemModstamp and the primary key for then entity is field Id.   
 
    "Account": {
      "global": {
        "fields":["Id","SystemModstamp"],
        "custom": {
          "hub": ["Id"],
          "timestamp": "SystemModstamp"
        }
      }
    }

In this example, the Salesforce downloader will download the Account entity from Salesforce. It will download only the field Id and SystemModstamp (please don't forget that from legacy reasons the fields settings is in different level then ignored_fields setting).    

 
    "Account": {
       "global": {
         "fields":["Id","SystemModstamp"],
         "custom": {
           "hub": ["Id"],
           "timestamp": "SystemModstamp",
           "full": true
         }
       }
     }
 
In this example, the Salesforce downloader will download the Account entity from Salesforce. It will download only the field Id and SystemModstamp. It will always download the full entity.    

     "Account": {
        "global": {
          "fields":["Id","SystemModstamp"],
          "custom": {
            "hub": ["Id"],
            "timestamp": "SystemModstamp",
            "full": true,
            "fields_to_override":[
                      	{
                      		"name" :"revenue__c",
                      	 	"type" : "decimal-30-10"
                      	},
                      	{
                      		"name" :"user_added_revenue__c",
                      	 	"type" : "decimal-30-10"
                      	}
            ]    
          }
        }
      }
 
This example shows how the fields_to_override settings work. Both fields will be set to decimal-30-10 (default value is decimal-30-15)
 
     "Account": {
        "global": {
          "custom": {
            "hub": ["Id"],
            "timestamp": "SystemModstamp",
            "full": true,
            "functions":{
              "convertCurrency":[
                "account_balance__c","account_overdue_balance__c","annualrevenue","revenue__c","unbilled_orders__c","user_added_revenue__c"
               ]
            }    
          }
        }
      }
 
This example shows how the functions settings work. The function convertCurrency will be applied on all fields listed in array
