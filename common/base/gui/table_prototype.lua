-- base prototype
local prototype = {}
function prototype:__new(o)
    o = o or {}
    setmetatable(o, self)
    rawset(self, '__index', self)
    return o
end

-- -- 为现有对象设置原型
-- local function set_prototype(o, base)
--     setmetatable(o, {__index = base})
-- end

-- 串联数据定义
local function data_inherit(...)
    local data_definitions = {...}
    return function(m)
        local final_data = m
        for _, def in ipairs(data_definitions) do
            final_data = def(final_data) or final_data
        end
        return final_data
    end
end

local function make_class(data_def_fn, proto)
    return function()
        return proto:new(data_def_fn{})
    end
end

-- 在obj的原型链头部插入新对象作为原型
local function prototype_chain_push_front(obj, base)
    if rawget(base, '__index') ~= nil or getmetatable(base) ~= nil then
        error('基类对象已有__index或已有元表')
        return nil
    end
    local proto = getmetatable(obj)
    if proto and rawget(proto, '__index') ~= proto then
        error('对象原来的元表不是原型对象')
        return nil
    end
    rawset(base, '__index', base)
    setmetatable(base, proto)
    return setmetatable(obj, base)
end

return {
    prototype = prototype,
    data_inherit = data_inherit,
    make_class = make_class,
    prototype_chain_push_front = prototype_chain_push_front,
}