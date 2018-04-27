---------------------------------------------------------------------------------------------------
-- User story: https://github.com/smartdevicelink/sdl_core/issues/1031

-- Pre-conditions:
-- 1. Core, HMI started.
-- 2. App is registered and deactivated on HMI (has LIMITED level)
-- 3. OnKeyboardInput notification is allowed to the App from LIMITED
-- 4. Choise set with id 1 is created.

-- Steps to reproduce:
-- 1. Send PerformInteraction(ICON_ONLY)
-- 2. During processing request send OnKeyboardInput notification

-- Expected:
-- In case there is no active PerformInteraction(KEYBOARD), SDL should resend 
-- OnKeyboardInput only to App that is currently in FULL.
---------------------------------------------------------------------------------------------------

--[[ Required Shared libraries ]]
local runner = require('user_modules/script_runner')
local commonSmoke = require('test_scripts/Smoke/commonSmoke')
local commonPreconditions = require('user_modules/shared_testcases/commonPreconditions')

config.application1.registerAppInterfaceParams.appHMIType = { "DEFAULT" }
config.application1.registerAppInterfaceParams.isMediaApplication = true
config.application2.registerAppInterfaceParams.appHMIType = { "DEFAULT" }
config.application2.registerAppInterfaceParams.isMediaApplication = true

--[[ Local Variables ]]
local putFileParams = {
  requestParams = {
    syncFileName = 'icon.png',
    fileType = "GRAPHIC_PNG",
    persistentFile = false,
    systemFile = false
  },
  filePath = "files/icon.png"
}

local storagePath = commonPreconditions:GetPathToSDL() .. "storage/" ..
config.application1.registerAppInterfaceParams.appID .. "_" .. commonSmoke.getDeviceMAC() .. "/"

local ImageValue = {
  value = storagePath .. "icon.png",
  imageType = "DYNAMIC",
}

local function PromptValue(text)
  local tmp = {
    {
      text = text,
      type = "TEXT"
    }
  }
  return tmp
end

local initialPromptValue = PromptValue(" Make your choice ")

local helpPromptValue = PromptValue(" Help Prompt ")

local timeoutPromptValue = PromptValue(" Time out ")

local vrHelpvalue = {
  {
    text = " New VRHelp ",
    position = 1,
    image = ImageValue
  }
}

local requestParams = {
  initialText = "StartPerformInteraction",
  initialPrompt = initialPromptValue,
  interactionMode = "BOTH",
  interactionChoiceSetIDList = {
    100
  },
  helpPrompt = helpPromptValue,
  timeoutPrompt = timeoutPromptValue,
  timeout = 10000,
  vrHelp = vrHelpvalue,
  interactionLayout = "ICON_ONLY"
}

--[[ Local Functions ]]
local function setChoiseSet(choiceIDValue)
  local temp = {
    {
      choiceID = choiceIDValue,
      menuName ="Choice" .. tostring(choiceIDValue),
      vrCommands = {
        "VrChoice" .. tostring(choiceIDValue),
      },
      image = {
        value ="icon.png",
        imageType ="STATIC",
      }
    }
  }
  return temp
end

local function CreateInteractionChoiceSet(choiceSetID, self)
  local choiceID = choiceSetID
  local cid = self.mobileSession1:SendRPC("CreateInteractionChoiceSet", {
      interactionChoiceSetID = choiceSetID,
      choiceSet = setChoiseSet(choiceID),
    })
  EXPECT_HMICALL("VR.AddCommand", {
      cmdID = choiceID,
      type = "Choice",
      vrCommands = { "VrChoice" .. tostring(choiceID) }
    })
  :Do(function(_,data)
      self.hmiConnection:SendResponse(data.id, data.method, "SUCCESS", { })
    end)
  self.mobileSession1:ExpectResponse(cid, { resultCode = "SUCCESS", success = true })
end

local function SendOnSystemContext(self, ctx)
  self.hmiConnection:SendNotification("UI.OnSystemContext",
    { appID = commonSmoke.getHMIAppId(), systemContext = ctx })
end

local function setExChoiseSet(choiceIDValues)
  local exChoiceSet = { }
  for i = 1, #choiceIDValues do
    exChoiceSet[i] = {
      choiceID = choiceIDValues[i],
      image = {
        value = "icon.png",
        imageType = "STATIC",
      },
      menuName = "Choice" .. choiceIDValues[i]
    }
  end
  return exChoiceSet
end

local function OnKeyboardInput1app(self)
  self.hmiConnection:SendNotification("UI.OnKeyboardInput",{data = "abc", event = "KEYPRESS"})
  self.mobileSession1:ExpectNotification("OnKeyboardInput")
  :Times(0)
end

local function OnKeyboardInput2app(self)
  OnKeyboardInput1app(self);
  self.mobileSession2:ExpectNotification("OnKeyboardInput")
end

local function PI_PerformViaMANUAL_ONLY(paramsSend, onKeyboardInput, self)
  paramsSend.interactionMode = "MANUAL_ONLY"
  local cid = self.mobileSession1:SendRPC("PerformInteraction", paramsSend)
  EXPECT_HMICALL("VR.PerformInteraction", {
      helpPrompt = paramsSend.helpPrompt,
      initialPrompt = paramsSend.initialPrompt,
      timeout = paramsSend.timeout,
      timeoutPrompt = paramsSend.timeoutPrompt
    })
  :Do(function(_,data)
      self.hmiConnection:SendNotification("TTS.Started")
      self.hmiConnection:SendResponse(data.id, data.method, "SUCCESS", { })
    end)
  EXPECT_HMICALL("UI.PerformInteraction", {
      timeout = paramsSend.timeout,
      choiceSet = setExChoiseSet(paramsSend.interactionChoiceSetIDList),
      initialText = {
        fieldName = "initialInteractionText",
        fieldText = paramsSend.initialText
      }
    })
  :Do(function(_,data)
      SendOnSystemContext(self,"HMI_OBSCURED")
      onKeyboardInput(self)
      local function uiResponse()
        self.hmiConnection:SendResponse(data.id, data.method, "SUCCESS",
          { choiceID = paramsSend.interactionChoiceSetIDList[1] })
        self.hmiConnection:SendNotification("TTS.Stopped")
        SendOnSystemContext(self,"MAIN")
      end
      RUN_AFTER(uiResponse, 5000)
    end)
  self.mobileSession1:ExpectResponse(cid,
    { success = true, resultCode = "SUCCESS", choiceID = paramsSend.interactionChoiceSetIDList[1] })
end

local function PI_PerformViaMANUAL_ONLY_1apps(paramsSend, self)
  PI_PerformViaMANUAL_ONLY(paramsSend, OnKeyboardInput1app, self)
end

local function PI_PerformViaMANUAL_ONLY_2apps(paramsSend, self)
  PI_PerformViaMANUAL_ONLY(paramsSend, OnKeyboardInput2app, self)
end

local function deactivateToLimited(self)
  self.hmiConnection:SendNotification("BasicCommunication.OnAppDeactivated", {appID = commonSmoke.getHMIAppId()})
  self.mobileSession1:ExpectNotification("OnHMIStatus",
    { systemContext = "MAIN", hmiLevel = "LIMITED", audioStreamingState = "AUDIBLE"})
end

local function ptuFuncApp1(tbl)
  local AppGroup = {
    rpcs = {
      PerformInteraction = {
        hmi_levels = { "NONE", "BACKGROUND", "FULL", "LIMITED" }
      },
      OnKeyboardInput = {
        hmi_levels = {"BACKGROUND", "FULL", "LIMITED"}
      }
    }
  }
  tbl.policy_table.functional_groupings.NewTestCaseGroup1 = AppGroup
  tbl.policy_table.app_policies[config.application1.registerAppInterfaceParams.appID].groups =
  { "Base-4", "NewTestCaseGroup1" }
end

local function ptuFuncApp2(tbl)
  local AppGroup = {
    rpcs = {
      OnKeyboardInput = {
        hmi_levels = {"BACKGROUND", "FULL", "LIMITED"}
      }
    }
  }
  tbl.policy_table.functional_groupings.NewTestCaseGroup2 = AppGroup
  tbl.policy_table.app_policies[config.application2.registerAppInterfaceParams.appID].groups =
  { "Base-4", "NewTestCaseGroup2" }
end

local function activateSecondApp(self)
  commonSmoke.activateApp(2, self)
  self.mobileSession1:ExpectNotification("OnHMIStatus",
    { hmiLevel = "BACKGROUND", audioStreamingState = "NOT_AUDIBLE", systemContext = "MAIN"})
end

--[[ Scenario ]]
runner.Title("Preconditions")
runner.Step("Clean environment", commonSmoke.preconditions)
runner.Step("Start SDL, HMI, connect Mobile, start Session", commonSmoke.start)
runner.Step("RAI, PTU", commonSmoke.registerApplicationWithPTU, {1, ptuFuncApp1 })
runner.Step("Activate App", commonSmoke.activateApp)
runner.Step("Upload icon file", commonSmoke.putFile, {putFileParams})
runner.Step("Deactivate App to LIMITED", deactivateToLimited)
runner.Step("CreateInteractionChoiceSet with id 100", CreateInteractionChoiceSet, {100})


runner.Title("Test")
runner.Step("PerformInteraction in limited", PI_PerformViaMANUAL_ONLY_1apps, {requestParams})
runner.Step("RAI, PTU App2", commonSmoke.registerApplicationWithPTU, { 2, ptuFuncApp2 })
runner.Step("Activate App2", activateSecondApp)
runner.Step("PerformInteraction in background", PI_PerformViaMANUAL_ONLY_2apps, {requestParams})

runner.Title("Postconditions")
runner.Step("Stop SDL", commonSmoke.postconditions)
