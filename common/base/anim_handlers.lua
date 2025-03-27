-- 分两种动画：单次播放的动画和循环播放的动画
local mt = {}
mt.__index = mt
mt.anim = nil
mt.owner_id = nil
mt.owner_name = nil
mt.owner_type = nil
mt.priority = 0
mt.loop = false    -- 默认为不循环播放

local anim_id = 1
local anim_map = setmetatable({}, { __mode = 'v' })

local bracket_anim_id = 1
local bracket_anim_map = setmetatable({}, { __mode = 'v' })

function base.get_anim_map()
    return anim_map
end

function base.get_anim_bracket_map()
    return bracket_anim_map
end

function base.anim(anim_name, owner_type, owner_id, owner_name, params)
    local id = params.id or anim_id
    --log_file.info('base.anim',id,params.id,bracket_anim_id)
    local anim = setmetatable({
        id = id,
        type = 'anim',
        anim = anim_name,
        owner_type = owner_type,
        owner_id = owner_id,
        owner_name = owner_name,
        time = params.time,
        time_type = params.time_type,
        blend_time = params.blend_time,
        start_offset = params.start_offset,
        priority = params.priority,
        paused = false,
    }, {__index = mt})
    anim_map[id] = anim
    if id > 0 then anim_id = anim_id + 1 end
    return anim
end

function base.bracket_anim(anim_birth, anim_stand, anim_death, params, owner_type, owner_id, owner_name)   
    local id = params.id or bracket_anim_id
    --log_file.info('base.bracket_anim',id,params.id,bracket_anim_id)
    local anim = setmetatable({
        id = id,
        type = 'bracket_anim',
        owner_type = owner_type,
        owner_id = owner_id,
        owner_name = owner_name,
        anim_birth = anim_birth,
        anim_stand = anim_stand,
        anim_death = anim_death,
        force_one_shot = params.force_one_shot,
        kill_on_finish = params.kill_on_finish,
        sync = params.sync,
        priority = params.priority,
        paused = false,
        anim_speed = 1,
    }, {__index = mt})
    bracket_anim_map[id] = anim
    if id > 0 then bracket_anim_id = bracket_anim_id + 1 end
    return anim
end

function mt:play(anim, loop, speed, blend_time)
    --log_file.info(anim, loop, speed, blend_time, self.owner_type, self.owner_id)
    anim = anim or self.anim
    loop = loop or false
    blend_time = blend_time or self.blend_time
    local owner = self:get_unit_or_actor()
    speed = speed or (1 / owner._global_scale) or 1
    game.actor_play_anim(self.owner_id, anim, loop, speed, blend_time,self.owner_type == 'actor')
    owner._current_anim = self
end

function mt:get_unit_or_actor()
    if self.owner_type == 'actor' then
        return base.actor_from_id(self.owner_id)
    elseif self.owner_type == 'unit' then
        return base.unit_info().unit_map[self.owner_id]
    end
end

function mt:replay()
    if not self:check_valid() then return end
    if self.type == 'anim' then
        self:play(self.anim, false, nil, nil)
    end
end

function mt:refresh_global_pause(paused)
    if not self:check_valid() then return end   
    local final_paused = paused or self.paused
    if final_paused then
        game.actor_pause(self.owner_id, self.owner_type == 'actor')
    else
        game.actor_resume(self.owner_id, self.owner_type == 'actor')
    end
end

function mt:pause()
    if not self:check_valid() then return end
    self.paused = true
    local owner = self:get_unit_or_actor()
    if owner._current_anim and owner._current_anim.id == self.id then
        game.actor_pause(self.owner_id, self.owner_type == 'actor')
    end
end

function mt:resume()
    if not self:check_valid() then return end
    self.paused = false
    local owner = self:get_unit_or_actor()
    if owner._global_anim_pause then return end
    if owner._current_anim and owner._current_anim.id == self.id then
        game.actor_resume(self.owner_id, self.owner_type == 'actor')
    end
end

---@param time number
---@param trigger_events boolean
function mt:set_time(time, trigger_events)
    if not self:check_valid() then return end
    trigger_events = trigger_events or false
    local owner = self:get_unit_or_actor()
    if owner._current_anim and owner._current_anim.id == self.id then
        game.actor_set_play_time(self.owner_id, time, trigger_events, self.owner_type == 'actor')
    end
end

---@param scale number
function mt:set_time_scale(scale)
    if not self:check_valid() then return end
    self.time_type = 2
    if scale <= 0 then scale = 1 end
    self.time_scale = scale
    local owner = self:get_unit_or_actor()
    local global_scale = owner._global_scale or 1
    local speed = 1 / (scale * global_scale)
    if owner._current_anim and owner._current_anim.id == self.id then
        game.actor_set_play_speed(self.owner_id, speed, self.owner_type == 'actor')
    end

    if self.type == "bracket_anim" then
        self.anim_speed = speed
    end
end

---@param scale number
function mt:set_time_scale_absolute(scale)
    if not self:check_valid() then return end
    self.time_type = 3
    if scale <= 0 then scale = 1 end
    local owner = self:get_unit_or_actor()
    if owner._current_anim and owner._current_anim.id == self.id then
        game.actor_set_play_speed(self.owner_id, 1 / scale, self.owner_type == 'actor')
    end

    if self.type == "bracket_anim" then
        self.anim_speed = 1 / scale
    end
end

---@param
function mt:set_percentage(percentage)
    if not self:check_valid() then return end
    if self.type == "bracket_anim" then return end
    local owner = self:get_unit_or_actor()
    if owner._current_anim and owner._current_anim.id == self.id then
        game.actor_set_play_percentage(self.owner_id, percentage, self.owner_type == 'actor')
    end
end

function mt:set_duration(duration)
    if not self:check_valid() then return end
    if self.type == "bracket_anim" then return end
    local owner = self:get_unit_or_actor()
    if owner._current_anim and owner._current_anim.id == self.id then
        game.actor_set_play_duration(self.owner_id, duration, self.owner_type == 'actor')
    end
end

function mt:destroy()
    local owner = self:get_unit_or_actor()
    if owner and owner._current_anim and owner._current_anim.id == self.id then
        if self._type == 'anim' then
            game.actor_stop_animation(self.owner_id, self.owner_type == 'actor')
        else 
            game.actor_stop_bracket(self.owner_id, self.owner_type == 'actor')
        end
        owner._current_anim = nil
    end    

    if self._type == 'anim' then
        anim_map[self.id] = nil
    else 
        bracket_anim_map[self.id] = nil
    end
end

function mt:bracket_stop()
    if self.type == 'anim' then
        self:destroy()
    else 
        game.actor_stop_bracket(self.owner_id, self.owner_type == 'actor')
    end
end

-- 检查该句柄的有效性
function mt:check_valid()
    if self.type == 'anim' then
        if not anim_map[self.id] then
            return false
        end
    elseif self.type == 'bracket_anim' then
        if not bracket_anim_map[self.id] then
            return false
        end
    end
    return true
end

function mt:remove()
    if self.type == 'anim' then
        anim_map[self.id] = nil
    else
        bracket_anim_map[self.id] = nil
    end
end