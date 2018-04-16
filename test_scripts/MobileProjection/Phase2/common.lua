---------------------------------------------------------------------------------------------------
-- Common module
---------------------------------------------------------------------------------------------------
--[[ General configuration parameters ]]
config.defaultProtocolVersion = 2

--[[ Required Shared libraries ]]
local actions = require("user_modules/sequences/actions")
local utils = require("user_modules/utils")
local test = require("user_modules/dummy_connecttest")
local events = require("events")

--[[ Module ]]
local m = actions

m.failedTCs = {}

m.wait = utils.wait

function m.setAppConfig(pAppId, pAppHMIType, pIsMedia)
  m.getConfigAppParams(pAppId).appHMIType = { pAppHMIType }
  m.getConfigAppParams(pAppId).isMediaApplication = pIsMedia
end

function m.registerApp(pAppId)
  if not pAppId then pAppId = 1 end
  m.getMobileSession(pAppId):StartService(7)
  :Do(function()
      local corId = m.getMobileSession(pAppId):SendRPC("RegisterAppInterface", m.getConfigAppParams(pAppId))
      m.getHMIConnection():ExpectNotification("BasicCommunication.OnAppRegistered",
        { application = { appName = m.getConfigAppParams(pAppId).appName } })
      :Do(function(_, d)
          m.setHMIAppId(pAppId, d.params.application.appID)
        end)
      m.getMobileSession(pAppId):ExpectResponse(corId, { success = true, resultCode = "SUCCESS" })
      :Do(function()
          m.getMobileSession(pAppId):ExpectNotification("OnHMIStatus",
            { hmiLevel = "NONE", audioStreamingState = "NOT_AUDIBLE", systemContext = "MAIN" })
        end)
    end)
end

function m.unregisterApp(pAppId)
  if not pAppId then pAppId = 1 end
  local cid = m.getMobileSession(pAppId):SendRPC("UnregisterAppInterface", {})
  m.getMobileSession(pAppId):ExpectResponse(cid, { success = true, resultCode = "SUCCESS" })
  m.getHMIConnection():ExpectNotification("BasicCommunication.OnAppUnregistered", {
    unexpectedDisconnect = false,
    appID = m.getHMIAppId(pAppId)
  })
end

function m.cleanSessions()
  EXPECT_EVENT(events.disconnectedEvent, "Disconnected")
  :Do(function()
      utils.cprint(35, "Mobile disconnected")
    end)
  local function toRun()
    for i = 1, m.getAppsCount() do
      test.mobileSession[i] = nil
      utils.cprint(35, "Mobile session " .. i .. " deleted")
    end
    test.mobileConnection:Close()
  end
  RUN_AFTER(toRun, 1000)
  utils.wait()
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

function m.getTCNum(pTCs, pTC)
  return string.format("%0" .. string.len(tostring(#pTCs)) .. "d", pTC)
end

function m.checkAudioSS(pTC, pEvent, pExpAudioSS, pActAudioSS)
  if pActAudioSS ~= pExpAudioSS then
    if m.failedTCs[pTC] == nil then
      m.failedTCs[pTC] = ""
    else
      m.failedTCs[pTC] = m.failedTCs[pTC] .. "\n\t"
    end
    local msg = pEvent .. ": audioStreamingState: expected " .. pExpAudioSS
      .. ", actual value: " .. tostring(pActAudioSS)
    m.failedTCs[pTC] = m.failedTCs[pTC] .. msg
    return false, msg
  end
  return true
end

function m.checkVideoSS(pTC, pEvent, pExpVideoSS, pActVideoSS)
  if pActVideoSS ~= pExpVideoSS then
    if m.failedTCs[pTC] == nil then
      m.failedTCs[pTC] = ""
    else
      m.failedTCs[pTC] = m.failedTCs[pTC] .. "\n\t"
    end
    local msg = pEvent .. ": videoStreamingState: expected " .. pExpVideoSS
      .. ", actual value: " .. tostring(pActVideoSS)
    m.failedTCs[pTC] = m.failedTCs[pTC] .. msg
    return false, msg
  end
  return true
end

function m.checkHMILevel(pTC, pEvent, pExpHMILvl, pActHMILvl)
  if pActHMILvl ~= pExpHMILvl then
    if m.failedTCs[pTC] == nil then
      m.failedTCs[pTC] = ""
    else
      m.failedTCs[pTC] = m.failedTCs[pTC] .. "\n\t"
    end
    local msg = pEvent .. ": hmiLevel: expected " .. pExpHMILvl .. ", actual value: " .. tostring(pActHMILvl)
    m.failedTCs[pTC] = m.failedTCs[pTC] .. msg
    return false, msg
  end
  return true
end

function m.printFailedTCs()
  for tc, msg in m.spairs(m.failedTCs) do
    utils.cprint(35, string.format("%02d", tc), msg)
  end
end

return m
