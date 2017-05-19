---------------------------------------------------------------------------------------------
-- Requirement summary:
-- [APPLINK-19983]: [Mobile Navi]: SDL must send EndService to mobile app in case mobile app continue streaming being at BACKGROUND

-- Description:
-- SDL sends EndService to mobile app in case mobile app continue streaming being at BACKGROUND

-- Preconditions:
-- SDL first life cycle.
-- ini file contains StopStreamingTimeout = 1000
-- Core and HMI Started
-- 2 media Navi apps are registered (MobileNavi checkbox checked)
-- Activate Navi app1 on HMI.

-- Steps:
-- 1. Enable Video service.
-- 2. Start Audio streaming (be sure that Stop stream on "BACKGROUND"" checkbox is unchecked).
-- 3. Change app1 to BACKGROUND by activating app2

-- Expected result:
-- Navi App received BACKGROUND
-- After 1 second SDL should send EndService() requests for 11 service
-- and SDL should send StopStream to HMI

---------------------------------------------------------------------------------------------
require('user_modules/all_common_modules')
config.defaultProtocolVersion = 3
local constants = require('protocol_handler/ford_protocol_constants')

--[[ Local variables]]
local file_name = "files/ELL_PART_5_768k.wmv"
local time_background = 0

--[[ Preconditions ]]
common_steps:AddNewTestCasesGroup("Preconditions")
-- Update ini file contains StopStreamingTimeout = 1000
common_functions:SetValuesInIniFile("%p?StopStreamingTimeout%s?=%s-[%d]-%s-\n", "StopStreamingTimeout", 1000)
-- ForceProtectedService is set to Non
common_functions:SetValuesInIniFile("ForceProtectedService%s?=%s-[^\n]-%s-\n", "ForceProtectedService", "Non")
-- Set app1 as NAVIGATION media app
local app1 = config.application1.registerAppInterfaceParams
app1.isMediaApplication = true
app1.appHMIType = {"NAVIGATION"}
common_steps:PreconditionSteps("Preconditions", const.precondition.ACTIVATE_APP)
-- Set app1 as NAVIGATION media app
local app2 = config.application2.registerAppInterfaceParams
app2.isMediaApplication = true
app2.appHMIType = {"NAVIGATION"}
common_steps:AddMobileSession("Preconditions_AddMobileSession2", nil, "mobileSession2")
common_steps:RegisterApplication("Preconditions_RegisterApp2", "mobileSession2", app2)

--[[ Test ]]
common_steps:AddNewTestCasesGroup("Tests")

function Test:App1_StartService()
  self.mobileSession:StartService(constants.SERVICE_TYPE.VIDEO)
  EXPECT_HMICALL("Navigation.StartStream")
  :Do(function(_,data)
      self.hmiConnection:SendResponse(data.id, data.method, "SUCCESS", { })
    end)
end

function Test:App1_StartStreaming()
  self.mobileSession:StartStreaming(constants.SERVICE_TYPE.VIDEO, file_name)
  EXPECT_HMINOTIFICATION("Navigation.OnVideoDataStreaming", {available = true})
end

function Test:Change_App1_To_BackGround()
  local hmi_app_id2 = common_functions:GetHmiAppId(app2.appName, self)
  local cid = self.hmiConnection:SendRequest("SDL.ActivateApp", {appID = hmi_app_id2})
  EXPECT_HMIRESPONSE(cid, {method = "SDL.ActivateApp", code = 0})
  self.mobileSession2:ExpectNotification("OnHMIStatus", {hmiLevel = "FULL", audioStreamingState = "AUDIBLE", systemContext = "MAIN"})
  self.mobileSession:ExpectNotification("OnHMIStatus", {hmiLevel = "BACKGROUND", audioStreamingState = "NOT_AUDIBLE", systemContext = "MAIN"})
  :Do(function()
      time_background = timestamp()
    end)
end

function Test:SDL_Sends_EndService_Request()
  -- Create an event to catch END_SERVICE event from SDL to mobile
  local event = events.Event()
  event.matches = function(_, data)
    return data.frameType == constants.FRAME_TYPE.CONTROL_FRAME and
    data.serviceType == constants.SERVICE_TYPE.VIDEO and
    data.frameInfo == constants.FRAME_INFO.END_SERVICE and
    data.sessionId == self.mobileSession.sessionId
  end
  self.mobileSession:ExpectEvent(event, "EndService Request from SDL")
  :ValidIf(function()
      local current_time = timestamp()
      local interval = current_time - time_background
      -- timeout is 1000 ms. +/-200 ms is deviation
      if (interval > 1000 - 200) and (interval < 1000 + 200) then
        return true
      end
      self:FailTestCase("SDL sends EndService Request to mobile after " .. tostring(interval) .. " ms. Expected timeout is 1000 ms")
    end)
  :Do(function()
      -- Mobile sends END_SERVICE_ACK
      self.mobileSession:Send(
        {
          frameType = constants.FRAME_TYPE.CONTROL_FRAME,
          serviceType = constants.SERVICE_TYPE.VIDEO,
          frameInfo = constants.FRAME_INFO.END_SERVICE_ACK,
          sessionId = self.mobileSession.sessionId,
          binaryData = self.mobileSession.hashCode
        })
    end)
  local hmi_app_id1 = common_functions:GetHmiAppId(app1.appName, self)
  EXPECT_HMICALL("Navigation.StopStream", {appID = hmi_app_id1})
  :ValidIf(function()
      local current_time = timestamp()
      local interval = current_time - time_background
      -- timeout is 1000 ms. +/-200 ms is deviation
      if (interval > 1000 - 200) and (interval < 1000 + 200) then
        return true
      end
      self:FailTestCase("SDL sends Navigation.StopStream Request to HMI after " .. tostring(interval) .. " ms. Expected timeout is 1000 ms")
    end)
  :Do(function(_,data)
      self.hmiConnection:SendResponse(data.id, "Navigation.StopStream", "SUCCESS", {})
    end)
end

--[[ Postconditions ]]
common_steps:AddNewTestCasesGroup("Postconditions")
common_steps:UnregisterApp("Postconditions_Unregister_App1", app1.appName)
common_steps:UnregisterApp("Postconditions_Unregister_App2", app2.appName)
common_steps:StopSDL("Postconditions_StopSDL")