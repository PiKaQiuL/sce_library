
local function get(arg)
    return common.get_argv(arg)
end

local function get_bool(arg)
    local v = get(arg)
    return v == 'true' or v == '1'
end

local function has(arg)
    return common.has_arg(arg)
end

local function add(arg, value)
    return common.add_argv(arg, value)
end

return {
    get = get,
    get_bool = get_bool,
    has = has,
    add = add,
}