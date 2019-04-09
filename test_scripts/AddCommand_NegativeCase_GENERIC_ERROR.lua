---------------------------------------------------------------------------------------------------
-- Description:
-- Mobile application sends valid AddCommand request with the both "vrCommands"
-- and "menuParams" data and does not get "SUCCESS" for the VR.AddCommand or
-- VR.AddCommand or both responses from HMI

-- Pre-conditions:
-- a. HMI and SDL are started
-- b. appID is registered and activated on SDL
-- c. appID is currently in Background, Full or Limited HMI level

-- Steps:
-- appID requests AddCommand with the both vrCommands and menuParams

-- Expected:
-- 1. SDL validates parameters of the request
-- 2. SDL checks if UI interface is available on HMI
-- 3. SDL checks if VR interface is available on HMI
-- 4. SDL checks if AddCommand is allowed by Policies
-- 5. SDL checks if all parameters are allowed by Policies
-- 6. SDL transfers the UI part of request with allowed parameters to HMI
-- 7. SDL transfers the VR part of request with allowed parameters to HMI
-- 8. SDL does not receives UI or VR or both part of response from HMI with
-- 	  "SUCCESS" result code
-- 9. SDL responds with (resultCode: GENERIC_ERROR, success:false) to mobile
--    application whis info "<interface-name> component does not respond"
---------------------------------------------------------------------------------------------------

--[[ Required Shared libraries ]]
local runner = require('user_modules/script_runner')
local commonSmoke = require('test_scripts/Smoke/commonSmoke')

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

local requestParams = {
	cmdID = 11,
	menuParams = {
		position = 0,
		menuName ="Commandpositive"
	},
	vrCommands = {
		"VRCommandonepositive",
		"VRCommandonepositivedouble"
	},
	grammarID = 1,
	cmdIcon = {
		value ="icon.png",
		imageType ="DYNAMIC"
	}
}

local responseUiParams = {
	appID = commonSmoke.getHMIAppId(),
	cmdID = requestParams.cmdID,
	cmdIcon = {
		value = commonSmoke.getPathToFileInStorage("icon.png"),
		imageType ="DYNAMIC"
	},
	menuParams = requestParams.menuParams
}

local responseVrParams = {
	appID = commonSmoke.getHMIAppId(),
	cmdID = requestParams.cmdID,
	type = "Command",
	vrCommands = requestParams.vrCommands
}

local responseToUi = {
	requestParams = requestParams;
	responseCommand = "UI.AddCommand",
	response = responseUiParams,
	notResponseCommand = "VR.AddCommand",
	notResponse = responseVrParams,
	deleteCommand = "UI.DeleteCommand",
	deleteResponse = {
		cmdID = 11,
		appID = commonSmoke.getHMIAppId()
	},
	info = "VR component does not respond"
}

local responseToVR = {
	requestParams = requestParams;
	responseCommand = "VR.AddCommand",
	response = responseVrParams,
	notResponseCommand = "UI.AddCommand",
	notResponse = responseUiParams,
	deleteCommand = "VR.DeleteCommand",
	deleteResponse = {
		appID = commonSmoke.getHMIAppId(),
		cmdID = requestParams.cmdID,
		type = "Command",
	},
	info = "UI component does not respond"
}

 local allParams = {
	requestParams = requestParams,
	responseUiParams = responseUiParams,
	responseVrParams = responseVrParams
 }

--[[ Local Functions ]]
local function addCommand(params, self)
	local cid = self.mobileSession1:SendRPC("AddCommand", params.requestParams)

	EXPECT_HMICALL(params.responseCommand, params.response)
	:Do(function(_,data)
		self.hmiConnection:SendResponse(data.id, data.method, "SUCCESS", {})
	end)

	EXPECT_HMICALL(params.notResponseCommand, notResponse)

	self.mobileSession1:ExpectResponse(cid, {
		success = false,
		resultCode = "GENERIC_ERROR",
		info = params.info
	})

	EXPECT_HMICALL(params.deleteCommand, params.deleteResponse)
	:Do(function(_,data)
		self.hmiConnection:SendResponse(data.id, data.method, "SUCCESS", {})
	end)
end

local function addComandBothNotResponse(params, self)
	local cid = self.mobileSession1:SendRPC("AddCommand", params.requestParams)
	EXPECT_HMICALL("VR.AddCommand", params.responseVrParams)
	EXPECT_HMICALL("UI.AddCommand", params.responseUiParams)
	self.mobileSession1:ExpectResponse(cid, {
		success = false,
		resultCode = "GENERIC_ERROR",
		info = "UI component does not respond, VR component does not respond"
	})
end

--[[ Scenario ]]
runner.Title("Preconditions")
runner.Step("Clean environment", commonSmoke.preconditions)
runner.Step("Start SDL, HMI, connect Mobile, start Session", commonSmoke.start)
runner.Step("RAI", commonSmoke.registerApp)
runner.Step("Activate App", commonSmoke.activateApp)
runner.Step("Upload icon file", commonSmoke.putFile, {putFileParams})

runner.Title("Test")
runner.Step("Response UI.AddCommad and does not send response VR.AdddCommand",
				addCommand, {responseToUi})
runner.Step("Response VR.AddCommad and does not send response UI.AdddCommand",
				addCommand, {responseToVR})
runner.Step("VR and UI AddCommad does not send response",
				addComandBothNotResponse, {allParams})

runner.Title("Postconditions")
runner.Step("Stop SDL", commonSmoke.postconditions)
