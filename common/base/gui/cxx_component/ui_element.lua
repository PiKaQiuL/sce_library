--local table_prototype = require '@common.base.gui.table_prototype'
--local prototype_chain_push_front = table_prototype.prototype_chain_push_front

cxx_GUIControl.__index = cxx_GUIControl

local guid = 0

local NULL_FUNCTION = function()
end

local cxx_instance_mt = {
    __index = function(self, key)
        local lib = self.lib
        local instance = self.ref
        return lib[key] or (lib['get_'..key] or NULL_FUNCTION)(instance[0])
    end,
    __newindex = function(self, key, value)
        local lib = self.lib
        local instance = self.ref
        (lib['set_'..key] or NULL_FUNCTION)(instance[0], value)
    end,
}

local cxx_component_base = {
    __ext = function(self, instance) -- create_wrapper
        return setmetatable({ref = instance, lib = self.lib}, cxx_instance_mt)
    end,
    new = function(self, ...)
        local lib = self.lib
        guid = guid + 1
        local id = guid
        local name = ''
        local type = self.type_name
        local parentId = 'main'
        local instance = {
            [0] = lib.new(id, name, type, parentId),
            lib = lib,
            --prop = self.prop,
            method = self.method,
        }
        instance.ref = instance
        return setmetatable(instance, cxx_instance_mt)
    end,
    __call = function(self, o)
        --o.__type = self.name
        o.__class = self
        return o
    end,
}
cxx_component_base.__index = cxx_component_base

local function cxx_component(name, lib)
    return setmetatable({
        type_name = name,
        name = 'cxx_component::'..name,
        lib = lib,
        cxx = lib,
        prop = {
            __index = function(self, key)
                return (lib['get_'..key] or function() end)(self[0])
            end,
            __newindex = function(self, key, value)
                (lib['set_'..key] or function() end)(self[0], value)
            end,
        },
        method = {
            __index = function(self, key)
                return lib[key]
            end,
        },
        --event = {},
    }, cxx_component_base)
end

return {
    panel = cxx_component('panel', cxx_GUIPanel),
}