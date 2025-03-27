local platform = require 'base.platform'
local util = require 'base.util'
local path_parent = util.path_parent

---@class path
local mt = {}

local function path(str)
    if type(str) == 'table' then
        if str.__is_path then
            return str
        end
    end
    return setmetatable({str = tostring(str),__is_path = true}, mt)
end

mt.__div = function(a, b)
    if type(b) == 'string' then 
        if b == '' then 
            return path(a.str)
        else
            if a.str:sub(a.str:len()) == '/' then
                return path(a.str .. b)
            else
                return path(a.str .. '/' .. b)
            end
        end
    end
    if b == nil then
        log.error('path1 / path2, but path2 is nil')
    end
    return a / b.str
end

mt.__tostring = function(self)
    return self.str
end

function mt:is_absolute()
    if #self.str <= 0 then
        return false
    end

    if platform.is_win() then
        if self.str:find('^%a[%d%a]*:[/\\]') then
            return true
        end
    else  -- posix
        if self.str[1] == '/' then
            return true
        end
    end

    return false
end

function mt:parent()
    return path(path_parent(self.str))
end

mt.__index = mt

return path