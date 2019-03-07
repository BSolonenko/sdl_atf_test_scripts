---------------------------------------------------------------------------------------------------
-- Proposal:
-- https://github.com/smartdevicelink/sdl_evolution/blob/master/proposals/0207-rpc-message-protection.md

-- Description:
-- Check that before the encryption of RPC service 7 is enabled (encryption is not available)
-- SDL does not sends a notification if the notification RPC needs protection.

-- Sequence:
-- 1) The HMI sends RPC notification to the SDL
-- a. SDL does not send notification RPC to mobile application
---------------------------------------------------------------------------------------------------
--[[ Required Shared libraries ]]
local runner = require('user_modules/script_runner')
local common = require('test_scripts/Security/RPCMessageProtection/common')

--[[ Test Configuration ]]
runner.testSettings.isSelfIncluded = false

--[[ Local Variables ]]
local testCases = {
  [001] = { a = true, f = true },
  [002] = { a = nil, f = true }
}

--[[ Local Function ]]
local function sendOnLanguageChange()
  common.getHMIConnection():SendNotification("UI.OnLanguageChange", {language = "EL-GR"} )
  common.getMobileSession():ExpectNotification("OnLanguageChange",
    {hmiDisplayLanguage = "EL-GR", language = "EN-US"} )
  :Times(0)
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
  runner.Step("OnLanguageChange in unprotected mode, param for App="..tostring(tc.a)..",for Gruop="..tostring(tc.f),
    sendOnLanguageChange)

  runner.Title("Postconditions")
  runner.Step("Clean sessions", common.cleanSessions)
  runner.Step("Stop SDL, restore SDL settings", common.postconditions)
  runner.Step("Restore PreloadedPT", common.restorePreloadedPT)
end

