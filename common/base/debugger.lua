return function(wait)
    if common.get_platform() ~= "Windows" then return end
    local dbg = require 'debugger'
    dbg:io('listen:0.0.0.0:4278')
    if wait then dbg:wait() end
    dbg:start()
end