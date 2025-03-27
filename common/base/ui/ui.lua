local ipairs = ipairs
local pairs = pairs
local xpcall = xpcall
local type = type
local ui_map = {} -- all created ctrls
local ui_id_map = {} -- all ctrls (include waiting)
local ui_list = {}
local bind_map = {}
local ui_list_reverse = setmetatable({}, { __mode = 'kv' })
local tick_map = setmetatable({}, { __mode = 'v' })
local wait_to_create = {}
local has_inited
local flush_state = 'stop'
local callback_count = 0

local platform  = include 'base.platform'
local argv      = include 'base.argv'
local profiler  = include 'base.profiler'
local co        = include 'base.co'

include 'class'

local bibind = require '@common.base.gui.bibind'
local dispatch_bibind = bibind.dispatch_bibind
local control_util = require '@common.base.gui.control_util'
local on_prop_changed = control_util.on_prop_changed
local emit_on_created = control_util.emit_on_created
local creating_components_stack = control_util.creating_components_stack
local register_as_component_part = control_util.register_as_component_part
local get_owner_component = control_util.get_owner_component
local get_final_ext_component = control_util.get_final_ext_component
local is_component_ctrl = control_util.is_component_ctrl
local unregister_part = control_util.unregister_part
local unregister_component_child = control_util.unregister_component_child
local is_component_template = control_util.is_component_template

-- 用于调试时检测爆栈，性能很差，注意不要在发布版中执行
local function GetStackDepth()
    local depth = 0
    while true do
        if not debug.getinfo(3 + depth) then
            break
        end
        depth = depth + 1
    end
    return depth
end

local function emit_prop_changed(ctrl, prop_name, value)
    dispatch_bibind(ctrl, prop_name, value)
    on_prop_changed(ctrl, prop_name, value)
end

-- 非ui属性但是以set_开头的api
local is_not_prop_set = {
    set_global_scale = true,
    set_control_prop = true,
    set_show = true, -- window 使用了，就先放出来
    set_line_width = true,
    set_line_color = true,
    set_fill_color = true,
    set_window_silent = true,
    set_scene_view_priority = true,
    set_scene_view_scale = true,
    set_scene_view_scissor_rect = true,
}

local _set_control_prop = ui.set_control_prop
local gui = setmetatable({}, {__index = function (self, key)
    local is_set_function = key:find('^set_')
    if _set_control_prop and is_set_function and not is_not_prop_set[key] then
        local k = key:sub(5)
        self[key] = function (id, ...)
            callback_count = callback_count + 1
            local result = ui_map[id] and _set_control_prop(id, k, ...)
            return result
        end
    else
        if is_set_function then
            local k = key:sub(5)
            self[key] = function (id, ...)
                callback_count = callback_count + 1
                local result = ui[key](id, ...)
                return result
            end
        else
            self[key] = function (id, ...)
                callback_count = callback_count + 1
                return ui[key](id, ...)
            end
        end
    end
    return self[key]
end})

function gui.set_show(id, show)
    local ui_inst = ui_map[id]
    if not ui_inst then
        return
    end
    callback_count = callback_count + 1
    local v = show and ui_inst._visible
    ui.set_show(id, v)
end

function gui.set_array(id, v)
    local ui_inst = ui_id_map[id]
    if ui_inst.__set_array == nil then
        return
    end
    ui_inst.__set_array(nil, v)
end

local mt = {}

local function init()
    if has_inited then
        return
    end
    has_inited = true

    local main = {
        type = 'panel',
        id = 'main',
        image = '',
        static = true,
        clip = false,
        layout = {
            grow_width = 1,
            grow_height = 1,
        },
        z_index = 0,
        parent = {}
    }
    ui.add_childs_t { main }

    ui_map['main'] = setmetatable({
        type = 'main',
        id = 'main',
        child = {},
    }, mt)
end

local is_traversing_tick_map

local function on_tick(delta)
    common.profile_begin_block('on_tick_callback')
    is_traversing_tick_map = true
    for func, ui in pairs(tick_map) do
        if ui.removed then
            tick_map[func] = nil
        else            
            -- 如果要看具体哪个控件的tick消耗了的话，就把下面两行注释打开，并且要加-inner参数
            -- common.profile_begin_block('on_tick:' .. tostring(ui.meta_info_str))
            xpcall(func, base.error, delta)
            -- common.profile_end_block()
        end
    end
    is_traversing_tick_map = false
    common.profile_end_block()
end

local function check_create()
    local perf = profiler.new()
    local count = #wait_to_create
    for i, ui in ipairs(wait_to_create) do
        wait_to_create[i] = nil
        if not ui.removed then
            perf:start()
            gui.add_child_t(ui.parent.id, ui)
            perf:finish()
            ui_map[ui.id] = ui
            ui:subscribe_now()
        end
    end
    return perf:get_used(), count
end

local function check_create_new()
    common.profile_begin_block('check_create_new')
    local perf = profiler.new()
    local count = #wait_to_create
    perf:start()
    -- if count > 0 then
    --     print('create ctrl: '..count)
    -- end
    gui.add_childs_t(wait_to_create)
    perf:finish()
    -- for i, ui in ipairs(wait_to_create) do
    --     wait_to_create[i] = nil
    --     if not ui.removed then
    --         ui_map[ui.id] = ui
    --         ui:subscribe_now()
    --     end
    -- end
    -- 为了解决嵌套创建控件的情况，改成下面这种写法
    for i = 1, count do
        local ui = wait_to_create[i]
        wait_to_create[i] = nil
        if not ui.removed then
            ui_map[ui.id] = ui
            ui:subscribe_now()
            -- 一些逻辑必须在真正创建完成后执行
            emit_on_created(ui)
        end
    end
    if wait_to_create[count + 1] then
        local i = count + 1
        while (wait_to_create[i]) do
            wait_to_create[i - count] = wait_to_create[i]
            wait_to_create[i] = nil
            i = i + 1
        end
    end
    common.profile_end_block()
    return perf:get_used(), count
end

local function eq(a, b)
    local tp1, tp2 = type(a), type(b)
    if tp1 ~= tp2 then
        return false
    end
    if tp1 == 'table' then
        local mark = {}
        for k in pairs(a) do
            if not eq(a[k], b[k]) then
                return false
            end
            mark[k] = true
        end
        for k in pairs(b) do
            if not mark[k] then
                return false
            end
        end
        return true
    end
    return a == b
end

local cache = include 'base.ui.image_cache'
local function watch(ui, template, bind, key, format)
    ui[key] = template[key]
    local func = gui['set_'..key]
    local value = ui[key]
    if value and cache.test(key, value) then
        cache.run(ui, key, value, func)
    end
    if not template.bind or template.bind[key] == nil then
        return
    end
    bind.watch[key] = function (self, v)
        if format then
            v = format(v)
        end
        if cache.test(key, v) then
            cache.run(ui, key, v, func)
        else
            ui[key] = v
            if not ui_map[ui.id] then
                return
            end
            func(ui.id, v)
            emit_prop_changed(ui, key, v)
        end
    end
end

function base.event.on_ui_tick(delta)
    -- 渲染这帧新创建的控件
    local timer = profiler.new()
    timer:start()
    -- 执行现有控件的帧回调
    on_tick(delta)
    local perf, count = check_create_new()
    timer:finish()
    local usage = timer:get_used()
    if usage > 100 then
        local desc = ('创建控件耗时过高, 控件个数[%d], 总耗时[%.2fms]，创建耗时[%.2fms]'):format(count, usage, perf)
        print(desc)
        log_file.warn(desc)
    end
end

local function update_event(self, k, v)
    if not self.event then
        self.event = {}
    end
    if self.event[k] then
        self:unsubscribe(k)
    end
    if v then
        self:subscribe(k)
    end
    self.event[k] = v
    emit_prop_changed(self, {'event', k}, v)
end

local function update_data(self, k, v)
    if not self.data then
        self.data = {}
    end
    self.data[k] = v
    emit_prop_changed(self, {'data', k}, v)
end

local function update_transition(self, k, v)
    if not self.transition then
        self.transition = {}
    end
    self.transition[k] = v
    if ui_map[self.id] then
        gui.set_transition(self.id, {[k] = v})
    end
    emit_prop_changed(self, {'transition', k}, v)
end

local function update_layout(self, k, v)
    if not self.layout then
        self.layout = {}
    end
    self.layout[k] = v
    if ui_map[self.id] then
        gui.set_layout(self.id, {[k] = v})
    end
    emit_prop_changed(self, {'layout', k}, v)
end

local function add_child(self, child)
    if child == nil or rawget(child, '__not_ui') then
        return true
    end
    if child.parent then
        -- 从父控件中清除自己
        for i, c in ipairs(child.parent.child) do
            if c == child then
                table.remove(child.parent.child, i)
                break
            end
        end
    end
    self.child[#self.child+1] = child
    child.parent = self
    return true
end

local function remove_ui(self)
    if self.removed then
        return false
    end
    local com = get_final_ext_component(self)
    if is_component_ctrl(com) then
        rawset(com, '__not_valid', 1)
        com:on_destroy()
    end

    -- 释放事件
    base.ui.event.release_event(self)

    -- 递归删除子控件
    if self.child then
        local children = self.child
        for i = #children, 1, -1 do
            local child = children[i]
            remove_ui(child)
            children[i] = nil
        end
    end

    unregister_component_child(self)
    unregister_part(self)
    self.removed = true

    if self.id then
        -- 清除控件记录
        ui_map[self.id] = nil
        ui_id_map[self.id] = nil
        if ui_list_reverse[self] then
            ui_list[ui_list_reverse[self]] = nil
            bind_map[ui_list_reverse[self]] = nil
            ui_list_reverse[self] = nil
        end
        -- 通知前端删除控件
        gui.remove_control(self.id)
    end

    -- 触发删除事件
    if self.on_remove then
        xpcall(self.on_remove, base.error, self)
    end
end

local function remove_childs(self)
    local list = {}
    for i, child in ipairs(self.child) do
        self.child[i] = nil
        list[i] = child
    end
    for _, child in ipairs(list) do
        remove_ui(child)
    end
end

local function remove(self)
    if self.removed then
        return false
    end

    -- 从父控件中清除自己
    if self.parent then
        local children = self.parent.child
        -- array缩减时从后向前删除
        for i = #children, 1, -1 do
            local child = children[i]
            if child == self then
                table.remove(children, i)
                break
            end
        end
    end
    remove_ui(self)

    return true
end

local function flush(mode)
    if mode == nil then
        for name, ui in pairs(ui_list) do
            if ui._flush == 'collect' then
                ui_list[name] = nil
                remove(ui)
            end
        end
    elseif type(mode) == 'string' then
        flush_state = mode
    else
        mode._flush = flush_state
    end
end

local function add_wait_to_create_ctrl(ui_ctrl)
    ui_id_map[ui_ctrl.id] = ui_ctrl
    -- print('add ctrl to create: '..ui_ctrl.id)
    wait_to_create[#wait_to_create+1] = ui_ctrl
end

local ui_index = 0
local function view(data)
    ui_index = ui_index + 1
    local id = 'ui-' .. tostring(ui_index) .. '-' .. tostring(data.name)
    if not data.id then
        data.id = id
    end
    data.child = {}
    local ui = setmetatable(data, mt)
    -- 先把控件添加给 main
    ui_map['main']:add_child(ui)
    add_wait_to_create_ctrl(ui)
    return ui
end

local function deep_copy(t)
    if type(t) ~= 'table' then return t end
    local new = {}
    for k, v in pairs(t) do
        new[k] = deep_copy(v)
    end
    if t.__type == 'call' then
        setmetatable(new, getmetatable(t))
    end
    return new
end

local function ui_default(ui, template, bind, parent)
    watch(ui, template, bind, 'swallow_event')
    watch(ui, template, bind, 'swallow_events')
    watch(ui, template, bind, 'static')
    watch(ui, template, bind, 'disabled')
    watch(ui, template, bind, 'overflow')
    watch(ui, template, bind, 'enable_drag')
    watch(ui, template, bind, 'enable_drop')
    watch(ui, template, bind, 'z_index')
    watch(ui, template, bind, 'clip')
    watch(ui, template, bind, 'enable')
    watch(ui, template, bind, 'show')
    watch(ui, template, bind, 'color')
    watch(ui, template, bind, 'gray')
    watch(ui, template, bind, 'round_corner_radius')
    watch(ui, template, bind, 'image')
    watch(ui, template, bind, 'mask_image')
    watch(ui, template, bind, 'border')
    watch(ui, template, bind, 'opacity')
    watch(ui, template, bind, 'focus')
    watch(ui, template, bind, 'scale')
    watch(ui, template, bind, 'rotate')
    watch(ui, template, bind, 'low_level')
    watch(ui, template, bind, 'render_group')
    watch(ui, template, bind, 'flip_x')
    watch(ui, template, bind, 'flip_y')
    watch(ui, template, bind, 'fix_scale')
    watch(ui, template, bind, 'fix_border')
    watch(ui, template, bind, 'meta_info_str')
    watch(ui, template, bind, 'blur_image')

    ui.name       = template.name
    ui.CustomString = template.CustomString
    ui.event      = deep_copy(template.event)
    ui.layout     = deep_copy(template.layout)
    ui.transition = deep_copy(template.transition)
    ui.__EDIT_TIME = deep_copy(template.__EDIT_TIME)

    if template.__component_node then
        -- local com = creating_components_stack[#creating_components_stack] or get_owner_component(parent)
        local com = get_owner_component(parent) or creating_components_stack[#creating_components_stack]
        if com then
            register_as_component_part(ui, com, deep_copy(template.__component_node))
        end
    end

    if ui.event then
        for k, _ in pairs(ui.event) do
            ui:subscribe(k)
        end
    end

    if template.bind == nil then return end
    local tbind = template.bind

    if tbind.layout ~= nil then
        function bind.watch:layout(k, v)
            update_layout(ui, k, v)
        end
    end

    if tbind.event ~= nil then
        function bind.watch:event(k, v)
            update_event(ui, k, v)
        end
    end

    if tbind.transition ~= nil then
        function bind.watch:transition(k, v)
            update_transition(ui, k, v)
        end
    end
end

local function template_obj(props)
    if argv.has('inner') then
        local info = debug.getinfo(2)
        local ctrl_name = (type(props.name) ~= 'table' and props.name)
            or (type(props.id) ~= 'table' and props.id)
            or ''
        props.meta_info_str = info.source..' '..(info.name or '')..' '..info.currentline..' '..ctrl_name
    end
    return props
end

local ui_creates = {}
local function template(ui, type_name)
    -- type_name = '_ui' .. type_name
    if ui_creates[type_name] then
        log.error('repeat register ui:' .. type_name)
        return
    end

    ui_creates[type_name] = ui

    return function (str_or_props)
        if type(str_or_props) == 'string' then
            return function (props)
                props.__part_tags = {str_or_props}
                props.__ui_type = type_name
                return template_obj(props)
            end
        end
        str_or_props.__ui_type = type_name
        return template_obj(str_or_props)
    end
end

local ui_type_name = {}
local function component(type_name, base)
    -- 防止组件名称重复
    type_name = 'cui_' .. type_name
    if not ui_type_name[type_name] then
        ui_type_name[type_name] = 1
    else
        ui_type_name[type_name] = ui_type_name[type_name] + 1
        type_name = type_name .. ui_type_name[type_name]
    end

    local base_class = base and (base.ctor and base or base.__component) or include 'base.ui.component.base'
    local component = class(type_name, base_class)
    ui_creates[type_name] = function(props, bind)
        local ui, slot_ui = component.new():__create(props, bind)
        return ui, slot_ui, true -- 返回true表示组件
    end

    local rs = {
        __component = component,
        __newindex = function(self, k ,v)
            component[k] = v
        end,
        __index = function(self, k)
            return component[k]
        end,
        __call = function(self, props)
            props.__ui_type = type_name
            return props
        end
    }
    return setmetatable(rs, rs)
end

-- local function register_ui_creates(type_name, fn)
--     ui_creates[type_name] = fn
-- end

local function compile_child(template, bind, parent)
    bind:load(template)
    if is_component_template(template) then
        local ctrl = template.__class:new(nil, template, bind, false, parent)
        return ctrl.ui
    end

    local class = template.__ui_type

    -- 兼容之前的自定义ui
    local c_create = rawget(base.p_ui, 'create_'..(template.class or ''))
    if c_create then
        return c_create(template, bind)
    end

    local ui, slot_ui, is_component = ui_creates[class](template, bind, parent)
    if template.imgui_slot then
        if not is_component then
            slot_ui = ui
        end
    else
        slot_ui = nil
    end
    if is_component then
        return ui, slot_ui
    end

    ui_default(ui, template, bind, parent)

    local outer = bind.outer
    if template.array then
        local array_id = template.bind and template.bind.array or ui.id
        bind:push(array_id)
        for i = 1, template.array or 1 do
            bind:index(i)
            for _, ct in ipairs(template) do
                local bind = ct._use_outer and outer or bind
                local cui = compile_child(ct, bind, ui)
                add_child(ui, cui)
            end
        end
        bind:pop()
    else
        for _, ct in ipairs(template) do
            local bind = ct._use_outer and outer or bind
            local cui, cslot_ui = compile_child(ct, bind, ui)
            if not slot_ui then
                slot_ui = cslot_ui
            end
            add_child(ui, cui)
        end
    end
    return ui, slot_ui -- [todo] 尝试返回组件 get_final_ext_component(ctrl)
end

local function set_array(self, v, template, bind)
    if self.removed or v < 0 then
        return
    end
    local old = self.array
    if old == nil then
        return
    end
    if old == v then
        return
    end
    self.array = v
    local array_id = template.bind and template.bind.array or self.id
    if v > old then
        local outer = bind.outer
        bind:push(array_id)
        for i = old+1, v do
            bind:index(i)
            for _, ct in ipairs(template) do
                local bind = ct._use_outer and outer or bind
                local cui = compile_child(ct, bind, self)
                add_child(self, cui)
            end
        end
        bind:pop()
    else
        local count = (old - v) * #template
        local child_count = #(self.child)
        for i = child_count, child_count - count + 1, -1 do
            local child = self.child[i]
            local ctrl = get_final_ext_component(child)
            if is_component_ctrl(ctrl) then
                ctrl:destroy()
            else
                child:remove()
            end
        end
        bind:compact(array_id, v)
    end
end

local function create(template, name, bind, p)
    init()
    local bind = bind or base.bind()
    local timer = profiler.new()
    local last_count = #wait_to_create
    timer:start()
    local ui, slot_ui = compile_child(template, bind, p)
    timer:finish()
    local added = #wait_to_create - last_count
    local usage = timer:get_used()
    if usage > 100 then
        local warn = ('预创建控件耗时过高 [%.2f]ms [%s] [%d]个控件'):format(usage, name, added)
        log_file.warn(warn)
        print(warn)
    end
    if name then
        bind_map[name] = bind.api
        ui_list[name] = ui
        ui_list_reverse[ui] = name
    end
    return ui, bind.api, slot_ui
end

mt.__index = mt

mt.id = '未知'
mt.name = '匿名'
mt._visible = true
mt.show = true

function mt:__tostring()
    if self.parent and base.test then
        return (('{%s|%q|%q} <- %s'):format(self.type, self.id, self.name, self.parent))
    else
        return (('{%s|%q|%q}'):format(self.type, self.id, self.name))
    end
end

function mt:on_tick(callback)
    if is_traversing_tick_map then
        base.next(function()
            if callback then
                tick_map[callback] = self
            end
        end)
    else
        tick_map[callback] = self
    end
    return function ()
        tick_map[callback] = nil
        callback = nil
    end
end

function mt:remove()
    return remove(self)
end

function mt:add_child(child)
    if self.removed then
        return false
    end
    if self.array then
        return false
    end
    return add_child(self, child)
end

local get_screen_rect = ui.get_rect
function mt:get_screen_rect()
    return get_screen_rect(self.id)
end

local get_global_scale = require 'base.ui.auto_scale'.current_scale
function mt:get_ui_rect()
    local x, y, w, h = get_screen_rect(self.id)
    if x then
        local s = get_global_scale()
        return x / s, y / s, w / s, h / s
    end
end

-- @deprecated
function mt:rect()
    return ui.get_rect(self.id)
end

function mt:xywh(relative_ctrl_or_option)
    relative_ctrl_or_option = relative_ctrl_or_option or 'root'
    local is_option = type(relative_ctrl_or_option) == 'string'
    local x,y,w,h = ui.get_rect(self.id)
    if x == nil then
        return
    end
    local global_scale = ui.get_ctrl_global_scale(self.id)
    if global_scale ~= 0 and global_scale ~= 1 then
        x = x / global_scale
        y = y / global_scale
        w = w / global_scale
        h = h / global_scale
    end
    if is_option then
        local option = relative_ctrl_or_option
        if option ~= 'ui_parent' then
            return x,y,w,h
        end
        relative_ctrl_or_option = self.parent
    end
    -- 传入控件
    local relative_ctrl = relative_ctrl_or_option
    x, y = ui.screen_space_to_ctrl_space(relative_ctrl.id, x, y)
    return x,y,w,h
end

function mt:get_image_wh()
    return base.ui.gui.get_image_wh(self.id)
end

function mt:set_visible(visible)
    if self._visible == visible then
        return
    end
    self._visible = visible
    if self.show then
        gui.set_show(self.id, true)
    end
end

register_reload_event("ui_remove_main_children", function ()
    remove_childs(ui_map['main'])
    ui_index = 0
end)

function base.ui_info()
    return {
        ui_map = ui_map,
        tick_map = tick_map,
        wait_to_create = wait_to_create,
        callback = callback_count,
    }
end

local function get_ui_at_position(x, y, enabledOnly)
    local id = ui.get_control_at_position(x, y, enabledOnly)
    if id then
        return ui_map[id]
    end
end

local check_text_callback_list = {}

function base.gui_get_input_text(input, callback)
    local text = nil
    if input then
        text = input.text_input
    end
    
    if not text or text == '' then
        if callback then
            callback('')
        end
    end
    
    base.game:server'__get_check_text'{
        text = text,
    }
    if callback then
        check_text_callback_list[#check_text_callback_list + 1] = callback
    end
    return nil
end

base.proto.__return_check_text = function(msg)
    local origin_text = msg.origin_text
    local text = msg.text
    local callback = check_text_callback_list[1] 

    if callback and type(callback) == 'function' then
        callback(text)
        table.remove(check_text_callback_list, 1)
    end
end

function base.gui_set_input_text(input, text)
    if input then
        input.text_input = text
    end
end

base.ui = {
    create          = create,
    map             = ui_map,
    bind            = bind_map,
    gui             = gui,
    mt              = mt,
    view            = view,
    watch           = watch,
    set_array       = set_array,
    flush           = flush,
    list            = ui_list,
    template        = template,
    component       = component,
    update_event    = update_event,
    -- register_ui_creates = register_ui_creates,
    check_create_new = check_create_new,
    deep_copy = deep_copy,
    add_wait_to_create_ctrl = add_wait_to_create_ctrl,
    auto_scale = require 'base.ui.auto_scale',
    emit_prop_changed = emit_prop_changed,
    get_ui_at_position = get_ui_at_position,
}
print('>>>>>>>>================== init base.ui')