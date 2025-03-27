local kData = {}
local kType = {}
local kNew = {}
local kOnSet = {}
local kOnGet = {}
local kOnAfterSet = {}
local kByRef = {}

local byRefKey = {
    kType = true,
    -- kData = true,
}

local byRefTypeMt = {
    enum_set_mt = true
}

local function clone(t)
    if type(t) ~= 'table' then
        return t
    end
    local out = {}
    for key, value in pairs(t) do
        if type(value) == 'table' then
            local ty = value[kType]
            local type_mt = ty and getmetatable(ty) or nil
            out[key] = (byRefKey[key] or byRefTypeMt[type_mt] or value[kByRef]) and value or clone(value)
        else
            out[key] = value
        end
    end
    setmetatable(out, getmetatable(t))
    return out
end

local warpped_inst_mt = {
    __index = function(self, k)
        local d, t = self[kData], self[kType]
        local def = t[k]
        if def == nil then
            print('获取未定义的字段')
            return nil
        end
        local is_table = type(def) == 'table'
        if is_table then
            local t = def[kType]
            if t then
                local get = t[kOnGet]
                if type(get) == 'function' then -- 特化了get行为
                    return get(self, k, d[k] or def)
                end
            end
            local data = d[k]
            if data == nil then
                -- data = clone(def)
                -- def.__index = def
                -- data = setmetatable({}, def)
                data = def
                d[k] = data
            end
            return data
        end
        return d[k] or def
    end,
    __newindex = function(self, k, v)
        local d, t = self[kData], self[kType]
        local def = t[k]
        if def == nil then
            print('设置未定义的字段')
            return
        end
        local on_after_set
        if type(def) == 'table' then
            local t = def[kType]
            if t then
                on_after_set = t[kOnAfterSet]
                local set = t[kOnSet]
                if type(set) == 'function' then -- 特化了set行为
                    -- print('修改前')
                    local result = set(self, v, k, d[k] or def)
                    if result and type(on_after_set) == 'function' then
                        -- print('修改后')
                        on_after_set(self, v, k, d[k] or def)
                    end
                    return
                elseif not (v and v[kType] == t) then
                    local new = t[kNew]
                    if new then
                        local new_v = new(t, v)
                        if new_v then
                            v = new_v
                        end
                        if not (v and v[kType] == t) then
                            print('构造失败，保留之前的值')
                            return
                        end
                    else
                        print('没有构造函数，无法从其他类型的值构造出该类型的值')
                        return
                    end
                end
            end
        end
        if d[k] == v then -- 设置的值与原先一致则不会修改
            return
        end
        -- print('修改前')
        d[k] = v -- 转发给 data
        -- print('修改后')
        if type(on_after_set) == 'function' then
            on_after_set(self, v, k, d[k] or def)
        end
    end,
}

local function typed_inst_mt_default_new(self, o)
    if type(o) ~= 'table' then
        return nil
    end
    local data = {}
    for k, v in pairs(o) do
        data[k] = v
        rawset(o, k, nil)
    end
    rawset(o, kData, data)
    rawset(o, kType, self)
    setmetatable(data, getmetatable(o))
    return setmetatable(o, warpped_inst_mt)
end
local typed_inst_mt = {
    __call = typed_inst_mt_default_new,
    [kNew] = typed_inst_mt_default_new
}
typed_inst_mt.__index = typed_inst_mt

-- inst_obj -> warp_mt(shared by all warps)
--          \_ inst_data_obj -> mt...
--          \_ default_data_obj(shared by all inst of this type)
local typed = setmetatable({}, {
    __call = function(self, o)
        return setmetatable(o, typed_inst_mt)
    end
})

local function enum_set_mt_default_new(self, s)
    return self[s]
end
local enum_set_mt = {
    __call = enum_set_mt_default_new,
    [kNew] = enum_set_mt_default_new,
    [kOnGet] = function(inst, k, self)
        return self[kData]
    end,
}
enum_set_mt.__index = enum_set_mt

local enum_set = setmetatable({}, {
    __call = function(self, o)
        for _, value in ipairs(o) do
            o[value] = {[kType] = o, [kData] = value}
        end
        return setmetatable(o, enum_set_mt)
    end
})

-- local function getset_mt_default_new(self, default_value)
--     -- return self[kOnSet](, default_value, )
-- end
-- local getset_mt = {
--     __call = getset_mt_default_new,
--     [kNew] = getset_mt_default_new,
--     --[kOnGet] = o.get, [kOnSet] = o.set
-- }
-- getset_mt.__index = getset_mt

local getset = setmetatable({}, {
    __call = function(self, o)
        return {[kType] = {[kOnGet] = o.get, [kOnSet] = o.set}} --setmetatable(o, getset_mt)
    end
})

return {
    typed = typed,
    enum_set = enum_set,
    getset = getset,
    kType = kType,
    kData = kData,
}
