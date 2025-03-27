Target = base.tsc.__TS__Class()
Target.name = 'Target'

base.table_unpack = require 'base.table_writer'
local io_open = io.open
local string_gsub = string.gsub
local string_match = string.match

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

---string.format wrap function
---@param context string
---@return string
function base.format_string(context, ...)
    local args = {...}
    local function exception_handler(e)
        log.error("格式化字符串失败！\n" .. e)
        return context
    end

    local _, result = xpcall(function()
        return string.format(context, table.unpack(args))
    end, exception_handler)
    return result
end

---old string.format wrap function
---@param context string
---@return string
function base.string_format(context, params)
    local function exception_handler(e)
        log.error("格式化字符串失败！\n" .. e)
        return context
    end

    local _, result = xpcall(function()
        return string.format(context, table.unpack(params))
    end, exception_handler)
    return result
end

-- 定义一个函数来比较字符串
function base.compare_string(str1, str2)
    if str1 > str2 then
        return 1	
    elseif str1 < str2 then
        return -1
    else
        return 0
    end
end

function base.concat_string(str1, ...)
    local args = {...}
    return table.concat({ str1, table.unpack(args) })
end

---@param str string
---@param start number
---@param ending number
function base.string_substring(str, start, ending)
    return base.utf8_sub(str, start, ending)
end

function base.string_to_upper(str)
    return str and string.upper(str)
end

function base.string_to_lower(str)
    return str and string.lower(str)
end

function base.string_starts_with(str, searchString)
    return string.sub(str, 1, #searchString) == searchString
end

function base.string_ends_with(str, searchString)
    return string.sub(str, #str - #searchString + 1, #str) == searchString
end

---@param str1 string
---@param str2 string
function base.string_equals(str1, str2)
    return str1 == str2
end

---@param str string
function base.string_is_null_or_empty(str)
    return str == nil or str == ''
end

---@param str string
---@param search_string string
function base.string_includes(str, search_string)
    local index = string.find(str, search_string, 1, true)
    return index ~= nil
end

function base.string_include_count(str, search_string)
    local index = 1
    local count = 0
    while true do
        local start, ending = string.find(str, search_string, index, true)
        if start == nil then break end
        count = count + 1
        index = ending + 1
    end
    return count
end

function base.string_trim(str)
    local result = string.gsub(str, "^[%s ﻿]*(.-)[%s ﻿]*$", "%1")
    return result
end

function base.string_trim_end(str)
    local result = string.gsub(str, "[%s ﻿]*$", "")
    return result
end

function base.string_trim_start(str)
    local result = string.gsub(str, "^[%s ﻿]*", "")
    return result
end

function base.string_length(str)
    return utf8.len(str)
end

function base.string_split(str, separator)
    local limit = 2^16-1
    local result = {}
    local resultIndex = 1
    if separator == nil or separator == "" then
        for i = 1, #str do
            result[resultIndex] = string.sub(str, i, i)
            resultIndex = resultIndex + 1
        end
    else
        local currentPos = 1
        while resultIndex <= limit do
            local startPos, endPos = string.find(str, separator, currentPos, true)
            if not startPos then
                break
            end
            result[resultIndex] = string.sub(str, currentPos, startPos - 1)
            resultIndex = resultIndex + 1
            currentPos = endPos + 1
        end
        if resultIndex <= limit then
            result[resultIndex] = string.sub(str, currentPos)
        end
    end
    return result
end

function base.string_replace(str, search_value, replace_value)
    local result, _ = string.gsub(str, search_value, replace_value)
    return result
end

function base.string_pad_start(str, max_length, fill_string)
    if fill_string == nil then
        fill_string = " "
    end
    if max_length ~= max_length then
        max_length = 0
    end
    if max_length == -math.huge or max_length == math.huge then
        log.error("Invalid string length", 0)
    end
    if utf8.len(str) >= max_length or #fill_string == 0 then
        return str
    end
    max_length = max_length - utf8.len(str)
    if max_length > utf8.len(fill_string) then
        fill_string = fill_string .. string.rep(fill_string, math.floor(max_length / utf8.len(fill_string)))
    end
    return base.string_substring(fill_string, 1, math.floor(max_length)) .. str
end

function base.string_pad_end(str, max_length, fill_string)
    if fill_string == nil then
        fill_string = " "
    end
    if max_length ~= max_length then
        max_length = 0
    end
    if max_length == -math.huge or max_length == math.huge then
        log.error("Invalid string length", 0)
    end
    if utf8.len(str) >= max_length or utf8.len(fill_string) == 0 then
        return str
    end
    max_length = max_length - utf8.len(str)
    if max_length > utf8.len(fill_string) then
        fill_string = fill_string .. string.rep(fill_string, math.floor(max_length / utf8.len(fill_string)))
    end
    return str..base.string_substring(fill_string, 1, math.floor(max_length))
end

function base.string_repeat(str, times)
    return string.rep(str, times)
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

local argv = require 'base.argv'
require 'base.ip'

local _G_IP = _G.IP

local http_address = argv.get('http')
if http_address == '' or http_address == nil then
    http_address = _G_IP
end

log.info(("2 http_base_address: %s"):format(http_address))

local need_use_new_domain_mapping = {
    ['e.master.sce.xd.com'] = 1,
    ['editor-master.sce.xd.com'] = 1,
    ['entrance-new-master.spark.xd.com'] = 1,
    ['e.production.spark.xd.com'] = 1,
    ['entrance-new-pd.spark.xd.com'] = 1,
    ['editor-pd.spark.xd.com'] = 1,
}

base.need_use_new_domain = need_use_new_domain_mapping[_G_IP]
if base.need_use_new_domain then
    base.new_base_domain = 'tapsce.cn'
    if argv.get('wx_lobby') == 'app_xianxia' then
        base.new_base_domain = 'fjrll.com'
    end
end

function base.calc_server_address(server_name, default_port)
    local IP = http_address

    if IP:find('[a-zA-Z]') ~= nil then
        if IP:match('^editor%-[^.]+%.spark%.xd%.com$') then --对于编辑器的字符串特殊处理一下 把editor- 替换成 editor.
            IP = string_gsub(IP, "editor%-", "editor.", 1)
        end

        local address = IP:gsub('^[^.]+[.](.*)$', server_name .. '-%1'):gsub('sce%.xd%.com', 'spark.xd.com')
        address = address:gsub('production', 'pd')

        if base.new_base_domain then
            address = address:gsub('spark%.xd%.com', base.new_base_domain)
        end

        return address, 'matched'
    end

    if type(default_port) == 'number' then
        return IP .. ':' .. default_port
    else
        return IP
    end
end

local base_calc_server_address = base.calc_server_address

function base.calc_http_server_address(server_name, default_port)
    local function schema(ssl)
        return ssl and 'https://' or 'http://'
    end

    local address, matched = base_calc_server_address(server_name, default_port)
    if matched then
        return schema(true)..address
    else
        return schema(false)..address
    end
end

function base.get_http_env()
    local IP = http_address
    local env = string_match(IP, "[.-]([^.-]+)%.")
    env = env:gsub('production', 'pd')
    return env
end

return {
    Target = Target,
}