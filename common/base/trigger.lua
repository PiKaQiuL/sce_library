---@class Trigger
---@field remove fun()
---@field events Event[]
---@field callback function

local setmetatable = setmetatable
local table = table
local weak_v_metatable = { __mode = 'v' }
local trigger_map = setmetatable({}, { __mode = 'kv' })
local scene_manager = require 'base.scene'


Trigger = base.tsc.__TS__Class()
Trigger.name = 'Trigger'

---@type Trigger
local mt = Trigger.prototype

---@type Trigger
base.trig = mt

--结构
mt.type = 'trigger'

--是否允许
mt.enable_flag = true

mt.sign_remove = false

--事件
mt.event = nil

-- if base.test then
--     function mt:__tostring()
--         return ('[table:trigger:%X]'):format(base.test.topointer(self))
--     end
-- else
    function mt:__tostring()
        return '[table:trigger]'
    end
-- end

--禁用触发器
function mt:disable()
    self.enable_flag = false
end

function mt:enable()
    self.enable_flag = true
end

function mt:is_enable()
    return self.enable_flag
end

--运行触发器
function mt:__call(...)
    if self.sign_remove then
        return
    end
    if self.enable_flag then
        return self:callback(...)
    end
end

--摧毁触发器(移除全部事件)
function mt:remove()
    if not self.events then
        return
    end
    trigger_map[self] = nil
    local events = self.events
    self.events = nil
    self.sign_remove = true
    base.wait(0, function()
        for _, event in ipairs(events) do
            local obj = event.obj
            local name = event.event_name
            if obj and name then
                local event_delegate = obj._events[name]
                if event_delegate then
                    for i = #event_delegate, 1, -1 do
                        local trg = event_delegate[i]
                        if trg == self then
                            table.remove(event_delegate, i)
                            break
                        end
                    end
                    if #event_delegate == 0 then
                        if event.remove then
                            event:remove()
                        end
                    end
                end
            end
        end
    end)
end

function base.trigger_size()
	local count = 0
	for trg in pairs(trigger_map) do
		if not trg.sign_remove then
			count = count + 1
		end
	end
	return count
end

function base.each_trigger()
    return pairs(trigger_map)
end

--创建触发器
--旧方案，不要再使用
function base.trigger(event, callback)
    local trg = setmetatable({callback = callback, events={} }, mt)
    if event then
        table.insert(event, trg)
        table.insert(trg.events, event)
    end
    trigger_map[trg] = true
    return trg
end

---通过函数创建一个新的触发器
---@param action function
---@param combine_args boolean
---@param sync boolean sync区别新旧方法，旧方法传进来的func已经是协程，不好处理
---@return Trigger
function base.trig:new(action, combine_args, scene, sync)
    local trg
    if sync then
        trg = setmetatable({callback = coroutine.will_async(action), callback_sync = action, events = {}, combine_args = combine_args, scene = scene}, self.__index)
    else
        trg = setmetatable({callback = action, events = {}, combine_args = combine_args, scene = scene}, self.__index)
    end
    trigger_map[trg] = true
    return trg
end

function mt:add_event_common(event)
    if event then
        if not(event.time) then
            self:add_event(event.obj, event.event_name, event.custom_event, event.time, event.periodic)
        else
            self:add_event_game_time(event.time, event.periodic)
        end
    end
end

function mt:remove_event_common(event)
    if event then
        if event.time then
            for i = #self.events, 1, -1 do
                local e = self.events[i]
                if event.time == e.time and event.periodic == e.periodic then
                    self:_remove_event(e.obj, e.event_name)
                end
            end
        else
            self:_remove_event(event.obj, event.event_name)
        end
    end
end

--复制触发器
function mt:replicate(include_event)
    local trg
    trg = setmetatable({callback = self.callback, events = {}, combine_args = self.combine_args, scene = self.scene}, self.__index)
    if include_event then
        for i = 1, #self.events do
            local event = self.events[i]
            trg:add_event(event.obj, event.event_name, event.custom_event, event.time, event.periodic)
        end
    end
    return trg
end

--从函数创建回调
function base.trigger_new_from_function(func)
    local trg
    trg = setmetatable({callback = coroutine.will_async(func), callback_sync = func, events = {}, combine_args = true, scene = nil}, mt.__index)
    trigger_map[trg] = true
    return trg
end

---comment
---@param obj table
---@param name string
function mt:add_event(obj, name, custom_event, time, periodic)
    if not name then
        log.error('event_name is error')
        return
    end
    if not obj then
        log.error('event object is nil')
        return
    end
    if self.scene and self.combine_args then
        self:_add_scene_event(obj, name, custom_event, time, periodic)
    else
        if type(obj) == 'function' then
            obj = obj()
        end
        self:_add_event(obj, name, custom_event, time, periodic)
    end

    -- if circle_check(obj) or rect_check(obj) then
    --     if obj.init_region and type(obj.init_region) == 'function' then
    --         obj:init_region()
    --     end
    -- end

    -- local events_delegate = obj._events
    -- if not events_delegate then
    --     events_delegate = {}
    --     obj._events = events_delegate
    -- end

    -- local event_delegate = events_delegate[name]

    -- if not event_delegate then
    --     event_delegate = {}
    --     events_delegate[name] = event_delegate
    --     local ac_event = base.event_subscribe_list[name] or name
    --     if obj.event_subscribe then
    --         obj:event_subscribe(ac_event)
    --     end
    -- end

    -- if event_delegate then
    --     table.insert(event_delegate, self)
    --     table.insert(self.events, event_delegate)
    -- end

    -- event_delegate.custom_event = custom_event
end

function mt:_add_scene_event(obj, name, custom_event, time, periodic)
    if not obj then
        log.error('event object is nil')
        return
    end

    local events_delegate = scene_manager.get_obj_scene_events(self.scene, obj)
    local event_delegate = events_delegate[name]

    if not event_delegate then
        event_delegate = {}
        events_delegate[name] = event_delegate
    end

    event_delegate.custom_event = custom_event
    table.insert(event_delegate, self)

    self.scene_events = self.scene_events or {}
    local trg_event_table = {
        obj = obj,
        event_name = name,
        custom_event = custom_event,
        time = time,
        periodic = periodic,
    }
    trg_event_table = setmetatable(trg_event_table, weak_v_metatable)
    table.insert(self.scene_events, trg_event_table)

    if scene_manager.is_scene_activated(self.scene) then
        self:_add_event(obj, name, custom_event, time, periodic)
    end
end

function mt:_add_event(obj, name, custom_event, time, periodic)
    if not obj then
        log.error('event_ object is nil, can not add event')
        return
    end

    if circle_check(obj, true) or rect_check(obj, true) then
        if obj.init_region and type(obj.init_region) == 'function' then
            obj:init_region()
        end
    end

    local events_delegate = obj._events
    if not events_delegate then
        events_delegate = {}
        obj._events = events_delegate
    end

    --触发器和obj不再用同一个表，obj强引用触发器，触发器弱引用obj
    local event_delegate = events_delegate[name]

    if not event_delegate then
        event_delegate = {}
        events_delegate[name] = event_delegate
        local ac_event = base.event_subscribe_list[name] or name
        if obj.event_subscribe then
            obj:event_subscribe(ac_event)
        end
    end
    event_delegate.custom_event = custom_event
    table.insert(event_delegate, self)

    local trg_event_table = {
        obj = obj,
        event_name = name,
        custom_event = custom_event,
        time = time,
        periodic = periodic,
    }
    trg_event_table = setmetatable(trg_event_table, weak_v_metatable)
    table.insert(self.events, trg_event_table)
end

function mt:_remove_event(obj, name)
    if not obj then
        log.error('event object is nil, can not remove event')
        return
    end
    local events_delegate = obj._events
    if not events_delegate then
        return
    end

    local event_delegate = events_delegate[name]

    if not event_delegate then
        return
    end

    for i = #event_delegate, 1, -1 do
        if event_delegate[i] == self then
            table.remove(event_delegate, i)
        end
    end
end

local event_game_timer = '计时器-游戏时间'

local is_playing = false
local pending_game_timers = {}
--客户端没有阶段事件,用游戏-开始和游戏-结束事件代替
base.game:event('游戏-开始', function()
    is_playing = true
    for key, value in ipairs(pending_game_timers) do
        value.trg:add_event_game_time_internal(value.time, value.periodic)
        pending_game_timers[key] = nil --清空引用
    end
end)

base.game:event('游戏-结束', function()
    is_playing = false
end)
local current_scene = nil
base.game:event('场景-加载完成', function(_, scene)
    if current_scene then
        scene_manager.set_scene_not_activated(current_scene)
    end
    current_scene = scene
    scene_manager.set_scene_activated(current_scene)
end)

-- base.game:event('游戏-阶段切换', function()
-- 	-- if not is_playing and (base.game:status() >= 4 and base.game:status() < 6) then
--     --     is_playing = true
--     --     for _, value in ipairs(pending_game_timers) do
--     --         value.trg:add_event_game_time_internal(value.time, value.periodic)
--     --     end
--     --     -- for _, value in ipairs(pending_game_units) do
--     --     --     local default_unit = base.game.get_default_unit(value.node_mark)
--     --     --     if default_unit and type(default_unit) ~= 'string' then
--     --     --         value.trg:add_event(default_unit, value.event_name)
--     --     --     end
--     --     -- end
-- 	-- end
-- end)

-- base.game:event('游戏-属性变化', function(trigger, game, key, value)
--     base.game:event_notify('游戏-字符串属性变化', game, key, value)
-- end)

-- base.game:event('玩家-属性变化', function(trigger, player, key, value)
--     if base.table.constant['玩家属性'] then
--         for k, id in pairs(base.table.constant['玩家属性']) do
--             if id == key then
--                 if type(value) == 'number' then
--                     base.game:event_notify('玩家-数值属性变化', player, k, value)
--                 elseif type(value) == 'string' then
--                     base.game:event_notify('玩家-字符串属性变化', player, k, value)
--                 end
--                 break
--             end
--         end
--     end
-- end)

-- base.game:event('单位-属性变化', function(trigger, unit, key, value)
--     if base.table.constant['单位属性'] then
--         for k, id in pairs(base.table.constant['单位属性']) do
--             if id == key then
--                 if type(value) == 'number' then
--                     base.game:event_notify('单位-数值属性变化', unit, k, value)
--                 elseif type(value) == 'string' then
--                     base.game:event_notify('单位-字符串属性变化', unit, k, value)
--                 end
--                 break
--             end
--         end
--     end
-- end)
---comment
---@param periodic boolean
---@param time number
function mt:add_event_game_time(time, periodic)
    if is_playing then
        self:add_event_game_time_internal(time, periodic)
    else
        table.insert(pending_game_timers, {trg = self, time = time, periodic = periodic})
    end
end

---comment
---@param periodic boolean
---@param time number
function mt:add_event_game_time_internal(time, periodic)
    local count = periodic and 0 or 1
    local timer = base.timer(time * 1000, count, function (timer)
        if is_playing then
            base.event_notify(timer, event_game_timer)
        end
    end)
    self:add_event(timer, event_game_timer)
end

---comment
---@param action function
function mt:set_action(action)
    self.callback = action
end

---@class Event
---@field remove fun()


base.trig.event = {}

---@type Event
local evt = base.trig.event
evt.evt_args = {}
local args = evt.evt_args


---TODO: 移除damage的概念，所有的伤害都应该通过伤害效果造成。
---@class Damage
---@field damage number
---@field fatal boolean
---@field current_damage number
---@field damage_type string
---@field source string
---@field target string


---通用事件参数类型
---@class EventArgs
---@field sender table
---@field trig Trigger

---comment
---@param obj table
---@param evt_name string
---@return EventArgs
function args.event(obj, evt_name)
    return { sender = obj, evt_name = evt_name }
end

---单位事件参数类型，大部分只有一个参数的单位事件可以共用
---@class UnitEventArgs:EventArgs
---@field unit Unit

---comment
---@param obj table
---@param evt_name string
---@param unit Unit
---@return UnitEventArgs
function args.event_unit(obj, evt_name, unit)
    ---@type UnitEventArgs Description
    local e = args.event(obj, evt_name)
    e.unit = unit
    return e
end

---@class UnitPropertyChangeEventArgs:UnitEventArgs
---@field property string
---@field value_n number
---@field value_s string

---comment
---@param obj any
---@param unit Unit
---@param property string
---@param value number|string
---@return UnitPropertyChangeEventArgs
function args.event_unit_property_change(obj, evt_name, unit, property, value)
    ---@type UnitPropertyChangeEventArgs Description
    local e = args.event_unit(obj, evt_name, unit)
    e.property = property
    if type(value) == "number" then
        e.value_n = value
    else
        e.value_s = value
    end
    return e
end


---comment
---@param obj table
---@param evt_name string
---@param skill Skill
---@return UnitSkillEventArgs
function args.event_skill(obj, evt_name, skill)
    ---@type UnitSkillEventArgs Description
    local e = args.event_unit(obj, evt_name, skill:get_owner())
    e.skill = skill
    return e
end

---@class UnitSkillPropertyChangeEventArgs:UnitSkillEventArgs
---@field property string
---@field value number

---comment
---@param obj any
---@param skill Skill
---@param property string
---@param value number
---@return UnitSkillPropertyChangeEventArgs
function args.event_skill_property_change(obj, evt_name, skill, property, value)
    ---@type UnitSkillPropertyChangeEventArgs Description
    local e = args.event_skill(obj, evt_name, skill)
    e.property = property
    e.value_n = value
    return e
end


---@class UnitSkillLevelChangeEventArgs:UnitSkillEventArgs
---@field level number

---comment
---@param obj any
---@param skill Skill
---@param level number
---@return UnitSkillLevelChangeEventArgs
function args.event_skill_level_change(obj, evt_name, skill, level)
    ---@type UnitSkillLevelChangeEventArgs Description
    local e = args.event_skill(obj, evt_name, skill)
    e.level = level
    return e
end

---@class UnitSkillStackChangeEventArgs:UnitSkillEventArgs
---@field stack number

---comment
---@param obj any
---@param skill Skill
---@param stack number
---@return UnitSkillStackChangeEventArgs
function args.event_skill_stack_change(obj, evt_name, skill, stack)
    ---@type UnitSkillStackChangeEventArgs Description
    local e = args.event_skill(obj, evt_name, skill)
    e.stack = stack
    return e
end


---@class UnitSkillCooldownEventArgs:UnitSkillEventArgs
---@field time_remaining number
---@field time_total number

---comment
---@param obj any
---@param skill Skill
---@param time_remaining_ms number
---@param time_total_ms number
---@return UnitSkillCooldownEventArgs
function args.event_skill_cooldown(obj, evt_name, skill, time_remaining_ms, time_total_ms)
    ---@type SkillCooldownEventArgs Description
    local e = args.event_skill(obj, evt_name, skill)
    e.time_remaining = time_remaining_ms / 1000
    e.time_total = time_total_ms / 1000
    return e
end


---@class UnitDieEventArgs:UnitEventArgs
---@field killer Unit

---comment
---@param obj table
---@param evt_name string
---@param unit Unit
---@param killer Unit
---@return UnitDieEventArgs
function args.event_unit_die(obj, evt_name, unit, killer, type)
    ---@type UnitDieEventArgs Description
    local e = args.event_unit(obj, evt_name, unit)
    e.killer = killer
    e.type = type
    return e
end

---@class UnitDamagedEventArgs:UnitEventArgs
---@field ref_param EffectParam
---@field damage Damage
---@field amount number
---@field damage_source Unit
---@field damage_target Unit

--伤害事件
function args.event_unit_damage_dealt(obj, evt_name, damage)
    ---@type UnitDamagedEventArgs Description
    local e = args.event(obj, evt_name)
    e.damage = damage
    e.amount = damage.damage

    e.unit = damage.source

    e.damage_source = damage.source
    e.damage_target = damage.target

    if damage.ref_param and damage.ref_param.type == 'eff_param' then
        e.ref_param = damage.ref_param
    end

    return e
end

--伤害事件
function args.event_unit_damage_taken(obj, evt_name, damage)
    ---@type UnitDamagedEventArgs Description
    local e = args.event(obj, evt_name)
    e.damage = damage
    e.amount = damage.damage

    e.unit = damage.target

    e.damage_source = damage.source
    e.damage_target = damage.target

    if damage.ref_param and damage.ref_param.type == 'eff_param' then
        e.ref_param = damage.ref_param
    end

    return e
end

---@class UnitBuffEventArgs:UnitEventArgs
---@field buff Buff

function args.event_unit_buff(obj, evt_name, unit, buff)
    ---@type UnitBuffEventArgs Description
    local e = args.event_unit(obj, evt_name, unit)
    e.buff = buff
    return e
end

function args.event_buff(obj, evt_name, buff)
    ---@type UnitBuffEventArgs Description
    local e = args.event_unit(obj, evt_name, buff:get_owner())
    e.buff = buff
    return e
end

---@class UnitBuffStackChangeEventArgs:UnitSkillEventArgs
---@field stack number

---comment
---@param obj any
---@param buff Buff
---@param stack number
---@return UnitSkillStackChangeEventArgs
function args.event_buff_stack_change(obj, evt_name, buff, stack, unit)
    ---@type UnitSkillStackChangeEventArgs Description
    local e = args.event_buff(obj, evt_name, buff)
    e.stack = stack
    e.unit = unit
    return e
end

---@class UnitPurchaseItemEventArgs:UnitEventArgs
---@field item_name string

function args.event_unit_purchase_item(obj, evt_name, unit, item_name)
    ---@type UnitPurchaseItemEventArgs Description
    local e = args.event_unit(obj, evt_name, unit)
    e.item_name = item_name
    return e
end

---@class UnitInventoryEventArgs:UnitEventArgs
---@field slot integer

function args.event_unit_inventory(obj, evt_name, unit, slot)
    ---@type UnitInventoryEventArgs
    local e = args.event_unit(obj, evt_name, unit)
    e.slot = slot
    return e
end

---@class UnitInventoryTargetEventArgs:UnitInventoryEventArgs
---@field target Target

function args.event_unit_inventory_target(obj, evt_name, unit, slot, target)
    ---@type UnitInventoryTargetEventArgs
    local e = args.event_unit_inventory(obj, evt_name, unit, slot)
    e.target = target
    if target then
        e.target_unit = target:get_unit()
        e.target_point = target:get_point()
    end
    return e
end

---@class UnitItemEventArgs:UnitEventArgs
---@field item Item
---@field drop_mode boolean

function args.event_unit_item(obj, evt_name, unit, item, drop_mode)
    ---@type UnitItemEventArgs
    local e = args.event_unit(obj, evt_name, unit)
    e.item = item
    e.drop_mode = drop_mode
    return e
end

---@class UnitCmdRequestEventArgs:UnitEventArgs
---@field command string
---@field target Target
---@field key_modifier integer

function args.event_unit_cmd_request(obj, evt_name, unit, command, target, key_modifier)
    ---@type UnitCmdRequestEventArgs
    local e = args.event_unit(obj, evt_name, unit)
    e.command = command
    e.target = target
    if target then
        e.target_unit = target:get_unit()
        e.target_point = target:get_point()
    end
    e.key_modifier = key_modifier
    return e
end

---@class UnitMovedEventArgs:UnitEventArgs
---@field pos_old Point
---@field pos_new Point

function args.event_unit_moved(obj, evt_name, unit, pos_old, pos_new)
    ---@type UnitMovedEventArgs
    local e = args.event_unit(obj, evt_name, unit)
    e.pos_old = pos_old
    e.pos_new = pos_new
    return e
end

--[[
---@class UnitLanedEventArgs:UnitEventArgs
---@field vector_z number

function args.event_unit_laned(obj, evt_name, unit, vector_z)
    ---@type UnitLanedEventArgs
    local e = args.event_unit(obj, evt_name, unit)
    e.vector_z = vector_z
    return e
end
]]--

---@class UnitSkillEventArgs:UnitEventArgs
---@field skill Skill

function args.event_unit_skill(obj, evt_name, unit, skill)
    ---@type UnitSkillEventArgs
    local e = args.event_unit(obj, evt_name, unit)
    e.skill = skill
    return e
end

---@class UnitSkillCastEventArgs:UnitEventArgs
---@field skill_id string
---@field time_elapsed number
---@field time_total number

---comment
---@param obj any
---@param unit Unit
---@param skill_id string
---@param time_elapsed_ms number
---@param time_total_ms number
---@return UnitSkillCastEventArgs
function args.event_unit_skill_stage(obj, evt_name, unit, skill_id, time_elapsed_ms, time_total_ms)
    ---@type UnitSkillCastEventArgs
    local e = args.event_unit(obj, evt_name, unit)
    e.skill_id = skill_id
    e.time_elapsed = time_elapsed_ms / 1000
    e.time_total = time_total_ms / 1000
    return e
end

---@class UnitSkillResultEventArgs:UnitSkillEventArgs
---@field result_code integer

function args.event_unit_skill_result(obj, evt_name, unit, skill, result_code)
    ---@type UnitSkillResultEventArgs
    local e = args.event_unit_skill(obj, evt_name, unit, skill)
    e.result_code = result_code
    return e
end


---TODO: 需要针对xp_data操作的特殊函数
---@class UnitXPEventArgs:UnitEventArgs
---@field xp table

function args.event_unit_xp(obj, evt_name, xp_data)
    ---@type UnitXPEventArgs
    local e = args.event(obj, evt_name)
    e.unit = xp_data.hero
    e.xp = xp_data.exp
    return e
end

---@class UnitMoverEventArgs:UnitEventArgs
---@field mover Mover

function args.event_unit_mover(obj, evt_name, unit, mover)
    ---@type UnitMoverEventArgs
    local e = args.event_unit(obj, evt_name, unit)
    e.mover = mover
    return e
end

---@class UnitSceneEventArgs:UnitEventArgs
---@field scene_name string

function args.event_unit_scene(obj, evt_name, unit, scene_name)
    ---@type UnitSceneEventArgs
    local e = args.event_unit(obj, evt_name, unit)
    e.scene_name = scene_name
    return e
end

---@class Area

---@class AreaEventArgs:UnitEventArgs
---@field area Area

function args.event_area(obj, evt_name, area, unit)
    ---@type AreaEventArgs
    local e = args.event_unit(obj, evt_name, unit)
    e.area = area
    return e
end

---@class PlayerEventArgs:EventArgs
---@field player Player

---@param player Player
function args.event_player(obj, evt_name, player)
    ---@type PlayerEventArgs
    local e = args.event(obj, evt_name)
    e.player = player
    return e
end

---@class PlayerUnitEventArgs:PlayerEventArgs
---@field unit Unit

---@param player Player
---@param unit Unit
function args.event_player_unit(obj, evt_name, player, unit)
    ---@type PlayerEventArgs
    local e = args.event_player(obj, evt_name, player)
    e.unit = unit
    return e
end


---@class PlayerTeamEventArgs:PlayerEventArgs
---@field team number

---@param player Player
---@param team number
function args.event_player_team(obj, evt_name, player, team)
    ---@type PlayerTeamEventArgs
    local e = args.event_player(obj, evt_name, player)
    e.team = team
    return e
end

---@class PlayerPropertyChangeEventArgs:PlayerEventArgs
---@field property string
---@field value_n number
---@field value_s string

---comment
---@param obj any
---@param player Player
---@param property string
---@param value number|string
---@return PlayerPropertyChangeEventArgs
function args.event_player_property_change(obj, evt_name, player, property, value)
    ---@type PlayerPropertyChangeEventArgs Description
    local e = args.event_player(obj, evt_name, player)
    e.property = property
    if type(value) == "number" then
        e.value_n = value
    else
        e.value_s = value
    end
    return e
end


---@class PlayerConnectEventArgs:PlayerEventArgs
---@field is_reconnect boolean

---@param player Player
function args.event_player_connect(obj, evt_name, player, is_reconnect)
    ---@type PlayerConnectEventArgs
    local e = args.event_player(obj, evt_name, player)
    e.is_reconnect = is_reconnect
    return e
end

--[[
---@class PlayerChatEventArgs:PlayerEventArgs
---@field msg string

function args.event_player_chat(obj, evt_name, player, msg)
    ---@type PlayerChatEventArgs
    local e = args.event_player(obj, evt_name, player)
    e.msg = msg
    return e
end
]]--

---@class PlayerPickHeroEventArgs:PlayerEventArgs
---@field hero_name string

function args.event_player_pick_hero(obj, evt_name, player, hero_name)
    ---@type PlayerPickHeroEventArgs
    local e = args.event_player(obj, evt_name, player)
    e.hero_name = hero_name
    return e
end

---@class PlayerSceneEventArgs:PlayerEventArgs
---@field scene_name string

function args.event_player_scene(obj, evt_name, player, scene_name)
    ---@type PlayerSceneEventArgs
    local e = args.event_player(obj, evt_name, player)
    e.scene_name = scene_name
    return e
end

---@class PlayerConfigEventArgs:PlayerEventArgs
---@field config string

function args.event_player_config(obj, evt_name, player, config)
    ---@type PlayerConfigEventArgs
    local e = args.event_player(obj, evt_name, player)
    e.config = config
    return e
end

---@class PlayerPingEventArgs:PlayerEventArgs
---@field ping table

function args.event_player_ping(obj, evt_name, player, ping)
    ---@type PlayerPingEventArgs
    local e = args.event_player(obj, evt_name, player)
    e.ping = ping
    return e
end

---@class PlayerKeyDownEventArgs:PlayerEventArgs
---@field key string

function args.event_player_key_down(obj, evt_name, player, key)
    ---@type PlayerKeyDownEventArgs
    local e = args.event_player(obj, evt_name, player)
    e.key = key
    e.key_keyboard = key
    return e
end

---@class PlayerKeyUpEventArgs:PlayerEventArgs
---@field key string

function args.event_player_key_up(obj, evt_name, player, key)
    ---@type PlayerKeyUpEventArgs
    local e = args.event_player(obj, evt_name, player)
    e.key = key
    e.key_keyboard = key
    return e
end

---@class PlayerMouseDownEventArgs:PlayerEventArgs
---@field mouse integer

function args.event_player_mouse_down(obj, evt_name, player, key)
    ---@type PlayerMouseDownEventArgs
    local e = args.event_player(obj, evt_name, player)
    e.key = key
    return e
end

---@class PlayerMouseUpEventArgs:PlayerEventArgs
---@field mouse integer

function args.event_player_mouse_up(obj, evt_name, player, key)
    ---@type PlayerMouseUpEventArgs
    local e = args.event_player(obj, evt_name, player)
    e.key = key
    return e
end

---@class PlayerWheelMoveEventArgs:PlayerEventArgs
---@field delta_whell number

function args.event_player_wheel_move(obj, evt_name, player, delta_wheel)
    ---@type PlayerWheelMoveEventArgs
    local e = args.event_player(obj, evt_name, player)
    e.delta_wheel = delta_wheel
    return e
end

---@class GameUpdateEventArgs:EventArgs
---@field delta number

function args.event_update(obj, evt_name, delta)
    ---@type GameUpdateEventArgs
    local e = args.event(obj, evt_name)
    e.delta = delta
    return e
end

---@class GameUpdateEventArgs:EventArgs
---@field screen_pos ScreenPos
---@field actors_ID table
---@field button string
function args.event_click(obj, evt_name, screen_pos, actors_ID, button)
    local e = args.event(obj, evt_name)
    e.screen_pos = base.screen_pos(screen_pos.x, screen_pos.y)
    e.actors_ID = actors_ID
    e.button = button == 1 and 'button_left' or button == 2 and 'button_middle' or button == 4 and 'button_right'
    return e
end

function args.event_enter_foreground(obj, evt_name, module_key)
    local e = args.event(obj, evt_name)
    e.key = module_key
    return e
end

---@class GamePropertyChangeEventArgs:EventArgs
---@field property string
---@field value string

function args.event_property_change(obj, evt_name, property, value)
    ---@type GameUpdateEventArgs
    local e = args.event(obj, evt_name)
    e.property = property
    e.value_s = value
    return e
end

---@class MessageEventArgs:EventArgs
---@field msg string

function args.event_message(obj, evt_name, msg)
    ---@type MessageEventArgs
    local e = args.event(obj, evt_name)
    e.msg = msg
    return e
end

---@class MessageTimedEventArgs:MessageEventArgs
---@field duration number

function args.event_message_timed(obj, evt_name, msg, duration)
    ---@type MessageTimedEventArgs
    local e = args.event_message(obj, evt_name, msg)
    e.duration = duration
    return e
end

---@class MessageChatEventArgs:MessageEventArgs
---@field player_slot_id number

function args.event_message_chat(obj, evt_name, player_slot_id, type, msg, time)
    local e = args.event_message(obj, evt_name, msg)
    e.player = base.player(player_slot_id)
    e.duration = time --不太确定这个time表示的含义，看起来和上面的消息是一样的
end

---@class ResolutionEventArgs:EventArgs
---@field width number
---@field height number

function args.event_resolution(obj, evt_name, width, height)
    ---@type ResolutionEventArgs
    local e = args.event(obj, evt_name)
    e.width = width
    e.height = height
    return e
end

---@class ScaleEventArgs:EventArgs
---@field scale number

function args.event_scale(obj, evt_name, scale)
    ---@type ResolutionEventArgs
    local e = args.event(obj, evt_name)
    e.scale = scale
    return e
end

---@class KeyEventArgs:EventArgs
---@field key string

function args.event_key(obj, evt_name, key)
    ---@type KeyEventArgs
    local e = args.event(obj, evt_name)
    e.key = key
    return e
end

---@class KeyDownEventArgs:EventArgs
---@field key string

function args.event_key_down(obj, evt_name, key)
    ---@type KeyDownEventArgs
    local e = args.event(obj, evt_name)
    e.key = key
    e.key_keyboard = key
    return e
end

---@class KeyUpEventArgs:EventArgs
---@field key string

function args.event_key_up(obj, evt_name, key)
    ---@type KeyUpEventArgs
    local e = args.event(obj, evt_name)
    e.key = key
    e.key_keyboard = key
    return e
end

---@class MouseDownEventArgs:EventArgs
---@field key string

function args.event_mouse_down(obj, evt_name, key)
    ---@type MouseDownEventArgs
    local e = args.event(obj, evt_name)
    e.key = key
    return e
end

---@class MouseUpEventArgs:EventArgs
---@field key string

function args.event_mouse_up(obj, evt_name, key)
    ---@type MouseUpEventArgs
    local e = args.event(obj, evt_name)
    e.key = key
    return e
end

---@class ActorEventArgs:EventArgs
---@field actor Actor

function args.event_actor(obj, evt_name, id)
    ---@type ActorEventArgs
    local e = args.event(obj, evt_name)
    e.actor = base.actor_from_id(id)
    return e
end

---@class ActorAnimMessageEvent:ActorEventArgs
---@field anim string
---@field msg string

function args.event_actor_anim_message(obj, evt_name, id, msg, anim)
    ---@type ActorAnimMessageEvent
    local e = args.event_actor(obj, evt_name, id)
    e.msg = msg
    e.anim = anim
    return e
end

---@class ActorSoundMessageEvent:ActorEventArgs
---@field msg string
function args.event_actor_sound_message(obj, evt_name, id, msg)
    ---@type ActorAnimMessageEvent
    local e = args.event_actor(obj, evt_name, id)
    e.msg = msg
    return e
end

-- ---@class MapEventArgs:EventArgs
-- ---@field map_name string
-- function args.event_map(obj, evt_name, map_name)
--     ---@type MapEvent
--     local e = args.event(obj, evt_name)
--     e.map_name = map_name
--     return e
-- end

-- ---@class MapPercentEventArgs:EventArgs
-- ---@field map_name string
-- function args.event_map_percent(obj, evt_name, content, percent)
--     local e = args.event(obj, evt_name)
--     e.load_content = content
--     e.percent = percent
--     return e
-- end

---@class SceneEventArgs:EventArgs
---@field scene_name string
function args.event_scene(obj, evt_name, scene_name)
    local e = args.event(obj, evt_name)
    e.scene_name = scene_name
    return e
end

---@class GameSceneEventArgs:EventArgs
---@field scene_name string

function args.event_game_scene(obj, evt_name, game, scene_name)
    ---@type GameSceneEventArgs
    local e = args.event(obj, evt_name)
    e.scene_name = scene_name
    return e
end

---@class EffectParamEventArgs:EventArgs
---@field ref_param EffectParam

function args.event_eff_param(obj, evt_name, ref_param)
    ---@type EffectParamEventArgs
    local e = args.event(obj, evt_name)
    e.ref_param = ref_param
    return e
end

---@class EffectParamImpactUnitEventArgs:EffectParamEventArgs
---@field ref_param EffectParam
---@field impacted_unit Unit

function args.event_eff_param_impact_unit(obj, evt_name, ref_param, impacted_unit)
    ---@type EffectParamImpactUnitEventArgs
    local e = args.event(obj, evt_name)
    e.ref_param = ref_param
    e.impacted_unit = impacted_unit
    return e
end

---@class CustomEventArgs:CustomEventArgs
---@field name string
function args.event_custom_event(obj, evt_name, custom_args)
    local e = args.event(obj, evt_name)
    e[evt_name] = custom_args
    return e
end

function args.game_string_attribute_change(obj, evt_name, game, key, value)
    local e = args.event(obj, evt_name)
    e.game_attribute_key = key
    e.game_attribute_string_value = value
    return e
end

function args.player_number_attribute_change(obj, evt_name, player, key, value, value_change)
    local e = args.event_player(obj, evt_name, player)
    e.player_attribute_key = key
    e.player_attribute_number_value = value
    e.player_attribute_number_value_change = value_change
    return e
end

function args.player_string_attribute_change(obj, evt_name, player, key, value)
    local e = args.event_player(obj, evt_name, player)
    e.player_attribute_key = key
    e.player_attribute_string_value = value
    return e
end

function args.unit_number_attribute_change(obj, evt_name, unit, key, value, value_change)
    local e = args.event_unit(obj, evt_name, unit)
    e.unit_attribute_key = key
    e.unit_attribute_number_value = value
    e.unit_attribute_number_value_change = value_change
    return e
end

function args.unit_string_attribute_change(obj, evt_name, unit, key, value)
    local e = args.event_unit(obj, evt_name, unit)
    e.unit_attribute_key = key
    e.unit_attribute_string_value = value
    return e
end

function args.event_conversation(obj, evt_name, speaker, listener, ref_param, conversation_link)
    local e = args.event(obj, evt_name)
    e.speaker = speaker
    e.listener = listener
    e.ref_param = ref_param
    e.conversation_link = conversation_link
    return e
end

function args.event_conversation_choose(obj, evt_name, speaker, listener, ref_param, conversation_link, conversation_choice_item_link)
    local e = args.event(obj, evt_name)
    e.speaker = speaker
    e.listener = listener
    e.ref_param = ref_param
    e.conversation_link = conversation_link
    e.conversation_choice_item_link = conversation_choice_item_link
    return e
end

function args.event_item_inventory(
    obj, evt_name, item
    ,slot               ,slot_previous
    ,slot_index         ,slot_previous_index
    ,inventory          ,inventory_previous
    ,inventory_index    ,inventory_previous_index
)
    local e = args.event(obj, evt_name) --[[@as ItemEventArgs]]
    e.item = item
    e.slot = slot
    e.slot_index = slot_index
    e.inventory = inventory
    e.inventory_index = inventory_index
    e.slot_previous = slot_previous
    e.slot_previous_index = slot_previous_index
    e.inventory_previous = inventory_previous
    e.inventory_previous_index = inventory_previous_index
    return e
end

function args.event_inventory_item_tooltip( obj, evt_name, item, item_tooltip_panel, slot_panel, inventory_panel)
    local e = args.event(obj, evt_name) --[[@as ItemEventArgs]]
    --e.inventory = inventory
    --e.slot = slot
    e.item = item
    e.item_tooltip_panel = item_tooltip_panel
    e.slot_panel = slot_panel
    e.inventory_panel = inventory_panel
    return e
end

function args.event_server_change_scene( obj, evt_name, old_scene, new_scene)
    local e = args.event(obj, evt_name)
    e.old_scene = old_scene
    e.new_scene = new_scene
    return e
end

function args.event_scene_combind_area_notify( obj, evt_name, from_scene, from_area, to_scene, to_area)
    local e = args.event(obj, evt_name)
    if from_scene=='' then from_scene = nil end
    if from_area=='' then from_area = nil end
    if to_scene=='' then to_scene = nil end
    if to_area=='' then to_area = nil end
    e.from_scene = from_scene
    e.from_area = from_area
    e.to_scene = to_scene
    e.to_area = to_area
    return e
end

function args.event_scene_combind_area_notifyB( obj, evt_name, scene, area, target_scene)
    local e = args.event(obj, evt_name)
    if scene=='' then scene = nil end
    if area=='' then area = nil end
    if target_scene=='' then target_scene = nil end
    e.scene = scene
    e.area = area
    e.target_scene = target_scene
    return e
end

function args.event_spellbuild_preview( obj, evt_name, owner, skill, spellbuild_unit_actor)
    local e = args.event(obj, evt_name)
    e.owner = owner
    e.skill = skill
    e.spellbuild_unit_actor = spellbuild_unit_actor
    return e
end

function args.event_toast_show( obj, evt_name, toast, text, source)
    local e = args.event(obj, evt_name)
    e.toast = toast
    e.text = text
    e.source = source
    return e
end

base.debug_bp = debug_bp

---todo:

evt.event_list = {
    ['单位-进入视野'] = 'event_unit',
    ['单位-离开视野'] = 'event_unit',

    ['单位-选中'] = 'event_player_unit',
    ['单位-取消选中'] = 'event_player_unit',

    ['单位-属性变化'] = 'event_unit_property_change',

    ["单位-施法开始"] = 'event_unit_skill_stage',
    ["单位-施法引导"] = 'event_unit_skill_stage',
    ["单位-施法出手"] = 'event_unit_skill_stage',
    ["单位-施法完成"] = 'event_unit_skill_stage',
    ["单位-施法停止"] = 'event_unit_skill_stage',

    ['单位-获得状态'] = 'event_unit_buff',
    ['单位-失去状态'] = 'event_unit_buff',
    ['单位-状态层数变化'] = 'event_buff_stack_change',

    ['单位-失去物品'] = 'event_unit_item',
    ['单位-获得物品'] = 'event_unit_item',

    ['技能-获得'] = 'event_unit_skill',
    ['技能-失去'] = 'event_unit_skill',

    ['技能-属性变化'] = 'event_skill_property_change',
    ['技能-等级变化'] = 'event_skill_level_change',
    ['技能-层数变化'] = 'event_skill_stack_change',
    ['技能-槽位变化'] = 'event_skill',
    ['技能-可用状态变化'] = 'event_skill',
    ['技能-学习状态变化'] = 'event_skill',
    ['技能-冷却完成'] = 'event_skill',
    ['技能-冷却激活'] = 'event_skill_cooldown',
    ['技能-充能激活'] = 'event_skill_cooldown',

    ['状态-获得'] = 'event_unit_buff',
    ['状态-失去'] = 'event_unit_buff',
    ['状态-层数变化'] = 'event_buff_stack_change',

    ['玩家-改变英雄'] = 'event_player_unit',
    ['玩家-改变队伍'] = 'event_player_team',
    ['玩家-属性变化'] = 'event_player_property_change',
    ['玩家-断线']     = 'event_player',
    ['玩家-重连']     = 'event_player',
    ['玩家-暂时离开']     = 'event_player',
    ['玩家-回到游戏']     = 'event_player',

    ['游戏-开始'] = 'event',
    ['游戏-结束'] = 'event',
    ['游戏-更新'] = 'event_update',
    ['游戏-点击'] = 'event_click',
    ['游戏进入前台'] = 'event_enter_foreground',
    ['游戏-属性变化'] = 'event_property_change',
    ['游戏-阶段切换'] = 'event',
    ['场景-加载完成'] = 'event_scene',
    -- 测试了一下加载地图的时机比注册触发器还早，所以这几个事件在触发器里面没意义。。
    -- ['加载地图'] = 'event_map',
    -- ['加载地图进度'] = 'event_map_percent',
    -- ['加载地图完成'] = 'event_map',
    -- ['卸载地图'] = 'event_map',

    ['消息-技能'] = 'event_message',
    ['消息-错误'] = 'event_message_timed',
    ['消息-公告'] = 'event_message_timed',
    ['消息-聊天'] = 'event_message_chat',

    ['画面-分辨率变化'] = 'event_resolution',
    ['画面-分辨率缩放变化'] = 'event_scale',

    ['按键-按下'] = 'event_key_down',
    ['按键-松开'] = 'event_key_up',

    ['鼠标-按下'] = 'event_mouse_down',
    ['鼠标-松开'] = 'event_mouse_up',
    ['鼠标-移动'] = 'event',
    ['Src-PostCacheInit'] = 'event',

    ['表现-动画事件开始'] = 'event_actor_anim_message',
    ['表现-动画事件结束'] = 'event_actor_anim_message',
    ['表现-音效事件'] = 'event_actor_anim_message',

    ['对话-开始'] = 'event_conversation',
    ['对话-结束'] = 'event_conversation',
    ['对话-跳过'] = 'event_conversation',
    ['对话-选择'] = 'event_conversation_choose',
    ['物品-创建'] = 'event_item',
    ['物品-在物品栏内移动'] = 'event_item_inventory',
    ['鼠标-点击物品栏格子时'] = 'event_inventory_item_tooltip',
    ['鼠标-长按物品栏格子时'] = 'event_inventory_item_tooltip',
    ['鼠标-长按物品栏格子抬起时'] = 'event_inventory_item_tooltip',

    ['场景-请求切换'] = 'event_server_change_scene',
    ['联合场景-区域通知'] = 'event_scene_combind_area_notify',
    ['联合场景-跨越区域'] = 'event_scene_combind_area_notify',
    ['联合场景-进入区域'] = 'event_scene_combind_area_notifyB',
    ['联合场景-离开区域'] = 'event_scene_combind_area_notifyB',

    ['技能-建造预放置开始'] = 'event_spellbuild_preview',
    ['技能-建造预放置取消'] = 'event_spellbuild_preview',
    ['技能-建造预放置确认'] = 'event_spellbuild_preview',

    ['界面-消息提示显示时'] = 'event_toast_show',
    ['鼠标-'] = 'event_inventory',
}

--dispatch机制存在问题，当多个触发器请求了这些事件时会发生争夺。
--目前暂时可能就不予考虑，用技能编辑器来解决了
evt.dispatch_events = {

}

--[[
用于删除事件的函数，然而由于大部分地图都使用了现有触发器，这个改动需要改动那些地图
---@field object table
---@field name string


evt.__index = evt

function evt:new(obj, name)
    local events_delegate = obj._events
    if not events_delegate then
        events_delegate = {}
        obj._events = events_delegate
    end

    local event_delegate = events_delegate[name]

    if not event_delegate then
        event_delegate = {}
        events_delegate[name] = event_delegate
        local base_event = base.event_subscribe_list[name] or name
        if obj.event_subscribe then
            obj:event_subscribe(base_event)
        end
    end

    local event = { object = obj, name = name}
    setmetatable(event, self.__index)
    return event
end

function evt:remove()
    if self.object then
        self.object._events = nil
        if self.object.event_unsubscribe then
            local base_event = base.event_subscribe_list[self.name] or self.name
            self.object:event_unsubscribe(base_event)
        end
    end
end
]]--

return {
    Trigger = Trigger,
}