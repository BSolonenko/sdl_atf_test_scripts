---------------------------------------------------------------------------------------------------
-- Common module
---------------------------------------------------------------------------------------------------
--[[ General configuration parameters ]]
config.defaultProtocolVersion = 2

--[[ Required Shared libraries ]]
local actions = require("user_modules/sequences/actions")
local common = require("test_scripts/Security/SSLHandshakeFlow/common")
local utils = require("user_modules/utils")
local commonPreconditions = require('user_modules/shared_testcases/commonPreconditions')
local commonFunctions = require("user_modules/shared_testcases/commonFunctions")
local json = require("modules/json")
local test = require("user_modules/dummy_connecttest")

--[[ General configuration parameters ]]
config.SecurityProtocol = "DTLS"
config.application1.registerAppInterfaceParams.appName = "server"
config.application1.registerAppInterfaceParams.fullAppID = "spt"

--[[ Variables ]]
local m = actions
common.cloneTable = utils.cloneTable
local preloadedPT = commonFunctions:read_parameter_from_smart_device_link_ini("PreloadedPT")

--[[ Common Functions ]]
function m.backupPreloadedPT()
  commonPreconditions:BackupFile(preloadedPT)
end

function m.restorePreloadedPT()
  commonPreconditions:RestoreFile(preloadedPT)
end

function m.registerAppOnPermChange(pAppId, func)
  if not pAppId then pAppId = 1 end
  m.getMobileSession(pAppId):StartService(7)
  :Do(function()
      local corId = m.getMobileSession(pAppId):SendRPC("RegisterAppInterface", m.getConfigAppParams(pAppId))
      m.getHMIConnection():ExpectNotification("BasicCommunication.OnAppRegistered",
        { application = { appName = m.getConfigAppParams(pAppId).appName } })
      :Do(function(_, d1)
          m.setHMIAppId(d1.params.application.appID, pAppId)
        end)
      m.getMobileSession(pAppId):ExpectResponse(corId, { success = true, resultCode = "SUCCESS" })
      :Do(function()
          m.getMobileSession(pAppId):ExpectNotification("OnHMIStatus",
            { hmiLevel = "NONE", audioStreamingState = "NOT_AUDIBLE", systemContext = "MAIN" })
          if func then
            func()
          end
        end)
    end)
end

function m.updatePreloadedPT(pAppPolicy, pFuncGroup)
  local preloadedFile = commonPreconditions:GetPathToSDL() .. preloadedPT
  local pt = utils.jsonFileToTable(preloadedFile)
  pt.policy_table.app_policies["spt"] = utils.cloneTable(pt.policy_table.app_policies.default)
  pt.policy_table.functional_groupings["Base-4"].encryption_required = pFuncGroup
  pt.policy_table.app_policies["spt"].encryption_required = pAppPolicy
  pt.policy_table.functional_groupings["DataConsent-2"].rpcs = json.null
  utils.tableToJsonFile(pt, preloadedFile)
end

function m.startServiceProtected(pServiceId)
  m.getMobileSession():StartSecureService(pServiceId)
  m.getMobileSession():ExpectHandshakeMessage()
  m.getMobileSession():ExpectControlMessage(pServiceId, {
    frameInfo = m.frameInfo.START_SERVICE_ACK,
    encryption = true
  })
end

local preconditionsOrig = m.preconditions
function m.preconditions()
  preconditionsOrig()
  m.initSDLCertificates("./files/Security/client_credential.pem", false)
end

function m.getPutFileAllParams()
  return {
    syncFileName = "icon.png",
    fileType = "GRAPHIC_PNG",
    persistentFile = false,
    systemFile = false,
    offset = 0,
    length = 11600
  }
end

function m.spairs(pTbl)
  local keys = {}
  for k in pairs(pTbl) do
    keys[#keys+1] = k
  end
  local function getStringKey(pKey)
    return tostring(string.format("%03d", pKey))
  end
  table.sort(keys, function(a, b) return getStringKey(a) < getStringKey(b) end)
  local i = 0
  return function()
    i = i + 1
    if keys[i] then
      return keys[i], pTbl[keys[i]]
    end
  end
end

function m.cleanSessions()
  for i = 1, m.getAppsCount() do
    test.mobileSession[i]:StopRPC()
    :Do(function(_, d)
        utils.cprint(35, "Mobile session " .. d.sessionId .. " deleted")
        test.mobileSession[i] = nil
      end)
  end
  utils.wait()
end

return m

