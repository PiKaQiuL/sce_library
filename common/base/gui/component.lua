local module_selector = require '@common.base.gui.selector'
local build_selector = module_selector.build_selector
local parse_simple_selector_info = module_selector.parse_simple_selector_info
local module_alias_prop = require '@common.base.gui.alias_prop'
local alias_from_selector_info = module_alias_prop.alias_from_selector_info
local alias = module_alias_prop.alias
local module_key_frame_state = require '@common.base.gui.key_frame_state'
local key_frame_state_info = module_key_frame_state.key_frame_state_info
local anim_trans = module_key_frame_state.anim_trans
local module_table_util = require '@common.base.gui.table_util'
local iterate_table_recursively_bf = module_table_util.iterate_table_recursively_bf
local get_prop = module_table_util.get_prop
local module_bibind = require '@common.base.gui.bibind'
local dispatch_bibind = module_bibind.dispatch_bibind
local register_bibind = module_bibind.register_bibind
local register_bind = module_bibind.register_bind
local module_control_util = require '@common.base.gui.control_util'
local push_creating_component = module_control_util.push_creating_component
local pop_creating_component = module_control_util.pop_creating_component
local is_component_class = module_control_util.is_component_class
local creating_components_stack = module_control_util.creating_components_stack
local is_component_template = module_control_util.is_component_template
local is_component_ctrl = module_control_util.is_component_ctrl
local register_as_component_part = module_control_util.register_as_component_part
local unregister_part = module_control_util.unregister_part
local set_ctrl_prop = module_control_util.set_ctrl_prop
local move_to_new_parent = module_control_util.move_to_new_parent
local get_final_ext_component = module_control_util.get_final_ext_component
local get_direct_owner_component = module_control_util.get_direct_owner_component
local get_owner_component = module_control_util.get_owner_component
local is_template = module_control_util.is_template
local get_ctrl_prop = module_control_util.get_ctrl_prop
local destroy_ctrl = module_control_util.destroy_ctrl
local module_prototype = require '@common.base.gui.table_prototype'
local prototype = module_prototype.prototype
local dumper = require '@common.base.gui.dump'
local gui_utils = require '@common.base.gui.gui_utils'

local type, pairs, ipairs, rawget, rawset = type, pairs, ipairs, rawget, rawset

local bind_mt
bind_mt = {
    __call = function(self, bind_name)
        return setmetatable({ __type = rawget(self, '__type'), bind_name }, bind_mt)
    end,
    __index = function(self, k)
        local out = { __type = rawget(self, '__type') }
        for i = 1, rawlen(self) do
            local prop_key = rawget(self, i)
            table.insert(out, prop_key)
        end
        table.insert(out, k)
        return setmetatable(out, bind_mt)
    end,
}
local bind = setmetatable({ __type = 'bind' }, bind_mt)
local bibind = setmetatable({ __type = 'bibind' }, bind_mt)
local alias_by = setmetatable({ __type = 'alias' }, bind_mt)

local function getset(o)
    o.__type = 'getset'
    return setmetatable(o, {
        __call = function(self, v)
            o.__default = v
            return o
        end
    })
end

---- utils

local function string_begin_with(str, begin_str)
    return str and string.match(str, '^' .. begin_str) ~= nil
end

local is_selector_str = gui_utils.cache_table(function(str)
    local l, r = string.find(str, '[%w_]+')
    return l ~= 1 or r ~= #str
end, false)

---- component common

local function get_class_state(self, state_name)
    local class = rawget(self, '__class')
    local states = rawget(class, 'state')
    if states == nil then
        return nil
    end
    local state = states[state_name]
    if state == nil then
        return nil
    end
    return rawget(state, '__value') -- 状态为nil 表示状态未初始化
end

local connection_mt = prototype:__new { -- 类似触发器接口
    remove = function(self)
        self:disable()
    end,
    disable = function(self)
        for i, reg in ipairs(self.regs) do
            local idx = reg[1]
            local tb = reg[2]
            if idx == nil then
                goto CONTINUE
            end
            tb[idx] = nil
            reg[1] = nil
            ::CONTINUE::
        end
    end,
    enable = function(self)
        for i, reg in ipairs(self.regs) do
            local idx = reg[1]
            local tb = reg[2]
            if idx ~= nil then
                goto CONTINUE
            end
            idx = #tb + 1
            tb[idx] = self
            reg[1] = idx
            ::CONTINUE::
        end
    end,
    is_enable = function(self)
        local idx = self.regs[1]
        return idx ~= nil
    end,
    __call = function(self, ...)
        return self.fn(...)
    end
}

local get_event_prop_name = gui_utils.cache_table(function(event_name)
    return string.match(event_name, '^on_prop_change_(.+)')
end, false)

local function is_defined_event(self, event_name)
    local event = self.class.event
    local prop = self.class.prop
    local prop_name = get_event_prop_name[event_name]
    local default_handler = event and event[event_name]
    if prop_name and prop and prop[prop_name] ~= nil then
        if default_handler == nil then
            return true
        end
        return default_handler
    end
    return default_handler
end

local function dispatch_event_handlers(self, event_name, ...)
    local event_handlers = self.connection -- 动态注册的handler
    if type(event_handlers) ~= 'table' then
        return false
    end
    local handlers = event_handlers[event_name]
    if type(handlers) ~= 'table' or #handlers == 0 then
        return false
    end
    for i, handler in pairs(handlers) do -- 多播
        handler(self, ...)
    end
    return true
end

local function dispatch_event(self, event_name, ...)
    local default_handler = is_defined_event(self, event_name)
    if not default_handler then
        return false
    end
    -- 派发到默认事件处理函数
    if type(default_handler) == 'string' then
        local ctrl_list = self:select(default_handler):collect_ctrl()
        for _, ctrl in ipairs(ctrl_list) do
            ctrl:emit(event_name, ...)
        end
        ctrl_list:release()
        return true
    elseif type(default_handler) == 'boolean' then

    else
        default_handler(self, ...)
    end
    -- 派发到事件处理函数
    dispatch_event_handlers(self, event_name, ...)
    return true
end

local empty_function = function() end
local default_method_name_map = {
    update = true,
}
local component_method_base_prototype = prototype:__new {
    init = function(self, ...)
        -- 不转发
    end,
    on_destroy = function(self)
    end,
    on_new_child = function(self, v)
        return v
    end,
    on_add_child = function(self, v)
        return v
    end,
    new_child = function(self, v, index, bind, parent) -- 动态子控件
        parent = parent or self
        v = self:on_new_child(v)                       -- 新建子项前的回调（可对v做修改）
        local target = self.part[self.class.default_child_pos or 1][1]
        if is_component_ctrl(target) then
            return target:new_child(v, index, bind, parent)
        end
        if is_template(v) then
            local ui_ctrl, _bind = base.ui.create(v, nil, bind, parent)
            local ctrl = get_final_ext_component(ui_ctrl)
            move_to_new_parent(ctrl, parent)
            return ctrl, _bind
        end
    end,

    emit = function(self, event_name, ...) -- 转发；触发注册的回调, 没定义则转发？
        local result = dispatch_event(self, event_name, ...)
        if not result then
            if is_component_ctrl(self.base) then
                return self.base:emit(event_name, ...)
            end
            -- 派发未定义事件
            return dispatch_event_handlers(self.base, event_name, ...)
        end
        return result
    end,

    connect = function(self, event_name, handler) -- 转发；只有定义过的才能连
        local def = is_defined_event(self, event_name)
        if not def then
            if is_component_ctrl(self.base) then
                return self.base:connect(event_name, handler)
            end
            self = self.base -- 未定义事件放在ui上
        elseif type(def) == 'string' then
            local connections = self.connection[event_name]
            if connections == nil then
                connections = {}
                self.connection[event_name] = connections
            end
            local res = {}
            local selector = self:select(def)
            local ctrl_list = selector:collect_ctrl()
            for _, ctrl in ipairs(ctrl_list) do
                if not is_component_ctrl(ctrl) then
                    ctrl_list:release()
                    return
                end
                local connection_table = { ctrl:connect(selector.event, handler) }
                for i, connection in ipairs(connection_table) do
                    local idx = #connections + 1
                    connections[idx] = connection
                    table.insert(connection.regs, { idx, connections })
                    table.insert(res, connection)
                end
            end
            ctrl_list:release()
            return table.unpack(res)
        end
        local event_handlers = self.connection
        if event_handlers == nil then
            event_handlers = {}
            self.connection = event_handlers
        end
        local handlers = event_handlers[event_name]
        if type(handlers) ~= 'table' then
            handlers = {}
            event_handlers[event_name] = handlers
        end
        local idx = #handlers + 1
        local connection = connection_mt:__new { regs = { { idx, handlers } }, fn = handler }
        handlers[idx] = connection
        return connection
    end,

    disconnect = function(self, connection)
        return connection:remove()
    end,

    get_state = function(self, state_name) -- 会转发
        local self_states = rawget(self, '__state')
        local self_state
        if self_states == nil then
            self_state = get_class_state(self, state_name)
        else
            self_state = rawget(self_states, state_name) or get_class_state(self, state_name)
        end
        if self_state == nil and is_component_ctrl(self.base) then
            return self.base:get_state(state_name)
        end
        return self_state -- 状态为nil 表示状态未初始化
    end,

    set_state = function(self, state_name, v) -- 会转发
        local current_state = self:get_state(state_name)
        if current_state == v then
            return -- 已经在该状态
        end

        local self_states = rawget(self, '__state')
        local class = rawget(self, '__class')
        local states = rawget(class, 'state')
        if states == nil then
            if is_component_ctrl(self.base) then
                self.base:set_state(state_name, v)
            end
            return
        end
        local state_ = states[state_name]
        if state_ == nil then
            if is_component_ctrl(self.base) then
                self.base:set_state(state_name, v)
            end
            return
        end
        local state_def = rawget(state_, v)
        if state_def == nil then
            if is_component_ctrl(self.base) then
                self.base:set_state(state_name, v)
            end
            return
        end

        if self_states == nil then
            self_states = {}
            rawset(self, '__state', self_states)
        end

        -- do trans
        if type(state_def) == 'function' then
            local entry_action = state_def
            entry_action(self, current_state, v)
        end
        rawset(self_states, state_name, v)
    end,

    select = function(self, selector_str) -- 不转发（转发的话要考虑的情况很多，用户不易控制）
        local selector = self.__selector[selector_str]
        if not selector then
            selector = build_selector(parse_simple_selector_info(selector_str), self)
            self.__selector[selector_str] = selector
        end
        return selector
    end,

    destroy = function(self) -- 转发
        if rawget(self, '__not_valid') == 1 then
            return
        end

        -- destroy all ctrl
        local base = self.base
        if is_component_ctrl(base) then
            base:destroy()
        else
            base:remove()
        end

        rawset(self, '__not_valid', 1)

        -- remove all ref, all selector will be invalid
        unregister_part(self)
        -- todo
        -- 1) destroy on bibind callback?
        -- 2) destroy on event callback?
        -- 3) destroy on animation callback?
    end,
}

local table_prop_base = prototype
local component_base_prop_base = prototype
local instance_table_prop_base

local function is_table_prop(t)
    return getmetatable(t) == instance_table_prop_base or rawget(t, '__type') == 'props'
end

local function get_table_from_table_prop(tp)
    if not is_table_prop(tp) then
        return tp
    end
    local out = {}
    tp = tp.__prop or tp
    local tps = { tp }
    while tp do
        tp = getmetatable(tp)
        table.insert(tps, tp)
    end
    for i = #tps - 1, 1, -1 do
        local tp = tps[i]
        for key, v in pairs(tp) do
            if type(key) == 'string' and (string_begin_with(key, '__')) then
                goto CONTINUE
            end
            if type(v) == 'table' then
                out[key] = get_table_from_table_prop(v)
            else
                out[key] = v
            end
            ::CONTINUE::
        end
    end
    return out
end

local prop_name_list_pool = gui_utils.create_list_pool()
local function get_table_prop_prop_name(self, new_key)
    local prop_name = rawget(self, '__prop_name')
    if prop_name == nil then
        local owner = self
        local temp = {}
        while owner do
            table.insert(temp, rawget(owner, '__key'))
            owner = rawget(owner, '__owner')
        end
        prop_name = {}
        for i = #temp, 1, -1 do
            table.insert(prop_name, temp[i])
        end
        local prop_name_str
        if #prop_name == 0 then
            prop_name_str = ''
        else
            prop_name_str = table.concat(prop_name, '_') .. '_'
        end
        rawset(self, '__prop_name', prop_name) -- cached
        prop_name.__prop_name_str = prop_name_str
    end
    local _prop_name_list = prop_name_list_pool()
    local new_len = 0
    if #prop_name == 0 then
        new_len = 1
    else
        table.move(prop_name, 1, #prop_name, 1, _prop_name_list)
        new_len = #prop_name + 1
    end
    _prop_name_list[new_len] = new_key
    _prop_name_list:resize(new_len)

    return _prop_name_list, prop_name.__prop_name_str
end

instance_table_prop_base = {
    __owner = nil, -- 所属的table
    __key = nil,   -- 所属的key
    __prop = nil,  -- 实际的属性
    __ctrl = nil,  -- 所属控件
    __len = function(self)
        return #(self.__prop)
    end,
    __pairs = function(self)
        return pairs(self.__prop)
    end,
    __newindex = function(self, new_key, value)
        local forward_to_base
        local self_props = self.__prop
        local self_prop = self_props[new_key]
        if self_prop == nil then -- 未定义的key，向基组件/内置控件转发
            forward_to_base = true
        else
            if self_prop == value then -- 赋相同的值不再处理(getset除外)
                return
            end
        end

        local ctrl = self.__ctrl

        if type(self_prop) == 'table' then
            if self_prop.__prop then
                self_prop = self_prop.__prop
            end
            local t = rawget(self_prop, '__type')
            if t == 'getset' then -- handle get-set prop
                -- set 默认不触发 on_prop_change 事件，由 set 返回值决定是否触发
                local emit_change_event = self_prop.set(ctrl, value, self_prop, new_key)
                if emit_change_event then
                    goto EMIT
                end
                return
            end
        end
        if forward_to_base then
            local prop_name = get_table_prop_prop_name(self, new_key)
            set_ctrl_prop(ctrl.base, prop_name, value) -- 递归
            prop_name:release()
            return
        else
            rawset(self_props, new_key, value)
        end
        ::EMIT::
        local prop_name, prop_name_str = get_table_prop_prop_name(self, new_key)
        -- 触发事件与绑定
        dispatch_event(ctrl, 'on_prop_change_' .. prop_name_str .. new_key, value)
        dispatch_event(ctrl, 'on_prop_change', prop_name, value)
        dispatch_bibind(ctrl, prop_name, value)
        prop_name:release()
    end,
    __index = function(self, new_key)
        local self_props = self.__prop
        local self_prop = self_props[new_key]
        local ctrl = self.__ctrl
        if self_prop == nil then -- 未定义的key，尝试从基组件/内置控件获取
            local prop_name = get_table_prop_prop_name(self, new_key)
            local prop = get_ctrl_prop(ctrl.base, prop_name)
            prop_name:release()
            return prop
        end

        if type(self_prop) == 'table' then
            local t = rawget(self_prop, '__type')
            if t == 'getset' then -- handle get-set prop
                return self_prop.get(ctrl, self_prop, new_key)
            end
            if t == 'props' then -- 获取的是模板表属性，创建prop包装
                local sub_table_prop = setmetatable({
                    __prop = self_prop:__new {},
                    __owner = self_props,
                    __key = new_key,
                    __ctrl = ctrl,
                }, instance_table_prop_base)
                rawset(self_props, new_key, sub_table_prop)
                return sub_table_prop
            end
        end
        return self_prop
    end,
}

local component_base = {
    __newindex = function(self, new_key, value)
        if new_key == 'parent' then -- 特殊处理
            self.ui.__component_parent = value
            return
        end
        -- 选择器
        if is_selector_str[new_key] then
            self:select(new_key):set(value)
            return
        end
        -- 属性
        self.prop[new_key] = value
    end,

    __index = function(self, new_key)
        if new_key == 'parent' then -- 特殊处理
            return self.ui.__component_parent or self.ui.parent
        end
        -- 自身方法
        local method = self.method[new_key]
        if type(method) == 'function' then
            return method
        end
        -- 基类方法
        local target = self.base
        while is_component_ctrl(target) do
            method = target.method[new_key]
            if type(method) == 'function' then
                return function(that, ...)
                    if that == self then
                        return method(target, ...)
                    end
                    return method(that, ...)
                end
            end
            target = target.base
        end
        -- 返回空方法
        if default_method_name_map[new_key] then
            return empty_function
        end
        -- 选择器
        if is_selector_str[new_key] then
            return self:select(new_key):get()
        end
        -- 属性
        return self.prop[new_key]
    end,
}
module_control_util.component_ctrl_mt = component_base

local function create_component(template, bind, parent)
    local com
    local com_class = rawget(template, '__class')
    if com_class then
        com = com_class:new(nil, template, bind, false, parent)
    else
        error('不是有效的模板对象')
        --com = template:new(nil, nil, bind)
    end
    --return com, nil, true
    return com.ui, nil, true -- 组件对象不插入控件树
end

local function new(any, ...) -- 当 template 的 new 被覆盖掉时可以用该方法
    if any == nil then
        return
    end
    if is_component_template(any) then
        return rawget(any, '__class'):new(nil, any)
    end
    return base.ui.create(any)
end

local component_template_mt = {
    new = function(self)
        return rawget(self, '__class'):new(nil, self)
    end
}
component_template_mt.__index = component_template_mt

local function create_component_template(component_class, t)
    rawset(t, '__class', component_class)
    rawset(t, '__ui_type', rawget(component_class, '__ui_type'))
    setmetatable(t, component_template_mt)
    return t
end

local component_class_base_event = prototype:__new {
    on_tick = true,
    on_remove = true,
    -- on_prop_changed = true,
}

local event_mt = {
    __index = function(self, k)
        local evt_map = self.__connections
        if evt_map[k] then
            return evt_map[k].fn
        end
        evt_map = get_ctrl_prop(self.__target.ui, { 'event' }) or {}
        return evt_map[k]
    end,
    __newindex = function(self, k, v)
        if is_defined_event(self.__target, k) then
            local evt_map = self.__connections
            if evt_map[k] then
                self.__target:disconnect(evt_map[k])
            end
            evt_map[k] = self.__target:connect(k, v)
        else
            self.__target.ui:subscribe(k)
            if not self.__target.ui.event then
                self.__target.ui.event = {}
            end
            self.__target.ui.event[k] = v
        end
    end,
    __pairs = function(self)
        return pairs(get_ctrl_prop(self.__target.ui, { 'event' }) or {})
    end,
}


local component_class_base_prototype = prototype:__new {
    __call = function(self, s_or_t)    -- 返回模板对象
        if type(s_or_t) == 'string' then
            local part_tags = { s_or_t } --string.split(s_or_t, ';')
            return function(t)
                t.__part_tags = part_tags
                return create_component_template(self, t)
            end
        end
        local t = s_or_t
        return create_component_template(self, t)
    end,

    rename = function(self, new_name) -- 重命名, 记录老名字的模板在老名字没有被占用前任然有效
        -- if self.__ui_type == new_name then
        --     return
        -- end
        -- print('修改组件名 '..self.__ui_type..' -> '..new_name)
        self.__ui_type = new_name
        self.name = new_name
    end,

    __create = function(self, instance_name, bind, override_template, parent)
        local e = setmetatable({
            __class = self,
            __part = {},
            __selector = {},
            class = self,
            child = {}, -- 不转发
            connection = {},
        }, component_base)
        rawset(e, 'state', setmetatable({}, {
            __index = function(self, k)
                return e:get_state(k)
            end,
            __newindex = function(self, k, v)
                e:set_state(k, v)
            end,
        }))

        local template = rawget(self, 1)
        -- 从模板创建控件实例
        push_creating_component(e)
        local ui, bind_helper = base.ui.create(template, instance_name, nil)
        pop_creating_component()
        rawset(e, 'ui', ui)
        rawset(e, 'bind', bind_helper)

        -- 处理组件链
        -- 覆写性: 通过 get_final_ext_component() 访问最终子类
        local component_chain = rawget(ui, '__component_chain')
        if component_chain == nil then
            rawset(ui, '__ext', e)
            rawset(e, 'base', ui)
            component_chain = { e }
            rawset(ui, '__component_chain', component_chain)

            -- 注册默认事件与处理函数
            local remove_tick
            remove_tick = ui:on_tick(function(delta)
                local ctrl = get_final_ext_component(e)
                local update = ctrl.update
                if update == empty_function then -- 提前判不了，就写在这了
                    return remove_tick()
                end
                update(ctrl, delta) -- 这个由update的实现控制是否覆写
            end)
            rawset(ui, 'on_remove', function()
                local ctrl = get_final_ext_component(e)
                while is_component_ctrl(ctrl) do
                    ctrl:emit('on_remove')
                    ctrl = self.base
                end
            end)
        else
            local base = component_chain[#component_chain]
            rawset(base, '__ext', e)
            rawset(e, 'base', base)
            table.insert(component_chain, e)
        end

        -- 处理控件引用表，将自己设置到父组件的引用表中
        if override_template then
            local cc = get_owner_component(parent) or creating_components_stack[#creating_components_stack]
            local com_node = override_template.__component_node
            if cc and com_node then
                register_as_component_part(e, cc, base.ui.deep_copy(com_node))
            end
            if type(override_template.bind) == 'table' and bind then
                for key, value in pairs(override_template.bind) do
                    bind.watch[key] = function(self, k, v)
                        if v then
                            set_ctrl_prop(e, { key, k }, v)
                        else
                            e.prop[key] = k
                        end
                    end
                end
            end
        end

        -- part 不转发
        rawset(e, 'part', e.__part)
        -- method 转发
        rawset(e, 'method', self.method:__new {})
        -- data 不转发
        if type(self.data) == 'function' then
            rawset(e, 'data', self.data())
        else
            rawset(e, 'data', self.data:__new {})
        end

        local inst_prop = self.prop:__new {}
        -- 构建需要构建的属性（主要是 alias）
        local need_build_props = rawget(self, '__need_build_prop')
        if need_build_props ~= nil then
            for key, value in pairs(need_build_props) do
                inst_prop[key] = value:build(e, key)
            end
        end
        -- prop 转发 (instance_table_prop_base 中处理)
        rawset(e, 'prop', setmetatable({ __ctrl = e, __prop = inst_prop }, instance_table_prop_base))
        -- 事件
        rawset(e, 'event', setmetatable({ __type = 'event_mt', __target = e, __connections = {} }, event_mt))
        if override_template and type(override_template) == 'table' and override_template.event and type(override_template.event) == 'table' then
            for k, v in pairs(override_template.event) do
                e.event[k] = v
            end
        end

        -- 执行创建后任务(注册绑定)
        local on_created_tasks = rawget(self, '__on_created_task')
        if on_created_tasks ~= nil then
            for _, task in ipairs(on_created_tasks) do
                task(e)
            end
        end
        -- 派发被绑定属性的初值
        for prop_name_str, prop_name in pairs(self.__need_dispatch_props) do
            local ext_idx = self.__prop_def_table[prop_name[1]]
            local target = ext_idx and component_chain[ext_idx] or ui
            local prop = get_ctrl_prop(target, prop_name)
            if prop == nil then
                goto CONTINUE
            end
            prop = (type(prop) == 'table' and get_table_from_table_prop(prop) or prop)

            dispatch_bibind(target, prop_name, prop)
            ::CONTINUE::
        end

        if self.__props_with_template_default then
            for i, key in ipairs(self.__props_with_template_default) do
                if ui[key] then
                    e.prop[key] = ui[key]
                end
            end
        end
        if self.__props_with_default then
            for prop, default_value in pairs(self.__props_with_default) do
                e.prop[prop] = default_value
            end
        end

        local state = self.state
        if state then
            for key, value in pairs(state) do
                local default = value.__default
                if default then
                    e:set_state(key, default)
                end
            end
        end

        return e
    end,

    new = function(self, instance_name, t, bind, skip_init, parent)
        local e = self.__create(self, instance_name, bind, t, parent)

        -- 根据模板进行属性应用/创建子控件
        if t then
            for index, value in ipairs(t) do
                e:new_child(value, nil, bind)
            end
            for key, value in pairs(t) do
                local type_of_key = type(key)
                if key == 'event' then
                    value = base.ui.deep_copy(value)
                end
                if type_of_key == 'string' then
                    if string_begin_with(key, '__') and not string_begin_with(key, '__EDIT_TIME') then
                        goto CONTINUE
                    end
                    if not is_selector_str[key] then
                        e.prop[key] = value
                    else
                        e:select(key):set(value)
                    end
                end
                ::CONTINUE::
            end
        end

        if skip_init == nil or skip_init == false then
            e.method.init(e, t)
        end

        rawset(e, '__is_inited', true)
        return e
    end,

    -- inherit = function(self, sub)
    --     return getmetatable(getmetatable(self)).new(self, sub)
    -- end
}

--region prop wrapper----------------------------------------------------------

local E, type, pairs, next, setmetatable = {}, type, pairs, next, setmetatable

---@class _proxy_prop_type
---@field merge boolean
---@field constructor fun()
---@field children table<string, _proxy_prop_type>

---@class _proxy_prop_data
---@field proxy table
---@field target table
---@field old_target table
---@field disable boolean
---@field children table<string, _proxy_prop_data>

---@param parent_prop_data _proxy_prop_data
---@return _proxy_prop_data
local function get_sub_proxy_prop_data(parent_prop_data, child_name, old_target)
    local prop_data = parent_prop_data.children[child_name]
    if not prop_data or old_target then
        prop_data = { name = child_name, target = {}, children = {}, old_target = old_target }
        parent_prop_data.target[child_name] = prop_data.target
        parent_prop_data.children[child_name] = prop_data
        return prop_data
    end
    return prop_data, true
end

local get_proxy_prop

---@param parent_prop_data _proxy_prop_data
---@param prop_type _proxy_prop_type
local function set_proxy_prop(parent_prop_data, prop_type, new_value, first_call)
    local prop_name = prop_type.name
    local prop_data, old = get_sub_proxy_prop_data(parent_prop_data, prop_name)
    if parent_prop_data.disable or new_value == prop_data.target or new_value and new_value == prop_data.proxy then
        return true
    end
    new_value = prop_type.constructor(new_value)
    if not new_value then
        return false
    end
    if first_call and old then
        prop_data = get_sub_proxy_prop_data(parent_prop_data, prop_name, prop_data.target)
    else
        prop_data.old_target = (parent_prop_data.old_target or E)[prop_name] or E
    end
    local merge = prop_type.merge
    local children = prop_type.children
    local new_target = prop_data.target
    for k, v in pairs(prop_data.old_target) do
        local child_prop_type = children[k]
        if child_prop_type and not new_value[k] then
            set_proxy_prop(prop_data, child_prop_type, v)
        elseif merge then
            new_target[k] = v
        end
    end
    for k, v in pairs(new_value) do
        local child_prop_type = children[k]
        if child_prop_type then
            set_proxy_prop(prop_data, child_prop_type, v)
        else
            new_target[k] = v
        end
    end
    return true
end

---@param prop_type _proxy_prop_type
---@param parent_prop_data _proxy_prop_data
get_proxy_prop = function(parent_prop_data, prop_type)
    local prop_name = prop_type.name
    local prop_data = get_sub_proxy_prop_data(parent_prop_data, prop_name)
    local proxy = prop_data.proxy
    if proxy then
        return proxy
    end
    local target = prop_data.target
    local children = prop_type.children
    prop_data.proxy = setmetatable({}, {
        __len = function()
            return #target
        end,
        __pairs = function()
            return pairs(target)
        end,
        __index = function(proxy, k)
            local child_prop_type = children[k]
            if not child_prop_type then
                return target[k]
            end
            return get_proxy_prop(prop_data, child_prop_type), 1
        end,
        __newindex = function(proxy, k, v)
            local child_prop_type = children[k]
            if not child_prop_type then
                target[k] = v
            elseif not set_proxy_prop(prop_data, child_prop_type, v, true) then
                return
            end
            if parent_prop_data.children[prop_name] == prop_data then
                parent_prop_data.disable = true
                parent_prop_data.proxy[prop_name] = prop_type.merge and { [k] = v } or target
                parent_prop_data.disable = false
            end
        end,
    })
    return prop_data.proxy
end

local init_prop_type

---@param prop_type _proxy_prop_type
local function create_proxy_prop(prop_name, prop_type)
    prop_type = init_prop_type(prop_name, prop_type)
    local function get_root_prop_data(self)
        local prop_data = self.data.prop_data
        if not prop_data then
            prop_data = { name = 'root', target = self.ui, proxy = self, children = {} }
            self.data.prop_data = prop_data
        end
        return prop_data
    end
    return getset {
        get = function(self)
            return get_proxy_prop(get_root_prop_data(self), prop_type), 1
        end,
        set = function(self, value)
            if set_proxy_prop(get_root_prop_data(self), prop_type, value, true) then
                local ui = self.ui
                local old_value = ui[prop_name]
                set_ctrl_prop(ui, prop_name, value)
                ui[prop_name] = old_value
                return true
            end
        end,
        __need_set_template_default = true
    }
end

local function default_constructor(value)
    if value == nil then
        return {}
    end
    if type(value) == 'table' then
        return value
    end
end

local function border_constructor(value)
    if value == nil then
        return {}
    end
    local t = type(value)
    if t == 'number' then
        return { left = value, right = value, top = value, bottom = value }
    elseif t == 'table' then
        return value
    end
end

---@param prop_type _proxy_prop_type
init_prop_type = function(prop_name, prop_type)
    prop_type = prop_type or {}
    prop_type.name = prop_name
    prop_type.children = prop_type.children or {}
    prop_type.constructor = prop_type.constructor or default_constructor
    for k, v in pairs(prop_type.children) do
        init_prop_type(k, v)
    end
    return prop_type
end

local function create_layout_prop_wrapper()
    return create_proxy_prop('layout', {
        merge = true,
        children = {
            position = {},
            relative = {},
            padding = {
                constructor = border_constructor,
            },
            margin = {
                constructor = border_constructor,
            },
            test = {
                merge = true,
            }
        }
    })
end

local function create_font_prop_wrapper()
    return create_proxy_prop('font', {
        merge = true,
    })
end

local function create_border_prop_wrapper()
    return create_proxy_prop('border', {
        constructor = border_constructor,
    })
end

local function create_array_prop_wrapper()
    return create_proxy_prop('Array', {
        merge = true,
    })
end

local function create_transition_prop_wrapper()
    return create_proxy_prop('transition', {
        merge = true,
        children = {
            position = { children = { func = {} }, merge = true },
            show = { children = { func = {} }, merge = true },
            scale = { children = { func = {} }, merge = true },
            size = { children = { func = {} }, merge = true },
            rotate = { children = { func = {} }, merge = true },
            opacity = { children = { func = {} }, merge = true },
            progress = { children = { func = {} }, merge = true },
        }
    })
end

--endregion prop wrapper-------------------------------------------------------

local g_current_component_type = {}
local default_child_slot = {}

local function component_impl(o)
    o.__ui_type = g_current_component_type[#g_current_component_type]
    g_current_component_type[#g_current_component_type] = nil
    o.name = o.__ui_type
    o.__is_component_class = 1
    o.__template_metadata = {
        bind = {},
        bibind = {},
        alias = {},
    }
    o.__need_dispatch_props = {}
    o.prop = o.prop or {}

    -- 实例创建后执行的任务
    local on_created_tasks = {

    }

    -- 处理模板定义
    local template = rawget(o, 1)
    if template == nil then
        -- local flatten_template = rawget(o, 'flatten_template')
        -- if flatten_template then
        --     -- 是由编辑器生成的模板
        --     local ctrl_templates = {}
        --     local parent_indices = {}
        --     for i = 1, #flatten_template, 2 do
        --         table.insert(ctrl_templates, flatten_template[i])
        --         table.insert(parent_indices, flatten_template[i+1])
        --     end
        --     for i, t in ipairs(ctrl_templates) do
        --         local parent_idx = parent_indices[i]
        --         if parent_idx == 0 then
        --             goto CONTINUE
        --         end
        --         table.insert(ctrl_templates[parent_idx], t)
        --     ::CONTINUE::
        --     end
        --     template = ctrl_templates[1]
        --     rawset(o, 1, template)
        -- else
        template = base.ui.panel {}    -- 默认根模板，后面改成slot?
        rawset(o, 1, template)
        -- end
    end

    local queue = { template }
    local queue_parent = { 0 }
    local queue_begin = 1
    while queue_begin <= #queue do
        local t = queue[queue_begin]
        if is_component_class(t) then
            error('不能使用组件类作为模板，请使用 com{ ... }')
        end
        local part_idx = queue_begin

        local is_builtin_ctrl_template = false
        if t.__ui_type == '__SLOT__' then
        elseif t.__ui_type == '__ARRAY__' then
        elseif t == default_child_slot then
            -- 记录 parent part_idx
            o.default_child_pos = queue_parent[part_idx]
            local pt = queue[o.default_child_pos]
            for i, value in ipairs(pt) do
                if value == t then
                    table.remove(pt, i)
                    break
                end
            end
            --     goto CONTINUE3
        elseif getmetatable(t) == component_template_mt then
        elseif t.__component then
            -- 老组件
        elseif t.__ui_type == nil then
            error('不是组件/控件模板')
        else
            is_builtin_ctrl_template = true
        end

        t.__part_tags = t.__part_tags or {}
        local part_tags = t.__part_tags
        table.insert(part_tags, t.name) --or 'UNNAMED')

        for key, value in pairs(t) do
            if type(key) == 'string' then
                if string_begin_with(key, '__') or type(value) ~= 'table' then
                    goto CONTINUE
                end
                -- sub table
                iterate_table_recursively_bf(value, function(sub_key, value, parent, queue)
                    if type(value) == 'table' then
                        local typename = rawget(value, '__type')
                        local has_bind_mt = getmetatable(value) == bind_mt
                        if has_bind_mt or typename == 'need_build_prop' then
                            local prop_name = value
                            setmetatable(prop_name, nil) -- 不再需要元表
                            -- 从模板中剔除 bind 数据
                            if parent then
                                parent[3][sub_key] = nil
                            else
                                if (is_builtin_ctrl_template and key == 'array') then
                                    t[key] = 0 -- 特殊处理 array
                                else
                                    t[key] = nil
                                end
                            end
                            -- 如果属性绑定/引用到自身则忽略（多余的行为）
                            if part_idx == 1 and has_bind_mt and key == prop_name[1] and o.prop[key] == nil then
                                -- log_file.warn(('多余的bind/alias %s'):format(key))
                                return false -- break iteration
                            end

                            -- build selector info
                            local key_chain = { sub_key }
                            while parent do
                                local parent_idx = parent[1]
                                local key = parent[2]
                                if key == nil then
                                    break
                                end
                                table.insert(key_chain, key)
                                parent = queue[parent_idx]
                            end
                            local selector_info = { '@', part_idx, key }
                            for i = #key_chain, 1, -1 do
                                table.insert(selector_info, key_chain[i])
                            end

                            local prop_name_str = table.concat(prop_name, '.')
                            if has_bind_mt and typename ~= 'alias' then
                                o.__need_dispatch_props[prop_name_str] = prop_name
                            end

                            if __lua_state_name ~= 'StateGame' then
                                -- 非游戏环境下，记录下bind的元数据（用于UI编辑器属性面板）
                                local metadata = o.__template_metadata[typename]
                                if metadata[prop_name_str] == nil then
                                    metadata[prop_name_str] = {}
                                end
                                metadata[prop_name_str][table.concat({ part_idx, key, table.unpack(key_chain) }, '.')] = true
                                -- print(prop_name_str..' <=> '..table.concat({part_idx, key, table.unpack(key_chain)}, '.'))
                            end

                            if typename == 'alias' then
                                local def = o.prop[prop_name[1]]
                                local alias_prop = alias_from_selector_info(selector_info)
                                o.prop[prop_name[1]] = alias_prop
                                alias_prop.__default = def
                            elseif typename == 'need_build_prop' then
                                table.insert(on_created_tasks, function(ctrl)
                                    value.build(ctrl, selector_info)
                                end)
                            else
                                local register_bindness = (typename == 'bibind' and register_bibind or register_bind)
                                -- 保证优先执行，否则alias初值可能不会传递
                                table.insert(on_created_tasks, 1, function(ctrl)
                                    local selector = build_selector(selector_info, ctrl)
                                    register_bindness(ctrl, prop_name, selector)
                                end)
                            end
                            return false -- break iteration
                        end
                    end
                    return true
                end)
            elseif type(key) == 'number' then
                table.insert(queue, value)
                table.insert(queue_parent, part_idx)
            end
            ::CONTINUE::
        end

        rawset(t, '__component_node', { -- 模板数据都放在这里
            part_idx = part_idx,
            part_tags = part_tags,
        })

        queue_begin = queue_begin + 1
    end
    o.__part_count = queue_begin - 1

    if is_component_template(template) then
        o.__base_class = template.__class
        o.__ext_idx = o.__base_class.__ext_idx + 1
        o.__prop_def_table = o.__base_class.__prop_def_table:__new {}
    else
        o.__ext_idx = 1
        o.__prop_def_table = prototype:__new {}

        -- 几个复合属性
        if not o.prop.layout then
            o.prop.layout = create_layout_prop_wrapper()
        end
        if not o.prop.border then
            o.prop.border = create_border_prop_wrapper()
        end
        if not o.prop.font and (template.__ui_type == 'label' or template.__ui_type == 'input') then
            o.prop.font = create_font_prop_wrapper()
        end
        if not o.prop.Array and (template.__ui_type == 'panel') then
            o.prop.Array = create_array_prop_wrapper()
        end
        if not o.prop.transition then
            o.prop.transition = create_transition_prop_wrapper()
        end
        if not o.prop.Name then
            o.prop.Name = getset {
                get = function(self)
                    return self.name
                end,
                set = function(self, value)
                    self.name = value
                end,
            }
        end
    end

    for key, _ in pairs(o.prop) do
        if key == 'bind' then
            log_file.warn('请避免ui组件的属性名为 bind')
        end
        o.__prop_def_table[key] = o.__ext_idx
    end

    -- 收集需要在创建时构建的属性
    -- 需要构建的一般是要在创建时才能固定的属性：例如 alias
    local props_with_template_default = {}
    local props_with_default = {}
    local need_build_props = {}
    for key, value in pairs(o.prop) do
        if type(value) == 'table' then
            if value.__need_set_template_default then
                props_with_template_default[#props_with_template_default + 1] = key
            end
            if value.__default ~= nil and (value.__type == 'alias' or value.__type == 'getset') then
                props_with_default[key] = value.__default
            end
            if type(rawget(value, 'build')) == 'function' then
                need_build_props[key] = value -- 目前主要是 alias
                goto CONTINUE2
            end
        end
        ::CONTINUE2::
    end
    if next(need_build_props) ~= nil then
        o.__need_build_prop = need_build_props
    end
    if next(on_created_tasks) ~= nil then
        o.__on_created_task = on_created_tasks
    end
    if next(props_with_template_default) ~= nil then
        o.__props_with_template_default = props_with_template_default
    end
    if next(props_with_default) ~= nil then
        o.__props_with_default = props_with_default
    end

    o.prop = component_base_prop_base:__new(o.prop)

    -- 处理逻辑定义
    o.method = component_method_base_prototype:__new(o.method)

    -- 数据
    o.data = type(o.data) == 'function' and o.data or prototype:__new(o.data)

    -- 状态
    o.state = prototype:__new(o.state)

    -- 事件
    o.event = component_class_base_event:__new(o.event)

    local component_class = component_class_base_prototype:__new(o)
    return component_class
end

local function legacy_bind_prop(str)
    return getset {
        get = function(self)
            return self.bind[str]
        end,
        set = function(self, value)
            self.bind[str] = value
        end
    }
end

local function create_template_mt(typename)
    return prototype:__new {
        __type = typename,
        __call = function(self, str_or_props)
            if type(str_or_props) == 'string' then
                return function(props)
                    props.__part_tags = { str_or_props }
                    props.__ui_type = self.__type
                    return props
                end
            end
            str_or_props.__ui_type = self.__type
            return str_or_props
        end
    }
end

local function create_slot(template, bind, parent)
    local slot_obj = {
        __type = 'slot',
        __not_ui = true,        -- not added to parent's child
        parent = parent,
        remove = function(self) -- from ui_ctrl:remove
            -- body
            unregister_part(self)
        end,
    }
    -- if #template then
    -- end

    -- 注册到引用表
    local cc = get_owner_component(parent) or creating_components_stack[#creating_components_stack]
    if cc then
        register_as_component_part(slot_obj, cc, base.ui.deep_copy(template.__component_node))
    end

    return slot_obj, nil, true
end
local slot = base.ui.template(create_slot, '__SLOT__')

local function create_array(template, bind, parent)
    local e = {
        __type = 'array',
        __not_ui = true, -- not added to parent's child
        parent = parent,
        elems = {},
        remove = function() -- from ui_ctrl:remove
            -- body
        end
    }
    local cc = get_owner_component(parent) or creating_components_stack[#creating_components_stack]
    if cc == nil then
        return nil
    end

    e.set = function(o)
        if type(o) ~= 'number' then
            return
        end
        local size = #(e.elems)
        if o == size then
            return
        end
        if o > size then
            local inc = o - size
            for i = 1, inc do
                local elem = {}
                for j, t in ipairs(template) do
                    local ctrl = get_final_ext_component(base.ui.create(t, nil, bind))
                    local p = e.parent
                    -- while p do -- todo array{array{}}
                    --     if getmetatable(p) == base.ui.mt then
                    --         break
                    --     end
                    --     p = p.parent
                    -- end
                    if p then
                        move_to_new_parent(ctrl, p) -- 暂不处理创建位置
                    end
                    table.insert(elem, ctrl)
                end
                table.insert(e.elems, elem)
            end
        else
            for i = size, o, -1 do
                local elem = e.elems[i]
                for _, ctrl in ipairs(elem) do
                    if is_component_ctrl(ctrl) then
                        ctrl:destroy()
                    else
                        ctrl:remove()
                    end
                end
                table.remove(e.elems, i)
            end
        end
    end
    e.get = function()
        return #(e.elems)
    end

    -- 注册到引用表
    register_as_component_part(e, cc, base.ui.deep_copy(template.__component_node))

    e.set(template.default)

    return e, nil, true
end
local array = base.ui.template(create_array, '__ARRAY__')

local call_mt
if __lua_state_name == 'StateGame' then
    call_mt = {
        __call = function(self, ...)
            local c = self.client
            local s = self.server
            if s then
                base.game:server 'call_ui_response' {
                    id = s,
                    args = ...,
                }
            end
            if c then
                local fn = require(c)
                if type(fn) == 'function' then
                    local event_name = self.event_name
                    local ctrl = get_final_ext_component(base.ui.map[self.id])
                    if event_name == 'on_drag' or event_name == 'on_throw' then
                        return fn(ctrl)
                    end
                    if event_name == 'on_dropped' then
                        local source = get_final_ext_component(base.ui.map[...])
                        return fn(ctrl, source)
                    end
                    if event_name == 'on_drop' then
                        local target = get_final_ext_component(...)
                        return fn(ctrl, target)
                    end
                    if event_name then
                        return fn(ctrl, ...)
                    end
                    return fn(...)
                else
                    log.error('加载UI事件' .. c .. '失败！')
                end
            end
        end,
    }
else
    call_mt = {
        __call = function(self, ...)
            -- log_file.warn('"call" only work in Game context')
        end
    }
end
call_mt.__index = call_mt
call_mt[dumper.DUMP] = function(self)
    local mt = getmetatable(self)
    setmetatable(self, nil)
    local str = 'call' .. dumper.dump(self, 0, -1, function(k, v)
        if k == '__type' then
            return
        end
        return k, v
    end)
    setmetatable(self, mt)
    return str
end

-- call{ server = <id>, client = 'url...' }
local function call(o)
    o.__type = 'call'
    return setmetatable(o, call_mt)
end

local g_component_dummy_name = 0

return setmetatable({
    slot = slot,
    array = array,
    getset = getset,
    alias = alias,
    alias_by = alias_by,
    key_frame_state = key_frame_state_info,
    anim_trans = anim_trans,
    bind = bind,
    bibind = bibind,
    legacy_bind_prop = legacy_bind_prop,
    -- NULL = {},
    call = call,
    new = new,
    destroy = destroy_ctrl,
    default_child_slot = default_child_slot,
    struct_prop = function(v)
        v.__type = 'props'
        table_prop_base:__new(v)
        return v
    end,
}, {
    __call = function(self, obj_or_str)
        if type(obj_or_str) == 'table' then
            g_component_dummy_name = g_component_dummy_name + 1
            g_current_component_type[#g_current_component_type + 1] = '__unnamed_gui_type' .. g_component_dummy_name
            return component_impl(obj_or_str)
        elseif type(obj_or_str) == 'string' then
            g_current_component_type[#g_current_component_type + 1] = obj_or_str
            return component_impl
        end
        return nil
    end
})
