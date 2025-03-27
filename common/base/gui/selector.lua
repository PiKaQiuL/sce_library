local control_util = require '@common.base.gui.control_util'
local gui_utils = require '@common.base.gui.gui_utils'
local is_component_ctrl = control_util.is_component_ctrl
local get_child_by = control_util.get_child_by
local get_next_base_component = control_util.get_next_base_component
local get_child_by_name = control_util.get_child_by_name
local is_template = control_util.is_template
local get_final_ext_component = control_util.get_final_ext_component
local expect_ctrl_exists = control_util.expect_ctrl_exists
local set_ctrl_prop = control_util.set_ctrl_prop
local register_as_component_part = control_util.register_as_component_part
local unregister_part = control_util.unregister_part
local is_ctrl_exists = control_util.is_ctrl_exists
local get_ctrl_prop = control_util.get_ctrl_prop
local get_parent = control_util.get_parent
local get_owner_component = control_util.get_owner_component
local move_to_new_parent = control_util.move_to_new_parent
local destroy_ctrl = control_util.destroy_ctrl
local replace_ctrl = control_util.replace_ctrl

local ipairs, table = ipairs, table

-- 选择器，用于定位/指代某个/某些对象

-- prop_name : string|string[] 属性名/表字段链
-- selector_info_str : string 选择器描述字符串
-- selector_info : string[] 初步解析的选择器描述
-- selector : table<ctrl:string, string,> 选择器对象

local function foreach_target_ctrl(selector, fn)
    for _, part in ipairs(selector.parts) do
        for _, ctrl in ipairs(part) do
            if not is_ctrl_exists(ctrl) then
                goto CONTINUE
            end
            if fn(ctrl) then
                return
            end
        ::CONTINUE::
        end
    end
end

local ctrl_list_pool = gui_utils.create_list_pool()
local function collect_ctrl(selector, not_lock)
    local parts = selector.parts
    local ctrl_list = ctrl_list_pool(not_lock)
    local new_len = 0
    for pi = 1, #parts do
        local part = parts[pi]
        for ci = 1, #part do
            local ctrl = part[ci]
            if is_ctrl_exists(ctrl) then
                new_len = new_len + 1
                ctrl_list[new_len] = ctrl
            end
        end
    end
    return ctrl_list:resize(new_len)
end

local function assign_by_selector(selector, value)
    local ctrl_list = selector:collect_ctrl()
    if selector.event then
        local connections = {}
        for _, ctrl in ipairs(ctrl_list) do
            if is_component_ctrl(ctrl) then
                local connection = ctrl:connect(selector.event, value)
                table.insert(connections, connection)
            else
            end
        end
        ctrl_list:release()
        return table.unpack(connections)
    end
    if selector.state then
        for _, ctrl in ipairs(ctrl_list) do
            if is_component_ctrl(ctrl) then
                ctrl.state[selector.state] = value
            end
        end
        ctrl_list:release()
        return
    end
    if #selector == 0 then
        for _, ctrl in ipairs(ctrl_list) do
            replace_ctrl(ctrl, value)
        end
        ctrl_list:release()
        return
    end
    local prop_name = selector
    for _, ctrl in ipairs(ctrl_list) do
        set_ctrl_prop(ctrl, prop_name, value)
    end
    ctrl_list:release()
end

local function get_by_selector(selector)
    local parts = selector.parts
    if parts == nil then
        return nil
    end
    if selector.event then
        local results = {}
        foreach_target_ctrl(selector, function(ctrl)
            table.insert(results, ctrl.connection[selector.event])
        end)
        return table.unpack(results)
    end
    if selector.state then
        local results = {}
        foreach_target_ctrl(selector, function(ctrl)
            table.insert(results, ctrl.state[selector.state])
        end)
        return table.unpack(result)
    end
    local results = selector:collect_ctrl()
    local prop_name = selector
    if #prop_name == 0 then
    else
        for i = 1, #results do
            results[i] = get_ctrl_prop(results[i], prop_name)
        end
    end
    results:release()
    return table.unpack(results) -- 返回所有值
end

local function parse_simple_selector_info(str)
    local out = {}
    for head, name in string.gmatch(str, '([@#:%~]?)([^%.@#:~]*)') do
        if string.len(head) ~= 0 then
            table.insert(out, head)
        end
        table.insert(out, name or "")
    end
    return out
end

-- selector {ctrl = <ctrl>, ctrl_ref = <ref_item>, string...}
local selector_mt = {
    __index = {
        __type = 'selector',
        get = get_by_selector,
        set = assign_by_selector,
        collect_ctrl = collect_ctrl,
    },
}
local function build_selector(selector_info, src_ctrl)
    local selector = setmetatable({
        parts = {{src_ctrl}},
    }, selector_mt)
    local i = 1
    while i <= #selector_info do
        local str = selector_info[i]
        i = i + 1
        if str == '~' then
            str = selector_info[i]
            i = i + 1
            selector.state = str
            goto CONTINUE
        -- if str == '#' then
        --     str = selector_info[i]
        --     i = i + 1
        --     selector.ctrl = base.ui.map[str]
        --     goto CONTINUE
        elseif str == ':' then
            str = selector_info[i]
            i = i + 1
            selector.event = str
            goto CONTINUE
        elseif str == '%' or str == '@' then -- 返回控件的引用
            local id = selector_info[i]
            i = i + 1
            if id == '' then
                goto CONTINUE
            end
            id = str == '%' and tonumber(id) or id
            local parts = selector.parts -- { { ctrl... }... }
            if parts then
                local new_parts = {}
                for i, part in ipairs(parts) do
                    for _, ctrl in ipairs(part) do
                        if not is_component_ctrl(ctrl) then
                            goto CONTINUE2
                        end
                        local new_part = rawget(ctrl, '__part')[id]
                        if new_part then
                            table.insert(new_parts, new_part)
                        end
                    ::CONTINUE2::
                    end
                end
                selector.parts = new_parts
            end
            goto CONTINUE
        end
        -- prop name
        local prop_name = str
        table.insert(selector, prop_name)
    ::CONTINUE::
    end
    return selector
end

return {
    assign_by_selector = assign_by_selector,
    get_by_selector = get_by_selector,

    parse_simple_selector_info = parse_simple_selector_info,
    build_selector = build_selector,
}
