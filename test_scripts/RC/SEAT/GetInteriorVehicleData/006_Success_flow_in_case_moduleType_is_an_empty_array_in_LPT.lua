---------------------------------------------------------------------------------------------------
-- Proposal: https://github.com/smartdevicelink/sdl_evolution/blob/master/proposals/0105-remote-control-seat.md
-- User story:
-- Use case:
-- Item:
--
-- Description:
-- In case:
-- 1) "moduleType" in app's assigned policies has an empty array
-- 2) and RC app sends GetInteriorVehicleData request with valid parameters
-- SDL must:
-- 1) Allow this RPC to be processed
---------------------------------------------------------------------------------------------------
--[[ Required Shared libraries ]]
local runner = require('user_modules/script_runner')
local commonRC = require('test_scripts/RC/SEAT/commonRC')
local json = require('modules/json')

--[[ Test Configuration ]]
runner.testSettings.isSelfIncluded = false

--[[ Local Functions ]]
local function getDataForModule(pModuleType)
  local mobSession = commonRC.getMobileSession()
  local cid = mobSession:SendRPC("GetInteriorVehicleData", {
    moduleType = pModuleType,
    subscribe = true
  })

  EXPECT_HMICALL("RC.GetInteriorVehicleData", {
    appID = commonRC.getHMIAppId(),
    moduleType = pModuleType,
    subscribe = true
  })
  :Do(function(_, data)
      commonRC.getHMIconnection():SendResponse(data.id, data.method, "SUCCESS", {
        moduleData = commonRC.getModuleControlData(pModuleType),
        isSubscribed = true
      })
    end)

  mobSession:ExpectResponse(cid, { success = true, resultCode = "SUCCESS",
    isSubscribed = true,
    moduleData = commonRC.getModuleControlData(pModuleType)
  })
end

local function ptu_update_func(tbl)
  tbl.policy_table.app_policies[config.application1.registerAppInterfaceParams.fullAppID].moduleType = json.EMPTY_ARRAY
end

--[[ Scenario ]]
runner.Title("Preconditions")
runner.Step("Clean environment", commonRC.preconditions)
runner.Step("Start SDL, HMI, connect Mobile, start Session", commonRC.start)
runner.Step("RAI, PTU", commonRC.rai_ptu, { ptu_update_func })
runner.Step("Activate App", commonRC.activate_app)

runner.Title("Test")
runner.Step("GetInteriorVehicleData SEAT", getDataForModule, { "SEAT" })

runner.Title("Postconditions")
runner.Step("Stop SDL", commonRC.postconditions)
