Data Filters Brick
==================
This brick provides improved way to handle data permissions set up both through data permissions and variables.

## Important terms

### Data filters
Data filters are basically whatever comes after WHERE in MAQL. Imagine

    WHERE city IN ('San Francisco', 'Prague', 'Amsterdam')

The difference is that in both cases you can define it per user.

### Variable
Variable is a per user filter. You can apply a variable on per report basis so you can basically pick which report will be filtered and which not. This is different with data permissions.

### Data permissions
Data permission is again a filter that is defined per user. The difference that an intersection of all filters is applied to every computation a user performs automatically so it is well suited to implement security rules.

## Colum-based vs row-based sources of data
In many cases you cannot pick what kind of data you get. We are trying to help minimize glue code as much as possible. You can easily configure this brick to accept couple types of input with respect to its shape and name of the columns. Let's try to illustrate different shapes given the example with cities at the beginning.

Imagine there are two users in your system and you would like to set him with these values.

 login              | filter
--------------------|----------
 john@example.com   | WHERE city ('San Francisco', 'Prague', 'Amsterdam')
 jane@example.com   | WHERE city ('San Francisco', 'Dublin')

### Column based

This is how the values would be expressed in a column based file.

 login              | city          | other_unused_value
--------------------|---------------|-------------
 john@example.com   | San Francisco | x
 john@example.com   | Prague        | x
 john@example.com   | Amsterdam     | y
 jane@example.com   | Dublin        | y
 jane@example.com   | San Francisco | y

Take note that multiple values are expressed by repeating the user. Brick also deduplicates the values before setting them as Data Filters. This might easily happen if you got the file for filters as an output of a join.

Notice that in our case the file has headers but this is not a requirement and brick can cope with both situations.

### Row based
While column based file is the most commonly used source but imagine that a different kind of file would arrive. The example above could be also expressed like this


  Note: Please use your imagination and fancy that the table does not have headers. Unfortunately Markdown does not seem to support that :-)

  .                 | .
--------------------|---------------------------------------
 john@example.com   | "San Francisco", "Prague", "Amsterdam"
 jane@example.com   | "Dublin", "San Francisco"
 
Notice that this file cannot have headers since we do not know how many columns we will have  (They are d).

## Adding filters

Regardless of which type of source you use to define your filters the information you provide will be used as the blueprint for the end state of the project. It is very similar to how adding user works. You are providing how the end state should look like and the system determines what to do.

### Why declarative and not additive

Let me explain shortly why we decided to go the declarative ('give me how the project should look like and I will make it so') way as opposed to additive ('let me know each day who to add and remove'). The benefit of being declarative is the fact that it is stateless. If I give you the full file every day you know where you will end up regardless of how the project looks like right now. Even if you run things several times you end up in the same spot. If I give you an increment where you end up is dependent on the state of the project. If something goes wrong (loss of users) you probably have to get the full state anyway. Thanks to this the declarative way is also self healing. If you make a mistake one day it is going to fix itself automatically when you fix the data.

If the source system can provide only incremental data you have to do the extra work in your stateful ETL to provide a complete snapshot of the system (as you have to do for other parts as well). Taking data from an intermediary storage has also another benefit is that you own the data you were using to perform the tasks so if you need them later you can access them which is not necessarily guaranteed with data you do not own.


## Use cases

### Data permissions through value enumeration with column based file

This is what we need to set up.

    john@example.com: WHERE city IN ('San Francisco')
    jane@example.com: WHERE city IN ('San Francisco', 'Prague')

This is how the file looks like

    login,city
    john@example.com,'San Francisco'
    jane@example.com,'Prague'
    jane@example.com,'San Francisco'

This is how you have to set up your process

    {
      "input_source": { "type": "web", "url": "https://gist.githubusercontent.com/fluke777/777406ede2f7919fc3b6/raw/c053f12c0b57aadcc9271074c91781b7febd4068/column_based_data_example.txt" }
      "domain": "my_domain",
      "filters_config": {
        "user_column": "login",
        "labels": [{"label": "label.cities.city_id.name", "column": "city"}]
      }
    }

Notes:

1) You can also use numbers to specify the "user_column" or "column" to be used in case you do not have headers.
2) If your file does not have a header you have to explicitly specify it using `"csv_headers": false` parameter.

### Data permissions through value enumeration with row based file

This is what we need to set up.

    john@example.com: WHERE city IN ('San Francisco')
    jane@example.com: WHERE city IN ('San Francisco', 'Prague')

This is how the file looks like

    john@example.com,'San Francisco','Prague'
    jane@example.com,'San Francisco'

This is how you have to set up your process

    {
      "input_source": { "type": "web", "url": "https://gist.githubusercontent.com/fluke777/4000a2312892bc914312/raw/616ac343277fb60e816dd7bb0a592895f4872e02/row_based_example_data.txt" },
      "domain": "my_domain",
      "filters_config": {
        "labels": [{"label": "label.cities.city_id.name"}]
      }
    }

Notes:
1) Login is expected to be the first column
2) File is expected not to have a header. Parameter `"csv_headers"` is ignored in this case.

### Support for over-to filters
Over to filters are useful in cases where there are so many individual values that need to be set up for each users that it is no longer practical to have them all in the filter. Rule of thumb is when number of values per user hits high hundreds. You can set up a dataset which contains all the values and you can set up the filter to look in that particular dataset for values. The upside of this solution is that it can handle more values and also simplifies the filters. The drawback with this is that you have to put additional datasets in the model which complicate the model.

    {
      "input_source": { "type": "web", "url": "https://gist.githubusercontent.com/fluke777/777406ede2f7919fc3b6/raw/c053f12c0b57aadcc9271074c91781b7febd4068/column_based_data_example.txt" },
      "filters_config": {
        "user_column": "login",
        "labels": [{"label": "label.cities.city_id.name", "column": "city", "over": "/gdc/md/obs5uxo2y5atzzx6jx9dpkbwfuttekju/obj/2022", "to": "/gdc/md/obs5uxo2y5atzzx6jx9dpkbwfuttekju/obj/2023"}]
      }
    }

### Data permissions edge cases and other considerations

#### Restricting access
Absence of a filter means that user has full access to all data. This is is fairly easy to ensure just do not add a line to the input file for the filters. What is a little more difficult to ensure is how to deny user access to all data. Since the filter is what it is a filter and we said previously that it is evaluated along with any execution what might work is to mark it as FALSE. The platform does not allow this but we can get around it easily in the brick. The only problem is to solve how to express this situation in the data.

#### Dealing with missing values
Data filters are not living in isolation. They are not even containing the values. When you are setting a filter

    john@example.com: WHERE city IN ('San Francisco')

What is actually sent to the API is something more like

    john@example.com: WHERE [/gdc/md/obs5uxo2y5atzzx6jx9dpkbwfuttekju/obj/2022] IN ([/gdc/md/obs5uxo2y5atzzx6jx9dpkbwfuttekju/obj/2021?element_id=34])

What does this mean for you is basically that when you are trying to use some value in the filter it has to be loaded in the project as an attribute element of that particular attribute. If this is not the case several thing might happen

1. By default the brick crashes. I think this is safest (eventually we are talking about security right?). It means some assumption you had is not valid so you should investigate.
2. If you are feeling lucky you can change the default behavior. What the brick tries to do is to omit the invalid values. Imagine you are trying to set this filter

        john@example.com: WHERE city IN ('San Francisco', 'Prague')
and value 'Prague' is not in the data. Brick will try to set up the filter

        john@example.com: WHERE city IN ('San Francisco')
This is fine. Prague is not in the data so it does not matter we are not restricting the user to see that. But what would happen if we do not have even 'San Francisco' in our data? The expression

        john@example.com: WHERE city IN ()
is not valid so brick drops the filter altogether which means that user has access to all data.
3. Is the same as case 2 but when the valid values are exhausted user is denied access.

#### Restricting users vs adding users into the project

Since we are talking about security it is mandatory that users are restricted before they are added into project. Brick can help you with this tremendously. All you need to do is set up an organization and set up proper processes (for example using our users_brick) so the users are there. Data filters brick can take users from domain set up their data permissions before they are actually added to the project. If you add them afterwards they have restricted access right from the start. The only thing you have to worry about is properly orchestrate the pieces and make sure users are first set up with their filters and only then added to project (best way of doing that is using the users_brick from the appstore). The picture below illustrates the situation.

We believe it is so important that we added the `domain` parameter as part of all the examples above. You should not do it any other way unless you have pretty good reason.
