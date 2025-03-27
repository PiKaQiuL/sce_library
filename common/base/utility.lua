local utility= require '@base.base.utility'
Target=utility.Target;

function base.hash(str)
    -- djb33
    local hash = 5381
    for i = 1, #str do
        hash = (hash << 5) + hash + str:byte(i)
        hash = hash & 0xFFFFFFFF
    end
    return hash
end

function base.get_appendable_enum(key)
    local data_table = require('@'..__MAIN_MAP__..'.obj.constant')
    local Map = {}
    for index, value in ipairs(data_table.AppendableEnum[key]) do
        Map[value.Value] = index
    end
    return Map
end

function base.get_appendable_keys(key)
    local data_table = require('@'..__MAIN_MAP__..'.obj.constant')
    local Map = {}
    for index, value in ipairs(data_table.AppendableKeys[key]) do
        Map[value.Value] = index
    end
    return Map
end

return utility -- 以下代码迁移到client_base到base里修改这些
--[[
Target = base.tsc.__TS__Class()
Target.name = 'Target'

base.table_unpack = require 'base.table_writer'
local io_open = io.open

function io.load(filename, mode)
    do
        error 'io.load已被禁止使用'
    end
    local f, e = io_open(filename, mode or 'rb')
    if not f then
        return nil, e
    end
    local buf = f:read 'a'
    f:close()
    return buf
end

function base.split(str, p)
    local rt = {}
    string.gsub(str, '[^' .. p .. ']+', function (w) table.insert(rt, w) end)
    return rt
end

---comment
---@param context string
---@param params string[]
---@return string
function base.string_format(context, params)
    return string.format(context, table.unpack(params))
end

function base.utf8_sub(s, i, j)
    local codes = { utf8.codepoint(s, 1, -1) }
    local len = #codes
    if i < 0 then
        i = len + 1 +i
    end
    if i < 1 then
        i = 1
    end
    if j < 0 then
        j = len + 1 + j
    end
    if j > len then
        j = len
    end
    if i > j then
        return ''
    end
    return utf8.char(table.unpack(codes, i, j))
end

function base.to_type(value, expect_type)
    if expect_type == 'float' then
        if type(value) == 'number' then
            return value
        else
            return 0.0
        end
    elseif expect_type == 'int' then
        if math.type(value) == 'integer' then
            return value
        else
            return 0
        end
    elseif expect_type == 'bool' then
        if type(value) == 'boolean' then
            return value
        else
            return false
        end
    elseif expect_type == 'string' then
        if type(value) == 'string' then
            return value
        else
            return ''
        end
    elseif expect_type == 'handle' then
        if type(value) == 'table' or type(value) == 'userdata' then
            return value
        else
            return nil
        end
    end
end

local name_map
function base.get_unit_name(type_id)
    if not name_map then
        name_map = {}
        for name, data in pairs(base.table.unit) do
            if not data.UnitTypeID then
                log.alert('没找到 type id', name)
            end
            name_map[data.UnitTypeID] = name
        end
    end
    return name_map[type_id]
end

function base.image_path(path)
    if not path then
        return ''
    end
    local dir, rest = path:match('^(.+)%.(.+)')
    if dir == 'SpellIcon' then
        return ('image/%s/%s.png'):format(dir, path)
    else
        return ('image/%s/%s.png'):format(dir, rest)
    end
    return ('image/%s.png'):format(path)
end

function base.load_string(str, skill)
    local unit = skill:get_owner()
    local unit_attr = setmetatable({}, {__index = function (_, k)
        return unit:get(k)
    end})
    return base.game.lni:format(str, unit_attr, skill)
end

function base.get_x(obj)
    local x, y = obj:get_xy()
    return x
end

function base.get_y(obj)
    local x, y = obj:get_xy()
    return y
end

function base.remove(obj)
    if obj then
        obj:remove()
    end
end

function base.default(v, default)
    if v == nil then
        return default
    end
    return v
end

local gc_mt = {}
gc_mt.__mode = 'k'
gc_mt.__index = gc_mt
function gc_mt:__shl(obj)
    if obj == nil then
        return nil
    end
    self[obj] = true
    return obj
end
function gc_mt:flush()
    for obj in pairs(self) do
        obj:remove()
    end
end
function base.gc()
    return setmetatable({}, gc_mt)
end

function base.calc_http_server_address(server_name, default_port)
    local IP = _G.IP
    if IP:find('[a-zA-Z]') ~= nil then
        local address = IP:gsub('^[^.]+[.](.*)$', server_name..'-%1'):gsub('sce%.xd%.com', 'spark.xd.com')
        address = address:gsub('production', 'pd')
        return 'https://'..address
    end

    return 'http:'..IP..default_port
end

return {
    Target = Target,
}]]