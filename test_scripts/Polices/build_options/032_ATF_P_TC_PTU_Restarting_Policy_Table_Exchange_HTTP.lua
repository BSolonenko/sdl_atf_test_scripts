---------------------------------------------------------------------------------------------
-- Requirements summary:
-- [PolicyTableUpdate] Restarting Policy Table Exchange
--
-- Description:
--Policy Manager must restart retry sequence within the same ignition cycle only if
--anything triggers Policy Table Update request.

-- Build SDL with flag above
-- 1. Used preconditions:
-- SDL is built with "-DEXTENDED_POLICY: HTTP" flag
-- First SDL life cycle
-- App is registered
-- PTU is not finished after retry
-- 2. Performed steps
-- New application is registered and PTU is triggered
-- Expected result:
-- SDL: Starts PTU sequence
-- SDL->HMI: OnStatusUpdate("UPDATE_NEEDED")
-- PTS is created by SDL.....//PTU started
-- SDL->app: OnSystemRequest()

---------------------------------------------------------------------------------------------

--[[ General configuration parameters ]]
config.deviceMAC = "12ca17b49af2289436f303e0166030a21e525d266e209267433801a8fd4071a0"
--ToDo: shall be removed when issue: "ATF does not stop HB timers by closing session and connection" is fixed
config.defaultProtocolVersion = 2

--[[ Required Shared libraries ]]
local commonSteps = require ('user_modules/shared_testcases/commonSteps')
local events = require('events')

--[[ Local Variables ]]
local seconds_between_retries = {1, 1, 1, 1, 1} -- in min
local timeout_after_x_seconds = 30 -- in sec
local timeout = {} -- in sec
timeout[1] = timeout_after_x_seconds
timeout[2] = timeout[1] + seconds_between_retries[1]
timeout[3] = timeout[1] + timeout[2] + seconds_between_retries[2]
timeout[4] = timeout[1] + timeout[3] + seconds_between_retries[3]
timeout[5] = timeout[1] + timeout[4] + seconds_between_retries[4]
timeout[6] = timeout[1] + timeout[5] + seconds_between_retries[5]

--[[ General Settings for configuration ]]
Test = require('connecttest')
require('cardinalities')
local mobile_session = require('mobile_session')

--[[ Local Functions ]]
local function BackupPreloaded()
  os.execute('cp ' .. config.pathToSDL .. 'sdl_preloaded_pt.json' .. ' ' .. config.pathToSDL .. 'backup_sdl_preloaded_pt.json')
  os.execute('rm ' .. config.pathToSDL .. 'policy.sqlite')
end

local function RestorePreloadedPT()
  os.execute('rm ' .. config.pathToSDL .. 'sdl_preloaded_pt.json')
  os.execute('cp ' .. config.pathToSDL .. 'backup_sdl_preloaded_pt.json' .. ' ' .. config.pathToSDL .. 'sdl_preloaded_pt.json')
end

local function SetRetryValuesInPreloadedFile()
  local pathToFile = config.pathToSDL .. 'sdl_preloaded_pt.json'
  local file = io.open(pathToFile, "r")
  local json_data = file:read("*all") -- may be abbreviated to "*a";
  file:close()
  local json = require("modules/json")
  local data = json.decode(json_data)

  if data.policy_table.functional_groupings["DataConsent-2"] then
    data.policy_table.functional_groupings["DataConsent-2"] = nil
  end
  data.policy_table.module_config.seconds_between_retries = seconds_between_retries
  data.policy_table.module_config.timeout_after_x_seconds = timeout_after_x_seconds
  data = json.encode(data)
  file = io.open(pathToFile, "w")
  file:write(data)
  file:close()
end

local function DelayedExp(time)
  local event = events.Event()
  event.matches = function(self, e) return self == e end
  EXPECT_EVENT(event, "Delayed event")
  :Timeout(time + 1000)
  RUN_AFTER(function()
      RAISE_EVENT(event, event)
      end, time)
  end

  --[[ Preconditions ]]
  function Test.Precondition_StopSDL()
    StopSDL()
  end

  function Test.Precondition_DeleteLogsAndPolicyTable()
    commonSteps:DeleteLogsFiles()
    commonSteps:DeletePolicyTable()
  end

  function Test.Precondition_Backup_sdl_preloaded_pt()
    BackupPreloaded()
  end

  function Test.Precondition_Set_Retry_Values_In_Preloaded_File()
    SetRetryValuesInPreloadedFile()
  end

  function Test.Precondition_StartSDL_FirstLifeCycle()
    StartSDL(config.pathToSDL, config.ExitOnCrash)
  end

  function Test:Precondition_InitHMI_FirstLifeCycle()
    self:initHMI()
  end

  function Test:Precondition_InitHMI_onReady_FirstLifeCycle()
    self:initHMI_onReady()
  end

  function Test:Precondition_ConnectMobile_FirstLifeCycle()
    self:connectMobile()
  end

  function Test:Precondition_StartSession()
    self.mobileSession = mobile_session.MobileSession(self, self.mobileConnection)
    self.mobileSession:StartService(7)
  end

  function Test.Precondition_RestorePreloadedPT()
    RestorePreloadedPT()
  end

  --[[ Test ]]
  function Test:TestStep_Register_App_And_Check_Retry_Timeouts()
    print("Wait retry sequence to elapse: " .. (timeout[1] + timeout[2] + timeout[3] + timeout[4] + timeout[5] + timeout[6]) .. "sec. + 2min tolerance")
    local startPTUtime = 0
    local firstTryTime = 0
    local secondTryTime = 0
    local thirdTryTime = 0
    local fourthTryTime = 0
    local fifthTryTime = 0

    local CorIdRAI = self.mobileSession:SendRPC("RegisterAppInterface",
      {
        syncMsgVersion =
        {
          majorVersion = 3,
          minorVersion = 0
        },
        appName = "AppName",
        isMediaApplication = true,
        languageDesired = "EN-US",
        hmiDisplayLanguageDesired = "EN-US",
        appID = "1234567",
        deviceInfo =
        {
          os = "Android",
          carrier = "Megafon",
          firmwareRev = "Name: Linux, Version: 3.4.0-perf",
          osVersion = "4.4.2",
          maxNumberRFCOMMPorts = 1
        }
      })
    EXPECT_NOTIFICATION("OnSystemRequest")
    :ValidIf(function(exp,data)
        if(data.payload.requestType == "HTTP") then

          if exp.occurences == 2 then
            startPTUtime = os.time()
            firstTryTime = timeout[1]
            return true
          end

          if exp.occurences == 3 and firstTryTime == os.time() then
            secondTryTime = timeout[2]
            print ("first retry time: " .. os.time())
            return true
          elseif exp.occurences == 2 and firstTryTime ~= os.time() then
            print ("Wrong first retry time! Expected: " .. timeout[1] .. " Actual: " .. os.time() - startPTUtime)
            return false
          end

          if exp.occurences == 4 and secondTryTime == os.time() then
            thirdTryTime = timeout[3]
            print ("second retry time: " .. os.time())
            return true
          elseif exp.occurences == 3 and secondTryTime ~= os.time() then
            print ("Wrong second retry time! Expected: " .. timeout[2] .. " Actual: " .. os.time() - firstTryTime)
            return false
          end

          if exp.occurences == 5 and thirdTryTime == os.time() then
            fourthTryTime = timeout[4]
            print ("third retry time: " .. os.time())
            return true
          elseif exp.occurences == 4 and thirdTryTime ~= os.time() then
            print ("Wrong third retry time! Expected: " .. timeout[3] .. " Actual: " .. os.time() - secondTryTime)
            return false
          end

          if exp.occurences == 6 and fourthTryTime == os.time() then
            fifthTryTime = timeout[5]
            print ("fourth retry time: " .. os.time())
            return true
          elseif exp.occurences == 5 and fourthTryTime ~= os.time() then
            print ("Wrong fourth retry time! Expected: " .. timeout[4] .. " Actual: " .. os.time() - thirdTryTime)
            return false
          end

          if exp.occurences == 7 and fifthTryTime == os.time() then
            print ("fifth retry time: " .. os.time())
            return true
          elseif exp.occurences == 6 and fifthTryTime ~= os.time() then
            print ("Wrong fifth retry time! Expected: " .. timeout[5] .. " Actual: " .. os.time() - fifthTryTime)
            return false
          end
        end

        return false

      end)
    :Times(#seconds_between_retries + 2) -- 6 HTTP, 1 LOCK_SCREEN_ICON_URL

    DelayedExp((timeout[1] + timeout[2] + timeout[3] + timeout[4] + timeout[5] + timeout[6])*1000 + 2*60000) --msec
    EXPECT_RESPONSE(CorIdRAI, { success = true, resultCode = "SUCCESS"})
  end

  function Test:TestStep_StartSession2()
    self.mobileSession2 = mobile_session.MobileSession(self, self.mobileConnection)
    self.mobileSession2:StartService(7)
  end

  function Test:TestStep_Register_New_App_And_Check_New_PTU_Starting()
    local CorIdRAI2 = self.mobileSession2:SendRPC("RegisterAppInterface",
      {
        syncMsgVersion =
        {
          majorVersion = 3,
          minorVersion = 0
        },
        appName = "AnotherAppName",
        isMediaApplication = true,
        languageDesired = "EN-US",
        hmiDisplayLanguageDesired = "EN-US",
        appID = "7654321",
        deviceInfo =
        {
          os = "Android",
          carrier = "Megafon",
          firmwareRev = "Name: Linux, Version: 3.4.0-perf",
          osVersion = "4.4.2",
          maxNumberRFCOMMPorts = 1
        }
      })
    EXPECT_NOTIFICATION("OnSystemRequest", {requestType = "LOCK_SCREEN_ICON_URL"}, {requestType = "HTTP"})
    EXPECT_HMINOTIFICATION("SDL.OnStatusUpdate", {status = "UPDATE_NEEDED"}, {status = "UPDATING"}):Times(2)
    self.mobileSession2:ExpectResponse(CorIdRAI2, {success = true, resultCode = "SUCCESS"})
  end

  --[[ Postconditions ]]
  function Test.Postcondition_SDLStop()
    StopSDL()
  end

  return Test
