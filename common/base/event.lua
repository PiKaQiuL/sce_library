local setmetatable = setmetatable
local ipairs = ipairs

local ac_game = base.game

--全局事件转换
local dispatch_events = {
    '单位-即将获得状态',
    '单位-学习技能',
    '单位-请求命令',
    '技能-即将施法',
    '技能-即将打断',
    '运动-即将获得',
    '运动-即将击中',
    '玩家-小地图信号',
    "玩家-暂停游戏",
    "玩家-恢复游戏",
}

local notify_events = {
    '单位-初始化',
    '单位-创建',
    '单位-死亡',
    '单位-移除',
    '单位-复活',
    '单位-获得状态',
    '单位-失去状态',
    '单位-购买物品',
    '单位-出售物品',
    '单位-撤销物品',
    '单位-发布命令',
    '单位-执行命令',
    '单位-失去物品',
    '单位-获得物品',
    '单位-移动',
    '移动-开始',
    '移动-结束',
    '技能-获得',
    '技能-失去',
    "技能-施法开始",
    "技能-施法打断",
    "技能-施法引导",
    "技能-施法出手",
    "技能-施法完成",
    "技能-施法停止",
    "技能-冷却完成",
    "技能-施法失败",
    '玩家-输入作弊码',
    '玩家-输入聊天',
    '玩家-选择英雄',
    '玩家-连入',
    '玩家-断线',
    '玩家-重连',
    '玩家-暂时离开',
    '玩家-回到游戏',
    '玩家-放弃重连',
    '玩家-修改设置',
    '游戏-阶段切换',
    '自定义UI-消息',
    '玩家-切换场景',
    '单位-切换场景',
    '游戏-加载场景',

    '游戏-属性变化',
    '游戏-字符串属性变化',
    '玩家-属性变化',
    '玩家-数值属性变化',
    '玩家-字符串属性变化',
    '单位-属性变化',
    '单位-属性改变',
    '单位-数值属性变化',
    '单位-字符串属性变化',
    'Src-PostCacheInit',
    '对话-开始',
    '对话-结束',
    '对话-跳过',
    '对话-选择',
    '联合场景区域通知',
    '技能-建造预放置开始',
    '技能-建造预放置取消',
    '技能-建造预放置确认',
    '游戏-消息提示显示时',
}

function base.assign_event(name, f)
    base.event[name] = f
end

for _, event in ipairs(dispatch_events) do
    base.assign_event(event, function(self, ...)
        if not self then
            log.error('[event] dispatch to null', event)
            return
        end
        return self:event_dispatch(event, self, ...)
    end)
end

for _, event in ipairs(notify_events) do
    base.assign_event(event, function(self, ...)
        if not self then
            log.error('[event] notify to null', event)
            return
        end
        return self:event_notify(event, self, ...)
    end)
end

-- 上层拆分的事件，需要订阅原事件
local event_subscribe_list = {
    ['玩家-界面消息'] = '自定义UI-消息',
}
base.event_subscribe_list = event_subscribe_list

base.assign_event('自定义UI-消息', function (self, ...)
    self:event_notify('玩家-界面消息', self, ...)
end)

local evt_list
local args

local event_name_send_to_server = {}

function base.forward_event_register(name)
    event_name_send_to_server[name] = true
end

function base.event_dispatch(obj, name, ...)
    if not evt_list then
        evt_list = base.trig.event.event_list
        args = base.trig.event.evt_args
    end

    local events = obj._events
    if not events then
        return
    end
    local event = events[name]
    if not event or #event < 0 then
        return
    end

    local combined_args
    if evt_list and evt_list[name] and args[evt_list[name]] then
        combined_args = args[evt_list[name]](obj, name, ...)
    elseif event.custom_event then
        -- 触发器定义的自定义事件
        combined_args = args.event_custom_event(obj, name, ...)
    end
    for i = #event, 1, -1 do
        local res, arg
        if event[i].combine_args then
            res, arg = event[i](combined_args)
        else
            res, arg = event[i](...)
        end
        if res ~= nil then
            return res, arg
        end
    end
end

local function is_ts_class_metatable(c)
    return type(c) == "table" and type(c.prototype) == "table" and c.prototype.__index == c.prototype and c.prototype.constructor == c
end

function base.event_serialize(t, depth, event_name)
    depth = depth or 0
    if depth > 10 then
        log_file.info('自定义事件参数的表深度超过上限！')
        return nil
    end
    local type_t = type(t)
    if type_t == "table" or type_t == "userdata" then
        if t == base.game then
            return '{game}'
        elseif t == Array then --t是数组的元表，特殊处理
            return '{prototype|Array}'
        elseif base.tsc.__TS__InstanceOf(t, Unit) then
            return '{unit|'..t._id..'}'
        elseif base.tsc.__TS__InstanceOf(t, Player) then
            local id = t:get_slot_id()
            return '{player|'..id..'}'
        elseif base.tsc.__TS__InstanceOf(t, Item) then
            return '{item|'..t.id..'}'
        elseif base.tsc.__TS__InstanceOf(t, Actor) then
            return '{actor|'..t._server_id..'}'
        elseif base.tsc.__TS__InstanceOf(t, Point) then
            return '{point|('..t[1]..', '..t[2]..', '..t[3]..')}'
        elseif base.tsc.__TS__InstanceOf(t, ScenePoint) then
            local scene_hash = t.scene_hash or base.get_scene_hash_by_name(t.scene)
            return '{scene_point|('..t[1]..', '..t[2]..', '..t[3]..', '..scene_hash..', '..tostring(t.error_mark)..')}'
        elseif is_ts_class_metatable(t) then --t是TS类的元表，则必定会有环
            log_file.info('自定义事件[' .. event_name .. ']包含不能序列化的触发器对象！')
            return nil
        else
            local ret = {}
            for k, v in pairs(t) do
                local s_k = base.event_serialize(k, depth + 1, event_name)
                local s_v = base.event_serialize(v, depth + 1, event_name)
                if s_k ~= nil then
                    ret[s_k] = s_v
                end
            end
            return ret
        end
    elseif type_t == 'function' or type_t == "thread" then
        return nil
    else
        return t
    end
end

function base.event_deserialize(t)
    local type_t = type(t)
    if type_t == 'string' then
        if t == '{game}' then
            return base.game
        end
        local type, ret
        type, ret = t:match('{(.*)|(.*)}')
        if type and ret then
            if type == 'prototype' then
                if ret == 'Array' then
                    return Array
                end
            elseif type == 'player' then
                return base.player(tonumber(ret))
            elseif type == 'unit' then
                return base.unit(tonumber(ret))
            elseif type == 'actor' then
                return base.actor_from_sid(tonumber(ret))
            elseif type == 'item' then
                return base.item(tonumber(ret))
            elseif type == 'point' then
                local x, y, z = ret:match('%((%S+), (%S+), (%S+)%)')
                return base.point(tonumber(x), tonumber(y), tonumber(z))
            elseif type == 'scene_point' then
                local x, y, z, scene_hash, error_mark = ret:match('%((%S+), (%S+), (%S+), (%S+), (%S+)%)')
                error_mark = error_mark == 'true' and true or false
                return base.scene_point_by_hash(tonumber(x), tonumber(y), tonumber(z), tonumber(scene_hash), error_mark)
            end
        end
        -- 不是序列化的字符串，直接返回
        return t
    elseif type_t == 'table' then
        local ret = {}
        for s_k, s_v in pairs(t) do
            local k = base.event_deserialize(s_k)
            local v = base.event_deserialize(s_v)
            if k ~= nil then
                ret[k] = v
            else
                return nil
            end
        end
        return ret
    else
        return t
    end
end

local function __client_event_to_server(obj, name, ...)
    if __lua_state_name == 'StateGame' then --只在游戏中转发
        --序列化事件参数
        local s_obj = base.event_serialize(obj, 0, name)
        local args = base.event_serialize({...}, 0, name)

        if s_obj == nil or args == nil then
            log_file.info('序列化事件：'..name..'的参数失败！')
            return
        end
        log_file.info('客户端向服务端转发事件：'..name)
        base.game:server'__client_event_to_server'{
            obj = s_obj,
            name = name,
            args = args
        }
    end
end

function base.event_notify(obj, name, ...)
    if event_name_send_to_server[name] == true then
        __client_event_to_server(obj, name, ...)
    end
    if not evt_list then
        evt_list = base.trig.event.event_list
        args = base.trig.event.evt_args
    end

    local events = obj._events
    if not events then
        return
    end
    local event = events[name]
    if not event or #event < 0 then
        return
    end

    local combined_args = ...
    if event.autoForward then
        -- 触发器V2的自定义事件
        combined_args = ...
    elseif evt_list and evt_list[name] and args[evt_list[name]] then
        combined_args = args[evt_list[name]](obj, name, ...)
    elseif event.custom_event then
        -- 触发器定义的自定义事件
        combined_args = args.event_custom_event(obj, name, ...)
    end
    for i = #event, 1, -1 do
        if event[i].combine_args then
            event[i](combined_args)
        else
            event[i](...)
        end
    end
end

function base.event_register(obj, name, f)
    local trig = base.trig:new(f)
    trig:add_event(obj, name)
    return trig
end

function base.game:event_dispatch(name, ...)
    return base.event_dispatch(self, name, ...)
end

function base.game:event_notify(name, ...)
    return base.event_notify(self, name, ...)
end

function base.game:event(name, f)
    return base.event_register(self, name, f)
end

function base.game:broadcast(name, f)
	return base.game:event('广播', function(_, message, ...)
		if name == message then
			f(...)
		end
	end)
end

function base.custom_event_notify(event_name, event_param)
    base.game:event_notify(event_name, event_param)
end

--触发V2用
function base.send_custom_event(event)
    if event and event.obj and event.obj.event_notify then
        event.obj:event_notify(event.event_name, event)
        if event.autoForward == true then
            event.player_slot_id = base.local_player():get_slot_id()
            __client_event_to_server(event.obj, event.event_name, event)
        end
    end
end

local TriggerEvent = base.tsc.__TS__Class()
TriggerEvent.name = "TriggerEvent"
function TriggerEvent.prototype.____constructor(self, obj, event_name, periodic, time)
    self.obj = obj
    self.event_name = event_name
    self.periodic = periodic
    self.time = time
end

base.单位进入视野 = base.tsc.__TS__Class()
base.单位进入视野.name = "单位进入视野"
base.tsc.__TS__ClassExtends(
    base.单位进入视野,
    TriggerEvent,
    function()
        return {}
    end
)
function base.单位进入视野.prototype.____constructor(self, obj, evt_name, unit)
    base.tsc.__TS__SuperTypeArgumentsFuncWrapper(单位进入视野, {}, TriggerEvent.prototype.____constructor)(self)
    self.obj = obj
    self.evt_name = evt_name
    self.unit = unit
    self.event_name = "单位-进入视野"
    self.autoForward = false
end

base.消息技能 = base.tsc.__TS__Class()
base.消息技能.name = "消息技能"
base.tsc.__TS__ClassExtends(
    base.消息技能,
    TriggerEvent,
    function()
        return {}
    end
)
function base.消息技能.prototype.____constructor(self, obj, evt_name, msg)
    base.tsc.__TS__SuperTypeArgumentsFuncWrapper(消息技能, {}, TriggerEvent.prototype.____constructor)(self)
    self.obj = obj
    self.evt_name = evt_name
    self.msg = msg
    self.event_name = "消息-技能"
    self.autoForward = false
end
base.场景加载完成 = base.tsc.__TS__Class()

base.场景加载完成.name = "场景加载完成"
base.tsc.__TS__ClassExtends(
    base.场景加载完成,
    TriggerEvent,
    function()
        return {}
    end
)
function base.场景加载完成.prototype.____constructor(self, obj, evt_name, scene_name)
    base.tsc.__TS__SuperTypeArgumentsFuncWrapper(场景加载完成, {}, TriggerEvent.prototype.____constructor)(self)
    self.obj = obj
    self.evt_name = evt_name
    self.scene_name = scene_name
    self.event_name = "场景-加载完成"
    self.autoForward = false
end

base.消息错误 = base.tsc.__TS__Class()
base.消息错误.name = "消息错误"
base.tsc.__TS__ClassExtends(
    base.消息错误,
    TriggerEvent,
    function()
        return {}
    end
)
function base.消息错误.prototype.____constructor(self, obj, evt_name, msg, duration)
    base.tsc.__TS__SuperTypeArgumentsFuncWrapper(消息错误, {}, TriggerEvent.prototype.____constructor)(self)
    self.obj = obj
    self.evt_name = evt_name
    self.msg = msg
    self.duration = duration
    self.event_name = "消息-错误"
    self.autoForward = false
end

base.消息聊天 = base.tsc.__TS__Class()
base.消息聊天.name = "消息聊天"
base.tsc.__TS__ClassExtends(
    base.消息聊天,
    TriggerEvent,
    function()
        return {}
    end
)
function base.消息聊天.prototype.____constructor(self, obj, evt_name, player, duration)
    base.tsc.__TS__SuperTypeArgumentsFuncWrapper(消息聊天, {}, TriggerEvent.prototype.____constructor)(self)
    self.obj = obj
    self.evt_name = evt_name
    self.player = player
    self.duration = duration
    self.event_name = "消息-聊天"
    self.autoForward = false
end

base.消息公告 = base.tsc.__TS__Class()
base.消息公告.name = "消息公告"
base.tsc.__TS__ClassExtends(
    base.消息公告,
    TriggerEvent,
    function()
        return {}
    end
)
function base.消息公告.prototype.____constructor(self, obj, evt_name, msg, duration)
    base.tsc.__TS__SuperTypeArgumentsFuncWrapper(消息公告, {}, TriggerEvent.prototype.____constructor)(self)
    self.obj = obj
    self.evt_name = evt_name
    self.msg = msg
    self.duration = duration
    self.event_name = "消息-公告"
    self.autoForward = false
end

base.画面分辨率变化 = base.tsc.__TS__Class()
base.画面分辨率变化.name = "画面分辨率变化"
base.tsc.__TS__ClassExtends(
    base.画面分辨率变化,
    TriggerEvent,
    function()
        return {}
    end
)
function base.画面分辨率变化.prototype.____constructor(self, obj, evt_name, width, height)
    base.tsc.__TS__SuperTypeArgumentsFuncWrapper(画面分辨率变化, {}, TriggerEvent.prototype.____constructor)(self)
    self.obj = obj
    self.evt_name = evt_name
    self.width = width
    self.height = height
    self.event_name = "画面-分辨率变化"
    self.autoForward = false
end

base.游戏阶段切换 = base.tsc.__TS__Class()
base.游戏阶段切换.name = "游戏阶段切换"
base.tsc.__TS__ClassExtends(
    base.游戏阶段切换,
    TriggerEvent,
    function()
        return {}
    end
)
function base.游戏阶段切换.prototype.____constructor(self, obj, evt_name)
    base.tsc.__TS__SuperTypeArgumentsFuncWrapper(游戏阶段切换, {}, TriggerEvent.prototype.____constructor)(self)
    self.obj = obj
    self.evt_name = evt_name
    self.event_name = "游戏-阶段切换"
    self.autoForward = false
end

base.游戏更新 = base.tsc.__TS__Class()
base.游戏更新.name = "游戏更新"
base.tsc.__TS__ClassExtends(
    base.游戏更新,
    TriggerEvent,
    function()
        return {}
    end
)
function base.游戏更新.prototype.____constructor(self, obj, evt_name, delta)
    base.tsc.__TS__SuperTypeArgumentsFuncWrapper(游戏更新, {}, TriggerEvent.prototype.____constructor)(self)
    self.obj = obj
    self.evt_name = evt_name
    self.delta = delta
    self.event_name = "游戏-更新"
    self.autoForward = false
end

base.玩家重连 = base.tsc.__TS__Class()
base.玩家重连.name = "玩家重连"
base.tsc.__TS__ClassExtends(
    base.玩家重连,
    TriggerEvent,
    function()
        return {}
    end
)
function base.玩家重连.prototype.____constructor(self, obj, evt_name, player)
    base.tsc.__TS__SuperTypeArgumentsFuncWrapper(玩家重连, {}, TriggerEvent.prototype.____constructor)(self)
    self.obj = obj
    self.evt_name = evt_name
    self.player = player
    self.event_name = "玩家-重连"
    self.autoForward = false
end

base.游戏属性变化 = base.tsc.__TS__Class()
base.游戏属性变化.name = "游戏属性变化"
base.tsc.__TS__ClassExtends(
    base.游戏属性变化,
    TriggerEvent,
    function()
        return {}
    end
)
function base.游戏属性变化.prototype.____constructor(self, obj, evt_name, property, value_s)
    base.tsc.__TS__SuperTypeArgumentsFuncWrapper(游戏属性变化, {}, TriggerEvent.prototype.____constructor)(self)
    self.obj = obj
    self.evt_name = evt_name
    self.property = property
    self.value_s = value_s
    self.event_name = "游戏-属性变化"
    self.autoForward = false
end

base.游戏开始 = base.tsc.__TS__Class()
base.游戏开始.name = "游戏开始"
base.tsc.__TS__ClassExtends(
    base.游戏开始,
    TriggerEvent,
    function()
        return {}
    end
)
function base.游戏开始.prototype.____constructor(self, obj, evt_name)
    base.tsc.__TS__SuperTypeArgumentsFuncWrapper(游戏开始, {}, TriggerEvent.prototype.____constructor)(self)
    self.obj = obj
    self.evt_name = evt_name
    self.event_name = "游戏-开始"
    self.autoForward = false
end

base.游戏结束 = base.tsc.__TS__Class()
base.游戏结束.name = "游戏结束"
base.tsc.__TS__ClassExtends(
    base.游戏结束,
    TriggerEvent,
    function()
        return {}
    end
)
function base.游戏结束.prototype.____constructor(self, obj, evt_name)
    base.tsc.__TS__SuperTypeArgumentsFuncWrapper(游戏结束, {}, TriggerEvent.prototype.____constructor)(self)
    self.obj = obj
    self.evt_name = evt_name
    self.event_name = "游戏-结束"
    self.autoForward = false
end

base.玩家断线 = base.tsc.__TS__Class()
base.玩家断线.name = "玩家断线"
base.tsc.__TS__ClassExtends(
    base.玩家断线,
    TriggerEvent,
    function()
        return {}
    end
)
function base.玩家断线.prototype.____constructor(self, obj, evt_name, player)
    base.tsc.__TS__SuperTypeArgumentsFuncWrapper(玩家断线, {}, TriggerEvent.prototype.____constructor)(self)
    self.obj = obj
    self.evt_name = evt_name
    self.player = player
    self.event_name = "玩家-断线"
    self.autoForward = false
end

base.画面分辨率缩放变化 = base.tsc.__TS__Class()
base.画面分辨率缩放变化.name = "画面分辨率缩放变化"
base.tsc.__TS__ClassExtends(
    base.画面分辨率缩放变化,
    TriggerEvent,
    function()
        return {}
    end
)
function base.画面分辨率缩放变化.prototype.____constructor(self, obj, evt_name, scale)
    base.tsc.__TS__SuperTypeArgumentsFuncWrapper(画面分辨率缩放变化, {}, TriggerEvent.prototype.____constructor)(self)
    self.obj = obj
    self.evt_name = evt_name
    self.scale = scale
    self.event_name = "画面-分辨率缩放变化"
    self.autoForward = false
end

base.按键松开 = base.tsc.__TS__Class()
base.按键松开.name = "按键松开"
base.tsc.__TS__ClassExtends(
    base.按键松开,
    TriggerEvent,
    function()
        return {}
    end
)
function base.按键松开.prototype.____constructor(self, obj, evt_name, key_keyboard)
    base.tsc.__TS__SuperTypeArgumentsFuncWrapper(按键松开, {}, TriggerEvent.prototype.____constructor)(self)
    self.obj = obj
    self.evt_name = evt_name
    self.key_keyboard = key_keyboard
    self.event_name = "按键-松开"
    self.autoForward = false
end

base.对话选择 = base.tsc.__TS__Class()
base.对话选择.name = "对话选择"
base.tsc.__TS__ClassExtends(
    base.对话选择,
    TriggerEvent,
    function()
        return {}
    end
)
function base.对话选择.prototype.____constructor(self, obj, evt_name, speaker, listener, ref_param, conversation_link, conversation_choice_item_link)
    base.tsc.__TS__SuperTypeArgumentsFuncWrapper(对话选择, {}, TriggerEvent.prototype.____constructor)(self)
    self.obj = obj
    self.evt_name = evt_name
    self.speaker = speaker
    self.listener = listener
    self.ref_param = ref_param
    self.conversation_link = conversation_link
    self.conversation_choice_item_link = conversation_choice_item_link
    self.event_name = "对话-选择"
    self.autoForward = false
end

base.对话开始 = base.tsc.__TS__Class()
base.对话开始.name = "对话开始"
base.tsc.__TS__ClassExtends(
    base.对话开始,
    TriggerEvent,
    function()
        return {}
    end
)
function base.对话开始.prototype.____constructor(self, obj, evt_name, speaker, listener, ref_param, conversation_link)
    base.tsc.__TS__SuperTypeArgumentsFuncWrapper(对话开始, {}, TriggerEvent.prototype.____constructor)(self)
    self.obj = obj
    self.evt_name = evt_name
    self.speaker = speaker
    self.listener = listener
    self.ref_param = ref_param
    self.conversation_link = conversation_link
    self.event_name = "对话-开始"
    self.autoForward = false
end

base.鼠标点击物品栏中物品 = base.tsc.__TS__Class()
base.鼠标点击物品栏中物品.name = "鼠标点击物品栏中物品"
base.tsc.__TS__ClassExtends(
    base.鼠标点击物品栏中物品,
    TriggerEvent,
    function()
        return {}
    end
)
function base.鼠标点击物品栏中物品.prototype.____constructor(self, obj, item, item_tooltip_panel, slot_panel, inventory_panel)
    base.tsc.__TS__SuperTypeArgumentsFuncWrapper(鼠标点击物品栏中物品, {}, TriggerEvent.prototype.____constructor)(self)
    self.obj = obj
    self.item = item
    self.item_tooltip_panel = item_tooltip_panel
    self.slot_panel = slot_panel
    self.inventory_panel = inventory_panel
    self.event_name = "鼠标-点击物品栏格子时"
    self.autoForward = false
end

base.鼠标长按物品栏中物品 = base.tsc.__TS__Class()
base.鼠标长按物品栏中物品.name = "鼠标长按物品栏中物品"
base.tsc.__TS__ClassExtends(
    base.鼠标长按物品栏中物品,
    TriggerEvent,
    function()
        return {}
    end
)
function base.鼠标长按物品栏中物品.prototype.____constructor(self, obj, item, item_tooltip_panel, slot_panel, inventory_panel)
    base.tsc.__TS__SuperTypeArgumentsFuncWrapper(鼠标长按物品栏中物品, {}, TriggerEvent.prototype.____constructor)(self)
    self.obj = obj
    self.item = item
    self.item_tooltip_panel = item_tooltip_panel
    self.slot_panel = slot_panel
    self.inventory_panel = inventory_panel
    self.event_name = "鼠标-长按物品栏格子时"
    self.autoForward = false
end

base.鼠标长按物品栏中物品抬起 = base.tsc.__TS__Class()
base.鼠标长按物品栏中物品抬起.name = "鼠标长按物品栏中物品抬起"
base.tsc.__TS__ClassExtends(
    base.鼠标长按物品栏中物品抬起,
    TriggerEvent,
    function()
        return {}
    end
)
function base.鼠标长按物品栏中物品抬起.prototype.____constructor(self, obj, item, item_tooltip_panel, slot_panel, inventory_panel)
    base.tsc.__TS__SuperTypeArgumentsFuncWrapper(鼠标长按物品栏中物品抬起, {}, TriggerEvent.prototype.____constructor)(self)
    self.obj = obj
    self.item = item
    self.item_tooltip_panel = item_tooltip_panel
    self.slot_panel = slot_panel
    self.inventory_panel = inventory_panel
    self.event_name = "鼠标-长按物品栏格子抬起时"
    self.autoForward = false
end

base.对话跳过时 = base.tsc.__TS__Class()
base.对话跳过时.name = "对话跳过时"
base.tsc.__TS__ClassExtends(
    base.对话跳过时,
    TriggerEvent,
    function()
        return {}
    end
)
function base.对话跳过时.prototype.____constructor(self, obj, evt_name, speaker, listener, ref_param, conversation_link)
    base.tsc.__TS__SuperTypeArgumentsFuncWrapper(对话跳过时, {}, TriggerEvent.prototype.____constructor)(self)
    self.obj = obj
    self.evt_name = evt_name
    self.speaker = speaker
    self.listener = listener
    self.ref_param = ref_param
    self.conversation_link = conversation_link
    self.event_name = "对话-跳过"
    self.autoForward = false
end

base.对话结束时 = base.tsc.__TS__Class()
base.对话结束时.name = "对话结束时"
base.tsc.__TS__ClassExtends(
    base.对话结束时,
    TriggerEvent,
    function()
        return {}
    end
)
function base.对话结束时.prototype.____constructor(self, obj, evt_name, speaker, listener, ref_param, conversation_link)
    base.tsc.__TS__SuperTypeArgumentsFuncWrapper(对话结束时, {}, TriggerEvent.prototype.____constructor)(self)
    self.obj = obj
    self.evt_name = evt_name
    self.speaker = speaker
    self.listener = listener
    self.ref_param = ref_param
    self.conversation_link = conversation_link
    self.event_name = "对话-结束"
    self.autoForward = false
end

base.按键按下 = base.tsc.__TS__Class()
base.按键按下.name = "按键按下"
base.tsc.__TS__ClassExtends(
    base.按键按下,
    TriggerEvent,
    function()
        return {}
    end
)
function base.按键按下.prototype.____constructor(self, obj, evt_name, key_keyboard)
    base.tsc.__TS__SuperTypeArgumentsFuncWrapper(按键按下, {}, TriggerEvent.prototype.____constructor)(self)
    self.obj = obj
    self.evt_name = evt_name
    self.key_keyboard = key_keyboard
    self.event_name = "按键-按下"
    self.autoForward = false
end

base.表现音效事件 = base.tsc.__TS__Class()
base.表现音效事件.name = "表现音效事件"
base.tsc.__TS__ClassExtends(
    base.表现音效事件,
    TriggerEvent,
    function()
        return {}
    end
)
function base.表现音效事件.prototype.____constructor(self, obj, evt_name, msg, actor)
    base.tsc.__TS__SuperTypeArgumentsFuncWrapper(表现音效事件, {}, TriggerEvent.prototype.____constructor)(self)
    self.obj = obj
    self.evt_name = evt_name
    self.msg = msg
    self.actor = actor
    self.event_name = "表现-音效事件"
    self.autoForward = false
end

base.表现动画事件开始 = base.tsc.__TS__Class()
base.表现动画事件开始.name = "表现动画事件开始"
base.tsc.__TS__ClassExtends(
    base.表现动画事件开始,
    TriggerEvent,
    function()
        return {}
    end
)
function base.表现动画事件开始.prototype.____constructor(self, obj, evt_name, actor, msg, anmi)
    base.tsc.__TS__SuperTypeArgumentsFuncWrapper(表现动画事件开始, {}, TriggerEvent.prototype.____constructor)(self)
    self.obj = obj
    self.evt_name = evt_name
    self.actor = actor
    self.msg = msg
    self.anmi = anmi
    self.event_name = "表现-动画事件开始"
    self.autoForward = false
end

base.鼠标按下 = base.tsc.__TS__Class()
base.鼠标按下.name = "鼠标按下"
base.tsc.__TS__ClassExtends(
    base.鼠标按下,
    TriggerEvent,
    function()
        return {}
    end
)
function base.鼠标按下.prototype.____constructor(self, obj, evt_name, key)
    base.tsc.__TS__SuperTypeArgumentsFuncWrapper(鼠标按下, {}, TriggerEvent.prototype.____constructor)(self)
    self.obj = obj
    self.evt_name = evt_name
    self.key = key
    self.event_name = "鼠标-按下"
    self.autoForward = false
end

base.表现动画事件结束 = base.tsc.__TS__Class()
base.表现动画事件结束.name = "表现动画事件结束"
base.tsc.__TS__ClassExtends(
    base.表现动画事件结束,
    TriggerEvent,
    function()
        return {}
    end
)
function base.表现动画事件结束.prototype.____constructor(self, obj, evt_name, anmi, msg, actor)
    base.tsc.__TS__SuperTypeArgumentsFuncWrapper(表现动画事件结束, {}, TriggerEvent.prototype.____constructor)(self)
    self.obj = obj
    self.evt_name = evt_name
    self.anmi = anmi
    self.msg = msg
    self.actor = actor
    self.event_name = "表现-动画事件结束"
    self.autoForward = false
end

base.鼠标松开 = base.tsc.__TS__Class()
base.鼠标松开.name = "鼠标松开"
base.tsc.__TS__ClassExtends(
    base.鼠标松开,
    TriggerEvent,
    function()
        return {}
    end
)
function base.鼠标松开.prototype.____constructor(self, obj, evt_name, key)
    base.tsc.__TS__SuperTypeArgumentsFuncWrapper(鼠标松开, {}, TriggerEvent.prototype.____constructor)(self)
    self.obj = obj
    self.evt_name = evt_name
    self.key = key
    self.event_name = "鼠标-松开"
    self.autoForward = false
end

base.鼠标移动 = base.tsc.__TS__Class()
base.鼠标移动.name = "鼠标移动"
base.tsc.__TS__ClassExtends(
    base.鼠标移动,
    TriggerEvent,
    function()
        return {}
    end
)
function base.鼠标移动.prototype.____constructor(self, obj, evt_name)
    base.tsc.__TS__SuperTypeArgumentsFuncWrapper(鼠标移动, {}, TriggerEvent.prototype.____constructor)(self)
    self.obj = obj
    self.evt_name = evt_name
    self.event_name = "鼠标-移动"
    self.autoForward = false
end

base.服务器请求切换场景 = base.tsc.__TS__Class()
base.服务器请求切换场景.name = "服务器请求切换场景"
base.tsc.__TS__ClassExtends(
    base.服务器请求切换场景,
    TriggerEvent,
    function()
        return {}
    end
)
function base.服务器请求切换场景.prototype.____constructor(self, obj, old_scene, new_scene)
    base.tsc.__TS__SuperTypeArgumentsFuncWrapper(服务器请求切换场景, {}, TriggerEvent.prototype.____constructor)(self)
    self.obj = obj
    self.old_scene = old_scene
    self.new_scene = new_scene
    self.event_name = "场景-请求切换"
    self.autoForward = false
end

base.玩家属性变化 = base.tsc.__TS__Class()
base.玩家属性变化.name = "玩家属性变化"
base.tsc.__TS__ClassExtends(
    base.玩家属性变化,
    TriggerEvent,
    function()
        return {}
    end
)
function base.玩家属性变化.prototype.____constructor(self, obj, evt_name, player, property, value_n, value_s)
    base.tsc.__TS__SuperTypeArgumentsFuncWrapper(玩家属性变化, {}, TriggerEvent.prototype.____constructor)(self)
    self.obj = obj
    self.evt_name = evt_name
    self.player = player
    self.property = property
    self.value_n = value_n
    self.value_s = value_s
    self.event_name = "玩家-属性变化"
    self.autoForward = false
end

base.玩家改变英雄 = base.tsc.__TS__Class()
base.玩家改变英雄.name = "玩家改变英雄"
base.tsc.__TS__ClassExtends(
    base.玩家改变英雄,
    TriggerEvent,
    function()
        return {}
    end
)
function base.玩家改变英雄.prototype.____constructor(self, obj, evt_name, player, unit)
    base.tsc.__TS__SuperTypeArgumentsFuncWrapper(玩家改变英雄, {}, TriggerEvent.prototype.____constructor)(self)
    self.obj = obj
    self.evt_name = evt_name
    self.player = player
    self.unit = unit
    self.event_name = "玩家-改变英雄"
    self.autoForward = false
end

base.单位施法完成 = base.tsc.__TS__Class()
base.单位施法完成.name = "单位施法完成"
base.tsc.__TS__ClassExtends(
    base.单位施法完成,
    TriggerEvent,
    function()
        return {}
    end
)
function base.单位施法完成.prototype.____constructor(self, obj, evt_name, unit, skill_id, time_elapsed, time_total)
    base.tsc.__TS__SuperTypeArgumentsFuncWrapper(单位施法完成, {}, TriggerEvent.prototype.____constructor)(self)
    self.obj = obj
    self.evt_name = evt_name
    self.unit = unit
    self.skill_id = skill_id
    self.time_elapsed = time_elapsed
    self.time_total = time_total
    self.event_name = "单位-施法完成"
    self.autoForward = false
end

base.单位施法出手 = base.tsc.__TS__Class()
base.单位施法出手.name = "单位施法出手"
base.tsc.__TS__ClassExtends(
    base.单位施法出手,
    TriggerEvent,
    function()
        return {}
    end
)
function base.单位施法出手.prototype.____constructor(self, obj, evt_name, unit, skill_id, time_elapsed, time_total)
    base.tsc.__TS__SuperTypeArgumentsFuncWrapper(单位施法出手, {}, TriggerEvent.prototype.____constructor)(self)
    self.obj = obj
    self.evt_name = evt_name
    self.unit = unit
    self.skill_id = skill_id
    self.time_elapsed = time_elapsed
    self.time_total = time_total
    self.event_name = "单位-施法出手"
    self.autoForward = false
end

base.单位施法停止 = base.tsc.__TS__Class()
base.单位施法停止.name = "单位施法停止"
base.tsc.__TS__ClassExtends(
    base.单位施法停止,
    TriggerEvent,
    function()
        return {}
    end
)
function base.单位施法停止.prototype.____constructor(self, obj, evt_name, unit, skill_id, time_elapsed, time_total)
    base.tsc.__TS__SuperTypeArgumentsFuncWrapper(单位施法停止, {}, TriggerEvent.prototype.____constructor)(self)
    self.obj = obj
    self.evt_name = evt_name
    self.unit = unit
    self.skill_id = skill_id
    self.time_elapsed = time_elapsed
    self.time_total = time_total
    self.event_name = "单位-施法停止"
    self.autoForward = false
end

base.单位失去状态 = base.tsc.__TS__Class()
base.单位失去状态.name = "单位失去状态"
base.tsc.__TS__ClassExtends(
    base.单位失去状态,
    TriggerEvent,
    function()
        return {}
    end
)
function base.单位失去状态.prototype.____constructor(self, obj, evt_name, unit, buff)
    base.tsc.__TS__SuperTypeArgumentsFuncWrapper(单位失去状态, {}, TriggerEvent.prototype.____constructor)(self)
    self.obj = obj
    self.evt_name = evt_name
    self.unit = unit
    self.buff = buff
    self.event_name = "单位-失去状态"
    self.autoForward = false
end

base.单位获得状态 = base.tsc.__TS__Class()
base.单位获得状态.name = "单位获得状态"
base.tsc.__TS__ClassExtends(
    base.单位获得状态,
    TriggerEvent,
    function()
        return {}
    end
)
function base.单位获得状态.prototype.____constructor(self, obj, evt_name, unit, buff)
    base.tsc.__TS__SuperTypeArgumentsFuncWrapper(单位获得状态, {}, TriggerEvent.prototype.____constructor)(self)
    self.obj = obj
    self.evt_name = evt_name
    self.unit = unit
    self.buff = buff
    self.event_name = "单位-获得状态"
    self.autoForward = false
end

base.单位状态层数变化 = base.tsc.__TS__Class()
base.单位状态层数变化.name = "单位状态层数变化"
base.tsc.__TS__ClassExtends(
    base.单位状态层数变化,
    TriggerEvent,
    function()
        return {}
    end
)
function base.单位状态层数变化.prototype.____constructor(self, obj, evt_name, buff, stack, unit)
    base.tsc.__TS__SuperTypeArgumentsFuncWrapper(单位状态层数变化, {}, TriggerEvent.prototype.____constructor)(self)
    self.obj = obj
    self.evt_name = evt_name
    self.buff = buff
    self.stack = stack
    self.unit = unit
    self.event_name = "单位-状态层数变化"
    self.autoForward = false
end

base.单位施法引导 = base.tsc.__TS__Class()
base.单位施法引导.name = "单位施法引导"
base.tsc.__TS__ClassExtends(
    base.单位施法引导,
    TriggerEvent,
    function()
        return {}
    end
)
function base.单位施法引导.prototype.____constructor(self, obj, evt_name, unit, skill_id, time_elapsed, time_total)
    base.tsc.__TS__SuperTypeArgumentsFuncWrapper(单位施法引导, {}, TriggerEvent.prototype.____constructor)(self)
    self.obj = obj
    self.evt_name = evt_name
    self.unit = unit
    self.skill_id = skill_id
    self.time_elapsed = time_elapsed
    self.time_total = time_total
    self.event_name = "单位-施法引导"
    self.autoForward = false
end

base.单位属性变化 = base.tsc.__TS__Class()
base.单位属性变化.name = "单位属性变化"
base.tsc.__TS__ClassExtends(
    base.单位属性变化,
    TriggerEvent,
    function()
        return {}
    end
)
function base.单位属性变化.prototype.____constructor(self, obj, evt_name, unit, property, value_n, value_s)
    base.tsc.__TS__SuperTypeArgumentsFuncWrapper(单位属性变化, {}, TriggerEvent.prototype.____constructor)(self)
    self.obj = obj
    self.evt_name = evt_name
    self.unit = unit
    self.property = property
    self.value_n = value_n
    self.value_s = value_s
    self.event_name = "单位-属性变化"
    self.autoForward = false
end

base.单位离开视野 = base.tsc.__TS__Class()
base.单位离开视野.name = "单位离开视野"
base.tsc.__TS__ClassExtends(
    base.单位离开视野,
    TriggerEvent,
    function()
        return {}
    end
)
function base.单位离开视野.prototype.____constructor(self, obj, evt_name, unit)
    base.tsc.__TS__SuperTypeArgumentsFuncWrapper(单位离开视野, {}, TriggerEvent.prototype.____constructor)(self)
    self.obj = obj
    self.evt_name = evt_name
    self.unit = unit
    self.event_name = "单位-离开视野"
    self.autoForward = false
end

base.单位施法开始 = base.tsc.__TS__Class()
base.单位施法开始.name = "单位施法开始"
base.tsc.__TS__ClassExtends(
    base.单位施法开始,
    TriggerEvent,
    function()
        return {}
    end
)
function base.单位施法开始.prototype.____constructor(self, obj, evt_name, unit, skill_id, time_elapsed, time_total)
    base.tsc.__TS__SuperTypeArgumentsFuncWrapper(单位施法开始, {}, TriggerEvent.prototype.____constructor)(self)
    self.obj = obj
    self.evt_name = evt_name
    self.unit = unit
    self.skill_id = skill_id
    self.time_elapsed = time_elapsed
    self.time_total = time_total
    self.event_name = "单位-施法开始"
    self.autoForward = false
end

base.单位选中 = base.tsc.__TS__Class()
base.单位选中.name = "单位选中"
base.tsc.__TS__ClassExtends(
    base.单位选中,
    TriggerEvent,
    function()
        return {}
    end
)
function base.单位选中.prototype.____constructor(self, obj, evt_name, player, unit)
    base.tsc.__TS__SuperTypeArgumentsFuncWrapper(单位选中, {}, TriggerEvent.prototype.____constructor)(self)
    self.obj = obj
    self.evt_name = evt_name
    self.player = player
    self.unit = unit
    self.event_name = "单位-选中"
    self.autoForward = false
end

base.单位取消选中 = base.tsc.__TS__Class()
base.单位取消选中.name = "单位取消选中"
base.tsc.__TS__ClassExtends(
    base.单位取消选中,
    TriggerEvent,
    function()
        return {}
    end
)
function base.单位取消选中.prototype.____constructor(self, obj, evt_name, player, unit)
    base.tsc.__TS__SuperTypeArgumentsFuncWrapper(单位取消选中, {}, TriggerEvent.prototype.____constructor)(self)
    self.obj = obj
    self.evt_name = evt_name
    self.player = player
    self.unit = unit
    self.event_name = "单位-取消选中"
    self.autoForward = false
end

base.玩家改变队伍 = base.tsc.__TS__Class()
base.玩家改变队伍.name = "玩家改变队伍"
base.tsc.__TS__ClassExtends(
    base.玩家改变队伍,
    TriggerEvent,
    function()
        return {}
    end
)
function base.玩家改变队伍.prototype.____constructor(self, obj, evt_name, player, team)
    base.tsc.__TS__SuperTypeArgumentsFuncWrapper(玩家改变队伍, {}, TriggerEvent.prototype.____constructor)(self)
    self.obj = obj
    self.evt_name = evt_name
    self.player = player
    self.team = team
    self.event_name = "玩家-改变队伍"
    self.autoForward = false
end

base.技能获得 = base.tsc.__TS__Class()
base.技能获得.name = "技能获得"
base.tsc.__TS__ClassExtends(
    base.技能获得,
    TriggerEvent,
    function()
        return {}
    end
)
function base.技能获得.prototype.____constructor(self, obj, evt_name, unit, skill)
    base.tsc.__TS__SuperTypeArgumentsFuncWrapper(技能获得, {}, TriggerEvent.prototype.____constructor)(self)
    self.obj = obj
    self.evt_name = evt_name
    self.unit = unit
    self.skill = skill
    self.event_name = "技能-获得"
    self.autoForward = false
end

base.技能属性变化 = base.tsc.__TS__Class()
base.技能属性变化.name = "技能属性变化"
base.tsc.__TS__ClassExtends(
    base.技能属性变化,
    TriggerEvent,
    function()
        return {}
    end
)
function base.技能属性变化.prototype.____constructor(self, obj, evt_name, skill, property, value_n)
    base.tsc.__TS__SuperTypeArgumentsFuncWrapper(技能属性变化, {}, TriggerEvent.prototype.____constructor)(self)
    self.obj = obj
    self.evt_name = evt_name
    self.skill = skill
    self.property = property
    self.value_n = value_n
    self.event_name = "技能-属性变化"
    self.autoForward = false
end

base.技能充能激活 = base.tsc.__TS__Class()
base.技能充能激活.name = "技能充能激活"
base.tsc.__TS__ClassExtends(
    base.技能充能激活,
    TriggerEvent,
    function()
        return {}
    end
)
function base.技能充能激活.prototype.____constructor(self, obj, evt_name, skill, time_remaining, time_total)
    base.tsc.__TS__SuperTypeArgumentsFuncWrapper(技能充能激活, {}, TriggerEvent.prototype.____constructor)(self)
    self.obj = obj
    self.evt_name = evt_name
    self.skill = skill
    self.time_remaining = time_remaining
    self.time_total = time_total
    self.event_name = "技能-充能激活"
    self.autoForward = false
end

base.技能冷却激活 = base.tsc.__TS__Class()
base.技能冷却激活.name = "技能冷却激活"
base.tsc.__TS__ClassExtends(
    base.技能冷却激活,
    TriggerEvent,
    function()
        return {}
    end
)
function base.技能冷却激活.prototype.____constructor(self, obj, evt_name, skill, time_remaining, time_total)
    base.tsc.__TS__SuperTypeArgumentsFuncWrapper(技能冷却激活, {}, TriggerEvent.prototype.____constructor)(self)
    self.obj = obj
    self.evt_name = evt_name
    self.skill = skill
    self.time_remaining = time_remaining
    self.time_total = time_total
    self.event_name = "技能-冷却激活"
    self.autoForward = false
end

base.状态获得 = base.tsc.__TS__Class()
base.状态获得.name = "状态获得"
base.tsc.__TS__ClassExtends(
    base.状态获得,
    TriggerEvent,
    function()
        return {}
    end
)
function base.状态获得.prototype.____constructor(self, obj, evt_name, unit, buff)
    base.tsc.__TS__SuperTypeArgumentsFuncWrapper(状态获得, {}, TriggerEvent.prototype.____constructor)(self)
    self.obj = obj
    self.evt_name = evt_name
    self.unit = unit
    self.buff = buff
    self.event_name = "状态-获得"
    self.autoForward = false
end

base.状态层数变化 = base.tsc.__TS__Class()
base.状态层数变化.name = "状态层数变化"
base.tsc.__TS__ClassExtends(
    base.状态层数变化,
    TriggerEvent,
    function()
        return {}
    end
)
function base.状态层数变化.prototype.____constructor(self, obj, evt_name, buff, stack, unit)
    base.tsc.__TS__SuperTypeArgumentsFuncWrapper(状态层数变化, {}, TriggerEvent.prototype.____constructor)(self)
    self.obj = obj
    self.evt_name = evt_name
    self.buff = buff
    self.stack = stack
    self.unit = unit
    self.event_name = "状态-层数变化"
    self.autoForward = false
end

base.状态失去 = base.tsc.__TS__Class()
base.状态失去.name = "状态失去"
base.tsc.__TS__ClassExtends(
    base.状态失去,
    TriggerEvent,
    function()
        return {}
    end
)
function base.状态失去.prototype.____constructor(self, obj, evt_name, unit, buff)
    base.tsc.__TS__SuperTypeArgumentsFuncWrapper(状态失去, {}, TriggerEvent.prototype.____constructor)(self)
    self.obj = obj
    self.evt_name = evt_name
    self.unit = unit
    self.buff = buff
    self.event_name = "状态-失去"
    self.autoForward = false
end

base.技能失去 = base.tsc.__TS__Class()
base.技能失去.name = "技能失去"
base.tsc.__TS__ClassExtends(
    base.技能失去,
    TriggerEvent,
    function()
        return {}
    end
)
function base.技能失去.prototype.____constructor(self, obj, evt_name, unit, skill)
    base.tsc.__TS__SuperTypeArgumentsFuncWrapper(技能失去, {}, TriggerEvent.prototype.____constructor)(self)
    self.obj = obj
    self.evt_name = evt_name
    self.unit = unit
    self.skill = skill
    self.event_name = "技能-失去"
    self.autoForward = false
end

base.技能冷却完成 = base.tsc.__TS__Class()
base.技能冷却完成.name = "技能冷却完成"
base.tsc.__TS__ClassExtends(
    base.技能冷却完成,
    TriggerEvent,
    function()
        return {}
    end
)
function base.技能冷却完成.prototype.____constructor(self, obj, evt_name, skill)
    base.tsc.__TS__SuperTypeArgumentsFuncWrapper(技能冷却完成, {}, TriggerEvent.prototype.____constructor)(self)
    self.obj = obj
    self.evt_name = evt_name
    self.skill = skill
    self.event_name = "技能-冷却完成"
    self.autoForward = false
end

base.技能可用状态变化 = base.tsc.__TS__Class()
base.技能可用状态变化.name = "技能可用状态变化"
base.tsc.__TS__ClassExtends(
    base.技能可用状态变化,
    TriggerEvent,
    function()
        return {}
    end
)
function base.技能可用状态变化.prototype.____constructor(self, obj, evt_name, skill)
    base.tsc.__TS__SuperTypeArgumentsFuncWrapper(技能可用状态变化, {}, TriggerEvent.prototype.____constructor)(self)
    self.obj = obj
    self.evt_name = evt_name
    self.skill = skill
    self.event_name = "技能-可用状态变化"
    self.autoForward = false
end

base.技能等级变化 = base.tsc.__TS__Class()
base.技能等级变化.name = "技能等级变化"
base.tsc.__TS__ClassExtends(
    base.技能等级变化,
    TriggerEvent,
    function()
        return {}
    end
)
function base.技能等级变化.prototype.____constructor(self, obj, evt_name, skill, level)
    base.tsc.__TS__SuperTypeArgumentsFuncWrapper(技能等级变化, {}, TriggerEvent.prototype.____constructor)(self)
    self.obj = obj
    self.evt_name = evt_name
    self.skill = skill
    self.level = level
    self.event_name = "技能-等级变化"
    self.autoForward = false
end

base.技能学习状态变化 = base.tsc.__TS__Class()
base.技能学习状态变化.name = "技能学习状态变化"
base.tsc.__TS__ClassExtends(
    base.技能学习状态变化,
    TriggerEvent,
    function()
        return {}
    end
)
function base.技能学习状态变化.prototype.____constructor(self, obj, evt_name, skill)
    base.tsc.__TS__SuperTypeArgumentsFuncWrapper(技能学习状态变化, {}, TriggerEvent.prototype.____constructor)(self)
    self.obj = obj
    self.evt_name = evt_name
    self.skill = skill
    self.event_name = "技能-学习状态变化"
    self.autoForward = false
end

base.技能层数变化 = base.tsc.__TS__Class()
base.技能层数变化.name = "技能层数变化"
base.tsc.__TS__ClassExtends(
    base.技能层数变化,
    TriggerEvent,
    function()
        return {}
    end
)
function base.技能层数变化.prototype.____constructor(self, obj, evt_name, skill, stack)
    base.tsc.__TS__SuperTypeArgumentsFuncWrapper(技能层数变化, {}, TriggerEvent.prototype.____constructor)(self)
    self.obj = obj
    self.evt_name = evt_name
    self.skill = skill
    self.stack = stack
    self.event_name = "技能-层数变化"
    self.autoForward = false
end

base.技能槽位变化 = base.tsc.__TS__Class()
base.技能槽位变化.name = "技能槽位变化"
base.tsc.__TS__ClassExtends(
    base.技能槽位变化,
    TriggerEvent,
    function()
        return {}
    end
)
function base.技能槽位变化.prototype.____constructor(self, obj, evt_name, skill)
    base.tsc.__TS__SuperTypeArgumentsFuncWrapper(技能槽位变化, {}, TriggerEvent.prototype.____constructor)(self)
    self.obj = obj
    self.evt_name = evt_name
    self.skill = skill
    self.event_name = "技能-槽位变化"
    self.autoForward = false
end

base.玩家暂时离开 = base.tsc.__TS__Class()
base.玩家暂时离开.name = "玩家暂时离开"
base.tsc.__TS__ClassExtends(
    base.玩家暂时离开,
    TriggerEvent,
    function()
        return {}
    end
)
function base.玩家暂时离开.prototype.____constructor(self, obj, evt_name, player)
    base.tsc.__TS__SuperTypeArgumentsFuncWrapper(玩家暂时离开, {}, TriggerEvent.prototype.____constructor)(self)
    self.obj = obj
    self.evt_name = evt_name
    self.player = player
    self.event_name = "玩家-暂时离开"
    self.autoForward = false
end

base.玩家回到游戏 = base.tsc.__TS__Class()
base.玩家回到游戏.name = "玩家回到游戏"
base.tsc.__TS__ClassExtends(
    base.玩家回到游戏,
    TriggerEvent,
    function()
        return {}
    end
)
function base.玩家回到游戏.prototype.____constructor(self, obj, evt_name, player)
    base.tsc.__TS__SuperTypeArgumentsFuncWrapper(玩家回到游戏, {}, TriggerEvent.prototype.____constructor)(self)
    self.obj = obj
    self.evt_name = evt_name
    self.player = player
    self.event_name = "玩家-回到游戏"
    self.autoForward = false
end

base.单位失去物品 = base.tsc.__TS__Class()
base.单位失去物品.name = "单位失去物品"
base.tsc.__TS__ClassExtends(
    base.单位失去物品,
    TriggerEvent,
    function()
        return {}
    end
)
function base.单位失去物品.prototype.____constructor(self, obj, evt_name, player, item, drop_mode)
    base.tsc.__TS__SuperTypeArgumentsFuncWrapper(单位失去物品, {}, TriggerEvent.prototype.____constructor)(self)
    self.obj = obj
    self.evt_name = evt_name
    self.player = player
    self.item = item
    self.drop_mode = drop_mode
    self.event_name = "单位-失去物品"
    self.autoForward = false
end

base.单位获得物品 = base.tsc.__TS__Class()
base.单位获得物品.name = "单位获得物品"
base.tsc.__TS__ClassExtends(
    base.单位获得物品,
    TriggerEvent,
    function()
        return {}
    end
)
function base.单位获得物品.prototype.____constructor(self, obj, evt_name, player, item)
    base.tsc.__TS__SuperTypeArgumentsFuncWrapper(单位获得物品, {}, TriggerEvent.prototype.____constructor)(self)
    self.obj = obj
    self.evt_name = evt_name
    self.player = player
    self.item = item
    self.event_name = "单位-获得物品"
    self.autoForward = false
end


base.联合场景区域通知 = base.tsc.__TS__Class()
base.联合场景区域通知.name = "联合场景区域通知"
base.tsc.__TS__ClassExtends(
    base.联合场景区域通知,
    TriggerEvent,
    function()
        return {}
    end
)
function base.联合场景区域通知.prototype.____constructor(self, obj, evt_name, from_scene, from_area, to_scene, to_area)
    base.tsc.__TS__SuperTypeArgumentsFuncWrapper(联合场景区域通知, {}, TriggerEvent.prototype.____constructor)(self)
    self.obj = obj
    self.evt_name = evt_name
    self.from_scene = from_scene
    self.from_area = from_area
    self.to_scene = to_scene
    self.to_area = to_area
    self.event_name = "联合场景-区域通知"
    self.autoForward = false
end



base.联合场景跨越区域 = base.tsc.__TS__Class()
base.联合场景跨越区域.name = "联合场景跨越区域"
base.tsc.__TS__ClassExtends(
    base.联合场景跨越区域,
    TriggerEvent,
    function()
        return {}
    end
)
function base.联合场景跨越区域.prototype.____constructor(self, obj, evt_name, from_scene, from_area, to_scene, to_area)
    base.tsc.__TS__SuperTypeArgumentsFuncWrapper(联合场景跨越区域, {}, TriggerEvent.prototype.____constructor)(self)
    self.obj = obj
    self.evt_name = evt_name
    self.from_scene = from_scene
    self.from_area = from_area
    self.to_scene = to_scene
    self.to_area = to_area
    self.event_name = "联合场景-跨越区域"
    self.autoForward = false
end

base.联合场景进入区域 = base.tsc.__TS__Class()
base.联合场景进入区域.name = "联合场景进入区域"
base.tsc.__TS__ClassExtends(
    base.联合场景进入区域,
    TriggerEvent,
    function()
        return {}
    end
)
function base.联合场景进入区域.prototype.____constructor(self, obj, evt_name, scene, area, target_scene)
    base.tsc.__TS__SuperTypeArgumentsFuncWrapper(联合场景进入区域, {}, TriggerEvent.prototype.____constructor)(self)
    self.obj = obj
    self.evt_name = evt_name
    self.scene = scene
    self.area = area
    self.target_scene = target_scene
    self.event_name = "联合场景-进入区域"
    self.autoForward = false
end

base.联合场景离开区域 = base.tsc.__TS__Class()
base.联合场景离开区域.name = "联合场景离开区域"
base.tsc.__TS__ClassExtends(
    base.联合场景离开区域,
    TriggerEvent,
    function()
        return {}
    end
)
function base.联合场景离开区域.prototype.____constructor(self, obj, evt_name, scene, area, target_scene)
    base.tsc.__TS__SuperTypeArgumentsFuncWrapper(联合场景离开区域, {}, TriggerEvent.prototype.____constructor)(self)
    self.obj = obj
    self.evt_name = evt_name
    self.scene = scene
    self.area = area
    self.target_scene = target_scene
    self.event_name = "联合场景-离开区域"
    self.autoForward = false
end

base.建造预放置开始 = base.tsc.__TS__Class()
base.建造预放置开始.name = "建造预放置开始"
base.tsc.__TS__ClassExtends(
    base.建造预放置开始,
    TriggerEvent,
    function()
        return {}
    end
)
function base.建造预放置开始.prototype.____constructor(self, obj, evt_name, owner, skill, spellbuild_unit_actor)
    base.tsc.__TS__SuperTypeArgumentsFuncWrapper(建造预放置开始, {}, TriggerEvent.prototype.____constructor)(self)
    self.obj = obj
    self.evt_name = evt_name
    self.owner = owner
    self.skill = skill
    self.spellbuild_unit_actor = spellbuild_unit_actor
    self.event_name = "技能-建造预放置开始"
    self.autoForward = false
end

base.建造预放置取消 = base.tsc.__TS__Class()
base.建造预放置取消.name = "建造预放置开始"
base.tsc.__TS__ClassExtends(
    base.建造预放置取消,
    TriggerEvent,
    function()
        return {}
    end
)
function base.建造预放置取消.prototype.____constructor(self, obj, evt_name, owner, skill, spellbuild_unit_actor)
    base.tsc.__TS__SuperTypeArgumentsFuncWrapper(建造预放置取消, {}, TriggerEvent.prototype.____constructor)(self)
    self.obj = obj
    self.evt_name = evt_name
    self.owner = owner
    self.skill = skill
    self.spellbuild_unit_actor = spellbuild_unit_actor
    self.event_name = "技能-建造预放置取消"
    self.autoForward = false
end

base.建造预放置确认 = base.tsc.__TS__Class()
base.建造预放置确认.name = "建造预放置确认"
base.tsc.__TS__ClassExtends(
    base.建造预放置确认,
    TriggerEvent,
    function()
        return {}
    end
)
function base.建造预放置确认.prototype.____constructor(self, obj, evt_name, owner, skill, spellbuild_unit_actor)
    base.tsc.__TS__SuperTypeArgumentsFuncWrapper(建造预放置确认, {}, TriggerEvent.prototype.____constructor)(self)
    self.obj = obj
    self.evt_name = evt_name
    self.owner = owner
    self.skill = skill
    self.spellbuild_unit_actor = spellbuild_unit_actor
    self.event_name = "技能-建造预放置确认"
    self.autoForward = false
end

base.消息提示显示时 = base.tsc.__TS__Class()
base.消息提示显示时.name = "消息提示显示时"
base.tsc.__TS__ClassExtends(
    base.消息提示显示时,
    TriggerEvent,
    function()
        return {}
    end
)
function base.消息提示显示时.prototype.____constructor(self, obj, evt_name, toast, text, source)
    base.tsc.__TS__SuperTypeArgumentsFuncWrapper(消息提示显示时, {}, TriggerEvent.prototype.____constructor)(self)
    self.obj = obj
    self.evt_name = evt_name
    self.toast = toast
    self.text = text
    self.source = source
    self.event_name = "界面-消息提示显示时"
    self.autoForward = false
end
