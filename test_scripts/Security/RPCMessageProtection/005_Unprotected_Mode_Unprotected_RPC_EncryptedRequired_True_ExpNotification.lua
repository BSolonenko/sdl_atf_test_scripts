---------------------------------------------------------------------------------------------------
-- Proposal:
-- https://github.com/smartdevicelink/sdl_evolution/blob/master/proposals/0207-rpc-message-protection.md
-- Description:
-- Precondition:
-- 1) App registered and activated, OnHMIStatus(FULL)
-- 2) RPC needs protection, encryption_required parameters to App within app_policies = true or (nil) and to the
--    appropriate function_group (Base-4) = true
-- In case:
-- 1) The mobile application sends unencrypted RPC request (AddCommand) to SDL
-- SDL does:
-- 1) send respose  (success = false, resultCode = "ENCRYPTION_NEEDED") to App
---------------------------------------------------------------------------------------------------
--[[ Required Shared libraries ]]
local runner = require('user_modules/script_runner')
local common = require('test_scripts/Security/RPCMessageProtection/common')

--[[ Test Configuration ]]
runner.testSettings.isSelfIncluded = false

--[[Local Variables]]
local testCases = {
  [001] = { a = true, f = true },
  [002] = { a = nil, f = true }
}

--[[Local Function]]
local function unprotectedRpcInUnprotectedModeEncryptedRequired()
	local params = {
    cmdID = 1,
    menuParams = {
      position = 1,
      menuName = "Command_1"
    }
  }
  local cid = common.getMobileSession():SendRPC("AddCommand", params)
  common.getMobileSession():ExpectResponse(cid, { success = false, resultCode = "ENCRYPTION_NEEDED" })
end

--[[ Scenario ]]
for _, tc in common.spairs(testCases) do
  runner.Title("Preconditions")
  runner.Step("Clean environment", common.preconditions)
  runner.Step("Back-up PreloadedPT", common.backupPreloadedPT)
  runner.Step("Preloaded update", common.updatePreloadedPT, { tc.a, tc.f })
  runner.Step("Start SDL, init HMI", common.start)
  runner.Step("Register App", common.registerAppWOPTU)
  runner.Step("Activate App", common.activateApp)

  runner.Title("Test")
  runner.Step("Unprotected RPC in protected mode, param for App="..tostring(tc.a)..",for Gruop="..tostring(tc.f),
    unprotectedRpcInUnprotectedModeEncryptedRequired)

  runner.Title("Postconditions")
  runner.Step("Clean sessions", common.cleanSessions)
  runner.Step("Stop SDL, restore SDL settings", common.postconditions)
  runner.Step("Restore PreloadedPT", common.restorePreloadedPT)
end

