-- ui_ctrl 内置控件
-- component_ctrl 组件控件
-- ctrl : ui_ctrl|component_ctrl 控件（内置控件或组件控件）
-- ui_ctrl_with_component_chain 被组件化包装的内置控件（是某个组件的根控件）
-- template 模板(包括特化的) (<template> { ... } 表示特化的模板，{}内为对模板的特化指定)
-- ui_template 内置控件的模板
-- component_class 组件类，可作为非特化模板
-- component_template 组件模板
local table_util = require '@common.base.gui.table_util'
local get_prop = table_util.get_prop

local type, pairs, ipairs, rawget, getmetatable = type, pairs, ipairs, rawget, getmetatable

local module
---- template utils
local function is_component_class(obj)
    return obj and rawget(obj, '__is_component_class')
end

local function is_template(obj)
    return obj and rawget(obj, '__ui_type') ~= nil and not is_component_class(obj)
end

local function is_component_template(obj)
    return is_template(obj) and is_component_class(rawget(obj, '__class'))
end

---- ui_ctrl utils

-- local function get_component_chain(ui_ctrl)
--     return rawget(ui_ctrl, '__component_chain')
-- end

local function is_cpp_ctrl_created(ui_ctrl)
    return base.ui.map[ui_ctrl.id] ~= nil
end

local function call_after_created(ui_ctrl, task)
    if is_cpp_ctrl_created(ui_ctrl) then
        -- already created
        task(ui_ctrl)
        return
    end
    local on_created = rawget(ui_ctrl, '__on_created')
    if on_created == nil then
        on_created = {}
        rawset(ui_ctrl, '__on_created', on_created)
    end
    table.insert(on_created, task)
end

local function emit_on_created(ui_ctrl)
    local on_created = rawget(ui_ctrl, '__on_created')
    if on_created then
        for _, handler in ipairs(on_created) do
            handler(ui_ctrl)
        end
    end
end

local function get_child_ui_if(ui_ctrl, fn)
    local queue = { ui_ctrl }
    local i = 1
    while i <= #queue do
        ui_ctrl = queue[i]
        i = i + 1

        if fn(ui_ctrl) then
            return ui_ctrl
        end

        if ui_ctrl.child then
            for _, child in ipairs(ui_ctrl.child) do
                table.insert(queue, child)
            end
        end
    end
    return nil
end

local function get_child_ui_by(ui_ctrl, key, value)
    if value == nil then
        return ui_ctrl
    end
    return get_child_ui_if(ui_ctrl, function(ui_ctrl)
        return ui_ctrl[key] == value
    end)
end

local function get_child_ui_by_name(ui_ctrl, child_name)
    if child_name == nil or child_name == '' then
        return ui_ctrl
    end
    return get_child_ui_by(ui_ctrl, 'name', child_name)
end

local function on_prop_changed(ui_ctrl, k, v)
    if not ui_ctrl then
        return
    end
    local handler = rawget(ui_ctrl, '__on_prop_changed')
    if type(handler) ~= 'function' then
        return
    end
    handler(ui_ctrl, k, v)
end

---- ctrl utils
local function is_ctrl(any)
    if type(any) ~= 'table' then
        return false
    end
    local mt = getmetatable(any)
    return mt == base.ui.mt or mt == module.component_ctrl_mt
end

local function is_component_ctrl(ctrl)
    return type(ctrl) == 'table' and getmetatable(ctrl) == module.component_ctrl_mt
end

local function get_next_ext_component(ctrl)
    if not is_ctrl(ctrl) then
        return nil
    end
    return rawget(ctrl, '__ext')
end

local function get_next_base_component(ctrl)
    if not is_component_ctrl(ctrl) then
        return nil
    end
    return rawget(ctrl, 'base')
end

local function get_final_ext_component(ctrl)
    if get_next_ext_component(ctrl) == nil then
        return ctrl
    end
    local cc = ctrl
    if is_component_ctrl(ctrl) then
        ctrl = ctrl.ui
    end
    local ext_chain = ctrl.__component_chain
    return ext_chain == nil and cc or ext_chain[#ext_chain]
end

local function get_parent(ctrl)
    if is_component_ctrl(ctrl) then
        ctrl = ctrl.ui
    end
    return get_final_ext_component(ctrl.parent)
end

local function get_children(ctrl)
    if is_component_ctrl(ctrl) then
        ctrl = ctrl.ui
    end
    local children = {}
    for i, child in ipairs(ctrl.child) do
        table.insert(children, get_final_ext_component(child))
    end
    return children
end

local function get_child_if(ctrl, fn)
    local queue = { ctrl }
    local i = 1
    while i <= #queue do
        ctrl = queue[i]
        i = i + 1
        
        if fn(ctrl) then
            return ctrl
        end
        
        local is_component = is_component_ctrl(ctrl)
        for j, child in ipairs(ctrl.child) do
            if not is_component then
                child = get_final_ext_component(child)
            end
            table.insert(queue, child)
        end
    end
    return nil
end

local function get_child_by(ctrl, key, value)
    if value == nil then
        return ctrl
    end
    return get_child_if(ctrl, function(ui_ctrl)
        return ui_ctrl[key] == value
    end)
end

local function get_child_by_name(ctrl, child_name)
    if child_name == nil or child_name == '' then
        return ctrl
    end
    return get_child_by(ctrl, 'name', child_name)
end

local function is_ctrl_exists(ctrl)
    if is_component_ctrl(ctrl) then
        return not rawget(ctrl, '__not_valid')
    else
        return not ctrl.removed
    end
end

local function is_ctrl_inited(ctrl)
    if is_component_ctrl(ctrl) then
        return rawget(ctrl, '__is_inited')
    end
    return true
end

local function expect_ctrl_exists(ctrl)
    if is_ctrl_exists(ctrl) then
        log_file.warn('访问被删除对象')
        -- print('[WARN] 访问被删除对象')
        return false, ctrl
    end
    return true, ctrl
end

local function register_as_component_part(ctrl, component_ctrl, component_node)
    rawset(ctrl, '__component_node', component_node)
    component_ctrl = get_final_ext_component(component_ctrl)
    component_node.direct_component = component_ctrl

    if component_node.part_tags then
        for _, tag in ipairs(component_node.part_tags) do
            local parts = component_ctrl.__part[tag]
            if type(parts) ~= 'table' then
                parts = {}
                component_ctrl.__part[tag] = parts
            end
            table.insert(parts, ctrl)
        end
    end

    if component_node.part_idx then
        local idx_part = component_ctrl.__part[component_node.part_idx]
        if type(idx_part) ~= 'table' then
            idx_part = {}
            component_ctrl.__part[component_node.part_idx] = idx_part
        end
        table.insert(idx_part, ctrl)
    end
end

local function unregister_part(ctrl) -- idx 保持不变，即使移动了顺序
    local component_node = rawget(ctrl, '__component_node')
    if component_node == nil then
        return
    end
    local direct_component = component_node.direct_component

    if component_node.part_tags then
        for _, tag in ipairs(component_node.part_tags) do
            local parts = direct_component.__part[tag]
            for i = #parts, 1, -1 do
                local part = parts[i]
                if part == ctrl then
                    table.remove(parts, i)
                    break
                end
            end
        end
    end

    if component_node.part_idx then
        local part = direct_component.__part[component_node.part_idx]
        if type(part) == 'table' then
            table.remove(part) -- array 必然倒着删除
            if #part == 0 then
                direct_component.__part[component_node.part_idx] = nil
            end
        end
    end

    rawset(ctrl, '__component_node', nil)
end

local metadatas
local function get_ctrl_metadata(ctrl)
    if is_component_ctrl(ctrl) then
        return ctrl.__class.metadata
    end
    if metadatas == nil then
        metadatas = require '@common.base.gui.metadatas'
    end
    return metadatas[ctrl.type]
end

local function get_template_metadata(template)
    if is_component_template(template) then
        return template.__class.metadata
    end
    if metadatas == nil then
        metadatas = require '@common.base.gui.metadatas'
    end
    return metadatas[template.__ui_type]
end

local function get_direct_owner_component(ctrl)
    if ctrl == nil then
        return nil
    end
    local component_node = rawget(ctrl, '__component_node')
    return component_node and component_node.direct_component or nil
end

local function get_owner_component(ctrl)
    return get_final_ext_component(get_direct_owner_component(ctrl))
end

local function destroy_ctrl(ctrl)
    if is_component_ctrl(ctrl) then
        ctrl:destroy()
    else
        ctrl:remove()
    end
end

local function register_component_child(ctrl, parent_ctrl)
    local final_ext = get_final_ext_component(ctrl)
    local ui_ctrl = is_component_ctrl(ctrl) and ctrl.ui or ctrl
    ui_ctrl.__component_parent = parent_ctrl
    local parent_list = {parent_ctrl}
    while parent_ctrl and is_component_ctrl(parent_ctrl) do
        parent_ctrl = parent_ctrl.part[parent_ctrl.class.default_child_pos or 1][1]
        table.insert(parent_list, parent_ctrl)
    end
    local endi = #parent_list
    for i, p in ipairs(parent_list) do
        if i == endi then
            table.insert(p.child, ui_ctrl)
            ui_ctrl.parent = p
            if is_cpp_ctrl_created(ui_ctrl) then
                if is_cpp_ctrl_created(p) then
                    ui.ctrl_set_parent(ui_ctrl.id, p.id)
                else
                    --call_after_created(ui_new_parent,
                    base.next(function()
                        ui.ctrl_set_parent(ui_ctrl.id, p.id)
                    end )
                end
            end
        else
            table.insert(p.child, final_ext)
            p:on_add_child(final_ext)
        end
    end
end

local function unregister_component_child(ctrl)
    local final_ext = get_final_ext_component(ctrl)
    local ui_ctrl = is_component_ctrl(ctrl) and ctrl.ui or ctrl
    local parent_ctrl = ui_ctrl.__component_parent
    local parent_list = {parent_ctrl}
    while parent_ctrl and is_component_ctrl(parent_ctrl) do
        parent_ctrl = parent_ctrl.part[parent_ctrl.class.default_child_pos or 1][1]
        table.insert(parent_list, parent_ctrl)
    end
    if not parent_ctrl and #parent_list == 0 then
        parent_list[1] = ui_ctrl.parent
    end
    local endj = #parent_list
    for j, p in ipairs(parent_list) do
        local children = p.child
        if j == endj then
            for i = #children, 1, -1 do
                local c = children[i]
                if c == ui_ctrl then --(内置控件的child不会存放组件实例)
                    table.remove(children, i)
                    c.parent = nil
                    break
                end
            end
        else
            for i = #children, 1, -1 do
                local c = children[i]
                if c == final_ext then --(组件控件的child不会存放base)
                    table.remove(children, i)
                    break
                end
            end
        end
    end
    ui_ctrl.__component_parent = nil
end

local function move_to_new_parent(ctrl, new_parent) -- 不影响 part
    unregister_component_child(ctrl)
    register_component_child(ctrl, new_parent)
end

local function as_sibling_of_(ui_ctrl, ui_ctrl_target, pos)
    if ui_ctrl == ui_ctrl_target then
        return
    end
    pos = (pos >= 0 and pos < 4) and pos or 0
    local parent_ctrl = ui_ctrl.parent
    local target_parent = ui_ctrl_target.parent
    if target_parent == nil then
        return
    end

    if parent_ctrl ~= target_parent then
        if parent_ctrl then
            local childern = parent_ctrl.child
            local count = #childern
            for i = count, 1, -1 do
                local c = childern[i]
                if c == ui_ctrl then
                    table.remove(childern, i)
                    break
                end
            end
        end

        ui_ctrl.parent = target_parent
        local idx
        if pos > 1 then
            if pos == 2 then
                idx = 0
            elseif pos == 3 then
                idx = #target_parent.child
            end
        else
            for i, ctrl in ipairs(target_parent.child) do
                if ctrl == ui_ctrl_target then
                    idx = i + pos
                elseif ctrl == ui_ctrl then
                    -- as_sibling_of传ui而不是组件的时候会导致重复插入，判一下
                    idx = -1
                    break
                end
            end
        end
        if idx >= 0 then
            table.insert(target_parent.child, idx, ui_ctrl)
        end
    end

    if is_cpp_ctrl_created(ui_ctrl) and is_cpp_ctrl_created(ui_ctrl_target) then
        ui.as_sibling_of(ui_ctrl.id, ui_ctrl_target.id, pos)
    else
        base.next(function()
            ui.as_sibling_of(ui_ctrl.id, ui_ctrl_target.id, pos)
        end)
    end
end

local function as_sibling_of(ctrl, ctrl_target, pos)
    ctrl = get_final_ext_component(ctrl)
    ctrl_target = get_final_ext_component(ctrl_target)
    if ctrl == ctrl_target then
        return
    end
    local ui_ctrl = is_component_ctrl(ctrl) and ctrl.ui or ctrl
    local ui_ctrl_target = is_component_ctrl(ctrl_target) and ctrl_target.ui or ctrl_target

    local target_com_parent = ctrl_target.__component_parent
    local com_parent = ctrl.__component_parent
    if com_parent ~= target_com_parent then
        unregister_component_child(ctrl) -- 从老组件父亲中移除
        ctrl.__component_parent = target_com_parent
        local final_ext = get_final_ext_component(ctrl)
        local target_final_ext = get_final_ext_component(ctrl_target)
        local parent_ctrl = target_com_parent
        local parent_list = {parent_ctrl}
        while parent_ctrl and is_component_ctrl(parent_ctrl) and parent_ctrl.class.default_child_pos do
            parent_ctrl = parent_ctrl.part[parent_ctrl.class.default_child_pos][1]
            table.insert(parent_list, parent_ctrl)
        end
        local count = #parent_list
        for i, p in ipairs(parent_list) do
            local idx = #(p.child)
            if pos == 2 then
                idx = 1
            elseif pos == 0 or pos == 1 then
                for i, child in ipairs(p.child) do
                    if child == target_final_ext then
                        idx = i + pos
                        break
                    end
                end
            end
            table.insert(p.child, idx, final_ext)
            if i ~= 1 or count ~= 1 then
                p:on_add_child(final_ext, idx)
            end
        end
    end

    as_sibling_of_(ui_ctrl, ui_ctrl_target, pos)
end

local function as_prev_sibling_of(ui_ctrl, ui_ctrl_target)
    as_sibling_of(ui_ctrl, ui_ctrl_target, 0)
end
local function as_next_sibling_of(ui_ctrl, ui_ctrl_target)
    as_sibling_of(ui_ctrl, ui_ctrl_target, 1)
end
local function as_first_sibling_of(ui_ctrl, ui_ctrl_target)
    as_sibling_of(ui_ctrl, ui_ctrl_target, 2)
end
local function as_final_sibling_of(ui_ctrl, ui_ctrl_target)
    as_sibling_of(ui_ctrl, ui_ctrl_target, 3)
end

local function get_ctrl_prop(ctrl, prop_name)
    if is_component_ctrl(ctrl) then
        return get_prop(rawget(ctrl, 'prop'), prop_name)
    end
    return get_prop(ctrl, prop_name)
end

local _one_key_prop_name = {}
local function set_ctrl_prop(ctrl, prop_name, value)
    if type(ctrl) ~= 'table' then
        return
    end
    if type(prop_name) ~= 'table' then
        _one_key_prop_name[1] = prop_name
        for i = 2, #_one_key_prop_name do
            _one_key_prop_name[i] = nil
        end
        prop_name = _one_key_prop_name
    end
    local is_component = is_component_ctrl(ctrl)
    if is_component then
        local ext_idx = ctrl.__class.__prop_def_table[prop_name[1]]
        ctrl = ext_idx and ctrl.ui.__component_chain[ext_idx] or ctrl.ui
        is_component = ext_idx ~= nil
    end

    local key = prop_name[#prop_name] -- 最后一个作为key
    local target = is_component and ctrl.prop or ctrl
    for i = 1, #prop_name - 1 do
        local new_target = target[prop_name[i]]
        if type(new_target) ~= 'table' then
            if new_target ~= nil then
                -- error/warn
                -- print('对应属性不是表属性：'..prop_name[i])
                return
            end
            -- print('创建表属性：'..prop_name[i])
            new_target = {}
            target[prop_name[i]] = new_target
        end
        target = new_target
    end

    if not is_component then
        -- 内置控件需要调用 c++ 接口
        local nested_value = value
        for i = #prop_name, 2, -1 do
            nested_value = {[prop_name[i]] = nested_value}
        end
        local prop_name_1 = prop_name[1]

        if prop_name_1 == 'event' then -- 特殊处理 event
            if nested_value then
                for k, v in pairs(nested_value) do
                    -- base.ui.update_event(ctrl, k, v)
                    ctrl:subscribe(k)
                end
            end
            target[key] = value
        else
            local id = rawget(ctrl, 'id')
            base.ui.gui['set_'..prop_name_1](id, nested_value) -- 注意table类型是增量设置
            target[key] = value
            base.ui.emit_prop_changed(ctrl, prop_name, value)
        end
    else
        target[key] = value -- 若是组件顶层属性内部会调用 dispatch_bibind
    end

end

local function get_ctrl_type_name(ctrl)
    if is_component_ctrl(ctrl) then
        return ctrl.__class.__ui_type
    else
        return ctrl.type
    end
end

local function replace_ctrl(ctrl, value)
    if type(value) ~= 'table' then
        return
    end

    -- 获得父控件与所属组件
    local parent_ctrl = get_parent(ctrl)
    local owner_com = get_owner_component(ctrl)
    local com_node = rawget(ctrl, '__component_node')
    local old_bibinds = rawget(ctrl, '__bibind')

    -- 移除老控件
    destroy_ctrl(ctrl)

    -- 如果传入模板则创建
    local new_ctrl = value
    if is_template(value) then
        -- if rawget(value, '__component_node') then -- 后面被注销
        -- end
        -- local bind = owner_com and owner_com.bind
        local ui, _ = base.ui.create(value, nil, nil, parent_ctrl) -- 会自动注册到父控件
        new_ctrl = get_final_ext_component(ui)
    end

    -- 插入新控件 -- [@abc] = panel 'ccc' {} ccc不被注册
    unregister_part(new_ctrl)
    move_to_new_parent(new_ctrl, parent_ctrl) -- 移动到新控件后被认为是动态控件（需要手动进行注册）
    register_as_component_part(new_ctrl, owner_com, com_node)
    -- todo [n] = panel{} 这个可以, 但不被内所引用，通过 child 接口进行访问

    -- 2) 移除老控件, 由于替代他的可能是其子控件所以最后进行移除
    if old_bibinds then
        local new_bibinds = rawget(new_ctrl, '__bibind')
        if new_bibinds then
            error('暂不支持合并绑定信息')
        end
        rawset(new_ctrl, '__bibind', old_bibinds)
    end
end

-- component creation

local creating_components_stack = {}
local function push_creating_component(com)
    table.insert(creating_components_stack, com)
end
local function pop_creating_component()
    table.remove(creating_components_stack)
end

local function get_prop_owner_ctrl(component_ctrl, prop_name)
    local ui = component_ctrl.ui
    local ext_idx = component_ctrl.class.__prop_def_table[prop_name[1]]
    local owner_ctrl = ext_idx and ui.__component_chain[ext_idx] or ui
    return owner_ctrl
end

module = {
    is_template = is_template,
    is_component_template = is_component_template,
    is_component_class = is_component_class,

    -- get_component_chain = get_component_chain,
    call_after_created = call_after_created,
    emit_on_created = emit_on_created,
    visit_child_ui = get_child_ui_if,
    get_child_ui_if = get_child_ui_if,
    get_child_ui_by = get_child_ui_by,
    get_child_ui_by_name = get_child_ui_by_name,
    on_prop_changed = on_prop_changed,

    is_component_ctrl = is_component_ctrl,
    get_next_base_component = get_next_base_component,
    get_next_ext_component = get_next_ext_component,
    get_final_ext_component = get_final_ext_component,
    visit_child_ctrl = get_child_if,
    get_child_if = get_child_if,
    get_child_by = get_child_by,
    get_child_by_name = get_child_by_name,
    is_ctrl_exists = is_ctrl_exists,
    is_ctrl_inited = is_ctrl_inited,
    expect_ctrl_exists = expect_ctrl_exists,
    register_as_component_part = register_as_component_part,
    unregister_part = unregister_part,
    unregister_component_child = unregister_component_child,
    get_parent = get_parent,
    get_children = get_children,
    move_to_new_parent = move_to_new_parent,
    replace_ctrl = replace_ctrl,
    as_next_sibling_of = as_next_sibling_of,
    as_prev_sibling_of = as_prev_sibling_of,
    as_first_sibling_of = as_first_sibling_of,
    as_final_sibling_of = as_final_sibling_of,
    as_sibling_of = as_sibling_of,
    get_ctrl_prop = get_ctrl_prop,
    set_ctrl_prop = set_ctrl_prop,
    get_ctrl_type_name = get_ctrl_type_name,
    get_direct_owner_component = get_direct_owner_component,
    get_owner_component = get_owner_component,
    destroy_ctrl = destroy_ctrl,
    get_ctrl_metadata = get_ctrl_metadata,
    get_template_metadata = get_template_metadata,

    push_creating_component = push_creating_component,
    pop_creating_component = pop_creating_component,
    creating_components_stack = creating_components_stack,

    is_ctrl = is_ctrl,
}

return module