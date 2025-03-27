local pairs = pairs
local ipairs = ipairs
local rawset = rawset
local type = type
local select = select
local table_unpack = table.unpack
local setmetatable = setmetatable

local compile_mt = {}
setmetatable(compile_mt, compile_mt)
local function compile_impl(exp)
    local str = 'return ' .. exp
    local keys = {}
    function compile_mt:__index(key)
        keys[#keys + 1] = key
        return self
    end
    assert(load(str, str, 't', compile_mt))()
    return keys
end

local compile_cache = {}
local function compile(exp)
    local res = compile_cache[exp]
    if not res then
        res = compile_impl(exp)
        compile_cache[exp] = res
    end
    return { table_unpack(res) }
end

local function copy_array(array, to)
    to = to or {}
    local len = #to
    for i = 1, #array do
        to[len + i], to[-len - i] = array[i], array[-i]
    end
    return to
end

local function watch_key(watching, key, func)
    local callbacks = watching[key]
    if callbacks then
        callbacks[#callbacks + 1] = func
    else
        watching[key] = { func }
    end
end

local function watch_state(keys, api, value)
    for i = 1, #keys - 1 do
        local key = keys[i]
        if not value[key] then
            rawset(api, key, {})
            value[key] = { _array_id = keys[-i - 1] }
        end
        api = api[key]
        value = value[key]
        if value._array_id ~= keys[-i - 1] then
            return
        end
    end
    local key = keys[#keys]
    return key, api, value
end

local function watch_new(key, api, value, func)
    value._watching = {}
    watch_key(value._watching, key, func)

    value.__index = value
    function value:__newindex(k, v)
        local callbacks = value._watching[k]
        if callbacks then
            for i = 1, #callbacks do
                callbacks[i](api, v)
            end
        end
        value[k] = v
    end
    return setmetatable(api, value)
    -- 为自定义控件改的，目的是可以直接这样用
    -- user: 
    --      bind.custom_attr[i][j] = value
    -- developer: 
    --      bind.watch.custom_attr = function(i, j, value)
    --           -- do something
    --      end
    -- 先去掉，暂时用不到
    -- function value:__index(k)
    --     if value[k] ~= nil then return value[k] end
    --     if watching[k] then
    --         local dispatch = function(...)
    --             for _, f in ipairs(watching[k]) do
    --                 f(api, ...)
    --             end
    --         end
    --         return setmetatable({}, {
    --             __newindex = function(t, idx1, v)
    --                 dispatch(idx1, v)
    --             end,
    --             __index = function(t, idx1)
    --                 return setmetatable({}, {
    --                     __newindex = function(t, idx2, v)
    --                         dispatch(idx1, idx2, v)
    --                     end
    --                 })
    --             end
    --         })
    --     end
    -- end
end

local function watch(keys, api, value, func, default)
    local key, api, value = watch_state(keys, api, value)
    if type(value) ~= 'table' then
        return log.error("错误的 bind 类型, key ：" .. base.json.encode(keys) .. "value : " .. tostring(value))
    end

    value[key] = default

    if value._watching then
        return watch_key(value._watching, key, func)
    end
    watch_new(key, api, value, func)
end

local function watch_exp(self, exp, func, default, ...)
    local keys = copy_array(self.array, compile(exp))
    if select('#', ...) == 0 then
        watch(keys, self.api, self.value, func, default)
    else
        local paths = { ... }
        local max = #paths
        for li = 1, max // 2 do
            local ri = max + 1 - li
            paths[li], paths[ri] = paths[ri], paths[li]
        end
        local function proxy(api, v)
            paths[max + 1] = v
            return func(api, table_unpack(paths))
        end
        watch(keys, self.api, self.value, proxy, default)
    end
end

local function watch_table(self, exp, func, default, ...)
    local tp = type(exp)
    if tp == 'string' then
        watch_exp(self, exp, func, default, ...)
    elseif tp == 'table' then
        for k, v in pairs(exp) do
            watch_table(self, v, func, default and default[k], k, ...)
        end
    end
end

local function init_watch(self)
    return setmetatable({}, { __newindex = function(_, key, func)
        local bind = self.current.bind
        local exp = bind and bind[key]
        if exp then
            watch_table(self, exp, func, self.current[key])
        end
    end })
end

local mt = {}
mt.__index = mt

function mt:load(bind)
    self.current = bind
end

function mt:push(id)
    local array = self.array
    array[-#array - 1] = id -- 负index记录array所属的ui
    array[#array + 1] = 0
    local outer = self.outer
    if outer then
        local array = outer.array
        array[-#array - 1] = id
        array[#array + 1] = 0
    end
end

function mt:pop()
    local array = self.array
    array[-#array] = nil
    array[#array] = nil
    local outer = self.outer
    if outer then
        local array = outer.array
        array[-#array] = nil
        array[#array] = nil
    end
end

function mt:index(n)
    local array = self.array
    array[#array] = n
    local outer = self.outer
    if outer then
        local array = outer.array
        array[#array] = n
    end
end

local function compact_recursive(api, value, array, id, n)
    if not value._array_id then
        for k, sub_api in pairs(api) do
            if value[k] and not (value._watching and value._watching[k]) then -- array 本身没有被 watch
                compact_recursive(sub_api, value[k], array, id, n)
            end
        end
        return
    end
    for i = 1, #array do
        local k = array[i]
        local same_array = value._array_id == array[-i] and not (value._watching and value._watching[k])
        api = same_array and api[k]
        value = same_array and value[k]
        if not api or not value then
            return
        end
    end
    if value._array_id ~= id then
        return
    end
    local watching_or_api = value._watching or api -- 有 watch 的是叶数组（最里层的数组）
    for i = #watching_or_api, n + 1, -1 do
        watching_or_api[i], value[i] = nil, nil
    end
end

function mt:compact(id, n)
    return compact_recursive(self.api, self.value, self.array, id, n)
end

function mt:get_state()
    local outer = self.outer
    return copy_array(self.array), outer and copy_array(outer.array)
end

function mt:switch_state(state1, state2)
    self.array, state1 = state1, self.array
    local outer = self.outer
    if outer then
        outer.array, state2 = state2, outer.array
    end
    return state1, state2
end

function base.bind(outer)
    local bind = setmetatable({
        api = {},
        value = {},
        array = {},
        outer = outer,
    }, mt)
    bind.watch = init_watch(bind)
    return bind
end