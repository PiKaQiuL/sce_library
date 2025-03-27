local util = require '@common.base.gui.control_util'
local module_selector = require '@common.base.gui.selector'
local build_selector = module_selector.build_selector
local dumper = require '@common.base.gui.dump'
local set_prop = require '@common.base.gui.binding_prop'.set_prop
local get_value = require '@common.base.gui.binding_prop'.get_value

local map = {}
local function selector_set_when_player_prop_changed(prop_name, selector, format, index)
    if next(map) == nil then
        base.local_player():event('玩家-属性变化', function(t,p,k,v)

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
            if next(map) == nil then
                t:remove()
            end
        end)
    end
    if map[prop_name] == nil then
        map[prop_name] = {}
    end
    map[prop_name][#map[prop_name] + 1] = {selector = selector, format = format, index = index}
end

local function on_player_prop(player_prop, f, index)
    player_prop = player_prop or ''
    if __lua_state_name == 'StateGame' then
        return {__type = 'need_build_prop', build = function(ctrl, prop_name)
            if type(prop_name) == 'string' then
                prop_name = {prop_name}
            end
            local selector = build_selector(prop_name, ctrl)
            selector_set_when_player_prop_changed(player_prop, selector, f, index)
            local p = base.local_player()
            local v = p:get(player_prop)
            v = get_value(player_prop, v, f, index)
            return selector:set(v)
        end}
    else
        local mt = {}
        mt.__index = mt
        mt.__type = 'player'
        mt[dumper.DUMP] = function()
            if f == '' then
                f = nil
            end
            local str = 'on_player_prop(\''..player_prop.. (f and '\', \'' .. f .. '\'' or '\', nil') .. (index and ', ' .. tostring(index) or ', nil') .. ')'
            return str
        end
        return setmetatable({player_prop, f, index}, mt)
    end
end

return on_player_prop
