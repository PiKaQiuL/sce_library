local module_selector = require '@common.base.gui.selector'
local assign_by_selector = module_selector.assign_by_selector
local build_selector = module_selector.build_selector
local table_util = require '@common.base.gui.table_util'
local get_prop = table_util.get_prop
local control_util = require '@common.base.gui.control_util'
local is_component_ctrl = control_util.is_component_ctrl

local type, rawget, ipairs = type, rawget, ipairs

local function dispatch_bindness(ctrl, prop_name, v)
    if ctrl == nil then
        return
    end
    local bibinds = rawget(ctrl, '__bibind')
    if bibinds == nil then
        return
    end
    if type(prop_name) ~= 'table' then
        prop_name = {prop_name}
    end
    for _, key in ipairs(prop_name) do
        bibinds = rawget(bibinds, key)
        if bibinds == nil then
            return
        end
    end
    for _, bibind_prop in ipairs(bibinds) do
        assign_by_selector(bibind_prop, v)
    end
end

local function register_bind(ctrl, prop_name, selector) -- 属性名可以是数组，表示该属性是表属性的子字段
    if type(prop_name) ~= 'table' then
        prop_name = {prop_name}
    end

    if is_component_ctrl(ctrl) then
        local defined = get_prop(ctrl.class.prop, prop_name)
        if defined == nil then
            return register_bind(ctrl.base, prop_name, selector)
        end
    end

    local ctrl_bibinds = rawget(ctrl, '__bibind') -- 如果找不到prop定义，则转发到base
    if ctrl_bibinds == nil then
        ctrl_bibinds = {}
        rawset(ctrl, '__bibind', ctrl_bibinds)
    end

    for _, key in ipairs(prop_name) do
        local bibinds = ctrl_bibinds[key]
        if bibinds == nil then
            bibinds = {}
            ctrl_bibinds[key] = bibinds
        end
        ctrl_bibinds = bibinds
    end
    table.insert(ctrl_bibinds, selector)
    return ctrl -- 返回最终注册的控件
end

local function register_bibind(src_ctrl, prop_name, target_selector) -- 属性名可以是数组，表示该属性是表属性的子字段
    if type(prop_name) ~= 'table' then
        prop_name = {prop_name}
    end

    local real_ctrl = register_bind(src_ctrl, prop_name, target_selector)

    local src_selector = build_selector(prop_name, real_ctrl)
    local ctrl_list = src_selector:collect_ctrl()
    for _, ctrl in ipairs(ctrl_list) do
        register_bind(ctrl, target_selector, src_selector)
    end
    ctrl_list:release()
    return real_ctrl
end

return {
    dispatch_bibind = dispatch_bindness,
    register_bibind = register_bibind,
    register_bind = register_bind,
}