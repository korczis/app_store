LDM synchronization brick
===========
This brick provides you way to synchronize LDM of a master and all clients in segment or in application.

## Key Features:
From a high level perspective this brick can do for you

- Synchornizes LDM of a segment's project master and its respective clients

## What you need to get started:
- an organization and an organization admin (for getting those contact our support)
- whitelabeled domain (bascically you need gd to set up your own hostname for you. If you do not have this it will not work)


## LDM Synchronization


#### Deployment parameters

This brick does not need any parameters to work besided the organization name. It needs to run under domain administrator so he has access to segment-client mappings.

If you need to you can specify parameter `segment` and the brick will perform its operations only under that particular segment.

  	{
      "organization": "organization_name",
      "segment" : "segment_1"
    }

#### Todo

- we need to figure out what the typical usecase is in terms of syncing with breaking changes. SDK allows to specify certain levels of safety during model updates. We need to figure a good way how to expose them here.