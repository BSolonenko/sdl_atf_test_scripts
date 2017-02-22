-- Requirement summary: 
--[APPLINK-16115][GeneralResultCodes]: INVALID_DATA mandatory parameters not provided

-- Description:
-- In case:
---- the request comes without parameters defined as mandatory in mobile API
-- SDL must:
---- respond with resultCode "INVALID_DATA" and success: "false" value.

-- Preconditions:
-- 1. Connection, session and service #7 are initialized for the application
-- 2. The request "RegisterAppInterface" is intended to be sent from mobile applicaton
-- 3. The request doesn't contain mandatory parameter "hmiDisplayLanguageDesired" defined as
----- mandatory in mobile API for the current request

-- Steps:
-- 1. Mob -> SDL: "RegisterAppInterface" without "hmiDisplayLanguageDesired"

-- Expected result:
-- SDL -> Mob: success = false, resultCode = "INVALID_DATA"
--------------------------------------------------------------------------------------------

require('user_modules/all_common_modules')
local consts = require('user_modules/consts')

--[[ Local Variables ]]
local rai_rpc_args =
{
  syncMsgVersion = 
  { 
    majorVersion = 2,
    minorVersion = 2,
  },
  appName = "Mobile_Applicaton",
  isMediaApplication = true,
  languageDesired = "EN-US",
  appID ="1234567"
}
---------------------------------------------------------------------------------------------

--[[ Preconditions ]]
common_steps:PreconditionSteps("Start_SDL_To_Add_Mobile_Session", 5)
---------------------------------------------------------------------------------------------

--[[ Test ]]
function Test:TestStep_RegisterAppInterface_Mandatory_Missing_hmiDisplayLanguageDesired()
  local cor_id = self.mobileSession:SendRPC("RegisterAppInterface", rai_rpc_args)
  self.mobileSession:ExpectResponse(cor_id, { success = false, resultCode = "INVALID_DATA" })
    :Timeout(consts.sdl_to_mobile_default_timeout)
end
---------------------------------------------------------------------------------------------

--[[ Postconditions ]]
common_steps:StopSDL("Postcondition_StopSDL")
