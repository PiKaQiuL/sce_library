require 'base.state_machine'

Unit = base.tsc.__TS__Class()
Unit.name = 'Unit'

base.tsc.__TS__ClassExtends(Unit, Target)

---@class Unit
local mt = Unit.prototype
mt.__index = mt

mt.type = 'unit'
mt._id = nil
mt._name = nil
mt._attribute = nil
mt._owner = nil
mt._statemachines = {}

function mt:__tostring()
    return ('{unit|%s|%s-%d} <- %s'):format(self:get_class(), self:get_name(), self._id, self:get_owner() or '{未知}')
end

local unit_map = setmetatable({}, { })
local sync_actors = {}
local visible_units = {}
local node_mark_map = {}

function mt:get_team_id()
    local player = self:get_owner()
    return player and player:get_team_id() or nil
end

function mt:is_visible()
    return not not visible_units[self]
end

function mt:get_name()
    return self._name or ''
end

---comment
---@param prop string
function mt:get_string(prop)
    local val = self:get(prop)
    if type(val) =="string" then
        return val
    end
    return ""
end

function mt:get_scene()
    if game.get_unit_scene_name then
        return game.get_unit_scene_name(self._id)
    end
    return self._scene
end

function mt:on_response()
    -- todo client side response
end

function mt:get_scene_name()
    if game.get_unit_scene_name then
        return game.get_unit_scene_name(self._id)
    end
    return self._scene
end

function mt:get_owner()
    if game.get_unit_owner then
        return base.player(game.get_unit_owner(self._id))
    else
        return self._owner
    end
end

function mt:get_data()
    local data = base.table.unit[self._name]
    return data
end

function mt:set(key, value)
    local attribute = self._attribute
    local old = attribute[key] or 0
    if old == value then
        return false
    end
    attribute[key] = value
    return true
end

function mt:get(key)
    return self._attribute[key] or 0
end

function mt:is_alive()
    return self:get '是否存活' == 1
end

function mt:get_level()
    return self._attribute['等级'] or 0
end

function mt:get_asset()
    return game.get_unit_asset(self._id)
end

function mt:get_model_path()
    return game.get_unit_model_path(self._id)
end

function mt:get_skill_points()
    return self._attribute['技能点'] or 0
end

function mt:get_snapshot()
    if not self:is_valid() then
        return
    end

	local snapshot = base.snapshot:new()
	snapshot.origin_type = 'unit'
	snapshot.name = self:get_name()
	snapshot.player = self:get_owner()
	snapshot.point = self:get_point()
	snapshot.facing = self:get_facing()
    snapshot.cache = base.eff.cache(snapshot.name)
    return snapshot
end

function mt:each_skill(type)
    local skills = {}
    for skill in pairs(self.skill) do
        if skill._slot_id and (not type or type == skill:get_type()) then
            skills[#skills+1] = skill
        end
    end
    table.sort(skills, function(a, b)
        return a._slot_id < b._slot_id
    end)
    local i = 0
    return function ()
        i = i + 1
        local ret_skill = skills[i]
        if ret_skill and not ret_skill.cache then
            ret_skill.cache = base.eff.cache(ret_skill:get_name())
        end
        return ret_skill
    end
end

function mt:each_skill_all()
    local skills = {}
    for skill in pairs(self.skill) do
        if skill._slot_id  then
            if not skill.cache then
                skill.cache = base.eff.cache(skill:get_name())
            end
            skills[#skills+1] = skill
        end
    end
    table.sort(skills, function(a, b)
        return a._slot_id < b._slot_id
    end)
    return skills
end

---comment
---@param label string
function mt:has_label(label)
    local unit_cache = base.eff.cache(self:get_name())
    local t = unit_cache and unit_cache.Filter
    if not t then
        return false
    end
    for _, value in pairs(t) do
        if value == label then
            return true
        end
    end
    return false
end

local unit_mark_bits = {
    ['定身'] = 0, -- 无法移动和主动特殊运动
    ['缴械'] = 1, -- 无法使用普通攻击
    ['物免'] = 2, -- 无法成为普通攻击的目标
    ['禁魔'] = 3, -- 无法使用技能
    ['魔免'] = 4, -- 无法成为技能的目标
    ['模型隐藏'] = 5, -- 显示上隐藏，逻辑上不隐藏
    ['天空'] = 6, -- 视野无视阻挡
    ['无敌'] = 7, -- 无法成为技能和普通攻击的目标
    ['免时停'] = 8, -- 使该单位不受时间停止的影响。
    ['蝗虫'] = 9, -- 无视选取
    ['虚空'] = 10, -- 无视地形高度，客户端坐标z直接就是离地高度，不会加上地形高度
    ['召唤'] = 11,
    ['禁止转向'] = 12,
    ['幽灵'] = 13,
    ['飞行'] = 14,
    ['暂停更新技能'] = 15,
    ['暂停更新增益'] = 16,
    ['暂停'] = 17,
}

---@param scene_point ScenePoint
function mt:set_point(scene_point)
    game.set_unit_location(self._id, scene_point[1], scene_point[2], scene_point[3], scene_point.scene_hash)
end

function mt:destroy()
    if self.remove then
        self:remove()
    end
    game.remove_unit(self._id)
end

function mt:set_position(x, y, z)
    game.set_unit_location(self._id, x, y, z)
end

function mt:set_rotation(x, y ,z)
    game.set_unit_rotation(self._id, x, y , z)
end

function mt:set_scale_xyz(x, y, z)
    self:set_scale(x, y, z);
end

function mt:set_scale(x, y, z)
    if not y then
        y = x
    end
    if not z then
        z = x
    end
    game.set_actor_scale(self._id, x, y, z)
end

function mt:has_restriction(restriction)
    local unit_restrictions = self:get '单位标记'
    local bit = unit_mark_bits[restriction]
    if not bit then
        return nil -- 客户端不知道
    end
    return ((unit_restrictions >> bit) & 1) == 1
end

local slot_type_map = {
    ['英雄'] = 0,
    ['物品'] = 1,
    ['通用'] = 2,
    ['隐藏'] = 3,
    ['攻击'] = 4,
}
function mt:find_skill(name, tp)
    if type(name) == 'number' then
        assert(slot_type_map[tp], 'find_skill 使用数字索引时必须要有类型')
        local slot_id = name + slot_type_map[tp] * 1000
        for skill in pairs(self.skill) do
            if skill._slot_id == slot_id then
                if not skill.cache then
                    skill.cache = base.eff.cache(skill:get_name())
                end
                return skill
            end
        end
        return nil
    else
        for skill in pairs(self.skill) do
            if skill._name == name then
                if not tp and skill.get_level and skill:get_level() == 0 then
                    return nil
                end
                if not skill.cache then
                    skill.cache = base.eff.cache(skill:get_name())
                end
                return skill
            end
        end
        return nil
    end
end

function mt:find_skill_by_slot(slot)
    return self:find_skill(slot, '英雄')
end

function mt:get_attack()
    for skill in self:each_skill() do
        if skill:is_attack() then
            return skill
        end
    end
    return nil
end

function mt:find_buff(name)
    local buff
    for buf in self:each_buff(name) do
        buff = buf
        break
    end
    return buff
end

function mt:each_buff(target)
    local buffs = {}
    for name, list in pairs(self.buff) do
        if not target or target == name then
            for index, buff in pairs(list) do
                buffs[#buffs+1] = buff
            end
        end
    end
    table.sort(buffs, function (a, b)
        if a._name < b._name then
            return true
        elseif a._name > b._name then
            return false
        elseif a._index < b._index then
            return true
        else
            return false
        end
    end)
    local i = 0
    return function ()
        i = i + 1
        return buffs[i]
    end
end

function mt:each_buff_all(target)
    local buffs = {}
    for name, list in pairs(self.buff) do
        if not target or target == name then
            for index, buff in pairs(list) do
                buffs[#buffs+1] = buff
            end
        end
    end
    table.sort(buffs, function (a, b)
        if a._name < b._name then
            return true
        elseif a._name > b._name then
            return false
        elseif a._index < b._index then
            return true
        else
            return false
        end
    end)
    return buffs
end

function mt:get_class()
    local data = self:get_data()
    return data and data.UnitClass or '未知'
end

function mt:get_tag()
    local data = self:get_data()
    return data and data.UnitTag or '未知'
end

function mt:get_xy()
    local x, y = game.get_unit_location(self._id)
    return x or 0.0, y or 0.0
end

-- 优先返回宿主坐标
function mt:get_point()
    local x, y, z, scene_hash = game.get_unit_location(self.attach_id or self._id)
    return base.scene_point_by_hash(x, y, z, scene_hash)
end

function mt:get_global_point()
    local x, y, z = game.get_unit_global_location(self._id)
    return base.point(x, y, z)
end

function mt:get_socket_point(socket)
    -- 这里是历史遗留api，pitch, yaw, roll顺序感觉有点问题，建议不要使用
    local x, y, z, pitch, yaw, roll = game.get_socket_location(self._id, socket)
    return x, y, z, pitch, yaw, roll
end

function mt:get_socket_position(socket)
    -- 世界坐标
    local x, y, z = game.get_socket_position(self._id, socket or 'Socket_Root')
    return base.point(x or 0.0, y or 0.0, z or 0.0)
end

function mt:get_socket_rotation(socket)
    -- 世界旋转
    -- C++里欧拉角x,y,z和约定俗成的不一样，一般约定yaw(偏航角)表示水平面内旋转，pitch俯仰，roll水平倾斜
    local x, y, z = game.get_socket_rotation(self._id, socket or 'Socket_Root')
    return { yaw = z, pitch = y, roll = x }
end

---@class IBaseAnimParams
---@field owner_id number
---@field is_actor boolean
---@field custom_handle number?

---@class ICustomAnimParams : IBaseAnimParams
---@field anim string
---@field logic_layer number?   // 默认：NORMAL
---@field priority number?                  // 取值：[0, 31]
---@field body_part number?
---@field speed number?
---@field blend_time number?
---@field start_offset number?
---@field loop boolean?

---@class AnimHandle
---@field handle

---comment
---@param anim_name string
---@param anim_param ICustomAnimParams
---@return AnimHandle?
function mt:play_anim_ex(anim_name, anim_param)
    anim_param.is_actor = false
    anim_param.owner_id = self._id
    anim_param.anim = anim_name
    local handle = game.actor_play_anim(anim_param)
    if handle == 0 then
        return nil
    end
    return base.tsc.__TS__New(
        base.defaultui.AnimHandle,
        {},
        self._id,
        false,
        handle
    )
end

---comment
---@return table<ICustomAnimParams>
function mt:get_anims()
    local anim_hanldes = game.actor_get_anims(self._id, false)
    local anims = {}
    for _, handle in ipairs(anim_hanldes) do
        local anim = base.tsc.__TS__New(
            base.defaultui.AnimHandle,
            {},
            self._id,
            false,
            handle
        )
        table.insert(anims, anim)
    end
    return anims
end

function mt:play_anim_bracket()
end

function mt:attach_to(target, socket)-- target must be unit/unitId
    local target_id = nil
    if type(target) == 'table' then
        target_id = target._id
    elseif type(target) == 'number' then
        target_id = target
    end
    if not target_id then
        log.error('attach to target nil.')
        return
    end
    if target_id == self._id then
        log.error('cannot attach actor to iteself.')
        return
    end
    self.attach_id = target_id

    if not socket then
        -- 服务端附着，具体绑点需要从单位属性上读取
        -- 这里先约定几个属性「附着目标绑点」、「骑乘目标绑点」、「骑乘动画」，其中骑乘相关的先供回响使用
        -- TODO：同步Actor目前只在c++中存在单位属性，脚本侧尚为处理，暂不支持指定绑点
        local riding_socket = self:get_string('骑乘目标绑点')
        socket = riding_socket ~= '' and riding_socket or self:get_string('附着目标绑点')
        if riding_socket ~= '' then
            local riding_anim = self:get_string('骑乘动画')
            if riding_anim ~= '' then 
                -- 这里使用了新的动画api，来播放下半身的骑乘动画
                self.__riding_anim_handle = game.actor_play_anim({
                    owner_id = self._id,
                    is_actor = false,
                    anim = riding_anim, 
                    body_part = 2, --LOWER_BODY,
                    loop = true,
                })
            end
        end
    end

    if socket and type(socket) == 'string' then
        game.attach_actor_to_socket(self._id, target_id, socket)
    else
        game.attach_actor_to_socket(self._id, target_id)
    end
end

function mt:detach()
    self.attach_id = nil
    game.detach_actor(self._id)

    -- 停止骑乘动画，若存在
    if self.__riding_anim_handle then
        game.anim_handle_stop({
            owner_id = self._id,
            is_actor = false,
            custom_handle = self.__riding_anim_handle,
        })
        self.__riding_anim_handle = nil
    end
end

function mt:get_height()
    local _, _, z = game.get_unit_location(self._id)
    return z or 0.0
end

function mt:get_facing()
    return game.get_unit_facing(self._id) or 0.0
end

function mt:get_highlight()
    return game.get_unit_highlight(self._id)
end

function mt:set_highlight(on, ...)
    game.set_unit_highlight(self._id, on, ...)
end

function mt:get_outstroke()
    return game.get_unit_outstroke(self._id)
end

function mt:set_outstroke(enable, color, thickness)
    game.set_unit_outstroke(self._id, enable, color, thickness)
end

function mt:set_shadow(enable)
    return game.set_unit_shadow(self._id, enable)
end

function mt:get_xray_enable()
    return game.get_unit_xray_enable(self._id)
end

function mt:set_xray_enable(enable)
    return game.set_unit_xray_enable(self._id, enable)
end

function mt:get_unit_random_model_index()
    return game.get_unit_random_model_index(self._id)
end

function mt:set_fow(enable, radius)
    return game.set_unit_fow(self._id, enable, radius)
end

function mt:set_sight(typ, param)
    return game.set_unit_sight(self._id, typ, param)
end

function mt:set_sight_skill_fan(x, y, z, radius, angle)
    --deprecated
    --return game.set_unit_sight_skill_fan(self._id, x, y, z, radius, angle)
end

function mt:set_eye_height(h)
    return game.set_unit_eye_height(self._id, h)
end

function mt:setup_occluding_camera_group(...)
    game.unit_setup_occluding_camera_group(self._id, ...)
end

function mt:set_tint_enabled(flag)
    return game.set_unit_tint_enabled(self._id, flag)
end

--idx: 1/2/3 clr:{r, g, b, a}
function mt:set_tint_color(idx, clr)
    game.set_unit_tint_color(self._id, idx, clr);
end

function mt:set_tick_disabled(on_or_off)
    game.unit_set_tick_disabled(self._id, on_or_off)
end

function mt:is_item()
    return self._attribute.sys_item_link ~= nil
end

function mt:event_notify(name, ...)
	base.event_notify(self, name, ...)
	local player = self:get_owner()
	if player then
		base.event_notify(player, name, ...)
	end
	base.event_notify(base.game, name, ...)
end

function mt:event(name, f)
	return base.event_register(self, name, f)
end

function mt:cast(skill, target, data)
    local skill_id = nil
    if skill and base.tsc.__TS__InstanceOf(skill, Skill) then
        skill_id = skill._id
        skill = skill:get_name()
    end
    local target_is_unit_id = false
    if getmetatable(target) == mt then
        target_is_unit_id = true
        target = target._id
    end
    local unit_id = nil
    if self ~= self:get_owner():get_hero() then
        unit_id = self._id
    end
    base.game:server 'cast' {
        name = skill,
        skill_id = skill_id,
        target = target,
        data = data,
        target_is_unit_id = target_is_unit_id,
        unit_id = unit_id,
    }
end

function mt:move_to_direction(x, y)
    local unit_id = nil
    if self ~= self:get_owner():get_hero() then
        unit_id = self._id
    end
    base.game:server 'move_to_direction' {
        unit_id = unit_id,
        x = x,
        y = y,
    }
end

function mt:stop_move_to_direction(x, y)
    local unit_id = nil
    if self ~= self:get_owner():get_hero() then
        unit_id = self._id
    end
    base.game:server 'stop_move_to_direction' {
        unit_id = unit_id,
    }
end

base.game:event('单位-动画结束', function(trig, id, anim, operation)
    log_file.debug("单位-动画结束", id, anim, operation)
    local unit = base.unit(id)
    if unit and unit._current_anim then
        if operation == 'bracket_animation_end' then
            if unit._current_anim then
                for i, v in ipairs(unit._bracket_anims)  do
                    if v == unit._current_anim then
                        table.remove(unit._bracket_anims, i) 
                        break
                    end
                end           
                unit._current_anim:remove()
                unit._current_anim = nil
            end
            -- 这个回调是状态机update做的，为了不想逻辑改的太复杂，这里最好还是延迟一帧再播下一个
            if #unit._bracket_anims > 1 then
                base.next(function()
                    if #unit._bracket_anims > 1 then
                        unit._current_anim = unit._bracket_anims[1]
                        game.actor_play_anim_bracket(unit._id, unit._current_anim.anim_birth, unit._current_anim.anim_stand, unit._current_anim. anim_death, unit._current_anim.force_one_shot, unit._current_anim.kill_on_finish, true, false)
                        game.unit_set_play_speed(id, unit._current_anim.anim_speed)
                        --log_file.info('actor_play_anim_bracket', unit._current_anim.anim_birth)
                    end
                end)
            end
        else
            if unit._current_anim then
                unit._current_anim:remove()
                unit._current_anim = nil
            end
        end
    end
end)

---@param anim_name string
---@param params table
function mt:anim_play(anim_name, params)
    local anim = base.anim(anim_name, 'unit', self._id, self._name, params)
    local time = anim.time or 0
    local time_type = anim.time_type or 0
    local start_offset = anim.start_offset or 0
    local blend_time = anim.blend_time or 0
    local current_anim = self._current_anim
    local global_scale = self._global_scale or 1
    local priority = anim.priority or 0
    --log_file.info('unit:anim_play', anim_name, json.encode(anim), json.encode(current_anim))

    if not current_anim
    or priority > current_anim.priority then -- 要播放的动画priority > 当前正在播放的动画的priority
        if time_type == 0 then -- 默认速度播放
            anim:play(anim_name, false, global_scale, blend_time)
            anim:set_time(start_offset, false)
        elseif time_type == 1 then -- 视为持续时间
            anim:play(anim_name)
            anim:set_time(start_offset, false)
            anim:set_duration(time)
        elseif time_type == 2 then -- 视为相对缩放倍率
            anim:play(anim_name)
            anim:set_time(start_offset, false)
            anim:set_time_scale(time)
        elseif time_type == 3 then -- 视为绝对缩放倍率
            anim:play(anim_name)
            anim:set_time(start_offset, false)
            anim:set_time_scale_absolute(time)
        end
    end
end

local function sort_bracket(bracket1,bracket2)
    return bracket1.priority > bracket2.priority
end
-- 添加bracket动画
local function add_bracket_to_table(self, bracket_anim)
    if self._bracket_anims == nil then
        self._bracket_anims = {}
    end
    for i, v in ipairs(self._bracket_anims) do
        if v == bracket_anim then
            return
        end
    end
    self._bracket_anims[#self._bracket_anims+1] = bracket_anim
    table.sort(self._bracket_anims, sort_bracket)
    -- 超过5个就把优先级最低的一个踢掉
    if #self._bracket_anims > 5 then
        table.remove(self._bracket_anims, #self._bracket_anims)
    end
    -- for i, v in ipairs(self._bracket_anims) do
    --     log_file.info('sortbracket',i,v.anim,v.priority)
    -- end
end

-- 手动构建BSD动画，然后play动画
---@param anim_birth string
---@param anim_stand string
---@param anim_death string
function mt:anim_play_bracket(anim_birth, anim_stand, anim_death, params)
    --log_file.info('anim_play_bracket',anim_birth, anim_stand, anim_death, params.force_one_shot)
    local bracket_anim = base.bracket_anim(anim_birth, anim_stand, anim_death, params, 'unit', self._id, self._name)
    if bracket_anim then
        if not self._current_anim or bracket_anim.priority > self._current_anim.priority then
            --sync: 仅在force_on_shot为否时有效，当客户端看到这个actor时（load对应的场景或者actor附着的单位appear了），从stand开始播放。
            game.actor_play_anim_bracket(self._id, anim_birth, anim_stand, anim_death, params.force_one_shot, params.kill_on_finish, params.sync and not params.force_one_shot, false)
            self._current_anim = bracket_anim
            -- 应用global
            --log_file.info('anim_play_bracket',anim_birth, anim_stand, anim_death)
            bracket_anim:set_time_scale(1)
        end
        if not params.force_one_shot then
            add_bracket_to_table(self, bracket_anim)
        end
    end
end

function mt:set_time_scale_global(scale)
    self._global_scale = scale
    if self._global_scale <= 0 then self._global_scale = 1 end
    if self._current_anim and (self._current_anim.time_type == 2 or self._current_anim.type == 'bracket_anim') then
        local anim_scale = self._current_anim.time_scale or 1
        self._current_anim:set_time_scale(anim_scale)
    end
end

function mt:anim_set_paused_all(paused)
    self._global_anim_pause = paused
    if self._current_anim then
        self._current_anim:refresh_global_pause(paused)
    else
        if paused then
            game.unit_pause(self._id)
        else
            game.unit_resume(self._id)
        end
    end
end

function mt:unit_anim_operation(value)
    local op = value.op
    local anim = value.anim or {}
    local params = value.params
    local anim_handle
    if self._current_anim and self._current_anim.id == anim.id and self._current_anim.type == anim.type then
        anim_handle = self._current_anim
    elseif anim.type == 'anim' then
        local anim_map = base.get_anim_map()
        anim_handle = anim_map[anim.id]
        if not anim_handle then
            anim_handle = base.anim(anim.anim, 'unit', self._id, self._name, anim)
        end
    elseif anim.type == 'bracket_anim' then
        local anim_map = base.get_anim_bracket_map()
        anim_handle = anim_map[anim.id]
        if not anim_handle then
            local bracket_params = {
                force_one_shot = anim.force_one_shot,
                id = anim.id,
                kill_on_finish = anim.kill_on_finish,
                priority = anim.priority,
                sync = anim.sync
            }
            anim_handle = base.bracket_anim(anim.anim_birth,anim.anim_stand,anim.anim_death, bracket_params, anim.owner_type,anim.owner_id,anim.owner_name)
        end
    end

    --log_file.info('unit_anim_operation',op, anim_handle,base.json.encode(params))
    if anim_handle then
        if op == 'play' then
            anim_handle:play(params.anim, false, self._global_scale, params.blend_time)
        elseif op == 'pause' then
            anim_handle:pause()
        elseif op == 'resume' then
            anim_handle:resume()
        elseif op == 'set_time' then
            anim_handle:set_time(params.time, params.trigger_events)
        elseif op == 'set_time_scale' then
            anim_handle:set_time_scale(params.scale)
        elseif op == 'set_time_scale_absolute' then
            anim_handle:set_time_scale_absolute(params.scale)
        elseif op == 'set_percentage' then
            anim_handle:set_percentage(params.percentage)
        elseif op == 'set_duration' then
            anim_handle:set_duration(params.duration)
        elseif op == 'destroy' then
            anim_handle:destroy()
        elseif op == 'bracket_stop' then
            anim_handle:bracket_stop()
        end
    end
end

function mt:learn_skill(skill)
    local skill_id = nil
    if skill and base.tsc.__TS__InstanceOf(skill, Skill) then
        skill_id = skill._id
        skill = skill:get_name()
    end
    local unit_id = nil
    if self ~= self:get_owner():get_hero() then
        unit_id = self._id
    end
    base.game:server 'learn' {
        unit_id = unit_id,
        name = skill,
        skill_id = skill_id,
    }
end

function mt:set_bone_chain_facing( CHAIN_ID, angle, time)
    game.unit_set_bone_chain_facing( self._id, CHAIN_ID, angle, time);
end

function mt:set_bone_chain_facing_v1( angle, time)
    --给触发用的，chain_id默认1
    self:register_model_bone_chain( true)
    self:set_bone_chain_facing( 1, angle, time or 0.2)
end

function mt:reset_bone_chain_facing( CHAIN_ID, time)
    game.unit_reset_bone_chain_facing( self._id, CHAIN_ID, time);
end
function mt:reset_bone_chain_facing_v1( time)
    --给触发用的，chain_id默认1
    self:reset_bone_chain_facing( 1, time)
end

local unit_destory_time = -1
local function get_destory_time()
    if base.eff.cache('$$.gameplay.dflt.root') and base.eff.cache('$$.gameplay.dflt.root').UnitDestoryTime then
        unit_destory_time = base.eff.cache('$$.gameplay.dflt.root').UnitDestoryTime * 1000
    end
end
if __lua_state_name ~= 'StateEditor' then
    if base.eff.cache_init_finished() then
        get_destory_time()
    else
        base.game:event('Src-PostCacheInit', function()
            get_destory_time()
        end)
    end
end

---comment
---@param id number
---@return Unit?
---@return boolean? new
function base.unit(id)
    if not id or id == 0 then
        return nil
    end
    local new = false
    if not unit_map[id] then
        new = true
        unit_map[id] = setmetatable({
            _id = id,
            _attribute = {},
            skill = {},
            buff = {},
            _global_scale = 1,
            _current_anim = nil,
            -- 设置一个销毁时间，离开视野的时候周期性判断一下这个时间。不准确，只是为了定期清除掉单位（ps:为什么不马上清除，是因为怕单位在视野旁边周期性的徘徊，忽进忽出，-1表示不清除）
            _destory_time = unit_destory_time,
        }, mt)
    end
    return unit_map[id], new
end

-- 单位离开视野的逻辑
--缓存离开视野的单位
local waiting_destory_unit = {}
local destory_list = {}
local free_unit_queue = {}
local game_frame_update_time = 0
local last_frame_update_time = 0

--定期清楚单位的逻辑
local function alloc_unit_queue()
	local n = #free_unit_queue
	if n > 0 then
		local q = free_unit_queue[n]
		free_unit_queue[n] = nil
		return q
	else
		return {}
	end
end

local function free_queue(q)
    free_unit_queue[#free_unit_queue + 1] = q
end

local function add_destory_unit(unit)
    if not unit then
        return 
    end
    if unit._destory_time < 0 then
        return
    end

     --已经准备删除了,在待删除队列里
    if waiting_destory_unit[unit._id] then
        return 
    end
    
    waiting_destory_unit[unit._id] = game_frame_update_time + unit._destory_time
    --再开一个队列来存
    local q = destory_list[game_frame_update_time + unit._destory_time]
    if not q then
        q = alloc_unit_queue()
        destory_list[game_frame_update_time + unit._destory_time] = q
    end
    q[unit._id] = unit._id
end

local function remove_destory_unit(unit)
    local time = waiting_destory_unit[unit._id]
    if not time then
        return
    end
    local q = destory_list[time]
    if q then
        q[unit._id] = nil
    end
    waiting_destory_unit[unit._id] = nil

end

--监控游戏更新
base.game:event('游戏-更新',function(_, update_delta)
    game_frame_update_time = game_frame_update_time + math.floor(update_delta)
    -- fix 频率可修改
    --定期清除一些单位
    --单帧最多遍历200个单位，其实肯定没有那么多的
    local max_size = 200
    local cur_size = 0
    while last_frame_update_time <= game_frame_update_time do
        local q = destory_list[last_frame_update_time]
        if q then
            for key,value in pairs(q) do
                -- 删除单位
                base.remove_unit(key)
                waiting_destory_unit[key] = nil
                cur_size = cur_size + 1
                q[key] = nil
            end
            free_queue(q)
        end
        destory_list[last_frame_update_time] = nil
        last_frame_update_time = last_frame_update_time + 1
        if cur_size > max_size then
            return 
        end
    end
end)

function base.remove_unit(id)
    if not id or id == 0 then
        return
    end
    if not unit_map[id] then
        return 
    end
    for skill in pairs(unit_map[id].skill) do
        skill:client_remove()
    end
    unit_map[id] = nil
end

function base.get_default_unit(node_mark)
    if type(node_mark) == 'string' then
        return node_mark_map[node_mark]
    end
end

function base.get_default_item(node_mark)
    local unit = base.get_default_unit(node_mark)
    if unit_check(unit) then
        local item = base.item(unit._id)
        if item == nil then
            log_file.debug("只有物品单位可获取物品对象")
            return nil
        end
        return item
    end
end



local function set(self, key, value)
    local attribute = self._attribute
    local old = attribute[key] or 0
    if old == value then
        return false
    end
    attribute[key] = value
    return true
end

local function modify_table(ori_tbl, modify_tbl)
    for k, v in pairs(modify_tbl) do
        if type(v) == 'table' then
            if type(ori_tbl[k]) ~= 'table' then
                ori_tbl[k] = {}
            end
            modify_table(ori_tbl[k], v)
        else
            ori_tbl[k] = v
        end
    end
end

local function delete_table(ori_tbl, modify_tbl)
    for k, v in pairs(modify_tbl) do
        if type(v) == 'table' then
            if type(ori_tbl[k]) ~= 'table' then
                ori_tbl[k] = {}
            end
            delete_table(ori_tbl[k], v)
        else
            ori_tbl[k] = nil
        end
    end
end

local function set_by_sync(self, key, value)
    local attribute = self._attribute
    local ori_tbl = attribute[key]
    if type(ori_tbl) ~= 'table' then
        ori_tbl = {}
    end
    if value.delete then
        delete_table(ori_tbl, value.delete)
    end
    if value.modify then
        modify_table(ori_tbl, value.modify)
    end
    attribute[key] = ori_tbl
    return attribute[key]
end

local key_map

function base.add_attribute_key(name, id)
    base.table.constant['单位属性'][name] = id
    if not key_map then
        key_map = {}
    end
    key_map[id] = name
end

local function init_attribute()
    if not key_map then
        key_map = {}
        for key, id in pairs(base.table.constant['单位属性']) do
            key_map[id] = key
        end
    end
end

local function on_attr_anim_func(self, key, value) 
    -- 不可见代表可能还没创建 
    if not self:is_visible() then return end
    if key == 'sys_unit_anim_play' then
        self:anim_play(value.anim, value)
    elseif key == 'sys_unit_anim_play_bracket' then
        self:anim_play_bracket(value.anim_birth, value.anim_stand, value.anim_death, value)
    elseif key == 'sys_unit_anim_set_global_scale' then
        self:set_time_scale_global(value)
    elseif key == 'sys_unit_anim_set_paused_all' then
        -- log_file.info('on_attr_anim_func', key, value)
        -- 直接发true和false会收不到，时间关系不去看了，不知道是bug还是feature --zhaomeng
        if value == 1 then
            self:anim_set_paused_all(true)
        else
            self:anim_set_paused_all(false)
    end
    elseif key == 'sys_unit_anim_operation' then
        self:unit_anim_operation(value)
    end
end

local function update_attribute(self, attr)
    --log_file.info('update_attribute',debug.traceback())
    init_attribute()
    local list = {}
    for id, value in pairs(attr) do
        local key = key_map[id]      
        if key then
            local result = set(self, key, value)
            --log_file.info('update_attribute',key,value,result)
            if result then
                list[#list+1] = {key, value}
            end
            on_attr_anim_func(self, key,value)
        end
    end
    for _, data in ipairs(list) do
        local key = data[1]
        local value = data[2]
        self:event_notify('单位-属性变化', self, key, value)
        self:event_notify('单位-属性改变', self, key, value)
    end
end

local function update_attribute_by_array(attr)
    --log_file.info('update_attribute_by_array',debug.traceback())
    init_attribute()
    for _, data in ipairs(attr) do
        local unit = base.unit(data[1])
        local key = key_map[data[2]]
        if key then
            --log_file.info('update_attribute_by_array', unit, key,#data)
            if set(unit, key, data[3]) then
                unit:event_notify('单位-属性变化', unit, key, data[3])
                unit:event_notify('单位-属性改变', unit, key, data[3])
            end
            on_attr_anim_func(unit, key,data[3])
        end
    end
end

local function update_table_attribute(self, attr)
    init_attribute()
    local list = {}
    for id, value in pairs(attr) do
        local key = key_map[id]
        if key then
            -- 这里和普通属性不一样，增量修改
            local table_value = set_by_sync(self, key, value)
            list[#list+1] = { key, table_value, value }
        end
    end
    for _, data in ipairs(list) do
        local key = data[1]
        local value = data[2]
        local change_value = data[3]
        self:event_notify('单位-属性变化', self, key, value, change_value)
        self:event_notify('单位-属性改变', self, key, value, change_value)
    end
end

local function update_table_attribute_by_array(attr)
    init_attribute()
    for _, data in ipairs(attr) do
        local unit = base.unit(data[1])
        local key = key_map[data[2]]
        if key then
            local value = set_by_sync(unit, key, data[3])
            unit:event_notify('单位-属性变化', unit, key, value, data[3])
            unit:event_notify('单位-属性改变', unit, key, value, data[3])
        end
    end
end

local function update_attribute_without_event(self, attr)
    init_attribute()
    for id, value in pairs(attr) do       
        local key = key_map[id]
        if key then
            set(self, key, value)
        end
    end
end

function mt:attach_model(path, hand_point, hold_point)
    game.unit_attach_model(self._id, path, hand_point, hold_point)
end

function mt:detach_model(path)
    game.unit_detach_model(self._id, path)
end

function mt:change_model(path)
    game.unit_change_model(self._id, path)
end

---comment
---@param link string
---@param ignore_unit_list? boolean
function mt:create_actor(link, ignore_unit_list)
    local cache = base.eff.cache(link)
    if not cache then
        return
    end

    if cache.NodeType == 'ActorTerrainTex' then
        local _, tag = base.terrain:get_texture_info(self:get_point():get_xy())
        local new_link = cache.TerrainTexVar[tag]
        if not new_link or #new_link == 0 then
            new_link = cache.TerrainTexVar.Default
        end
        return self:create_actor(new_link)
    end

    local actor = base.actor(link)

    if not actor then
        return
    end

    if not ignore_unit_list then
        self.actors = self.actors or {}
        table.insert(self.actors, actor)
    end

    local socket = nil
    if cache.SocketName and #cache.SocketName> 0 then
        socket = cache.SocketName
    end

    actor:attach_to(self, socket)
    actor:play()
    
    return actor
end

function mt:create_actors(msg)
    local cache = self.cache or base.eff.cache(self._name)
    if not cache then
        return
    end

    local model_link =  self:get_asset() or cache.ModelData

    local model_cache = base.eff.cache(model_link)

    if cache.ActorArray then
        for index, value in ipairs(cache.ActorArray) do
            local Material_link = base.eff.cache(value)
            if Material_link and Material_link.DynamicMatColor then
                local color = Material_link.DynamicMatColor
                self:set_highlight(true,color[1]/255,color[2]/255,color[3]/255,color[4]/255,Material_link.DynamicMatColorTime*1000)
            end
        end
    end
    if not model_cache then
        return
    end
    local loc = self:get_point()
    local it_actor_cache
    if model_cache.ActorArray then
        for _, value in ipairs(model_cache.ActorArray) do
            it_actor_cache = base.eff.cache(value)
            if it_actor_cache and it_actor_cache.EventCreationModel == msg then
                -- local name, tag = base.terrain:get_texture_info(loc:get_xy())
                self:create_actor(value)
            end
        end
    end
end

local create_state_machines = function(unit, state_machines)
    for sm_name, sm_info in pairs(state_machines) do
        local sm, new = unit:get_or_create_state_machine(sm_name, sm_info.priority, sm_info.layer)
        log_file.debug('add state machine', sm_name, new)
        if new then
            for _, state_info in ipairs(sm_info.states) do -- 先添加所有的states
                log_file.debug('desc', state_info.desc, state_info.id)
                local state = sm:add_state(state_info.desc or '', state_info.id)
            end
            for _, state_info in ipairs(sm_info.states) do -- 再逐个给state加transition
                local state = sm:get_state(state_info.id)
                for evt_id, next_id in pairs(state_info) do
                    if type(evt_id) == 'number' then
                        state:add_transition(evt_id, sm:get_state(next_id))
                    end
                end
            end
            sm.sync = true
            sm:set_current_state(sm_info.cur)
            unit:event_notify('单位-状态机变化', unit, sm_name, sm)
        end
    end
end

function mt:get_node_mark()
    return self._node_mark
end

-- 原GameUnit创建处理
local function on_unit_created(id, attr)
    local unit, new = base.unit(id)
    if not unit then
        return
    end
    remove_destory_unit(unit)
    visible_units[unit] = true
    
    unit._name = base.get_unit_name(attr.unit_type_id)
    local cache = base.eff.cache(unit._name)
    unit.cache = cache
    unit._owner = base.player(attr.unit_slot)
    -- 设置默认属性，因为后面可能默认属性服务端就不发送了（和表的数据相同）否则还是会发的 这里的unit.cache赋值了竟然还是空，大概率是元表的问题，暂时是用的local的cache来缓存的
    if cache then
        for key, value in pairs(cache.Attribute) do
            set(unit, key, value)
        end
        --初始化字符串属性值
        -- 因为没有保存过的项目可能没有这个字段，得兼容一下
        if cache.AttributeString then
            for key, value in pairs(cache.AttributeString) do
                set(unit, key, value)
            end
        end
        
    end
    
    for name, list in pairs(unit.buff) do
        unit.buff[name] = nil
    end

    local node_mark = attr.node_mark
    if type(node_mark) == 'string' and #node_mark>0 then
        unit._node_mark = node_mark
        node_mark_map[node_mark] = unit
    end
    -- unit._scene = game.get_scene_name()
    unit._scene = attr.scene_name or game.get_scene_name();
    local player_slot = game.get_my_player_slot()
    if attr.actors then
        for actor_id, actor_info in pairs(attr.actors) do
            local create = true 
            local exclude_slots = actor_info.exclude_slots or {}
            for _, slot in pairs(exclude_slots) do
                if slot == player_slot then
                    create = false
                    break
                end
            end
            if create then
                local skip_birth = true
                local actor = base.actor(actor_info.name, actor_id, skip_birth, attr.scene_name)
                if actor then
                    --客户端LuaGame::OnUnitCreated决定了传哪些参数到actor_info，以下是必传参数
                    actor:attach_to(unit, actor_info.socket)
                    actor:set_position(actor_info.position.x, actor_info.position.y, actor_info.position.z)
                    actor:set_rotation(actor_info.rotation.x, actor_info.rotation.y, actor_info.rotation.z)
                    actor:set_scale(actor_info.scale.x, actor_info.scale.y, actor_info.scale.z)
                    --以下是可选参数
                    actor:set_shadow(actor_info.cast_shadow and true or false)
                    if actor_info.show ~= nil then
                        actor:show(actor_info.show)
                    end
                    if actor_info.owner_id and actor_info.owner_id ~= -1 then
                        actor:set_owner(actor_info.owner_id)
                    end
                    if actor_info.volume and actor_info.volume >= 0 then
                        actor:set_volume(actor_info.volume)
                    end
                    if actor_info.asset and actor_info.asset ~= '' then
                        actor:set_asset(actor_info.asset)
                    end
                    if actor_info.launch_unit and actor_info.launch_site then
                        actor:set_launch_site(actor_info.launch_unit, actor_info.launch_site)
                    end
                    if actor_info.impact_unit and actor_info.impact_site then
                        actor:set_impact_site(actor_info.impact_unit, actor_info.impact_site)
                    end
                    if actor_info.launch_position then
                        actor:set_launch_position(actor_info.launch_position.x, actor_info.launch_position.y, actor_info.launch_position.z)
                    end
                    if actor_info.launch_ground_z then
                        actor:set_launch_ground_z(actor_info.launch_ground_z)
                    end
                    actor:play()
                end
            end
        end
    end
    if attr.sm then --添加服务端协议传来的自定义状态机
        create_state_machines(unit, attr.sm)
    end
    if new then
        update_attribute_without_event(unit, attr)
        unit:event_notify('单位-进入视野', unit)
    else
        unit:event_notify('单位-进入视野', unit)
        update_attribute(unit, attr)
    end
    unit:create_actors('')
    return unit;
end

-- 轻量单位创建处理 （包含GameUnit和同步Actor）
local function on_light_unit_created(unit_id, attr_map, is_actor)
    local light_unit = nil

    if not is_actor then
        -- GameUnit创建，走原逻辑
        light_unit = on_unit_created(unit_id, attr_map)
        if not light_unit then
            return
        end
    else
        -- 同步Actor创建，c++不负责具体创建，转发给脚本走统一逻辑
        local link_name = attr_map.link_name
        local scene_name = attr_map.scene_name
        local position = attr_map.position
        local rotation = attr_map.rotation
        light_unit = base.actor(link_name, unit_id, false, scene_name)
        if not light_unit then
            return
        end
        light_unit:set_position(position.x, position.y, position.z)
        light_unit:set_rotation(rotation.x, rotation.y, rotation.z)
        light_unit.is_sync = true
        sync_actors[unit_id] = true

        -- 类似于GameUnit的属性同步、状态机变化、视野变化事件暂不处理，后面根据需要来加
    end

    -- 单位附着，统一由脚本处理
    if attr_map.attach_id then
        light_unit:attach_to(attr_map.attach_id)
    end

    -- TODO：处理同步属性的操作事件，如动画播放。
end

-- 注册轻量单位创建事件
base.event.on_unit_created = on_light_unit_created;

base.event.on_controlled_sync_unit_created = function(id, scene_name, unit_type_id, unit_slot)
    local unit, new = base.unit(id)
    if not unit then
        return
    end
    remove_destory_unit(unit)
    visible_units[unit] = true
    
    unit._name = base.get_unit_name(unit_type_id)
    local cache = base.eff.cache(unit._name)
    unit.cache = cache
    unit._owner = base.player(unit_slot)

    -- 这几个属性是没有在数编里面的，写死默认值（值和服务器填的一样）
    unit:set('是否存活', 1)
    unit:set('视野范围', 1000)
    unit:set('转身速度', 1500)

    -- 设置默认属性，因为后面可能默认属性服务端就不发送了（和表的数据相同）否则还是会发的 这里的unit.cache赋值了竟然还是空，大概率是元表的问题，暂时是用的local的cache来缓存的
    if cache then
        for key, value in pairs(cache.Attribute) do
            set(unit, key, value)
        end
        --初始化字符串属性值
        -- 因为没有保存过的项目可能没有这个字段，得兼容一下
        if cache.AttributeString then
            for key, value in pairs(cache.AttributeString) do
                set(unit, key, value)
            end
        end
        
    end
    
    for name, list in pairs(unit.buff) do
        unit.buff[name] = nil
    end

    unit._scene = scene_name
end

function mt:destroy_actors(msg)
    local cache = self.cache or base.eff.cache(self._name)
    if not cache or not self.actors then
        return
    end
    for _, actor in ipairs(self.actors) do
        local link = actor._name
        local actor_cache = base.eff.cache(link)
        if actor_cache and actor_cache.EventDestructionModel == msg then
            actor:destroy(false);
        end
    end
end

---comment
---@param data array [[id, key, value]]
function base.event.on_unit_attributes_changed(data, new)
    if new then
        update_attribute_by_array(data)
    else
        for id, attr in pairs(data) do
            local unit = base.unit(id)
            update_attribute(unit, attr)
        end
    end
end

function base.event.on_unit_table_attributes_changed(data, new)
    if new then
        update_table_attribute_by_array(data)
    else
        for id, attr in pairs(data) do
            local unit = base.unit(id)
            update_table_attribute(unit, attr)
        end
    end
end

function base.event.on_unit_model_changed(id, path)
    local unit = base.unit(id)
    if not unit then
        return
    end
    unit:destroy_actors("");
    unit:create_actors("");
    unit:event_notify('单位-模型改变', unit, path)
end

-- 原GameUnit销毁处理
local function on_unit_destory(id)
    local unit = base.unit(id)
    --单位销毁的时候 判断一下单位的_destory_time
    visible_units[unit] = nil
    unit:event_notify('单位-离开视野', unit)
    if unit._destory_time > 0 then
        add_destory_unit(unit)
    end
end

-- 轻量单位销毁处理 （包含GameUnit和同步Actor）
local function on_light_unit_destroy(unit_id)
    if not sync_actors[unit_id] then
        -- GameUnit销毁 走原逻辑
        on_unit_destory(unit_id)
        return
    end

    -- 同步Actor销毁 
    sync_actors[unit_id] = nil
    local actor = base.actor_from_id(id)
    if actor then
        actor:destroy()
    end
end

-- 注册轻量单位销毁事件
base.event.on_unit_destory = on_light_unit_destroy;

-- 轻量单位附着事件处理 （c++不处理具体附着逻辑，由脚本统一处理，其中包含GameUnit和同步Actor）
function base.event.on_unit_attach_changed(unit_id, attach_id)
    local light_unit
    if sync_actors[unit_id] then
        light_unit = base.actor_from_id(unit_id)
    else
        light_unit = base.get_unit_from_id(unit_id)
    end

    if not light_unit then
        return
    end

    if attach_id then
        light_unit:attach_to(attach_id)
    else
        light_unit:detach()
    end
end

function base.event.on_unit_hovered(id)
    if id then
        local unit = base.unit(id)
        base.game:event_notify('单位-悬停开始', unit)
    else
        base.game:event_notify('单位-悬停结束')
    end
end

function mt:set_blood_bar_visible(visible)
    self._blood_bar_visible = visible
    game.unit_set_blood_bar_visible(self._id, visible)
end

--- 设置血条是否显示（暴露到触发的api）
--- @param visible boolean
function mt:set_status_bar_visibility(visible)
    self:set_blood_bar_visible(visible)
end

--- @param unit Unit
local function sync_unit_actor(unit, key, value)
    if unit._name ~= '$$default_units_ts.unit.同步用单位.root' then
        return
    end

    local _slot_ids = unit and unit:get'_slot_ids'
    if not _slot_ids or type(_slot_ids) ~= "table" then
        return
    end

    local player_id = base.local_player() and base.local_player()._id
    if not _slot_ids[player_id] or key == '_slot_ids' then
        return
    end

    if type(value) ~= "table" then
        return
    end

    local actor = base.actor_from_sid(value[1])
    local params = {}
    for index, val in ipairs(value) do
        if index ~= 1 then
            params[#params+1] = val
        end
    end
    if actor and actor[key] ~= nil then
        actor[key](actor, table.unpack(params))
    end
end

--- @param unit Unit
base.game:event('单位-属性变化', function(_, unit, key, value, change_value)
    sync_unit_actor(unit, key, value)

    if key == '单位标记' then
        for buff in unit:each_buff() do
            buff:update_paused()
        end
        for skill in unit:each_skill() do
            skill:update_paused()
        end
    elseif key == '隐藏血条' then
        unit:set_blood_bar_visible(value and value == 1)
    elseif key == 'sys_quests' then
        --log_file.debug("单位-属性变化", unit, key, base.print_table(value), base.print_table(change_value))
        base.quest.update_quests(unit, value, change_value)
        local ctl_data = {
            is_hero = unit.is_hero,
            tracking_quest_id = unit.tracking_quest_id,
        }
        unit:event_notify('任务-更新', unit, unit.quests, ctl_data)
    elseif key == 'cast_rotation_upper_body' then
        if value == 1 then
            unit:register_model_bone_chain(true)
        else
            unit:register_model_bone_chain(false)
        end
    end
end)

function mt:set_blood_bar_template(template_name)
    self._blood_bar_template = template_name
    local ok = game.unit_set_blood_bar_template(self._id, template_name)
    if ok and self._blood_bar_widget_attributes then
        for key, value in pairs(self._blood_bar_widget_attributes) do
            game.unit_set_blood_bar_widget(self._id, key, value)
        end
    end
end

function mt:set_blood_bar_widget(key, value)
    if not self._blood_bar_widget_attributes then
        self._blood_bar_widget_attributes = {}
    end
    self._blood_bar_widget_attributes[key] = value
    return game.unit_set_blood_bar_widget(self._id, key, value)
end

function base.event.on_unit_blood_bar_created(unit_id)
    local unit = base.unit(unit_id)
    if unit._blood_bar_template then
        game.unit_set_blood_bar_template(unit._id, unit._blood_bar_template)
    end
    if unit._blood_bar_widget_attributes then
        for key, value in pairs(unit._blood_bar_widget_attributes) do
            game.unit_set_blood_bar_widget(unit._id, key, value)
        end
    end
end

function mt:set_minimap_icon_visible(visible)
    self._mini_map_icon_visible = not not visible
    if game.unit_set_minimap_icon_visible then
        return game.unit_set_minimap_icon_visible(self._id, visible)
    end
end

base.game:event('单位-进入视野', function(_, unit)
    local blood_bar_visible = unit._blood_bar_visible
    if blood_bar_visible ~= nil then
        unit:set_blood_bar_visible(blood_bar_visible)
    else
        local server_status_bar_visible = unit:get('隐藏血条')
        if server_status_bar_visible ~= 0 then
            unit:set_blood_bar_visible(server_status_bar_visible == 1)
        end
    end
    local last_visible = unit._mini_map_icon_visible
    if last_visible ~= nil then
        unit:set_minimap_icon_visible(last_visible)
    elseif unit.cache and unit.cache.UnitData and unit.cache.UnitData.MiniMapIconVisible ~= nil then
        unit:set_minimap_icon_visible(unit.cache.UnitData.MiniMapIconVisible)
    else
        unit:set_minimap_icon_visible(true)
    end
    if unit:get('cast_rotation_upper_body') ~= 0 then
        unit:register_model_bone_chain( true)
    end
end)

function base.unit_info()
    return {
        unit_map = unit_map,
    }
end

function mt:create_riseletter(position ,text, type, color, fontsize)
    local riseletter_id = 0
    if not position then 
        riseletter_id = game.create_riseletter(self._id, 0 , 0, text, type, color, fontsize)
    else
        local x,y = position[1],position[2]
        riseletter_id = game.create_riseletter(self._id, x, y, text, type, color, fontsize)
    end
    if riseletter_id == 0 then
        return nil
    else
        return base.riseletter:new(self, riseletter_id)
    end
end

function mt:create_riseletter_by_link(position ,text, link, color, fontsize)
    return self:create_riseletter_by_templatename(position, text, link, color, fontsize)
end

function mt:create_riseletter_by_templatename(position ,text, template_name, color, fontsize)
    local riseletter_id = 0
    if not position then 
        riseletter_id = game.create_riseletter_by_templatename(self._id, 0 , 0, text, template_name, color, fontsize)
    else
        local x,y = position[1],position[2]
        riseletter_id = game.create_riseletter_by_templatename(self._id, x, y, text, template_name, color, fontsize)
    end
    if riseletter_id == 0 then
        return nil
    else
        return base.riseletter:new(self, riseletter_id)
    end
end

function mt:remove_riseletter( riseletter)
    game.remove_riseletter(riseletter:get_id())
end

function mt:set_riseletter_position( riseletter, position)
    local x, y = position[1], position[2]
    game.unit_set_riseletter_position(self._id, riseletter:get_id(), x, y)
end

function mt:create_riseletter_without_color_size(location,text,text_type)
    -- 这个飘字api不需要color和size 故传空值
    local position
    local color
    local riseletter = self:create_riseletter_by_templatename(position, text, text_type, color, 12)
    if riseletter then
        riseletter:set_world_position(location:get_point())
    end
    return riseletter
end

function mt:create_riseletter_with_color_size(location,text,text_type,color,size)
    local position
    local riseletter = self:create_riseletter_by_templatename(position, text, text_type, color, size)
    if riseletter then
        riseletter:set_world_position(location:get_point())
    end
    return riseletter
end

function mt:try_pick_item(item, callback)
    self._try_pick_item_callback = self._try_pick_item_callback or {}
    self._try_pick_item_callback[item.id] = callback
    base.game:server'__unit_try_pick_item'{
        unit_id = self._id,
        item_id = item.id,
    }
end

function mt:get_or_create_state_machine(name, priority, layer)
    if self._statemachines[name] then
        return self._statemachines[name], false
    end
    local sm = base.state_machine(name, priority or 0, layer or 0)
    self._statemachines[name] = sm
    game.add_state_machine(self._id, sm)
    return sm, true
end

function mt:remove_state_machine(sm_name)
    if self._statemachines[name] then
        game.remove_state_machine(self._id, sm_name)
        self._statemachines[name] = nil
    end
end

function base.event.on_unit_state_machine_changed(unit_id, state_machines)
    local unit = base.unit(unit_id) --客户端已经有的unit才会进这里，所以不判new
    -- 清理服务端没有的状态机, 注意：这里不会清理客户端独有的状态机
    for sm_name, sm in pairs(unit._statemachines) do
        if sm.sync and (not state_machines[sm_name]) then
            unit:remove_state_machine(sm_name)
        end
    end
    -- 添加服务端新加的状态机
    -- TODO: 更新服务端已有的状态机暂时想不到应用场景，所以不做
    create_state_machines(unit, state_machines)
end

function base.event.on_unit_state_machine_transit(unit_id, sm_name, event_id)
    local unit = base.unit(unit_id) --客户端已经有的unit才会进这里，所以不判new
    local sm = unit._statemachines[sm_name]
    if sm then
        sm:transit(event_id)
    end
end

function mt:is_valid()
    if not self then
        return false
    end

    if not self._id then
        return
    end

    return self:is_visible()
end


---comment
---@param target Unit|Point
---@param link string
---@param cache_override table?
---@return CmdResult
function mt:execute_on(target,link, cache_override)
    if not self:is_valid() then
        return base.eff.e_cmd.NotSupported
    end

    local ref_param=base.eff_param:new(true)
    ref_param:init(self,target)
    ref_param:set_cache(link)
    if ref_param.cache and cache_override then
        for key, value in pairs(ref_param.cache) do
            if not cache_override[key] then
                cache_override[key] = value
            end
        end
        ref_param.cache = cache_override
    end
    if not ref_param.cache then
        return base.eff.e_cmd.OK
    end
    return base.eff.execute(ref_param)
end

---comment
---@param target Point
---@param link string
---@param cache_override table?
---@return CmdResult
function mt:execute_on_point(target,link, cache_override)
    return self:execute_on(target, link, cache_override)
end

function mt:get_unit()
    if not self:is_valid() then
        return nil
    end
    return self
end

function mt:set_rotation(x, y, z)
    game.set_actor_rotation(self._id, x, y, z)
end

---comment
---@return Item[]
function mt:get_all_items()
    local result  = {}
    if self and self._attribute and self._attribute.sys_inv_items then
        for _, value in ipairs(self._attribute.sys_inv_items) do
            local item  = base.item(value)
            if item then
                table.insert(result, item)
            end
        end
    end
    return result
end

function mt:get_display_name()
    if not self then
        return ''
    end
    if self._display_name then
        return self._display_name
    end
    local cache = base.eff.cache(self:get_name())
    if not cache then
        return self:get_name()
    end
    local display_name
    if cache and cache.Character then
        local char_cache = base.eff.cache(cache.Character)
        if char_cache and char_cache.Name then
            display_name, _ = base.i18n.get_text(char_cache.Name, base.i18n.get_lang());
            return display_name
        end
    end
    display_name,_ = base.i18n.get_text(cache.Name, base.i18n.get_lang());
    return display_name
end

function mt:set_display_name(name)
    self._display_name = name
end

function mt:get_inventory_items(inv_idx)
    local result = {}
    local tmp = self:get_all_items()
    for key, value in pairs(tmp) do
        if value.inv_index == inv_idx then
            table.insert(result, value)
        end
    end
    return result
end


function base.get_units_from_screen_xy(xy, is_accurate)
    local x, y = xy[1], xy[2]
    local actors = game.get_actors_at_screen_xy(x, y, is_accurate and 0 or nil)
    local units = {}
    local units_st = {}

    if actors then
        for k, v in pairs(actors) do
            if v > 0 and units_st[v] ~= true then
                units_st[v] = true
                local unit = base.unit(v)
                if unit then
                    table.insert(units, unit)
                end
            end
        end
    end
    return units
end

local show_methods

local function try_load_show_methods()
    if show_methods then
        return
    end
    if base.eff and base.eff.has_cache_init() then
    local cache = base.eff.cache('$$.gameplay.dflt.root')
    local show_methods_link = cache and cache.ObjectShowMethods and cache.ObjectShowMethods.Unit
    show_methods = base.eff.cache(show_methods_link)
    end
end

function mt:get_show_name()
    try_load_show_methods()
    self.cache = self.cache or base.eff.cache(self._name)
    if not self.cache then
        return ''
    end

    if show_methods and show_methods.ShowNameMethod then
        return show_methods.ShowNameMethod(self)
    else
        return base.i18n.get_text(self.cache.Name)
    end
end

function mt:get_icon()
    try_load_show_methods()
    self.cache = self.cache or base.eff.cache(self._name)
    if show_methods and show_methods.IconMethod then
        return show_methods.IconMethod(self)
    else
        return self.cache.Icon
    end
end

function mt:get_tips()
    try_load_show_methods()
    self.cache = self.cache or base.eff.cache(self._name)
    if show_methods and show_methods.TipsMethod then
        return show_methods.TipsMethod(self)
    else
        return self.cache.Description == '' and '无描述' or base.i18n.get_text(self.cache.Description)
    end
end

function mt:get_current_cd()
    try_load_show_methods()
    if show_methods and show_methods.CoolDownMethod then
        return show_methods.CoolDownMethod(self)
    else
        return 0
    end
end

function mt:get_cd_max()
    try_load_show_methods()
    if show_methods and show_methods.MaxCoolDownMethod then
        return show_methods.MaxCoolDownMethod(self)
    else
        return 0
    end
end

-- 设置单位离开视野的销毁时间
function mt:set_disappear_destory_time(time)
    self._destory_time = time
end

function mt:get_cooldown(cooldown_key)
    local cd_data = game.get_cool_down(self._id, cooldown_key)
    return cd_data and cd_data.current_cd and cd_data.current_cd/1000
end

function mt:insert_into_cooldown_map(cooldown_key, skill)
    self.cooldown_map = self.cooldown_map or {}
    self.cooldown_map[cooldown_key] = self.cooldown_map[cooldown_key] or {}
    self.cooldown_map[cooldown_key][skill] = true
end

function mt:is_cooldown_map_empty()
    if not self.cooldown_map then
        return true
    else
        return next(self.cooldown_map) == nil
    end
end

function mt:remove_from_cooldown_map(cooldown_key, skill)
    if self.cooldown_map and self.cooldown_map[cooldown_key] and self.cooldown_map[cooldown_key][skill] then
        self.cooldown_map[cooldown_key][skill] = nil
    end
end

--参考 https://xindong.atlassian.net/wiki/spaces/Editor/pages/1060713486
function mt:register_bone_chain(CHAIN_ID, bone_chain_data)
    -- param1：单位id
    -- param2：骨骼链id （预期以后会有多个火力点，目前只用1就行）
    -- param2：填入允许旋转的骨骼及对应的旋转权重 （具体骨骼名可在编辑器里查看）
    game.unit_register_bone_chain( self._id, CHAIN_ID, bone_chain_data)
end

--开放给触发用户用的，应用模型配的数据
function mt:register_model_bone_chain( bol)
    if bol == true then
        if self._register_model_bone_chain then
            return
        end
        local data = {}
        local has = false
        if self.cache then
            local model_cache = base.eff.cache( self.cache.ModelData)
            if model_cache then
                if model_cache.BoneChainArray then
                    for k,v in pairs(model_cache.BoneChainArray) do
                        data[v.Key] = v.Value
                        has = true
                    end
                end
            end
            self._register_model_bone_chain = true
            self:register_bone_chain( 1, data)
        end
    else
        self._register_model_bone_chain = false
        self:register_bone_chain( 1, {})
    end
end

-- test_type: 0-粗糙（允许些微的高低不平） 1-严格 2-浮空
function mt:test_build_box(min, max, test_type)
    return game.test_unit_build_box(self._id, min, max, test_type)
end

function base.event.on_unit_cool_down(unit_id, cooldown_key)
    local unit = base.unit(unit_id)
    if unit and unit.cooldown_map and unit.cooldown_map[cooldown_key] then
        for skill, value in pairs(unit.cooldown_map[cooldown_key]) do
            skill:event_notify('技能-冷却完成', skill)
        end
    end
end


return {
    Unit = Unit,
}

