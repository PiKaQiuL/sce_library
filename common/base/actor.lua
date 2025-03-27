Actor = base.tsc.__TS__Class()
Actor.name = 'Actor'

-- 客户端表现相关的C++ api的封装
local mt = Actor.prototype

mt.type = 'actor'
mt._id = nil
mt._slot_id = nil
mt._name = nil

function mt:__tostring()
    return ('{actor|%d|%s|%s'):format(self._id, self._name, self._type)
end

local actor_mode_full = false

local mode_default = { __mode = 'v' }
local mode_full = {}

-- id与客户端actor的映射
local actor_map = setmetatable({}, mode_default)
-- 服务端传过来的id与客户端actor的映射
-- sid_map一定要用strong table因为服务器通知客户端创建的actor在客户端没有ref，会直接gc
local sid_map = {}

function base.set_actor_map(actor)
    actor_map[actor._id] = actor
end

---comment
---@param allow_ray_cast boolean
function base.set_actor_mode(allow_ray_cast)
    if allow_ray_cast == actor_mode_full then
        return
    end
    if allow_ray_cast then
        setmetatable(actor_map, mode_full)
    else
        setmetatable(actor_map, mode_default)
    end
end

function base.set_unit_highlight_on(unit,r,g,b,a,time)
    local r,g,b,a = r or 0,g or 0 ,b or 0 ,a or 0
    if unit then
        unit:set_highlight(true,r/255,g/255,b/255,a/255,time*1000)
    end
end

function base.set_unit_highlight_off(unit)
    if unit then
        unit:set_highlight(false)
    end
end

function base.actor(name, sid, skip_birth, scene) -- sid是服务端rpc创建actor传过来的id
    if scene and #scene > 0 and game.get_current_scene() ~= scene then
        return
    end
    if sid then
        local existing_actor =  sid_map[sid]
        -- 已经存在的与服务端对应的actor无需再创建
        if existing_actor then
            return existing_actor
        end
    end
    local cache = base.eff.cache(name)
    if not cache then
        return nil
    end
    if cache.CreationFilterLevel
    and base.actor_creation_filter_level
    and cache.CreationFilterLevel < base.actor_creation_filter_level then
        return nil
    end
    local sp = false
    if skip_birth then
        sp = true
    end
    local result, id, slot_id = game.create_actor(name, sp, scene)
    if not result and not cache.DynamicMatColor then
        return nil
    end
    local actor = setmetatable({
        _type = cache.NodeType,
        _id = id,
        _slot_id = slot_id,
        _name = name,
        _server_id = nil,
    }, { __index = mt })
    actor_map[id] = actor
    local model_link = cache.Model
    local model_cache = base.eff.cache(model_link)
    if model_cache then
        actor._global_scale = 1 -- 设置全局播放速度为1, 且只会影响新API相关动画
        actor._current_anim = nil
    end
    if sid then
        actor._server_id = sid
        sid_map[sid] = actor
    end
    local destroy_on_orphan = cache.DestroyOnOrphan
    if destroy_on_orphan then
        actor:set_destroy_on_orphan(true)
    end
    actor.cache = cache
    actor:do_sub_class_action()
    actor:create_actors('')
    return actor
end

---comment
---@param id number
---@return Actor
function base.actor_from_id(id)
    return actor_map[id]
end

---comment
---@param id number
---@return Actor
function base.actor_from_sid(id)
    return sid_map[id]
end

function mt:set_destroy_on_orphan(destroy)
    game.actor_set_remove_with_parent(self._id, destroy)
end

---comment
---@return boolean
function mt:is_destroy_on_orphan()
    return game.actor_is_remove_with_parent(self._id)
end

function mt:release()
    actor_map[self._id] = nil
    if self._server_id then
        sid_map[self._server_id] = nil
    end
end

function mt:destroy(force)
    if (self.cache and self.cache.DynamicMatColor) and self.unit_id then
        local unit = base.unit(self.unit_id)
        if unit then
            unit:set_highlight(false)
        end
    end
    if force then
        game.remove_actor(self._id, true)
    else
        game.remove_actor(self._id)
    end
    self:release()
end
-- 别名
mt.remove = mt.destroy

function mt:set_owner(owner_id)
    if self._slot_id ~= owner_id then
        self._slot_id = owner_id
        game.set_actor_owner(self._id, owner_id)
    end
end

function mt:set_shadow(enable)
    game.set_actor_shadow(self._id, enable)
end

---@param scene_point ScenePoint
function mt:set_point(scene_point)
    self:set_position(scene_point[1], scene_point[2], scene_point[3])
end

function mt:set_position(x, y, z)
    if type(x) == 'table' and x.type == 'point' then
        z = x[3]
        y = x[2]
        x = x[1]
    end
    x = x or 0
    y = y or 0
    if not self.hosted and self.bearings then
        self.cache = self.cache or base.eff.cache(self._name)
        local cache = self.cache
        if cache and cache.FollowRotation == 1 then
            local facing = self.bearings.facing
            local vec = self.bearings.source:polar_to({facing, x})
            vec = vec:polar_to({facing + 90, y})
            x = vec[1]
            y = vec[2]
        else
            x = self.bearings.source[1] + x
            y = self.bearings.source[2] + y
        end
        z = self.bearings.source[3] + z
        game.set_unit_location(self._id, x, y, z, true)
        if self.bearings.use_ground_height then
            self:set_ground_z(z)
        end
        return
    end
    game.set_unit_location(self._id, x, y, z, true)
end

function mt:get_world_position()
    local x,y,z = game.get_actor_world_position(self._id)
    return base.point(x or 0.0, y or 0.0, z or 0.0)
end

function mt:get_position()
    local x,y,z,scene_hash = game.get_unit_location(self._id, true)
    return base.scene_point_by_hash(x or 0.0, y or 0.0, z or 0.0, scene_hash)
end

function mt:set_ground_z(z)
    game.set_actor_ground_z(self._id, z)
end

function mt:set_position_from(target, socket)
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
    local x, y, z = game.get_socket_position(target_id, socket or 'Socket_Root')
    if not x or not y then
        return
    end
    self:detach()
    game.set_unit_location(self._id, x, y, z or 0.0, true)
end

function mt:set_rotation(x, y, z)
    local cache = self.cache
    if not self.hosted and self.bearings and cache and cache.FollowRotation == 1 then
        z = self.bearings.facing + z
    end
    self.rotation = {x, y, z}
    game.set_actor_rotation(self._id, x, y, z)
end

function mt:get_rotation()
    local x, y, z = game.get_actor_rotation(self._id)
    -- C++里欧拉角x,y,z和约定俗成的不一样，一般约定yaw表示水平面内旋转，pitch俯仰，roll水平倾斜
    return { yaw = z, pitch = y, roll = x }
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

function mt:set_scale(x, y, z)
    if not y then
        y = x
    end
    if not z then
        z = x
    end
    game.set_actor_scale(self._id, x, y, z)
end

function mt:set_scale_xyz(x, y, z)
    self:set_scale(x, y, z)
end

function mt:actor_set_scale(x)
    self:set_scale(x)
end

function mt:set_asset(asset)
    game.set_actor_asset(self._id, asset)
end

function mt:set_fow(enable, radius)
    game.set_actor_fow(self._id, enable, radius)
end

function mt:set_grid_size(size)
    if type(size) == 'table' then
        game.set_grid_actor_axis(self._id, size[1], 0, 0, size[2])
    elseif type(size) == 'number' then
        game.set_grid_actor_axis(self._id, size, 0, 0, size)
    end
end

function mt:set_grid_range(start_id, range)
    game.set_grid_actor_range(self._id, start_id[1], start_id[2], range[1], range[2])
end

function mt:set_grid_state(grid_id, state)
    -- id 为网格中心的坐标
    game.set_grid_actor_state(self._id, grid_id[1], grid_id[2], state)
end

function mt:set_grid_stick_to_ground(enable)
    -- 开贴地不要旋转
    game.set_grid_actor_stick_to_ground(self._id, enable)
end

function mt:attach_to(target, socket) -- target can be a unit or actor
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

    local AttachForwardOnce = false
    local link = self._name
    local cache
    if link then
        cache = base.eff.cache(link)
        if cache then
            AttachForwardOnce = cache.AttachForwardOnce
            if cache.ShowShadow == false then
                self:set_shadow(false)
            end
        end
    end

    local unit
    if target_id > 0 then
        unit = base.unit(target_id)
    end
    if cache and cache.DynamicMatColor and unit then
        self.unit_id = target_id
        local color = cache.DynamicMatColor
        unit:set_highlight(true,color[1]/255,color[2]/255,color[3]/255,color[4]/255,cache.DynamicMatColorTime * 1000)
    end
    if AttachForwardOnce then
        local x, y, z = game.get_socket_position(target_id, socket or 'Socket_Root')
        if not x or not y then
            return
        end
        local facing = 0
        if unit then
            facing = unit:get_facing()
        else
            local host_actor = base.actor(target_id)
            if host_actor then
                facing = host_actor:get_rotation().yaw
            end
        end
        self:set_bearings(x, y, z, facing, false)
        return
    else
        self.hosted = true
        game.attach_actor_to_socket(self._id, target_id, socket)
    end

    self:finalize_bearings()
end

function mt:attach_to_anchor(anchor_name)
    return game.attach_actor_to_anchor(self._id, anchor_name)
end



---comment
---@param x number|nil
---@param y? number
---@param z? number
---@param facing? number
---@param use_ground_height? boolean
function mt:set_bearings(x, y, z, facing, use_ground_height)
    local bearings
    if x and y then
        self:detach()
        bearings = {
            source = base.point(x, y, z or 0),
            facing = facing or 0,
            use_ground_height = use_ground_height
        }
        self.bearings = bearings
        self:finalize_bearings()
    end
    self.bearings = nil
end

function mt:finalize_bearings()
    local cache = self.cache
    if cache then
        local offset = cache.Offset
        if offset then
            self:set_position(offset.X, offset.Y, offset.Z)
        end
        local rot = cache.Rotation
        if rot and not self.rotation then
            self:set_rotation(rot.X, rot.Y, rot.Z)
            self.rotation = nil
        end
    end
end

function mt:detach()
    self.hosted = nil
    game.detach_actor(self._id)
end

function mt:show(status)
    if status == nil then
        status = true
    end
    game.actor_show(self._id, status)
end

function mt:play()
    game.actor_play(self._id)
end

---comment
---@param anim_name string
---@param anim_param ICustomAnimParams
function mt:play_anim_ex(anim_name, anim_param)
    anim_param.is_actor = true
    anim_param.owner_id = self._id
    anim_param.anim = anim_name
    local handle = game.actor_play_anim(anim_param)
    return base.tsc.__TS__New(
        base.defaultui.AnimHandle,
        {},
        self._id,
        true,
        handle
    )
end


---comment
---@return table<ICustomAnimParams>
function mt:get_anims()
    local anim_hanldes = game.actor_get_anims(self._id, true)
    local anims = {}
    for _, handle in ipairs(anim_hanldes) do
        local anim = base.tsc.__TS__New(
            base.defaultui.AnimHandle,
            {},
            self._id,
            true,
            handle
        )
        table.insert(anims, anim)
    end
    return anims
end

function mt:play_animation(anim, params)
    local loop = false
    local speed = 1.0
    if params then
        loop = params.loop or loop
        speed = params.speed or speed
    end
    game.actor_play_anim(self._id, anim, loop, speed, 0, true)
end

--SCE-11984搁置
--function mt:play_animation_bracket(anim, params)
--    local loop = false
--    local speed = 1.0
--    if params then
--        loop = params.loop or loop
--        speed = params.speed or speed
--    end
--    game.actor_play_anim(self._id, anim, loop, speed, 0, true)
--end

function mt:stop(fade)
    fade = fade or false
    game.actor_stop(self._id, fade, true)
end

function mt:pause()
    game.actor_pause(self._id, true)
end

function mt:resume()
    game.actor_resume(self._id, true)
end

function mt:set_volume(volume)
    game.actor_set_sound_volume(self._id, volume)
end

function mt:get_highlight()
    return game.get_actor_highlight(self._id)
end

function mt:set_highlight(on, ...)
    game.set_actor_highlight(self._id, on, ...)
end

function mt:set_material_parameters(...)
    game.set_actor_material_parameters(self._id, ...)
end

function mt:set_launch_site(unit, socket)
    local unit_id = nil
    if type(unit) == 'number' then
        unit_id = unit
    elseif unit.type == 'unit' then
        unit_id = unit._id
    end
    if unit_id then
        game.actor_set_launch_site(self._id, unit_id, socket)
    else
        log.error('set_launch_site failed, unit_id is nil.')
    end
end

function mt:set_impact_site(unit, socket)
    local unit_id = nil
    if type(unit) == 'number' then
        unit_id = unit
    elseif unit.type == 'unit' then
        unit_id = unit._id
    end
    if unit_id then
        game.actor_set_impact_site(self._id, unit_id, socket)
    else
        log.error('set_impact_site failed, unit_id is nil.')
    end
end

function mt:set_launch_position(x, y, z)
    if not z then
        z = 0
    end
    game.actor_set_launch_position(self._id, x, y, z)
end

---@param point ScenePoint
function mt:set_launch_scene_point(point)
    self:set_launch_position(point:get_x(), point:get_y(), point:get_z())
end

function mt:set_launch_ground_z(z)
    game.actor_set_launch_ground_z(self._id, z)
end

function mt:set_text(text)
    game.set_actor_text(self._id, text)
end

local function pos_distance(p1, p2)
    local x1 = p1[1]
    local y1 = p1[2]
	local x2 = p2[1]
    local y2 = p2[2]
	local x0 = x1 - x2
	local y0 = y1 - y2
	return math.sqrt(x0 * x0 + y0 * y0)
end

local sub_class_action = {}

function sub_class_action.CameraShake(self, cache)
    base.wait(0, function ()
        local mode = ''
        if cache.CameraShakeMode.X then
            mode  = mode..'x'
        end
        if cache.CameraShakeMode.Y then
            mode  = mode..'y'
        end
        if cache.CameraShakeMode.Z then
            mode  = mode..'z'
        end

        local frequency = cache.Frequency
        local amplitude = cache.Amplitude
        if cache.CameraShakeMode.Damping then
            local cam = game.GetCamera()
            local cam_pos = cam.position
            local shake_pos = self:get_world_position()
            local distance = pos_distance(cam_pos, shake_pos)
            local damping = cache.Damping
            if damping and damping > 0 and distance < cache.Damping then
                local factor = (damping - distance) / damping
                amplitude = amplitude * factor
            else
                return
            end

        end
        local  time = cache.Time
        game.shake_camera(mode, frequency, amplitude, time)
    end)
end

---comment
function mt:do_sub_class_action()
    local link = self._name
    if not link then
        return
    end

    local cache = base.eff.cache(link)
    if not cache then
        return
    end

    local action = sub_class_action[cache.SubClass]
    if action then
        action(self, cache)
    end
end

---comment
---@param link string
function mt:create_actor(link)
    local cache = base.eff.cache(link)
    if not cache then
        return
    end

    if cache.DynamicMatColor then
        local color = cache.DynamicMatColor
        self:set_highlight(true,color[1]/255,color[2]/255,color[3]/255,color[4]/255,cache.DynamicMatColorTime * 1000)
    end
    if cache.NodeType == 'ActorTerrainTex' then
        local _, tag = base.terrain:get_texture_info(self:get_position():get_xy())
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
    self.actors = self.actors or {}

    table.insert(self.actors, actor)

    local socket = nil
    if cache.SocketName and #cache.SocketName> 0 then
        socket = cache.SocketName
    end


    actor:attach_to(self, socket)
    actor:play()
end

function mt:create_actors(msg)
    local cache = self.cache or base.eff.cache(self._name)
    if not cache then
        return
    end

    local model_link =  cache.Model

    local model_cache = base.eff.cache(model_link)

    if not model_cache then
        return
    end

    local loc = self:get_position()

    local it_actor_cache
    if model_cache.ActorArray then
        for _, value in ipairs(model_cache.ActorArray) do
            it_actor_cache = base.eff.cache(value)
            if it_actor_cache and it_actor_cache.EventCreationModel == msg then
                --log_file.debug(base.terrain:get_texture_info(loc:get_xy()))
                self:create_actor(value)
            end
        end
    end
end

function mt:destroy_actors(msg)
    local cache = self.cache or base.eff.cache(self._name)
    if not cache or not self.actors then
        return
    end
    for _, actor in ipairs(self.actors) do
        local link = actor._name
        local actor_cache = base.eff.cache(link)
        if actor_cache 
        and not (actor_cache.ForceOneShot == 1 and actor_cache.KillOnFinish == 1)
        and actor_cache.EventCreationModel == msg then
            local force_kill = cache.KillOnDeactivate == 1 and true
            actor:destroy(force_kill);
        end
    end
end

function base.actor_info()
    return {
        actor_map = actor_map,
        server_actor_map = sid_map
    }
end

function base.get_actor_from_id(id)
    return actor_map[id]
end

function base.get_actor_from_sid(id)
    return sid_map[id]
end

base.game:event('表现-动画事件开始', function(trig, id, msg, anim)
    local actor = actor_map[id]
    if actor then
        actor:create_actors(msg)
    else
        local unit = base.unit(id)
        if unit then
            unit:create_actors(msg)
        end
    end
end)

base.game:event('表现-动画事件结束', function(trig, id, msg, anim)
    local actor = actor_map[id]
    if actor then
        actor:destroy_actors(msg)
    else
        local unit = base.unit(id)
        if unit then
            unit:destroy_actors(msg)
        end
    end
end)

-- 当前动画结束后，actor的动画播放速率会恢复为1（因为其只影响）
base.game:event('表现-动画结束', function(trig, id, anim, operation)
    --log_file.info('表现-动画结束',id, anim, operation)
    local actor = actor_map[id]
    if actor then
        if operation == 'bracket_animation_end' then
            if actor._current_anim then
                for i, v in ipairs(actor._bracket_anims)  do
                    if v == actor._current_anim then
                        --log_file.info('actor_play_anim_bracket table.remove', actor._current_anim. anim_birth,i)
                        table.remove(actor._bracket_anims, i) 
                        break
                    end
                end
                actor._current_anim:remove()
                actor._current_anim = nil
            end
           
            -- 这个回调是状态机update做的，为了不想逻辑改的太复杂，这里最好还是延迟一帧再播下一个
            if #actor._bracket_anims > 1 then
                base.next(function()
                    if #actor._bracket_anims > 1 then
                        actor._current_anim = actor._bracket_anims[1]
                        game.actor_play_anim_bracket(actor._id, actor._current_anim.anim_birth, actor._current_anim.    anim_stand, actor._current_anim.anim_death, actor._current_anim.    force_one_shot, actor.  _current_anim.kill_on_finish, true, true)
                        game.actor_set_play_speed(id, actor._current_anim.anim_speed)
                        --log_file.info('actor_play_anim_bracket', actor._current_anim.anim_birth,actor. _current_anim.anim_speed)
                    end
                end)
            end
        else
            if actor._current_anim then
                actor._current_anim:remove()
                actor._current_anim = nil
            end
            --game.actor_set_play_speed(id, 1)
        end
    end
end)

---@param anim_name string
---@param params table
function mt:anim_play(anim_name, params) -- 表现播放动画的新API
    local anim = base.anim(anim_name, 'actor', self._id, self._name, params)
    local time = anim.time or 0
    local time_type = anim.time_type or 0
    if not params.time or params.time < 0 then
        time_type = 0
    end
    local start_offset = anim.start_offset or 0
    local priority = anim.priority or 0 
    local global_scale = self._global_scale or 1
    local blend_time = anim.blend_time or 0
    --log_file.info('anim_play',anim_name,start_offset,priority,global_scale,blend_time,self._current_anim)
    if not self._current_anim or (self._current_anim
    and priority > self._current_anim.priority) then
        if time_type == 0 then -- 默认速度播放
            anim:play(anim_name, false, 1 / global_scale, blend_time)
            anim:set_time(start_offset, true)
        elseif time_type == 1 then -- 视为持续时间
            anim:play(anim_name, false)
            anim:set_time(start_offset, true)
            anim:set_duration(time)
        elseif time_type == 2 then -- 视为相对缩放倍率,仅在此时考虑_global_scale
            anim:play(anim_name, false)
            anim:set_time(start_offset, true)
            anim:set_time_scale(time)
        elseif time_type == 3 then -- 视为绝对缩放倍率
            anim:play(anim_name, false)
            anim:set_time(start_offset, true)
            anim:set_time_scale_absolute(time)
        end
    end
    return anim
end

-- 设置全局播放速度，只影响新API播放的动画
---@param scale number -- 全局播放速度，默认为1，负数视为1
function mt:set_time_scale_global(scale)
    self._global_scale = scale
    if self._global_scale <= 0 then self._global_scale = 1 end
    if self._current_anim and (self._current_anim.time_type == 2 or self._current_anim.type == 'bracket_anim')  then
        local anim_scale = self._current_anim.time_scale or 1
        self._current_anim:set_time_scale(anim_scale)
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
    --     log_file.info('bracket',i,v.anim,v.priority)
    -- end
end

-- 手动构建BSD动画，然后play动画
---@param anim_birth string
---@param anim_stand string
---@param anim_death string
function mt:anim_play_bracket(anim_birth, anim_stand, anim_death, params)
    local bracket_anim = base.bracket_anim(anim_birth, anim_stand, anim_death, params, 'actor', self._id, self._name)
    if bracket_anim then
        if not self._current_anim or bracket_anim.priority > self._current_anim.priority then
            --sync: 仅在force_on_shot为否时有效，当客户端看到这个actor时（load对应的场景或者actor附着的单位appear了），从stand开始播放。
            game.actor_play_anim_bracket(self._id, anim_birth, anim_stand, anim_death, params.force_one_shot, params.kill_on_finish, params.sync and not params.force_one_shot, true)
            self._current_anim = bracket_anim
            -- 应用global
            bracket_anim:set_time_scale(1)
        end
    end
    if not params.force_one_shot then
        add_bracket_to_table(self, bracket_anim)
    end
end

function mt:anim_set_paused_all(paused)
    self._global_anim_pause = paused
    if self._current_anim then
        self._current_anim:refresh_global_pause(paused)
    else
        if paused then
            self:pause()
        else
            self:resume()
        end
    end
end

--[[
    接收服务端表现动画句柄的方法调用，如果该句柄对应id在服务端不存在，则说明客户端已经不存在这个句柄
]]--

function mt:anim_operation(op, params, ...)
    --log_file.info('anim operation', op, base.json.encode(params))
    local anim_type = params.type
    local anim_id = params.id
    local anim_handle
    if anim_type == 'anim' then
        local anim_map = base.get_anim_map()
        anim_handle = anim_map[anim_id]      
    elseif anim_type == 'bracket_anim' then
        local bracket_anim_map = base.get_anim_bracket_map()
        anim_handle = bracket_anim_map[anim_id]
    end

    if anim_handle and op and anim_handle[op] then
        anim_handle[op](anim_handle, ...)
        -- if op == 'play' then
        --     anim_handle:play(...)
        -- elseif op == 'pause' then
        --     anim_handle:pause()
        -- elseif op == 'resume' then
        --     anim_handle:resume()
        -- elseif op == 'set_time' then
        --     anim_handle:set_time(...)
        -- elseif op == 'set_time_scale' then
        --     anim_handle:set_time_scale(...)
        -- elseif op == 'set_time_scale_absolute' then
        --     anim_handle:set_time_scale_absolute(...)
        -- elseif op == 'set_percentage' then
        --     anim_handle:set_percentage(...)
        -- elseif op == 'set_duration' then
        --     anim_handle:set_duration(...)
        -- elseif op == 'destroy' then
        --     anim_handle:destroy(...)
        -- elseif op == 'bracket_stop' then
        --     anim_handle:bracket_stop()
        -- end
    end
end


--参考 https://xindong.atlassian.net/wiki/spaces/Editor/pages/1060713486
function mt:register_bone_chain(CHAIN_ID, bone_chain_data)
    -- param1：单位id(actor)
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
            local model_cache = base.eff.cache( self.cache.Model)
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


function base.get_actors_from_screen_xy(xy)
    if not actor_mode_full then
        log_file.debug('从屏幕坐标获取所有表现功能只有在打开屏幕坐标获取表现功能后才可使用，请使用“设置是否允许通过屏幕坐标获取表现”动作来打开这一模式')
        return {}
    end
    local x, y = xy[1], xy[2]
    local actors = game.get_actors_at_screen_xy(x, y)
    local actors_ = {}
    local actors_st = {}

    if actors then
        for k, v in pairs(actors) do
            if v < 0 and actors_st[v] ~= true then
                actors_st[v] = true
                local actor = actor_map[v]
                if actor then
                    table.insert(actors_, actor)
                end
            end
        end
    end
    return actors_
end

--- 创建并播放2D音效
function base.play_sound_effect(link)
    local cache = base.eff.cache(link)
    if cache.NodeType ~= 'ActorSound' then
        log_file.warn(link..'不是音效表现，请检查传入参数！')
        return
    end
    if not cache.UISound or cache.UISound == 0 then
        log_file.warn(link..'不是2D音效，请检查数编配置！')
    end

    local actor = base.create_actor_at(link, base.point(1, 1, 1))
    actor:play()
    return actor
end

---@param link string
---@param source Unit|Point
---@param target Unit|Point
---@return Actor
function base.create_beam_effect(link, source, target)
    local cache = base.eff.cache(link)
    if cache.NodeType ~= 'ActorBeam' then
        log_file.warn(link..'不是闪电/光束表现，请检查传入参数！')
        return
    end

    if not source or (source.is_valid ~= nil and not source:is_valid()) then
        log_file.warn('发射源'..source..'非法！')
        return
    end

    if not target or (target.is_valid ~= nil and not target:is_valid()) then
        log_file.warn('发射目标'..target..'非法！')
        return
    end

    --- @type Actor
    local actor = base.create_actor_at(link, source:get_point(), true)

    if cache.Scale then
        actor:set_scale(cache.Scale)
    end

    if source.type == 'unit' then
        local launch_socket = nil
        if cache.LaunchSocketName and #cache.LaunchSocketName > 0 then
            launch_socket = cache.LaunchSocketName
        end
        actor:set_launch_site(source, launch_socket)
        actor:set_launch_position(cache.LaunchOffset.X, cache.LaunchOffset.Y, cache.LaunchOffset.Z)
    else
        source = source:get_point()
        actor:set_launch_position(source[1] + cache.LaunchOffset.X, source[2] + cache.LaunchOffset.Y)
        actor:set_launch_ground_z(cache.LaunchOffset.Z)
    end

    if target.type == 'unit' then
        local socket = nil
        if cache.SocketName and #cache.SocketName> 0 then
            socket = cache.SocketName
        end
        if cache.ShowShadow == false then
            actor:set_shadow(false)
        end
        actor:attach_to(target, socket)
    else
        actor:set_bearings(target[1], target[2], target[3], 0, true)
    end

    actor:play()
    return actor
end

return {
    Actor = Actor,
}
