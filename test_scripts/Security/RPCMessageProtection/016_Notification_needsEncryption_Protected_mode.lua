---------------------------------------------------------------------------------------------------
-- Proposal:
-- https://github.com/smartdevicelink/sdl_evolution/blob/master/proposals/0207-rpc-message-protection.md

-- Description:
-- Check that after the encryption of RPC service 7 is enabled (encryption is available)
-- SDL sends an encrypted notification if the RPC needs protection.

-- Sequence:
-- 1) The HMI sends RPC notification to the SDL
-- a. SDL send encrypted notification to mobile application.
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
  common.getMobileSession():ExpectEncryptedNotification("OnLanguageChange",
    {hmiDisplayLanguage = "EL-GR", language = "EN-US"} )
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
  runner.Step("Register App", common.registerAppWOPTU)
  runner.Step("Activate App", common.activateApp)
  runner.Step("Start RPC Service protected", common.startServiceProtected, { 7 })

  runner.Title("Test")
  runner.Step("OnLanguageChange in protected mode, param for App="..tostring(tc.a)..",for Gruop="..tostring(tc.f),
    sendOnLanguageChange)

  runner.Title("Postconditions")
  runner.Step("Clean sessions", common.cleanSessions)
  runner.Step("Stop SDL, restore SDL settings", common.postconditions)
  runner.Step("Restore PreloadedPT", common.restorePreloadedPT)
end

