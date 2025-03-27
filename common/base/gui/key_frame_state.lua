local module_selector = require '@common.base.gui.selector'
local assign_by_selector = module_selector.assign_by_selector
local build_selector = module_selector.build_selector
local get_by_selector = module_selector.get_by_selector
local parse_simple_selector_info = module_selector.parse_simple_selector_info
local control_util = require '@common.base.gui.control_util'
local call_after_created = control_util.call_after_created
local is_component_ctrl = control_util.is_component_ctrl
local anim = require '@common.base.anim'

local key_frame_targets

local function key_frame_state_entry_action(self, src_state_value, target_state_value)
end

local function key_frame_state_info_(o)
    local data = {}
    for key, value in pairs(o) do
        local len = #value
        if len ~= #key_frame_targets then
            -- error count not match
        end
        data[key] = value
        o[key] = function(self, src_state_value, target_state_value) -- key_frame_state_entry_action
            local d = o.__data[target_state_value]

            for i, target in ipairs(o.__targets) do
                if target.__type ~= 'selector' then
                    target = build_selector(target, self)
                end

                local target_value = d[i]
                if type(target_value) == 'table' and
                    target_value['__type'] == 'transition' and
                    target_value['time'] > 0 then
                    local value = get_by_selector(target)

                    local ctrl_list = target:collect_ctrl()
                    for _, ctrl in ipairs(ctrl_list) do
                        if is_component_ctrl(ctrl) then
                            ctrl = ctrl.ui
                        end
                        -- [todo] 如果在实际创建前就销毁了，那注册的任务要清除？
                        call_after_created(ctrl, function(ctrl)
                            -- <ctrl-id>.<prop>, {mode = 'once', method='', {},{}}, callback
                            local prop_name_str = table.concat(target, '.')
                            local anim_id = ctrl.id..'.'..prop_name_str
                            anim.set(anim_id, {
                                mode = 'once',
                                method = 'linear',
                                {time = 0, value = value},
                                {time = target_value['time'], value = target_value[1]},
                            }, function(v)
                                assign_by_selector(target, v)
                            end)
                        end)
                    end
                    ctrl_list:release()
                else
                    assign_by_selector(target, target_value)
                end

            end
        end
    end
    o.__targets = key_frame_targets
    o.__data = data
    key_frame_targets = nil
    return setmetatable(o, {__call = function(self, default_value)
        o.__default = default_value
        return o
    end})
end

local function key_frame_state_info(o)
    key_frame_targets = {}
    for _, simple_selector_info_str in ipairs(o) do
        local simple_selector_info = parse_simple_selector_info(simple_selector_info_str)
        table.insert(key_frame_targets, simple_selector_info)
    end
    return key_frame_state_info_
end

local function anim_trans(o)
    o.__type = 'transition'
    if #o > 1 then
        local array = {}
        for i, value in ipairs(o) do
            array[i] = value
            o[i] = nil
        end
        if o.time == nil then
            o.time = 500
        end
        for i, value in ipairs(array) do
            local cloned = base.ui.deep_copy(o)
            cloned[1] = value
            array[i] = cloned
        end
        return table.unpack(array)
    end
    return o
end

return {
    key_frame_state_info = key_frame_state_info,
    anim_trans = anim_trans,
}