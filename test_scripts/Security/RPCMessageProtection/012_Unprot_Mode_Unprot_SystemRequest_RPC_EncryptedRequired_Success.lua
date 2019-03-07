---------------------------------------------------------------------------------------------------
-- Proposal:
-- https://github.com/smartdevicelink/sdl_evolution/blob/master/proposals/0207-rpc-message-protection.md
-- Description:
-- Precondition:
-- 1) App registered and activated, OnHMIStatus(FULL)
-- 2) RPC needs protection, encryption_required parameters to App within app_policies = true and to the
--    appropriate function_group (Base-4) = true
-- In case:
-- 1) The mobile application sends unencrypted RPC request (SystemRequest) to SDL
-- SDL does:
-- 1) resend this request (SystemRequest) RPC to HMI
-- 2) HMI sends (SystemRequest) RPC response with resultCode = SUCCESS to SDL
-- SDL does:
-- 1) send unencrypted response (SystemRequest) to mobile application with result code “Success”
-- In case:
-- 2)RPC service 7 is started in protected mode
-- 2.1) mobile application sends unencrypted RPC request (SystemRequest) to SDL
-- SDL does:
-- 1) resend this request (SystemRequest) RPC to HMI
-- 2) HMI sends (SystemRequest) RPC response with resultCode = SUCCESS to SDL
-- SDL does:
-- 1) send unencrypted response (SystemRequest) to mobile application with result code “Success”
---------------------------------------------------------------------------------------------------
--[[ Required Shared libraries ]]
local runner = require('user_modules/script_runner')
local common = require('test_scripts/Security/RPCMessageProtection/common')
local utils = require('user_modules/utils')

--[[ Test Configuration ]]
runner.testSettings.isSelfIncluded = false

--[[ Local Variables ]]
local file = "./files/action.png"
local param = {
  requestType = "PROPRIETARY",
  fileName = "action.png"
}

--[[ Local Functions ]]
local function ptUpdate(pTbl)
  local filePath = "./files/Security/client_credential.pem"
  local crt = utils.readFile(filePath)
  pTbl.policy_table.module_config.certificate = crt
  pTbl.policy_table.app_policies["spt"].encryption_required = true
  pTbl.policy_table.functional_groupings["Base-4"].encryption_required = true
end


local function unprotSystemRequestInUnprotModeEncryptedRequired()
  local cid = common.getMobileSession():SendRPC("SystemRequest", param, file)
  common.getHMIConnection():ExpectRequest("BasicCommunication.SystemRequest")
  :Do(function(_,data)
    common.getHMIConnection():SendResponse(data.id,"BasicCommunication.SystemRequest", "SUCCESS", {})
  end)
  common.getMobileSession():ExpectResponse(cid, { success = true, resultCode = "SUCCESS"})
end

--[[ Scenario ]]
runner.Title("Preconditions")
runner.Step("Clean environment", common.preconditions)
runner.Step("Start SDL, init HMI", common.start)
runner.Step("Register App", common.registerApp)
runner.Step("Policy Table Update", common.policyTableUpdate, { ptUpdate })
runner.Step("Activate App", common.activateApp)
runner.Step("Unprotected System request, unprotected mod, encrypted required",
  unprotSystemRequestInUnprotModeEncryptedRequired)

runner.Title("Test")
runner.Step("Start RPC Service protected", common.startServiceProtected, { 7 })
runner.Step("Unprotected System request, protected mod, encrypted required",
  unprotSystemRequestInUnprotModeEncryptedRequired)

runner.Title("Postconditions")
runner.Step("Clean sessions", common.cleanSessions)
runner.Step("Stop SDL, restore SDL settings", common.postconditions)

