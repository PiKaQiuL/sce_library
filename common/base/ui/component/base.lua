include 'class'
local type = type
local pairs = pairs
local table_sort = table.sort
local table_concat = table.concat
local setmetatable = setmetatable
local ac_bind = base.bind
local log_error = log.error
local ac_ui_create = base.ui.create

local empty_func = function() end
---使用bind_heler的次数
local bind_helper_count = 0
---缓存helper表
local bind_helper_cache = {}
---更简单地使用bind
local bind_helper = setmetatable({}, {
    __newindex = empty_func,
    __index = function(_, key)
        bind_helper_count = bind_helper_count + 1
        if not bind_helper_cache[key] then
            bind_helper_cache[key] = { __bind_name = key }
        end
        return bind_helper_cache[key]
    end
})

---生成平常使用的bind方式， 若bind中已定义了某个bind，则会被覆盖
local function bind_helper_build(template)
    if bind_helper_count == 0 then return end
    bind_helper_count = 0

    local function bind_helper_build_impl(template)
        if type(template) ~= 'table' then
            return
        end
        local bind = template.bind or {}
        template.bind = bind
        for k, v in pairs(template) do
            if type(k) == 'number' then
                -- 递归子ui
                bind_helper_build_impl(v)
            elseif type(v) == 'table' then
                if v.__bind_name then
                    template[k] = nil
                    bind[k] = v.__bind_name
                    if k == 'array' then
                        template[k] = 0 -- array属性必须要有初值
                    end
                else
                    -- 二级属性
                    for vk, vv in pairs(v) do
                        if type(vv) == 'table' and rawget(vv, '__bind_name') then
                            if not bind[k] then
                                bind[k] = {}
                            end
                            v[vk] = nil
                            bind[k][vk] = vv.__bind_name
                        end
                    end
                end
            end
        end

        -- 若没有key，就设空
        for k, v in pairs(bind) do
            return
        end
        template.bind = nil
    end
    bind_helper_build_impl(template)
end

---深度合并from的k对应的值到to里，对于没有的table会浅拷贝，有的table进行合并
local function merge_table_key(from, k, to)
    local changed = false
    -- 假定fv不为nil
    local fv, tv = from[k], to[k]
    if type(fv) ~= type(tv) or type(fv) ~= 'table' then
        to[k] = fv
        changed = true
    else
        -- fv和tv都是table
        for k, _ in pairs(fv) do
            changed = merge_table_key(fv, k, tv) or changed
        end
    end
    return changed
end

local BaseComponent = class('base_component')

function BaseComponent:__create(out_props, bind)
    if type(out_props) ~= 'table' then
        self:__error('have no props.')
    end
    if type(self.define) ~= 'function' then
        self:__error('have no define function.')
    end

    -- 保存传进来的参数
    self:__set_instantiation_args(out_props)

    -- 获取out_props的children
    self:__set_children(out_props)

    -- 可以在define中使用bind_helper
    self.bind = bind_helper

    -- 用户定义props, template和一些成员变量
    self:define()

    self.__props_define = self.props or {}
    if type(self.template) ~= 'table' then
        self:__error('[name:', out_props.name or 'unknow', '] have no tempalte.')
    end

    self:after_define()

    -- template中的bind处理
    bind_helper_build(self.template)

    -- 非props的属性会合并到根节点（bind除外）
    self:__merge_props_to_root(out_props)

    -- 生成会调用setter的props
    self:__build_props(out_props)

    -- 监听bind过的props
    self:__watch_props(out_props, bind)

    -- create
    self.ui, self.bind, self.__slot_ui = ac_ui_create(self.template, nil, ac_bind(bind))

    -- 根据priority升序设置prop初值
    self:__set_default_props(out_props)

    -- 初始化
    self:init()

    -- update
    if self.on_update then
        self.ui:on_tick(function(delta)
            self:on_update(delta)
        end)
    end


    -- ui移除回调
    local other_on_remove = self.ui.on_remove
    self.ui.on_remove = function()
        if other_on_remove then
            other_on_remove()
        end
        self.__is_removed = true
        self:on_remove()
        self:__remove_all()
    end

    return self.ui, self.__slot_ui
end

function BaseComponent:__error(...)
    log_error(table_concat { 'ui component[', self.__cname, '] ', ... })
end


function BaseComponent:__set_instantiation_args(out_props)
    self.instantiation_args = {}
    for k, v in pairs(out_props) do
        self.instantiation_args[k] = v
    end
end

function BaseComponent:__set_children(props)
    local children = {}
    for i = 1, #props do
        local child = props[i]
        if type(child) == 'table' then
            -- child使用外层的bind
            child._use_outer = true
        end
        children[#children + 1] = child
    end
    self.children = children
end

local special_key = { bind = true, __ui_type = true, imgui_slot = true }
function BaseComponent:__merge_props_to_root(props)
    self.template.name = self.template.name or self.__cname
    local props_define, template = self.__props_define, self.template
    for k, v in pairs(props) do
        if type(k) == 'string' and not special_key[k] and not props_define[k] then
            merge_table_key(props, k, template)
        end
    end
end

function BaseComponent:__build_props(out_props)
    local props_inited = {}
    local props_value = {}
    local raw_set = {}
    local props = {
        __index = function(_, k)
            if props_inited[k] then
                return props_value[k]
            end
            if out_props[k] ~= nil then
                return out_props[k]
            end
            return self.__props_define[k].default
        end,
        __newindex = function(_, k, v)
            local define = self.__props_define[k]
            local old = props_value[k]
            props_value[k] = v  -- 先设置值
            props_inited[k] = true
            if not raw_set[k] then
                raw_set[k] = function(v)
                    if k then
                        props_value[k] = v
                    end
                    return v
                end
            end

            -- setter传入新值旧值和默认值，最后可以返回值以改变结果, TODO: 通过raw_set来设置，不处理返回值
            local set_v = define.setter and define.setter(v, old, define.default, raw_set[k])
            if set_v ~= nil then
                -- v = set_v
                props_value[k] = set_v
            end
        end
    }
    self.props = setmetatable(props, props)
end

function BaseComponent:__watch_props(out_props, bind)
    if out_props.bind then
        for k, v in pairs(out_props.bind) do
            if v == '' then
                log.error(self.__cname .. '的bind.' .. k .. '为空')
                out_props.bind[k] = nil
            end
        end
        bind:load(out_props)
        for k, _ in pairs(self.__props_define) do
            if out_props.bind[k] then
                bind.watch[k] = function(_, value)
                    if self.__is_removed then return end
                    self.props[k] = value
                end
            end
        end
    end
end

function BaseComponent:__set_default_props(out_props)
    local props_to_set = {}
    for k, v in pairs(self.__props_define) do
        if out_props[k] ~= nil then
            props_to_set[k] = out_props[k]
        else
            props_to_set[k] = v.default
        end
    end

    local keys = {}
    for k, _ in pairs(props_to_set) do
        keys[#keys + 1] = k
    end

    local props_define = self.__props_define
    table_sort(keys, function(k1, k2)
        local v1, v2 = props_define[k1], props_define[k2]
        -- 按priority排序
        return (v1 and v1.priority or 0) < (v2 and v2.priority or 0)
    end)

    for i = 1, #keys do
        local k = keys[i]
        self.props[k] = props_to_set[k]
    end
end

function BaseComponent:__remove_all()
    -- 移除相关的触发
    local triggers = self.__auto_remove_triggers or {}
    for i = #triggers, 1, -1 do
        triggers[i]:remove()
        triggers[i] = nil
    end

    -- 为了在ui移除后再调用这些就会报错，但若是其他地方缓存了一下就没办法了
    self.__auto_remove_triggers = nil
    self.__props_define = nil
    self.children = nil
    self.props = nil
    self.bind = nil
    self.ui = nil
end

---ui移除时自动删除trigger
function BaseComponent:auto_remove(trigger)
    if not trigger or not trigger.remove then
        return
    end

    self.__auto_remove_triggers = self.__auto_remove_triggers or {}
    local triggers = self.__auto_remove_triggers
    triggers[#triggers + 1] = trigger
end

function BaseComponent:after_define() end
function BaseComponent:init() end
-- function BaseComponent:on_update() end
function BaseComponent:on_remove() end

return BaseComponent