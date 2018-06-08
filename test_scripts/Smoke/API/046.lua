local runner = require('user_modules/script_runner')
local commonSmoke = require('test_scripts/Smoke/commonSmoke')
local commonFunctions = require("user_modules/shared_testcases/commonFunctions")
local commonPreconditions = require('user_modules/shared_testcases/commonPreconditions')



local function sendOnDeviceConnectionStatus(self)
    self.hmiConnection:SendNotification("SDL.OnDeviceConnectionStatus",
    {
        device = {
            name = "someName",
            id = "123",
            transportType = "USB_AOA",
            usbTransportStatus = "ENABLED"
        }

    }
)   
end


runner.Title("Preconditions")
runner.Step("Clean environment", commonSmoke.preconditions)
runner.Step("Start SDL, HMI, connect Mobile, start Session", commonSmoke.start)


runner.Step("sendOnDeviceConnectionStatus",sendOnDeviceConnectionStatus)


runner.Title("Postconditions")
runner.Step("Stop SDL", commonSmoke.postconditions)