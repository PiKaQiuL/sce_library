local path      = require 'base.path'
local io_write = io.write
local mt = {}

function mt:name()
    return 'MAP_PATH.JSON'
end

function mt:set(map, path)
    self[map] = path
end

function mt:save(root)
    local save_path = root / self:name()
    io_write(tostring(save_path), base.json.encode(self))
end

mt.__index = mt

return setmetatable({}, mt)