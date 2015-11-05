# encoding: UTF-8
#
# Copyright (c) 2010-2015 GoodData Corporation. All rights reserved.
# This source code is licensed under the BSD-style license found in the
# LICENSE file in the root directory of this source tree.

module GoodData
  module Environment
    module ConnectionHelper
      DEFAULT_SERVER = 'https://staging3.intgdc.com'
      DEFAULT_USER_URL = '/gdc/account/profile/a3700850b92a0a6c097e48369b5d226f'
      STAGING_URI = 'https://staging3.intgdc.com/gdc/uploads/'
    end

    module ProcessHelper
      PROCESS_ID = 'e4369e27-a6c7-4782-b4cb-a06b2e2db326'
      DEPLOY_NAME = 'graph/graph.grf'
    end

    module ProjectHelper
      PROJECT_ID = 'hq7ik4hpsaknrsvb07jz2adbci1iq5s8'
      PROJECT_URL = "/gdc/projects/#{PROJECT_ID}"
      PROJECT_TITLE = 'GoodTravis'
      PROJECT_SUMMARY = 'No summary'
    end

    module ScheduleHelper
      SCHEDULE_ID = '55ed6757e4b0d165852ab308'
    end
  end
end
