Users Brick
===========
This brick provides seamless user synchronization with your organization (domain) and/or project. It provides several modes of operations that suits several scenarios which we will explore below.

## Key Features:
From a high level perspective this brick can do for you

- Add users to organization
- Add/remove users to/from project
- Update user contact information
- Update user roles in a project

## Important terms

### Organization
In context of this document organization is a cache of users. User has to be created on the platform before he is added to the project and there are 2 ways. Either he registers himself/herself or he is added to an organization. User's existence in organization means only that he can log to the platform. He cannot see any project if he is explicitly not invited. Every organization has an organization admin. This admin can change users in his organization as he sees fit without users' consent.

### Project
Project is a place where data reside. User can be invited to a project which allows him to perform certain operations according to his role(s).

### Role
Set of permissions of a particular user in a given project. Example of a permission can be 'can_invite_users'. Set of these will form a role which can be assigned to a user in project.

## What you need to get started:
- an organization and an organization admin (for getting those contact our support)

## How things work

Let's describe all the pieces that we need to understand and then have a look at how the brick pieces things together.

## Adding users to organization

So we can add users to project later we have to add the to organization first. As stated previously organization contains information about users, their name, login, password etc. Organization is not connected to any project and the fact that a user is in an organization does not result in ability to access any project or data in that project for him. Only organization admin can access the domain.

The way domain updates work is that all the users that you provided in the input file are added to the domain. If they are already in they are updated accordingly. The update affects only the fields you provided. If you did not provide specific field it will not be touched. To illustrate let's see an example

![Updating user in organization](https://www.dropbox.com/s/y5betor6loa6bn3/updating_user_in_org.png?dl=0&raw=1)

Notice that while john's email was updated his first name was not.

### Notes
* you do not have to (and it is a good idea not to) provide a password. If not provided it is automatically generated when created for the first time and user can either change it later or he can be set up with a SingleSignOn.
* login has to have a format of an email address
* login cannot be changed and it is used to lookup a specific user
* if specific email address is not provided login is used instead

## Adding/changing/removing users to/from project

Having discussed adding users to organization. Let's discuss the same process with project. This works completely differently so let's dig deeper.

Syncing with project process is taking a list of users as an input. Each line of this list contains three pieces of information in some form. Which user and what role should be added to project. The file is declaring how the project should end up looking at the end of the process.

* Users that are in the project but not the file will end up being removed
* Users that are in the file but not in the project are added
* Users having different role are updated

To illustrate what is happening let's have a look at this picture.

![Syncing users into project](https://www.dropbox.com/s/1m83rgmcf9d936t/project_sync.png?dl=0&raw=1)

The file is on the far left. The project and its current data are in the middle. We take these to and identify several groups of users.

* Those that should be added because they are in the data coming from ETL but they are not in the project (todd@eample.com)
* Those that should be removed because they are in project but they are not in the data coming from ETL (seth@example.com)
* Those that exist in both but have different role and that has to updated (jane@example.com)
* Those that are identical in both and we do not have to touch them (john@example.com)

### Why declarative and not additive

Let me explain shortly why we decided to go the declarative ('give me how the project should look like and I will make it so') way as opposed to additive ('let me know each day who to add and remove'). The benefit of being declarative is the fact that it is stateless. If I give you the full file every day you know where you will end up regardless of how the project looks like right now. Even if you run things several times you end up in the same spot. If I give you an increment where you end up is dependent on the state of the project. If something goes wrong (loss of users) you probably have to get the full state anyway. Thanks to this the declarative way is also self healing. If you make a mistake one day it is going to fix itself automatically when you fix the data.

If the source system can provide only incremental data you have to do the extra work in your stateful ETL to provide a complete snapshot of the system (as you have to do for other parts as well). Taking data from an intermediary storage has also another benefit is that you own the data you were using to perform the tasks so if you need them later you can access them which is not necessarily guaranteed with data you do not own.

### Whitelisting
Typically you will have users in the project that are there for business reasons but also you will have there users that are there for various other reasons. Technical reasons (user deploying the ETL processes) various users from vendors etc. If we would do the synchronization strictly as described in the previous paragraph they would be removed every day as long as you would not add them to your data sources which typically does not make sense. You can whitelists users or classes of users so they are omitted from the process of adding removing users. We recommend to use this as little as possible. You can specify list of users that should be left alone like this.

	"whitelists" : ["etl_admin@gooddata.com"]

### Modes of authentication
Modes of authentication tell the platform how the user can access it. Currently there are two values available.

* password - User can access platform using his credentials
* sso - User can access platform using SSO

You can set up the synchronization in two ways

1) globally for all synchronized users
2) per user setup driven by data

#### Globally for all users
In many cases all users should receive the same setting so to make it more convenient you do not have to specify it in your data but you can provide a global setting in your process/schedule params

    {
      "input_source": { "type": "web", "url": "https://gist.githubusercontent.com/fluke777/4005f6d99e9a8c6a9c90/raw/63d2e58dabea89cc2953a690adb5d74b492a184f/domain_users.csv" },
      "sync_mode": "add_to_organization",
      "organization": "gooddata-tomas-svarovsky",
      "authentication_modes": "password"
    }

You can specify several values

    {
      "input_source": { "type": "web", "url": "https://gist.githubusercontent.com/fluke777/4005f6d99e9a8c6a9c90/raw/63d2e58dabea89cc2953a690adb5d74b492a184f/domain_users.csv" },
      "sync_mode": "add_to_organization",
      "organization": "gooddata-tomas-svarovsky",
      "authentication_modes": ["password", "sso"]
    }

Take note that this global setup takes precedence before data driven setup.

#### Per user data driven setup
Sometimes you need to be able to define things on more granular level and set each user with particular authentication mode.

Typically data data would look something like this

  login                 | first_name  | last_name      | authentication_modes  |
------------------------|-------------|----------------|-----------------------|
 jane.doe@example.com   | Jane        | Doe            | password              |
 john.doe@example.com   | John        | Doe            | "password, sso"       |

And the corresponding process params could look like this

    {
      "input_source": { "type": "web", "url": "some_file" },
      "sync_mode": "add_to_organization",
      "organization": "gooddata-tomas-svarovsky"
    }

Notice that there is no specification of global values in params so the brick will try to find the information in the data. You can specify several values in your data. Remember that in that case CSV field has to be quoted becase we are using separator inside a field. The data are by default exepcted in the column named *authentication_modes*.

On some occassions the information will be in the data but provided in column with a different name. For your convenience you can provide the name of custom column in the params. Here is an example of data

  login                 | first_name  | last_name      | my_authentication_modes_column  |
------------------------|-------------|----------------|---------------------------------|
 jane.doe@example.com   | Jane        | Doe            | password                        |
 john.doe@example.com   | John        | Doe            | "password, sso"                 |

And here you have corresponding process params

    {
      "input_source": { "type": "web", "url": "some_file" },
      "sync_mode": "add_to_organization",
      "organization": "gooddata-tomas-svarovsky",
      "authentication_modes_column": "my_authentication_modes_column"
    }

## Modes of synchronization

The brick can operate in different modes. We implemented several modes that we find useful in our day to day usage. If something that would be useful for you is not here let us know the list is not meant to be definitive.

### Sync organization
The process takes a data source synchronizes the organization. That is it.

#### Deployment parameters

  	{
  	  "sync_mode": "add_to_organization",
  	  "organization": "organization_name",
          "input_source": { "type": "web", "url": "https://gist.githubusercontent.com/fluke777/4005f6d99e9a8c6a9c90/raw/63d2e58dabea89cc2953a690adb5d74b492a184f/domain_users.csv" }
    }

### Sync project
The process takes a data source and synchronizes the project. That is it. The users have to be in the organization already it they are not there the process would fail.

#### Deployment parameters

    {
      "input_source": { "type": "web", "url": "https://gist.githubusercontent.com/fluke777/4005f6d99e9a8c6a9c90/raw/63d2e58dabea89cc2953a690adb5d74b492a184f/domain_users.csv" },
      "sync_mode": "sync_project",
      "organization": "gooddata-tomas-svarovsky",
      "whitelists" : ["svarovsky+gem_tester@gooddata.com"]
    }

### Sync organization and project in one go
The process takes a data source synchronizes the organization and then goes forward to synchronize users in the project. The intended usage for this mode is a customer who has one project so there is no benefit in splitting the organization and project synchronization into 2 tasks. You can achieve the same effect by using 2 processes in a series. First syncing the organization and the second syncing the project.

    {
      "input_source": { "type": "staging", "path": "users.csv" },
      "organization": "gooddata-tomas-svarovsky",
      "whitelists" : ["svarovsky+gem_tester@gooddata.com"]
    }

### Sync many projects in one process
There are occasions where someone is maintaining an application with several projects. There are couple of projects like 10 or so. This mode allows a process to sync those projects all in one go. The file has to contain and additional information about what user should go to which project. The file is partitioned based on this information and each partition is used to sync a give project. The project information has to be provided in a form of Project ID (aka pid, project hash).

![One to many sync in one process](https://www.dropbox.com/s/dxok260opv7jy3r/project_sync_mode_on_to_many.png?dl=0&raw=1)

This mode is meant for cases where a person is by hand managing small number of projects so having one process distributing the users allows him to have more manageable ETL. If you are in the Powered by GoodData and automating your deployment this is probably not your best bet and you should consider one of the following.

#### Deployment parameters

	  {
	    "sync_mode": "sync_multiple_projects_based_on_pid",
	    "organization": "organization_name",
      "input_source": { "type": "web", "url": "https://gist.githubusercontent.com/fluke777/4005f6d99e9a8c6a9c90/raw/63d2e58dabea89cc2953a690adb5d74b492a184f/domain_users.csv" },
      "whitelists" : ["etl_admin@gooddata.com"]
    }

### Sync one project with filtering based on project Id
In many cases you want the same thing as in previous case. You have one source of data and you would like to each project to use just a subset. It is incovenient to prepare N different data files or N tables. How this mode differs from the previous mode is that each proejct has one process deployed and the process is responsible for filtering the data for that particular project and update just that one project (as opposed to update all projects in the previous case).

The benefit here is that the process is deployed in each project so you have everything in one place and can orchestrate things easily using administration console. The problem with having many more processes and juggling with them is mitigated by the fact that Powered by GoodData applications are usually deployed automatically. Also if you remove a project all the ETL processes are removed with it so you do not have to consider any cleanup steps.

![One to many in PBG](https://www.dropbox.com/s/m0uzv3r4zwtq682/project_sync_mode_on_to_many_pbg.png?dl=0&raw=1)

#### Deployment parameters
    {
      "input_source": { "type": "web", "url": "https://gist.githubusercontent.com/fluke777/4005f6d99e9a8c6a9c90/raw/63d2e58dabea89cc2953a690adb5d74b492a184f/domain_users.csv" },
      "sync_mode": "sync_one_project_based_on_pid",
      "organization": "gooddata-tomas-svarovsky",
      "multiple_projects_column", "project_id"
      "whitelists" : ["etl_admin@gooddata.com"]
    }

### Sync one project with filtering based on custom project Id
Consider situation that is the same as in previous mode. How would you actually implement getting the file that is an input for user sync processes? The project is specified by an ID that does not come from the customer and is not known upfront. You can learn it only after a new project is spun up. While this can be done (and occasionally is and that is the reason why we keep the previous mode) it is usually nontrivial to synchronize the processes. It is even more difficult if things get separated between customer and a consultancy company (customer provides data and info how many projects should be spun up and consultancy takes care of implementing the ETL).

What customer can do is to generate an ID that for him internally identifies a project (we will call it Custom project ID). When some tool spins up a project it stores this id into project meta data storage. This creates the mapping between Project Id (that customer does not know) and Custom project Id. The flow of information is explained on the following picture.

![](https://www.dropbox.com/s/ybgsch8lf810xqm/project_sync_mode_one_to_many_pbg_custom_id.png?dl=0&raw=1)

Notice there are three distinct groups of processes (differentiated) by the color. The advantage that these things do not have to be synchronized and can run at their pace. Let's walk through the steps.

* Red - Customer loads the data and at some point they are picked up and put into storage. His data contains the Custom Id that would allow us to piece things together without knowing in which physical project they would end up.
* Yellow - at some point the process responsible for maintaining projects and deploying them wakes up. He notices there is need for spinning up a new project (Project 4) so he does that. Part of his responsibilities is to deploy an ETL process and mark the deployed project with 'Custom project Id'.
* Green - At some point the ETL wakes up and processes data. If it runs it means that the data for this project is already in the 

Let's have a look at how the ETL would run on the next picture.

![Etl detail](https://www.dropbox.com/s/xqywmmnscg6v0bm/project_sync_mode_on_to_many_pbg_custom_id.png?dl=0&raw=1)

At the top we have some datasets to illustrate data form the customer. There are 2 projects referenced by Custom Project Ids. And all the other datasets use the Custom project Id as a reference to project. Once the ETL is kicked off it would reach for the data and process them. One of the outputs would be also a file that would provide a data about users in particular project (bottom left).


### Column parameters

#### Data
Typical data that serve as an input might look something like this. Or there is an example on [gist](https://gist.githubusercontent.com/fluke777/4005f6d99e9a8c6a9c90/raw/63d2e58dabea89cc2953a690adb5d74b492a184f/domain_users.csv)

  project_id                      |  login                 | first_name  | last_name      | role  |
----------------------------------|------------------------|-------------|----------------|-------|
tspv1le9afb94q47pehiub568ubkkqqw  | john.doe@example.com   | John        | Doe            | admin |
tspv1le9afb94q47pehiub568ubkkqqw  | jane.doe@example.com   | Jane        | Doe            | admin |

#### Column name defaults
The following list contains the properties that are useful to specify for updating an organization. The name after hyphen is the default. In parenthesis you can find name of the parameter you can use to override the default.

* First name - first_name (first_name_column)
* Last name - last_name (last_name_column)
* Login - login (login_column)
* Password - password (password_column)
* Email - email (email_column)
* SSO Provider - sso_provider (sso_provider_column)
* Project ID - project_id (multiple_projects_column)
* Authentication modes - authentication_modes (authentication_modes_column)

For instance, if in your data first names would be stored in a column called "x", you would pass as param something along the lines of

    {
      "first_name_column": "x"
    }

Your data file then should look like this

  project_id                      |  login                 | x           | last_name      | role  |
----------------------------------|------------------------|-------------|----------------|-------|
tspv1le9afb94q47pehiub568ubkkqqw  | john.doe@example.com   | John        | Doe            | admin |
tspv1le9afb94q47pehiub568ubkkqqw  | jane.doe@example.com   | Jane        | Doe            | admin |

