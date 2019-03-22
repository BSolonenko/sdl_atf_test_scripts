---------------------------------------------------------------------------------------------------
-- Proposal:
-- https://github.com/smartdevicelink/sdl_evolution/blob/master/proposals/0207-rpc-message-protection.md
-- Description:
-- Precondition:
-- 1) Update preload_pt.json file and set value for app_policies = true and to the
--    appropriate function_group (Base-4) = false
-- In case:
-- 1) App registered
-- SDL does:
-- 1) send BasicCommunication.OnAppRegistered to HMI
-- 2) HMI send response to SDL
-- SDL does:
-- 1) send response with resultCode = SUCCESS to mobile application
-- 2) send OnPermissionsChange nitification with parameters for app_policies requireEncryption = true,
--    function_group requireEncryption = false
-- In case:
-- 2)RPC service 7 is started in protected mode
-- 2.1) mobile application sends encrypted RPC request (AddCommand) to SDL
-- SDL does:
-- 1) resend this request (AddCommand) RPC to HMI
-- 2) HMI sends (AddCommand) RPC response with resultCode = SUCCESS to SDL
-- SDL does:
-- 1) send encrypted response (AddCommand) to mobile application with result code “Success”
-- 2) send unencrypted notification (OnHashChange)
---------------------------------------------------------------------------------------------------
--[[ Required Shared libraries ]]
local runner = require('user_modules/script_runner')
local common = require('test_scripts/Security/RPCMessageProtection/common')

--[[ Test Configuration ]]
runner.testSettings.isSelfIncluded = false

--[[ Local Variables ]]
local testCases = {
  -- [001] = { a = true, f = false },
  -- [002] = { a = true, f = nil },
  -- [003] = { a = false, f = true },
  -- [004] = { a = false, f = false },
  -- [005] = { a = false, f = nil },
  [006] = { a = nil, f = false },
  -- [007] = { a = nil, f = nil }
}

--[[ Local Function ]]
local function onPermissionsChangeCheck(pApp,pApp, pFuncGroup)
  if pApp == nil then pApp = true end
  if pFuncGroup == nil then pFuncGroup = false end
  common.getMobileSession():ExpectNotification("OnPermissionsChange")
  :ValidIf(function(_,data)
    if data.payload.requireEncryption == pApp and data.payload.permissionItem[1].requireEncryption == pFuncGroup then
    return true
    end
      return false
  end)
end

local function registerApp(appId, pFuncGroup)
  common.registerAppOnPermChange(appId, onPermissionsChangeCheck(pApp, pFuncGroup))
end

local function protectedRpcInProtectedModeEncryptedNotRequired()
	local params = {
    cmdID = 1,
    menuParams = {
      position = 1,
      menuName = "Command_1"
    }
  }
  local cid = common.getMobileSession():SendEncryptedRPC("AddCommand", params)
  common.getHMIConnection():ExpectRequest("UI.AddCommand", params)
  :Do(function(_, data)
    common.getHMIConnection():SendResponse(data.id, data.method, "SUCCESS", { })
    end)
    common.getMobileSession():ExpectEncryptedResponse(cid, { success = true, resultCode = "SUCCESS" })
    common.getMobileSession():ExpectNotification("OnHashChange")
end

--[[ Scenario ]]
for _, tc in common.spairs(testCases) do
  runner.Title("Preconditions")
  runner.Step("Clean environment", common.preconditions)
  runner.Step("Back-up PreloadedPT", common.backupPreloadedPT)
  runner.Step("Preloaded update", common.updatePreloadedPT, { tc.a, tc.f })
  runner.Step("Init SDL certificates", common.initSDLCertificates,
    { "./files/Security/client_credential.pem" })
  runner.Step("Start SDL, init HMI", common.start)
  runner.Step("Register App, requireEncryption for App="..tostring(tc.a).." Gruop="..tostring(tc.f) ..
    "from OnPermissiionChange notification", registerApp, { 1, tc.a, tc.f })
  runner.Step("Activate App", common.activateApp)

  runner.Title("Test")
  runner.Step("Start RPC Service protected", common.startServiceProtected, { 7 })
  runner.Step("Protected RPC in protected mode", protectedRpcInProtectedModeEncryptedNotRequired)

  runner.Title("Postconditions")
  runner.Step("Clean sessions", common.cleanSessions)
  runner.Step("Stop SDL, restore SDL settings", common.postconditions)
  runner.Step("Restore PreloadedPT", common.restorePreloadedPT)
end

