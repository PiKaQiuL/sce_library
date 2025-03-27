-- 存储跨虚拟机的变量 不能存函数
local json = require 'json'


local function set_store_value(name, value)
    local tb = {}
    tb[name] = value
    local str = json.encode(tb)
    if type(name) == "string" and type(str) == "string" then
        common.set_value(name, str)
    end
end

local function remove_store_value(name)
    if type(name) ~= "string" then
        return
    end
    common.set_value(name, '')
end

local function get_store_value(name)
    if type(name) ~= "string" then
        return ''
    end
    local str = common.get_value(name)
    if not str or str == '' then
        return ''
    end
    local tb = json.decode(str);
    return tb[name]
end

local function get_store_bool(name)
    local value = get_store_value(name)
    if type(value) == "boolean" then
        return value
    end
    return false
end

local function get_store_string(name)
    local value = get_store_value(name)
    if type(value) == "string" then
        return value
    end
    return false
end

local function get_store_number(name)
    local value = get_store_value(name)
    if type(value) == "number" then
        return value
    end
    return 0
end

local function get_store_table(name)
    local value = get_store_value(name)
    if type(value) == "table" then
        return value
    end
    return {}
end

return {
    set_store_value = set_store_value,
    get_store_value = get_store_value,
    get_store_bool = get_store_bool,
    get_store_string = get_store_string,
    get_store_number = get_store_number,
    get_store_table = get_store_table,
    remove_store_value = remove_store_value
}
