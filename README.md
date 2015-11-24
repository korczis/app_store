# app_store

App store is a place where you can take piece of code that solves specific problem. App store also provides a central repository and its contents are curated, tested and maintained and it represent years of condensed experience and trial and error.

## Status

[![Build Status](https://travis-ci.org/gooddata/app_store.svg)](https://travis-ci.org/gooddata/app_store)

### Brick
Brick is the something that is in app_store and that you are going to use. This is a working title and it is likely to change but what we try to convey with the name is that it is something that should be part of bigger whole that plays along. In your ETL there are usually many problems but many of those repeat and thanks to us seeing many implementations we can see what is a recurring thing. Brick is something that should solve one problem particularly well. It should be tested, parametrizable, promote the right way to do it and to some extent flexible but mainly it should play well within the larger system.

### Ruby vs ?
While all our bricks are currently written in Ruby this is not mandatory. Brick can be in any language as long as it is supported within GoodData platform. Since majority of the bricks are currently dealing with APIs imperative language is the most flexible way to go.

### Deployment
You can find bricks in the [apps](https://github.com/gooddata/app_store/tree/master/apps) directory. Each folder there represent one brick. You can deploy by cloning the app store and using a web interface in "Administration console" or you can use Automation SDK. You can both [deploy](https://github.com/gooddata/gooddata-ruby-examples/blob/master/07_deployment_recipes/01_process_deployment.asciidoc) and [redeploy](https://github.com/gooddata/gooddata-ruby-examples/blob/master/07_deployment_recipes/02_process_redeployment.asciidoc) with it.

### Scheduling/Executing

### Working with nested parameters during deployment

Historically there was only one type of job you could deploy and that was Cloud Connect graph. CC graph supported parameters but it constrained them to key value pairs where both of those were strings. Imagine something like this.

    {
      "login" : "password",
      "name" : "Tomas"
    }

This was fine but as we added another type of deployment type it allowed us to deal with different tasks and we saw need to work with more structured parameters. Imagine something like this and  think how you would express it if you could only use strings as values.

    {
      "filters" : [
        "filter_1",
        "filter_2"
      ]
    }

Unfortunately the platform did not evolve with this reqiurement so we decided to come up with something that would allow us to use these nested parameters on the current platform. We encode the portion of the params that contain nested keys into special key. The previous example looks like this

    { "gd_encoded_params" : "{\"filters\":[\"filter_1\",\"filter_2\"]}" }

This means several things.

1) If you use either Ruby SDK or Goodot for scheduling or execution you do not have to do anything. All the magic happens behid the covers and you can just deploy parameters as you normally would (You can read about various ways how to schedule processes in our [cookbook](https://github.com/gooddata/gooddata-ruby-examples/tree/master/07_deployment_recipes)
). If you inspect the Administration console you will see the parameters in their raw form there but you do not need to pay special attention to that (SDK tries to create the parameters in a smarter way and encodes the parameters that are really nested so the result is as much readable on the UI as possible).

2) On the side of the script that is deployed the script needs to decode the parameters. If you use bricks from app store you again do not have ot do anything. If you decide to roll your own sript you have to decode the parameters from the API in the actual deployed script.

3) If you want to schedule things by hand you need to make sure that you are providing parameters that the script can understand. Specifically you have to do this.

- take the JSON you have and paste it UI into parameters named "gd_encoded_params" for regular parameters or "gd_encoded_hidden_params" if you would like to keep parameters hidden.

In previous example the result would look like this. Into paremeter name `gd_encoded_params` you would paste `{ "filters" : [ "filter_1", "filter_2" ] }`

### Input data sources
+As stated before we are trying to minimize the amount of glue code that is necessary to make things work. Since generally you do not know where your data would come from we want to give you power to consume wider number of sources (web, ADS, staging (aka WebDAV), S3) so you do not have to change any code just configuration. What is considered a source is specific for each brick bug generally you can recognize it by the name of the parameter in the documentation of specific brick. The name of the parameter will be "*_input_source" or just "input_source". If it is named according to this convention then you can treat is as a datasource. Below are couple of general example how things are configured. Again, the configuration is specific for each brick so please refer to their documentation specifically for further information.

#### Staging
Staging is an ephemeral storage that is part of gooddata platform. It supports couple of protocols most useful of which is WebDAV so sometimes it is internally referred to as WebDAV. You can specify a data source to consume a file from staging like this.

The file is consumed as is. Majority of the bricks are expecting CSV that is parsed using a [csv](http://ruby-doc.org/stdlib-1.9.2/libdoc/csv/rdoc/CSV.html) library.

    "input_source": {
  	  "type": "staging",
  	  "path": "filename"
  	}

Since staging is most common there is also a shorthand

  "input_source": "folder/filename/"

Which is equivalent to the previous. Filename is expected to be relative to the root of the project specific staging (ie relative to the "https://secure-di.gooddata.com/project-uploads/{PROJECT_ID}/"). Please note that there is not slash as the first character.

#### AWS S3
S3 is a storage provided by Amazon. We allow to consume the files from it directly by some bricks. You can set it up like this.
 [csv](http://ruby-doc.org/stdlib-1.9.2/libdoc/csv/rdoc/CSV.html) library.

    "aws_client": {
      "access_key_id" : "your_acccess_key",
      "secret_access_key" : "your_secret_key"
    },
    "input_source": {
      "type": "s3",
      "key": "your_object/key",
      "bucket": "bucket_name"
    }

The file is consumed as is. Majority of the bricks are expecting CSV that is parsed using a [csv](http://ruby-doc.org/stdlib-1.9.2/libdoc/csv/rdoc/CSV.html) library.


#### Agile data service (ADS)
ADS is a database service. You can specify a query to ADS as a data source.

##### query with global connection
You have to specify how to connect to ads. This is configured using ads_client structure. 

    "ads_client": { "username": "username@example.com", "password": "secret", "ads_id": "123898qajldna97ad8" },
    "input_source": {
  	  "type": "ads",
  	  "query": "SELECT * FROM my_table"
  	}

You can also omit username and password. In such case the defaults "GDC_USERNAME" and "GDC_PASSWORD" would be used. This is useful if you want different user than the one that is executing the rest of the task for example upload to webdav.

    "GDC_USERNAME": "username@example.com",
    "GDC_PASSWORD": "secret",
    "ads_client": { "ads_id": "123898qajldna97ad8" },
    "input_source": {
  	  "type": "ads",
  	  "query": "SELECT * FROM my_table"
  	}

The query is consumed using our JDBC driver. And it is accessible in the code as an Array of Hashes. The keys of each hash is equivalent to the name of the column from the query.

##### File from web
You can consume a file on the web directly.

    "input_source": {
      "type": "web",
      "url": "https://gist.githubusercontent.com/fluke777/4005f6d99e9a8c6a9c90/raw/d7c5eb5794dfe543de16a44ecd4b2495591df057/domain_users.csv"
    }

The file is consumed as is. Majority of the bricks are expecting CSV that is parsed using a [csv](http://ruby-doc.org/stdlib-1.9.2/libdoc/csv/rdoc/CSV.html) library.

### Output data sources

It would make sense to do something similar for the outputs and that is planned. Currently this is not implemented.
