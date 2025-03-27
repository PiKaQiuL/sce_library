Skill = base.tsc.__TS__Class()
Skill.name = 'Skill'

local mt = {}
local api = Skill.prototype

base.skill_api = api

local util = require 'base.util'

local key_map = {
    [2]  = 'cost',
    [4]  = 'target_type',
    [5]  = 'area_type',
    [6]  = 'cast_type',
    [7]  = 'affect_type',
    [8]  = 'need_cast_in_range',
    [9]  = 'distance',
    [10] = 'cool',
    [11] = 'charge_cool',
    [12] = '_disable',
    [13] = '_auto',
    [14] = '_requirement',
    [15] = 'range',
    [16] = 'fan_degree',
    [17] = 'rectangle_width',
    [18] = '_stack',
    [19] = 'show_stack',
    [20] = '_slot_id',
    [21] = '_level',
    [22] = 'cooldown_mode',
    [23] = 'charge_max_stack',
}
local dual_key = {}
for _, key in pairs(key_map) do
    dual_key[key] = true
end

local SLOT_MAX = 1000
local SLOT_TYPE = {
    [0] = '英雄',
    [1] = '物品',
    [2] = '通用',
    [3] = '隐藏',
    [4] = '攻击',
}
local SLOT_MAP = {
    ['英雄'] = SLOT_MAX * 0,
    ['物品'] = SLOT_MAX * 1,
    ['通用'] = SLOT_MAX * 2,
    ['隐藏'] = SLOT_MAX * 3,
    ['攻击'] = SLOT_MAX * 4,
}

local skill_name_hash_map
local function get_skill_name_by_hash(hash)
    if not skill_name_hash_map then
        skill_name_hash_map = {}
        for name in pairs(base.table.skill) do
            local hash = common.string_hash(name)
            skill_name_hash_map[hash] = name
        end
    end
    return skill_name_hash_map[hash]
end

local function active_cd(self, cd, total)
    local actived = not self._cd_tick
    self:resume()
    self._cd_tick = cd + base.clock()
    self._total_cd = total
    self:update_paused()
    if actived then
        self:event_notify('技能-冷却激活', self, cd, total)
    else
        self:event_notify('技能-冷却更新', self, cd, total)
    end
end

local function finish_cd(self)
    if not self._cd_tick then
        return
    end
    self._cd_tick = nil
    self:event_notify('技能-冷却完成', self)
end

local function active_charge_cd(self, cd, total)
    local actived = not self._charge_cd_tick
    self._charge_cd_tick = cd + base.clock()
    self._total_charge_cd = total
    if actived then
        self:event_notify('技能-充能激活', self, cd, total)
    end
end

local function finish_charge_cd(self)
    if not self._charge_cd_tick then
        return
    end
    self._charge_cd_tick = nil
    self:event_notify('技能-充能完成', self)
end

local skill_map = {}
local removed_skill_map = setmetatable({}, { __mode = 'v' })

local function is_removed(self)
    return not not removed_skill_map[self._id]
end

local client_remove_map = {}
function api:client_remove()
    if is_removed(self) then
        return
    end
    self._owner.skill[self] = nil
    skill_map[self._id] = nil
    removed_skill_map[self._id] = self
    client_remove_map[self._id] = self
    local cooldown_key = self:get_cooldown_key()
    if cooldown_key then
        self._owner:remove_from_cooldown_map(cooldown_key, self)
    end
end

local function remove(self)
    if is_removed(self) then
        return
    end
    self._owner.skill[self] = nil
    skill_map[self._id] = nil
    removed_skill_map[self._id] = self
    client_remove_map[self._id] = nil
    local cooldown_key = self:get_cooldown_key()
    if cooldown_key then
        self._owner:remove_from_cooldown_map(cooldown_key, self)
    end
    self._owner:event_notify('技能-失去', self._owner, self)
end

local function can_request(self)
    if is_removed(self) then
        return false
    end
    if not self._slot_id then
        return false
    end
    local unit = self:get_owner()
    local player = unit:get_owner()
    if player ~= base.local_player() then
        return false
    end
    return true
end

local DUMMY = {}
base.skill = setmetatable({}, {__index = function (self, name)
    local data = base.table.skill[name] or DUMMY
    local skill = base.game.lni:normalize(data)
    self[name] = skill
    return skill
end})
base.skill.get_skill_name_by_hash = get_skill_name_by_hash

local function ac_skill(id, hash, owner)
    if not id or id == 0 then
        return nil
    end
    if not skill_map[id] then
        if not hash or not owner then
            log.error('技能信息不全：', id)
            return nil
        end
        if removed_skill_map[id] and not client_remove_map[id] then
            log.error('访问已被移除的技能：', removed_skill_map[id])
            return removed_skill_map[id]
        else
            local name = get_skill_name_by_hash(hash)
            local skill = setmetatable({
                _id = id,
                _user_attribute = {},
                _name = name,
                _owner = owner,
                _hash = hash,
                _data = base.skill[name],
                cache = base.eff.cache(name)
            }, mt)
            for k, v in pairs(api) do
                skill[k] = v
            end
            owner.skill[skill] = id
            skill_map[id] = skill
            removed_skill_map[id] = nil
        end
    end
    return skill_map[id]
end
base.skill.ac_skill = ac_skill

local function set(self, key, value)
    local old = self[key]
    if old == value then
        return false
    end
    self[key] = value
    return true
end

local function set_user_attribute(self, key, value)
    local old = self._user_attribute[key]
    if old == value then
        return false
    end
    self._user_attribute[key] = value
    return true
end

local function update_attribute(self, attr, events)
    for id, value in pairs(attr) do
        local key = key_map[id]
        if key then
            if set(self, key, value) then
                if key == '_auto' then
                elseif key == '_level' then
                    events[#events+1] = {'技能-等级变化', self, value}
                elseif key == '_stack' then
                    events[#events+1] = {'技能-层数变化', self, value}
                elseif key == '_slot_id' then
                    events[#events+1] = {'技能-槽位变化', self}
                elseif key == '_disable' then
                    events[#events+1] = {'技能-可用状态变化', self}
                elseif key == '_requirement' then
                    events[#events+1] = {'技能-学习状态变化', self}
                else
                    events[#events+1] = {'技能-属性变化', self, key, value}
                end
            end
        elseif type(id) == 'string' and id ~= 'unit_id' and id ~= 'spell_id' then
            if set_user_attribute(self, id, value) then
            -- 这里是发user_attribute
                events[#events+1] = {'技能-属性变化', self, id, value}
            end
        end
    end
end

local function update_attribute_without_event(self, attr)
    for id, value in pairs(attr) do
        local key = key_map[id]
        if key then
            set(self, key, value)
        elseif type(id) == 'string' and id ~= 'unit_id' and id ~= 'spell_id' then
            set_user_attribute(self, id, value)
        end
    end
end

function base.event.on_spell_attributes_changed(key_values)
    local events = {}
    for id, attr in pairs(key_values) do
        local new = not skill_map[id]
        local unit = base.unit(attr.unit_id)
        local skill = ac_skill(id, attr.spell_id, unit)
        if new and not client_remove_map[id] then
            update_attribute_without_event(skill, attr)
            unit:event_notify('技能-获得', unit, skill)
            log_file.info(attr.unit_id .. ' 获得技能 ' .. skill._name .. ' ')
        else
            update_attribute(skill, attr, events)
        end
    end
    for _, event in ipairs(events) do
        local name = event[1]
        local skill = event[2]
        skill:event_notify(name, skill, event[3], event[4])
    end
end

function base.event.on_remove_spell(removed_spells)
    for unit_id, spells in pairs(removed_spells) do
        local unit = base.unit(unit_id)
        for skill_id, name_hash in pairs(spells) do
            local skill = ac_skill(skill_id, name_hash, unit)
            remove(skill)
        end
    end
end

function base.event.on_spell_cd_changed(id, cd, total, type)
    local skill = ac_skill(id)
    if not skill then
        return
    end
    if type == 0 then
        active_cd(skill, cd, total)
    elseif type == 1 then
        active_charge_cd(skill, cd, total)
    end
end

function base.event.on_spell_cd_finished(id, type)
    local skill = ac_skill(id)
    if not skill then
        return
    end
    if type == 0 then
        finish_cd(skill)
    elseif type == 1 then
        finish_charge_cd(skill)
    end
end

function base.event.on_spell_cast_approach_ex(unit_id, hash)
    local unit = base.unit(unit_id)
    local name = get_skill_name_by_hash(hash)
    unit:event_notify('单位-施法接近', unit, name)
end

function base.event.on_spell_cast_start_ex(unit_id, hash, time, total)
    local unit = base.unit(unit_id)
    local name = get_skill_name_by_hash(hash)
    unit:event_notify('单位-施法开始', unit, name, time, total)
    --[[ local skill = unit:find_skill(name)
    if skill then
        skill:destroy_actors("on_cast_start")
        skill:create_actors("on_cast_start")
    end ]]
end

function base.event.on_spell_cast_notify_ex(unit_id, hash, time, total)
    local unit = base.unit(unit_id)
    local name = get_skill_name_by_hash(hash)
    unit:event_notify('单位-施法引导', unit, name, time, total) ---以前叫引导，现在叫蓄力阶段，客户端不知道引导阶段的长度。不过为了一致性，lua里还叫引导
    --[[ local skill = unit:find_skill(name)
    if skill then
        skill:destroy_actors("on_cast_channel")
        skill:create_actors("on_cast_channel")
    end ]]
end

function base.event.on_spell_cast_shot_ex(unit_id, hash, time, total)
    local unit = base.unit(unit_id)
    local name = get_skill_name_by_hash(hash)
    unit:event_notify('单位-施法出手', unit, name, time, total)
    --[[ local skill = unit:find_skill(name)
    if skill then
        skill:destroy_actors("on_cast_shot")
        skill:create_actors("on_cast_shot")
    end ]]
end

function base.event.on_spell_cast_end_ex(unit_id, hash, time, total)
    local unit = base.unit(unit_id)
    local name = get_skill_name_by_hash(hash)
    unit:event_notify('单位-施法完成', unit, name, time, total)----后摇
    --[[ local skill = unit:find_skill(name)
    if skill then
        skill:destroy_actors("on_cast_finish")
        skill:create_actors("on_cast_finish")
    end ]]
end

function base.event.on_spell_cast_stop_ex(unit_id, hash, time, total)
    local unit = base.unit(unit_id)
    local name = get_skill_name_by_hash(hash)
    unit:event_notify('单位-施法停止', unit, name, time, total)
    --[[ local skill = unit:find_skill(name)
    if skill then
        skill:destroy_actors("on_cast_stop")
        skill:create_actors("on_cast_stop")
    end ]]
end

function base.event.on_spell_cast_break_ex(unit_id, hash)
    local unit = base.unit(unit_id)
    local name = get_skill_name_by_hash(hash)
    unit:event_notify('单位-施法打断', unit, name)
    -- --[[ local skill = unit:find_skill(name)
    -- if skill then
    --     skill:destroy_actors("on_cast_break")
    --     skill:create_actors("on_cast_break")
    -- end ]]
end

function base.event.on_spell_cast_failed_ex(unit_id, hash)
    local unit = base.unit(unit_id)
    local name = get_skill_name_by_hash(hash)
    unit:event_notify('单位-施法失败', unit, name)
end

base.proto.cancel_ignore_joy_stick = function(msg)
    if not msg.id then
        return
    end
    local unit = base.unit(msg.id)
    unit:event_notify('单位-施法失败', unit)
end

base.proto.skill_group_set_unit = function( msg)
    base.game:event_notify('技能摇杆组-显示单位技能', msg or {})
end

function mt:__tostring()
    return ('{skill|%s-%q|%s-%q} <- %s'):format(self._name, self._id, self:get_type(), self:get_slot_id(), self._owner or '{未知}')
end

function mt:__index(key)
    local v = self._data[key]
    if v ~= nil then
        if type(v) == 'table' and #v > 0 then
            local level = self._level
            local max_level = self._data.max_level[1]
            if level < 1 then
                level = 1
            elseif level > max_level then
                level = max_level
            end
            return v[level]
        end
        return v
    end
    if dual_key[key] then
        return 0
    end
    return nil
end

api.type = 'skill'
api._level = 0

---comment
---@param data LeveledData
---@param fallbackValue number
---@param level integer?
---@return number
function api:level_data(data, fallbackValue, level)
    if type(data) ~= "table" then
        return fallbackValue
    end
    ---@type number[]
    local table = data.LevelValues or data
    if #table == 0 then
        log_file.debug('等级信息配置错误，没有找到任何等级信息，将返回默认值')
        if not data.LevelFactor then
            return fallbackValue
        else
            table = { fallbackValue }
        end
    end
    level = level or self:get_level()
    if not level or level == 0 then
        level = 1
    end
    if level > #table then
        if data.LevelFactor then
            local value = level * data.LevelFactor
            + (data.BonusPerLevel or 0)
            if data.PreviousValueFactor and data.PreviousValueFactor ~= 0 then
                value = value + data.PreviousValueFactor * self:level_data(data, fallbackValue, level - 1)
            end
            return value
        else
            level = #table
        end
    end
    return table[level]
end

function api:get_name()
    return self._name or ''
end

function api:get_owner()
    return self._owner
end

function api:get_tip()
    self.cache = self.cache or base.eff.cache(self._name)
    local level = self:get_level() or 1
    if level <= 0 then
        level = 1
    end
    if self.cache then
        local cache = self.cache
        local tip = cache.Description
        if tip and #tip > 0 then
            tip = tip[math.min(#tip, level)]
            tip = base.i18n.get_text(tip)
            if cache.DescriptionParams then
                local params = {}
                for _, value in ipairs(cache.DescriptionParams) do
                    table.insert(params, value(self))
                end
                tip = string.format(tip, table.unpack(params))
            end
        end
        return tip or ""
    end
    return ""
end

function api:get_stack()
    return self._stack
end

function api:get_level()
    return self._level
end

function api:get_slot_id()
    if self._slot_id then
        return self._slot_id % SLOT_MAX
    else
        return -1
    end
end

function api:is_enable()
    return self._disable ~= 1
end

function api:is_charge_skill()
    return self.cache.Cost.CooldownMode == 1
end

function api:get_type()
    if self._slot_id then
        return SLOT_TYPE[self._slot_id // SLOT_MAX]
    else
        return '未知'
    end
end

-- deprecated，新的用can_learn
function api:can_upgrade()
    return self._requirement == 0
end

function api:can_learn()
    return self:get_user_attribute 'sys_can_learn' == 1
end

function api:event_notify(name, ...)
    base.event_notify(self, name, ...)
    base.event_notify(base.game, name, ...)
end

function api:event(name, f)
	return base.event_register(self, name, f)
end

function api:get_cd()
    if self:is_attack_modifier() then
        local unit = self:get_owner()
        local attack = unit and unit:get_attack()
        if attack then
            return attack:get_cd()
        else
            return 0, 1
        end
    end
    local cd
    if self._cd_tick then
        if self._paused_clock then
            cd = math.max(0, self._cd_tick - self._paused_clock)
        else
            cd = math.max(0, self._cd_tick - base.clock())
        end
    else
        cd = 0
    end
    if cd == 0 then
        return 0, 1
    else
        return cd / 1000, (self._total_cd or 1) / 1000
    end
end

function api:get_charge_cd()
    if self:is_attack_modifier() then
        local unit = self:get_owner()
        local attack = unit and unit:get_attack()
        if attack then
            return attack:get_charge_cd()
        else
            return 0, 1
        end
    end
    local cd
    if self._charge_cd_tick then
        if self._paused_clock then
            cd = math.max(0, self._charge_cd_tick - self._paused_clock)
        else
            cd = math.max(0, self._charge_cd_tick - base.clock())
        end
    else
        cd = 0
    end
    if cd == 0 then
        return 0, 1
    else
        return cd / 1000, (self._total_charge_cd or 1) / 1000
    end
end

function api:pause()
    if not self._paused_clock then
        self._paused_clock = base.clock()
    end
end

function api:resume()
    if self._paused_clock then
        if self._cd_tick then
            self._cd_tick = self._cd_tick - self._paused_clock + base.clock()
        end
        if self._charge_cd_tick then
            self._charge_cd_tick = self._charge_cd_tick - self._paused_clock + base.clock()
        end
        self._paused_clock = nil
    end
end

local game_time_paused = false

function api:update_paused()
    local unit = self:get_owner()
    if not unit then return end
    local unit_paused = unit:has_restriction('暂停') or unit:has_restriction('暂停更新技能')
    if unit_paused then
        self:pause()
    elseif unit:has_restriction('免时停') then
        self:resume()
    elseif game_time_paused then
        self:pause()
    else
        self:resume()
    end
end

base.game:event('游戏-时间暂停', function()
    game_time_paused = true
    for id, skill in pairs(skill_map) do
        if not removed_skill_map[id] then
            skill:update_paused()
        end
    end
end)

base.game:event('游戏-时间继续', function()
    game_time_paused = false
    for id, skill in pairs(skill_map) do
        if not removed_skill_map[id] then
            skill:update_paused()
        end
    end
end)

-- deprecated
function api:cast(smart)
    if not can_request(self) then
        return false
    end
    game.cast_spell(self._id, smart)
    return true
end

function api:client_channel_finish()
    base.game:server 'client_channel_finish' {name = self:get_name()}
end

---comment
---@param link any
local function get_target_indicator_cache(link)
    if not link or #link == 0 then
        return nil
    end
    local cache = base.eff.cache(link)
    if not cache then
        local links = util.split(link, ".")
        if links then
            link = links[#links]
        end
        link = '$$.target_indicator.'..link..'.root'
        print(link)
        cache = base.eff.cache(link)
        print(cache)
    end
    return cache
end

function api:show_range(follow, assistName)
    if not can_request(self) then
        return false
    end

    local cache = get_target_indicator_cache(assistName)
    local owner = self._owner
    game.show_spell_assist(self._slot_id, true, cache and cache.Link, owner and owner._id)
    return true
end

function api:hide_range()
    if not can_request(self) then
        return false
    end
    game.show_spell_assist(self._slot_id, false)
    return true
end

function api:move(slot)
    if not can_request(self) then
        return false
    end
    if self:get_type() ~= '物品' then
        return false
    end
    if self:get_slot_id() == slot then
        return false
    end
    game.request_move_item(self._id, SLOT_MAP['物品'] + slot)
    return true
end

function api:upgrade()
    if not can_request(self) then
        return false
    end
    if not self:can_upgrade() then
        return false
    end
    game.request_upgrade_spell(self._id)
    return true
end

function api:has_category(category)
    self.cache = self.cache or base.eff.cache(self.__name)
    local categories = self.cache.Categories
    if categories then
        for _, value in pairs(categories) do
            if value == category then
                return true
            end
        end
    end
    return false
end

function api:hotkey(smart)
    local keys
    local tp = self:get_type()
    local slot = self:get_slot_id()
    if tp == '英雄' then
        if slot >= 0 and slot <= 7 then
            if smart then
                return base.game:hotkey().spell_quick_cast[slot+1] or ''
            else
                return base.game:hotkey().spell_cast[slot+1] or ''
            end
        end
    elseif tp == '通用' then
        if slot >= 0 and slot <= 2 then
            if smart then
                return base.game:hotkey().spell_quick_cast[slot+9] or ''
            else
                return base.game:hotkey().spell_cast[slot+9] or ''
            end
        end
    elseif tp == '物品' then
        if slot >= 0 and slot <= 5 then
            if smart then
                return base.game:hotkey().item_quick_cast[slot+9] or ''
            else
                return base.game:hotkey().item_cast[slot+1] or ''
            end
        end
    end
    return ''
end

function api:create_actor(link)
    print(link)
    local target = self:get_owner()
    if not target then
        return
    end
    local actor = target:create_actor(link, true)
    if actor then
    table.insert(self.actors, actor)
    end
    return actor
end

---comment
---@param event string
function api:create_actors(event)
    self.cache = self.cache or base.eff.cache(self.__name)
    local cache = self.cache
    if not cache then
        return
    end
    local it_actor_cache
    if cache.ActorArray and #cache.ActorArray then
        self.actors = self.actors or {}
        for _, value in ipairs(cache.ActorArray) do
            it_actor_cache = base.eff.cache(value)
            if it_actor_cache and it_actor_cache.EventCreation == event then
                self:create_actor(value)
            end
        end
    end
end

---comment
---@param event string
function api:destroy_actors(event)
    if not self.actors then
        return
    end

    --只要填写了EventDestruction，那么在on_cast_stop时必定要销毁
    --bug: on_cast_break不一定触发on_cast_stop.现在暂时都判一下
    local stop = false
    if event == 'on_cast_stop' or event == 'on_cast_break' then
        stop = true
    end
    for _, actor in ipairs(self.actors) do
        local link = actor.name
        local actor_cache = base.eff.cache(link)
        self.actors = self.actors or {}
        if actor_cache and actor_cache.EventDestruction ~= '' then
            if stop or actor_cache.EventDestruction == event then
                actor:destroy(false);
            end
        end
    end
end

function api:is_attack()
    local cache = self.cache or base.eff.cache(self._name)
    if cache and cache.SpellFlags and cache.SpellFlags.IsAttack then
        return true
    end

    return false
end

function api:is_attack_modifier()
    local cache = self.cache or base.eff.cache(self._name)
    if cache and cache.NodeType == 'SpellAttackModifier' then
        return true
    end

    return false
end

---comment
---@param key string
function api:get_user_attribute(key)
    return self._user_attribute[key]
end

function api:is_toggled_on()
    return self:get_user_attribute("sys_state_toggled_on") == 1
end

function api:get_phase()
    return self:get_user_attribute('sys_count_phase') or 1
end

function api:get_current_show_cd()
    local a, b = self:get_cd()
    local cooldown_key = self:get_cooldown_key()
    local spell_cache = self.cache
    if cooldown_key then
        local unit = nil
        if spell_cache and spell_cache.Cost.CooldownLocation == 'Item' and self.item_unit then
            unit = self.item_unit
        else
            unit = self:get_owner()
        end
        if unit then
            a = unit:get_cooldown(cooldown_key) or 0
        end
    end
    return a
end

function api:get_max_show_cd()
    local a, b = self:get_cd()
    local cooldown_key = self:get_cooldown_key()
    local spell_cache = self.cache
    if cooldown_key then
        local unit = nil
        if spell_cache and spell_cache.Cost.CooldownLocation == 'Item' and self.item_unit then
            unit = self.item_unit
        else
            unit = self:get_owner()
        end
        if unit then
            local tmp = game.get_cool_down(unit._id, cooldown_key)
            if tmp then
                b = tmp.total_cd and tmp.total_cd/1000 or b
            end
        end
    end
    return b
end

function api:get_currrent_charge_show_cd()
    local a, b = self:get_charge_cd()
    return a
end

function api:get_max_charge_show_cd()
    local a, b = self:get_charge_cd()
    return b
end

local show_methods,charge_methods

local function try_load_show_methods()
    if show_methods then
        return
    end
    if base.eff and base.eff.has_cache_init() then
    local cache = base.eff.cache('$$.gameplay.dflt.root')
    local show_methods_link = cache and cache.ObjectShowMethods and cache.ObjectShowMethods.Skill
    local charge_methods_link = cache and cache.ObjectShowMethods and cache.ObjectShowMethods.ChargeSkill
    show_methods = base.eff.cache(show_methods_link)
    charge_methods = base.eff.cache(charge_methods_link)
    end
end

function api:get_show_name()
    try_load_show_methods()
    self.cache = self.cache or base.eff.cache(self._name)
    if show_methods and show_methods.ShowNameMethod then
        return show_methods.ShowNameMethod(self)
    else
        return base.i18n.get_text(self.cache.Name)
    end
end

function api:get_icon()
    try_load_show_methods()
    self.cache = self.cache or base.eff.cache(self._name)
    if show_methods and show_methods.IconMethod then
        return show_methods.IconMethod(self)
    else
        local icon_image = self.cache.IconName
        if self.cache.IconNameOff and self:get_user_attribute("sys_state_toggled_on") == 1 then
            icon_image = self.cache.IconNameOff
        end
        if self.cache.MultiPhaseSetting and self.cache.MultiPhaseSetting.IsMultiPhase and self.cache.MultiPhaseSetting.MultiPhaseConfig then
            local Multiphase_config = self.cache.MultiPhaseSetting.MultiPhaseConfig[math.min(self:get_user_attribute('sys_count_phase'), #self.cache.MultiPhaseSetting.MultiPhaseConfig)]
            if Multiphase_config.Icon and Multiphase_config.Icon ~= '' and Multiphase_config.Icon ~= 'unkown' then
                icon_image = Multiphase_config.Icon
            end
        end
        return icon_image
    end
end

function api:get_tips()
    try_load_show_methods()
    if show_methods and show_methods.TipsMethod then
        return show_methods.TipsMethod(self)
    else
        return self:get_tip()
    end
end

function api:get_current_cd()
    try_load_show_methods()
    if show_methods and show_methods.CoolDownMethod then
        return show_methods.CoolDownMethod(self)
    else
        return self:get_current_show_cd()
    end
end

function api:get_cd_max()
    try_load_show_methods()
    if show_methods and show_methods.MaxCoolDownMethod then
        return show_methods.MaxCoolDownMethod(self)
    else
        return self:get_max_show_cd()
    end
end

function api:get_current_charge_cd()
    try_load_show_methods()
    if charge_methods and charge_methods.ChargeCoolDownMethod then
        return charge_methods.ChargeCoolDownMethod(self)
    else
        return self:get_currrent_charge_show_cd()
    end
end

function api:get_charge_cd_max()
    try_load_show_methods()
    if charge_methods and charge_methods.ChargeMaxCoolDownMethod then
        return charge_methods.ChargeMaxCoolDownMethod(self)
    else
        return self:get_max_charge_show_cd()
    end
end

function api:get_cooldown_key()
    local spell_cache = self.cache
    local cooldown_key = nil
    if spell_cache and spell_cache.Cost.CooldownLocation and spell_cache.Cost.CooldownLocation ~= 'Ability' then
        cooldown_key = self._name
        if not spell_cache.Cost.UseDefaultCooldownKey then
            cooldown_key = spell_cache.Cost.CooldownKey
        end
    end
    return cooldown_key
end

function base.skill_info()
    return {
        skill_map = skill_map,
    }
end

base.proto.sync_skill = function(msg)
    local unit_id = msg.unit_id
    local id = msg.skill_id
    local name = msg.skill_name
    local unit = base.unit(unit_id)
    ac_skill(id, common.string_hash(name), unit)
    if skill_map[id] then
        skill_map[id].item_unit = base.unit(msg.item_unit_id)
    end
    -- 技能冷却位置初始化
    local skill = skill_map[id]
    local spell_cache = skill.cache
    if spell_cache and spell_cache.Cost.CooldownLocation and spell_cache.Cost.CooldownLocation ~= 'Ability' then
        local cooldown_key = skill._name
        local unit = nil
        if not spell_cache.Cost.UseDefaultCooldownKey then
            cooldown_key = spell_cache.Cost.CooldownKey
        end
        unit = skill:get_owner()
        --更新冷却
        if spell_cache.Cost.CooldownLocation == 'Item' then
            unit = skill.item_unit
            unit:set_tick_disabled(false)
        end
        unit:insert_into_cooldown_map(cooldown_key, skill)
    end
end

return {
    Skill = Skill,
}
