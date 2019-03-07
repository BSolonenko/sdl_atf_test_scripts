---------------------------------------------------------------------------------------------------
-- Proposal:
-- https://github.com/smartdevicelink/sdl_evolution/blob/master/proposals/0207-rpc-message-protection.md
-- Description:
-- Precondition:
-- 1) App registered and activated, OnHMIStatus(FULL)
-- 2) RPC service 7 is started in protected mode
-- 3) RPC needs protection, encryption_required parameters to App within app_policies = true and to the
--    appropriate function_group (Base-4) = false
-- In case:
-- 1) The mobile application sends unencrypted RPC request (AddCommand) to SDL
-- SDL does:
-- 1) resend this request (AddCommand) RPC to HMI
-- 2) HMI sends (AddCommand) RPC response with resultCode = SUCCESS to SDL
-- SDL does:
-- 1) send unencrypted response (AddCommand) to mobile application with result code “Success”
-- 2) send unencrypted notification (OnHashChange)
-- In case:
-- 2) During PTU updating parameters app_policies = false, function_group (Base-4) = true
-- 2.1) RPC service 7 is started in protected mode
-- 2.2) mobile application sends encrypted RPC request (AddCommand) to SDL
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
local utils = require('user_modules/utils')

--[[ Test Configuration ]]
runner.testSettings.isSelfIncluded = false

--[[ Local Functions ]]
local function ptUpdate(pTbl)
  local filePath = "./files/Security/client_credential.pem"
  local crt = utils.readFile(filePath)
  pTbl.policy_table.module_config.certificate = crt
  pTbl.policy_table.app_policies["spt"].encryption_required = true
  pTbl.policy_table.functional_groupings["Base-4"].encryption_required = false
end

local function ptUpdateNewParam(pTbl)
  pTbl.policy_table.app_policies["spt"].encryption_required = false
  pTbl.policy_table.functional_groupings["Base-4"].encryption_required = true
end

local function unprotectedRpcInUnprotectedModeEncryptedNotRequired()
	local params = {
    cmdID = 1,
    menuParams = {
      position = 1,
      menuName = "Command_1"
    }
  }
  local cid = common.getMobileSession():SendRPC("AddCommand", params)
  common.getHMIConnection():ExpectRequest("UI.AddCommand", params)
  :Do(function(_, data)
    common.getHMIConnection():SendResponse(data.id, data.method, "SUCCESS", { })
  end)
  common.getMobileSession():ExpectResponse(cid, { success = true, resultCode = "SUCCESS" })
  common.getMobileSession():ExpectNotification("OnHashChange")
end

local function protectedRpcInProtectedModeEncryptedRequired()
	local params = {
    cmdID = 2,
    menuParams = {
      position = 2,
      menuName = "Command_2"
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
runner.Title("Preconditions")
runner.Step("Clean environment", common.preconditions)
runner.Step("Start SDL, init HMI", common.start)
runner.Step("Register App", common.registerApp)
runner.Step("Policy Table Update", common.policyTableUpdate, { ptUpdate })
runner.Step("Activate App", common.activateApp)
runner.Step("Unprotected RPC in unprotected mode", unprotectedRpcInUnprotectedModeEncryptedNotRequired)
runner.Step("Register App_2", common.registerApp, { 2 })
runner.Step("Policy Table Update", common.policyTableUpdate, { ptUpdateNewParam })

runner.Title("Test")
runner.Step("Start RPC Service protected", common.startServiceProtected, { 7 })
runner.Step("Protected RPC in protected mode", protectedRpcInProtectedModeEncryptedRequired)

runner.Title("Postconditions")
runner.Step("Clean sessions", common.cleanSessions)
runner.Step("Stop SDL, restore SDL settings", common.postconditions)
runner.Step("Restore PreloadedPT", common.restorePreloadedPT)

