local util = require '@common.base.gui.control_util'
local module_selector = require '@common.base.gui.selector'
local build_selector = module_selector.build_selector
local dumper = require '@common.base.gui.dump'
local set_prop = require '@common.base.gui.binding_prop'.set_prop
local get_value = require '@common.base.gui.binding_prop'.get_value

local map = {}
local unit_
local trigger_


if __lua_state_name == 'StateGame' then
    -- 因为单位可能会变，需要监听单位变更事件

    base.local_player():event('玩家-改变英雄', function(_, player, unit)
        if trigger_ then
            trigger_:remove()
        end
        unit_ = unit
        if not unit then return end
        for key, value in pairs(map) do
            local selectors = value
            if selectors and #selectors > 0 then
                local v = unit_:get(key)
                for i = #selectors, 1, -1 do
                    set_prop(selectors[i], key, v)
                end
            end
        end
        trigger_ = unit:event('单位-属性变化', function(t, u, k, v)
            if u == unit_ then
                local selectors = map[k]
                if not selectors or #selectors == 0 then
                    return
                end
                for i = #selectors, 1, -1 do
                    set_prop(selectors[i], k, v)
                end
                if #selectors == 0 then
                    map[k] = nil
                end
            end
        end)
    end)
end

local function selector_set_when_unit_prop_changed(prop_name, selector, f, index)
    if map[prop_name] == nil then
        map[prop_name] = {}
    end
    map[prop_name][#map[prop_name] + 1] = {selector = selector, format = f, index = index}
end

local function on_unit_prop(unit_prop, f, index)
    unit_prop = unit_prop or ''
    if __lua_state_name == 'StateGame' then
        return {__type = 'need_build_prop', build = function(ctrl, prop_name)
            if type(prop_name) == 'string' then
                prop_name = {prop_name}
            end
            local selector = build_selector(prop_name, ctrl)
            selector_set_when_unit_prop_changed(unit_prop, selector, f, index)
            local v
            if unit_ then
                v = unit_:get(unit_prop)
            end
            v = get_value(unit_prop, v, f, index)
            return selector:set(v)
        end}
    else
        local mt = {}
        mt.__index = mt
        mt.__type = 'unit'
        mt[dumper.DUMP] = function()
            if f == '' then
                f = nil
            end
            local str = 'on_unit_prop(\''..unit_prop.. (f and '\', \'' .. f .. '\'' or '\', nil') .. (index and ', ' .. tostring(index) or ', nil') .. ')'
            return str
        end
        return setmetatable({unit_prop, f, index}, mt)
    end
end

return on_unit_prop
