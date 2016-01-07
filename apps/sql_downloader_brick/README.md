SQL Downloader Brick
==================
This brick can be used for downloading data from databases via JDBC. Currently the MsSQL and MySQL is supported.

## Description

This part of documentation is covering only the SQL downloader. The overall information about the connectors structure can be found in connectors metadata gem documentation [link](https://github.com/gooddata/gooddata_connectors_metadata/tree/bds_implementation).


## Deployment

The deployment on Ruby Executor infrastructure can be done manually or by the Goodot tool.

### Manual deployment

1. Pack the app store folder apps/sql_downloader_brick. The zip should contain only files, not the directory itself.
2. Deploy the ZIP on the gooddata platform by Data Admin Console [link] (https://secure.gooddata.com/admin/disc/)
3. Create the schedule and put mandatory configuration options to schedule parameters. Mandatory parameters are specified in info.json file.
4. Run the schedule

### Gooddot deployment

The deployment configuration for Gooddot could look like this:

    {
      "processes" : [
        {
            "deployment_type": "app_store",
            "app_id": "sql_downloader_brick",
            "process_type": "ruby",
            "name" : "SQL Connector - Goodot",
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
## How it works

THe SQL downloader is looking for table named exactly as the name of the entity in configuration file (**CASE SENSITIVE**). When the table is found, the downloader will extract the information about the table and convert it to metadata which can be used by ASD integartor. 
What it mean is that it will change the types from source DB types to generic types. If the types in source database is unknown, we are threading data as string.

After the metadata are successfully parsed, the SQL downloader will start downloading the data. Right now it is downloading always full data from the source table. The data are dumped in to the CSV files, the CSV file is GZIPed and uploaded on BDS.

## Configuration

This section is containing information about the SQL downloader section of the configuration.json file.

The structure of the configuration file for S3 data source looks like this:

 * **server** - the location of the SQL server
 * **database** - the database, where the tables are located
 * **username** - username for the database
 * **password** - password for the database
 * **default_start_date** (optional) (2010-01-01) - used for incremental download. This date will be set as starting data durring the first run of the downloader in the incremental mode

### Example

    "sql": {
        "type": "MsSql",
        "options": {
            "connection":{
                "server": "server",
                "database": "database",
                "username": "username",
                "password": ""don't put it here, user the propagation from GD schedule (sql|options|connection|password)""
            }
        }
    }

    "sql": {
            "type": "MySql",
            "options": {
                "connection":{
                    "server": "server",
                    "database": "database",
                    "username": "username"
                    "password": ""don't put it here, user the propagation from GD schedule (sql|options|connection|password)""
                }
            }
        }


## Entity configuration

There are some special configurations possible for the SQL downloader on entity level. The example entity configuration can look like this: 


 * **timestamp** - this value contains name of the field which should be used for incremental download from database. The field must be date.

### Example
 
    "Account": {
      "global": {
        "custom": {
          "hub": ["Id"],
          "timestamp": "updated_at",
        }
      }
    }



More info in example_configuraion.json file in the SQL Downloader folder.
 
