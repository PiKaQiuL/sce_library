local base=base
local log=log

local stages={
    start=1,
    channel=2,
    shot=3,
    finish=4,
}

EffectParam = EffectParam or base.tsc.__TS__Class()
EffectParam.name = 'EffectParam'

EffectParamShared = EffectParamShared or base.tsc.__TS__Class()
EffectParamShared.name = 'EffectParamShared'

base.eff_param = EffectParam.prototype
base.eff_param.type = 'eff_param'

base.eff_param_shared = EffectParamShared.prototype
base.eff_param_shared.type='eff_param_shared'

---@class EPLoopData
---@field channel boolean
---@field channeled Channeled
---@field init_link string
---@field child_link string
---@field periodic_offset table
---@field period number
---@field count integer
---@field it_index integer
---@field it_angle number
---@field activated boolean
---@field loop_flags table
---@field expire_link string
---@field final_link string

---@class EPSearchData
---@field found Unit[]

---@class EPOrderData
---@field unit Unit
---@field cache table
---@field type string
---@field target_type integer

---@class EBuffData
---@field buff Buff
---@field is_channeling boolean

---@class EPMissileData
---@field missile_range number
---@field impacted_count integer
---@field mover Mover

---@class Marker

---@class EffectParam
---@field type string
---@field parent EffectParam
---@field nullified boolean
---@field actors Actor[]
---@field facing number
---@field radius number
---@field result CmdResult
---@field shared EffectParamShared
---@field flags table
---@field source Target
---@field target Target
---@field default_target Target
---@field launch Target
---@field launch_unit Unit
---@field missile Unit
---@field inter_unit Unit
---@field local_var_unit Unit[]
---@field local_var_point Point[]
---@field missile_data EPMissileData
---@field loop_data EPLoopData
---@field search_data EPSearchData
---@field order_data EPOrderData
---@field buff_data EBuffData
---@field cache table
---@field link string
---@field buff Buff
---@field buff_link string
---@field child_index integer
---@field marker Marker
---@field marker_ai Marker
---@field reflected boolean
---@field it_target Target current hit target
local ref_param  = base.eff_param

---------------
-- Shared
---------------
---@class EffectParamShared
---@field root EffectParam
---@field channeler Channeler
---@field caster Target
---@field cast Cast
---@field skill Skill
---@field skill_id string
---@field main_target Target
---@field origin Snapshot
---@field creator_player Player
---@field modifier_source Unit
---@field flags table
---@field user_data table
---@field attribute table
---@field level integer
---@field weapon table
---@field weapon_id string
---@field item Item
---@field item_id string
---@field scene string?
---@field closed boolean?
local ref_shared = base.eff_param_shared

local eff = base.eff

local base_game = base.game
local base_wait = base.wait
local post_event = base.event_notify

local e_cmd = eff.e_cmd
local e_site = eff.e_site
local e_target_type = eff.e_target_type
local e_sub_name = eff.e_sub_name

---comment
---@return string
function ref_param:debuginfo()
    return self.type..':'..self.link..'['..tostring(self)..']'
end

---comment
---@return string?
function ref_param:logfail(result, info)
    if result == e_cmd.OK then
        return
    end

    if self.cache then
        if self.cache.SuppressValidatorFailOutput then
            return
        end
    end
    local infoText = info
    if not info then
        if type(result) == "table" and result.Result then
            infoText = result.ErrorText or base.eff.e_cmd_str[result.Result] or result.Result
        else
            infoText = base.eff.e_cmd_str[result] or result
        end
    end
    log_file.debug(self:debuginfo().."执行失败，原因："..tostring(infoText))
end

---comment
---@param init_tree boolean?
---@return EffectParam
function ref_param:new(init_tree)
    local param={shared={}, flags={}, result=e_cmd.Unknown, reflected = false }
    setmetatable(param, self.__index)
    if param.____constructor then
        param:____constructor()
    end
    if(init_tree)then
        param.shared=ref_shared:new(param)
    end
    return param
end

---comment
---@return boolean
function ref_param:is_root()
    return (self.parent==nil)
end

---comment
---@return EffectParam
function ref_param:root()
    return self.shared.root
end

---comment
---@return EffectParam
function ref_param:create_child()
    local child_param=ref_param:new()
    self:link_child(child_param)
    return child_param
end

---comment
---@return string?
function ref_param:get_scene()
    return (self.source and self.source:get_scene())
    or (self:caster() and self:caster():get_scene())
    or (
        self.shared
        and (self.shared.creator_player and self.shared.creator_player:get_scene_name())
            or (self.shared and self.shared.scene)
        )
end

---comment
---@param key string
---@param point Point
function ref_param:set_var_point(key, point)
    local new_table = {}
    if self.local_var_point then
        for it_key, value in pairs(self.local_var_point) do
            new_table[it_key] = value
        end
    end
    self.local_var_point = new_table
    self.local_var_point[key] = point
end

---comment
---@param key string
---@param unit Unit
function ref_param:set_var_unit(key, unit)
    local new_table = {}
    if self.local_var_unit then
        for it_key, value in pairs(self.local_var_unit) do
            new_table[it_key] = value
        end
    end
    self.local_var_unit = new_table
    self.local_var_unit[key] = unit
end

---comment
---@param key string
---@return Unit|nil
function ref_param:var_unit(key)
    if (not key) or not (self.local_var_unit) then
        return nil
    end
    return self.local_var_unit[key]
end

---comment
---@param key string
---@return Point|nil
function ref_param:var_point(key)
    if (not key) or not (self.local_var_point) then
        return nil
    end
    return self.local_var_point[key]
end

---comment
---@param child_param EffectParam
function ref_param:link_child(child_param)
    child_param.parent= self
    child_param.shared= self.shared
    child_param.reflected = self.reflected
    child_param:set(self)
end

---comment
---@param in_ref_param EffectParam
function ref_param:set(in_ref_param)
    self.buff=in_ref_param.buff
    self.buff_link=in_ref_param.buff_link
    self.child_index=in_ref_param.child_index
    self.marker=in_ref_param.marker
    self.marker_ai=in_ref_param.marker_ai
    self.local_var_point = in_ref_param.local_var_point
    self.local_var_unit = in_ref_param.local_var_unit
    self.respond_args = in_ref_param.respond_args
    if(self:is_root())then
        self.shared.skill=in_ref_param.shared.skill
        self.shared.cast=in_ref_param.shared.cast
        self.shared.skill_id=in_ref_param.shared.skill_id
        self.shared.weapon=in_ref_param.shared.weapon
        self.shared.weapon_id=in_ref_param.shared.weapon_id
        self.shared.item=in_ref_param.shared.item
        self.shared.item_id=in_ref_param.shared.item_id
    end
end

---comment
---@param source Target
---@param default_target Target
function ref_param:init(source,default_target)
    self:set_source(source)
    self.default_target=default_target
    if(not self.target)then
        self:set_target(default_target)
    end
    if(self:is_root())then
        self.shared.main_target=default_target
    end
end

---comment
---@param source Target
function ref_param:set_source(source)
    self.source=source
    if(self:is_root() and self:caster()==nil)then
        self:set_caster(source)
    end
end

function ref_param:calc_target()
    local cache = self.cache
    if cache.TargetLocation and cache.TargetType then
        local target = self:parse_loc(cache.TargetLocation,cache.TargetType)
        if target then
            self:set_target(target)
        else
            log.error(self,': Unable to reslove target with target location and target type!')
        end
    end
end

---comment
---@param target Target
function ref_param:set_target(target)
    self.target=target
end

---comment
---@param launch Target
function ref_param:set_launch(launch)
    self.launch=launch
end

function ref_param:get_level()
    if self.shared then
        if self.shared.level then
            return self.shared.level
        end
    end
    return -1
end

---@class LeveledData
---@field LevelValues boolean[]|string[]|number[]
---@field LevelFactor number
---@field PreviousValueFactor number
---@field BonusPerLevel number

---comment
---@param data LeveledData|boolean[]|string[]|number[]
---@param fallbackValue boolean|string|number
---@param level integer?
---@return boolean|string|number
function ref_param:level_data(data, fallbackValue, level)
    if type(data) ~= "table" then
        return fallbackValue
    end
    ---@type boolean[]|string[]|number[]
    local table = data.LevelValues or data
    if #table == 0 then
        log_file.debug('等级信息配置错误，没有找到任何等级信息，将返回默认值')
        if not data.LevelFactor then
            return fallbackValue
        else
            table = { fallbackValue }
        end
    end
    level = level or self.shared.level
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

---comment
---@param link string
function ref_param:set_cache(link)
    self.cache=eff.cache(link)
    self.link=link
end

---comment
---@param buff Buff
function ref_param:set_buff(buff)
    self.buff=buff
    self.buff_link=buff.name
end

---comment
---@param table table
---@return table
function ref_param:snap_shot_values(table)
    if type(table) ~= "table" then
        if type(table) == "function" then
            return table(self)
        end
        return table
    end
    local out_table = {}
    for key, value in pairs(table) do
        out_table[key] = self:snap_shot_values(value)
    end
    return out_table
end

---comment
---@param link string
---@return EffectParam
function ref_param:search(link)
    local params=self
    if(link==nil or link=='')then
        return params
    end
    while ((params~=nil) and (params.link~=link))
    do
        params=params.parent
    end
    return params
end

---comment
---@param group Unit[]
---@param sorts string[]
function ref_param:unit_sorts(group, sorts)
    if table and sorts and #sorts > 0 then
        -- 记录比较结果 如果相同的两个单位再进行比较 直接从这里获取结果
        local record = {}
        -- unit_a > unit_b: record[unit_a][unit_b] = 1
        -- unit_a < unit_b: record[unit_a][unit_b] = -1
        local set_record = function(unit_a, unit_b, result)
            record[unit_a] = record[unit_a] or {}
            record[unit_b] = record[unit_b] or {}
            record[unit_a][unit_b] = result
            record[unit_b][unit_a] = -result
        end
        local get_record = function(unit_a, unit_b)
            return record[unit_a] and record[unit_a][unit_b]
        end
        local cmp = function(unit_a, unit_b)
            local result = get_record(unit_a, unit_b)
            if result == 1 or result == -1 then
                return result
            end
            for _, sort in ipairs(sorts) do
                local sort_cache = eff.cache(sort)
                if sort_cache and sort_cache.Func then
                    result = sort_cache.Func(self, unit_a, unit_b, sort)
                    if type(result) == "boolean" then
                        log.error('排序函数错误：'..sort_cache.Link..'|'..tostring(sort_cache.Func)..' 返回值为布尔，应为数值。')
                        result = result and -1 or 1
                    end
                    if result ~= 0 then
                        set_record(unit_a, unit_b, result)
                        return result
                    end
                end
            end
            return 1
        end
        ---comment
        ---@param unit_a Unit
        ---@param unit_b Unit
        table.sort(group, function (unit_a, unit_b)
            if cmp(unit_a, unit_b) < 0 then
                return true
            else
                return false
            end
        end)
    end
end

---comment
function ref_param:missile_detach()
    self.flags.missile_nullified = true
end

---comment
---@return boolean
function ref_param:is_missile_detached()
    return self.flags.missile_nullified or false
end

---comment
---@param channeler Channeler
function ref_param:set_channeler(channeler)
    -- 只能设置一次！
    if(self.shared.channeler~=nil)then
        log.error('效果树只能进入一次引导状态。出错的效果树：'..self:debuginfo()..'；link为'..self.link)
    end
    self.shared.channeler=channeler
end

---comment
---@return Channeler
function ref_param:get_channeler()
    return self.shared.channeler
end

---comment
---@return Skill
function ref_param:skill()
    return self.shared.skill
end

---comment
---@return Cast
function ref_param:cast()
    return self.shared.cast
end

---comment
---@return Target
function ref_param:caster()
    return self.shared.caster
end

---comment
---@return Target
function ref_param:item()
    return self.shared.item
end

---comment
---@return table
function ref_param:user_data()
    return self.shared.user_data
end

---comment
---@param buff_link string
---@param prop_name string
---@param a number
---@param b number
---@param is_percentage boolean
---@param stack_index? integer
---@return number
function ref_param:item_random(buff_link, prop_name,a, b, is_percentage, stack_index)
    stack_index = stack_index or 1
    if self.shared.item then
        ---@type Item
        local item = self.shared.item
        local result = item:randomized_value(buff_link, prop_name, is_percentage, stack_index)
        if not result then
            result = base.math.random_smart(a, b)
            item:set_randomized_value(buff_link, prop_name, result, is_percentage, stack_index)
        end
        return result
    end

    return base.math.random_smart(a, b)
end

---comment
---@return Target
function ref_param:origin()
    return self.shared.origin
end

---comment
---@return Target
function ref_param:main_target()
    return self.shared.main_target
end

---comment
---@param caster Target
function ref_param:set_caster(caster)
    -- 通常只设置一次
    self.shared.caster=caster
    self:setup_caster()
end

---comment
---@param origin_target Target
function ref_param:set_origin(origin_target)
    -- 通常只设置一次
    if(origin_target.type==nil)then
        print('Invalid orgin for effect param: '..self..'with link: '..self.link)
    end
    self.shared.origin = origin_target:get_snapshot()
    if(self.shared.creator_player==nil)then
        self:set_creator(self.shared.origin.player)
    end
end

---comment
---@param creator_player Player
function ref_param:set_creator(creator_player)
    -- 通常只设置一次
    self.shared.creator_player=creator_player
end

---comment
function ref_param:creator_player()
    return self.shared.creator_player
end

---comment
function ref_param:setup_caster()
    if(self.shared.origin==nil)then
        self:set_origin(self.shared.caster)
    end

    if(self.shared.creator_player==nil)then
        self:set_creator(self.shared.origin.player)
    end

    if(self.shared.caster.type~='unit')then
        return
    end
    local unit=self.shared.caster

    if not self.shared.modifier_source then
        self:set_damage_modifiers(unit,false)
    end

    self.shared.scene = self.shared.scene or self.shared.caster:get_scene()
    --todo:设置actorscope
end

---comment
---@param unit Unit
---@param needreset boolean?
function ref_param:set_damage_modifiers(unit,needreset)
    if not self.shared.flags.can_refresh_modifiers then
        return
    end
    if not unit then
        return
    end
    if(needreset)then
        self.shared.attribute={}
    end

    self.shared.modifier_source=unit

    local level = self.shared.skill and self.shared.skill:get_level()

    if level then
        self.shared.level = level
    end

    self.shared.attribute['急速'] = unit:get '急速'
    if (self.shared.attribute['急速']==0) then
        self.shared.attribute['急速']=1
    end
end

---comment
---@param site string
---@return Target
function ref_param:get_site_target(site, var)
    local action={
        [e_site.default]=function ()
            return self.default_target
        end,
        [e_site.target]=function ()
            return self.target
        end,
        [e_site.caster]=function ()
            return self:caster()
        end,
        [e_site.launch]=function ()
            return self.launch
        end,
        [e_site.missile]=function ()
            return self.missile
        end,
        [e_site.source]=function ()
            return self.source
        end,
        [e_site.origin]=function ()
            return self:origin()
        end,
        [e_site.main_target]=function ()
            return self:main_target()
        end,
        [e_site.inter_unit]=function ()
            return self.inter_unit
        end,
        [e_site.local_var_unit]=function (in_var)
            if (not var) or not (self.local_var_unit) then
                return nil
            end
            return self.local_var_unit[in_var]
        end,
        [e_site.local_var_point]=function (in_var)
            if (not var) or not (self.local_var_point) then
                return nil
            end
            return self.local_var_point[in_var]
        end,
    }
    return action[site](var)
end

---comment
---@param loc_express LocExpress
---@param type string?
---@return Target?
function ref_param:parse_loc(loc_express, type)
    local params=self:search(loc_express.Effect)
    if not params then
        local target_cache = base.eff.cache(loc_express.Effect)
        local target_name = target_cache and target_cache.Name or loc_express.Effect
        local self_name = self.cache and self.cache.Name or self.cache.Link
        log.error('效果节点',self_name,'不存在名为',target_name,'的父级节点，请检查效果节点目标属性配置。（可以尝试在属性上点击右键重置，并重新选择）')
        return nil
    end
    local target=params:get_site_target(loc_express.Value, loc_express.LocalVar)
    if not target then
        local self_name = self.cache and self.cache.Name or self.cache.Link
        log.error('效果节点',self_name,'无法计算出目标位置，请检查节点配置')
    end
    if(type==nil or type==e_target_type.any)then
        return target
    end
    if(type==e_target_type.point)then
        return target:get_point()
    end
    if(type==e_target_type.unit)then
        return target:get_unit()
    end
end

---comment
---@param player_express PlayerExpress
---@return Player
function ref_param:parse_player(player_express)
    if(player_express.Value=='Neutral')then
        return base.player(0)
    end
    ---@type Target Description
    local loc=self:parse_loc(player_express.TargetLocation)
    local player = loc:get_owner()
    -- 假如没能获得任何玩家，而且类型设为默认，那么尝试获得施法者玩家
    if(player==nil
        and
        (player_express.TargetLocation.Value==e_site.default
        or player_express.TargetLocation.Value==e_site.caster))
        then
        return self.shared.creator_player
    end
    return player
end

---comment
---@param angle_express AngleExpress
---@return number
function ref_param:parse_angle(angle_express)
    local local_offset = angle_express.LocalOffset or 0
    if type(local_offset) == "function" then
        local_offset = local_offset(self)
    end
    if(angle_express.Method == 'Explicit')then
        return local_offset
    end
    local angle
    if(angle_express.Method == 'AngleBetweenPoints')then
        ---@type Point
        local angle_loc=self:parse_loc(angle_express.Location,e_target_type.point)
        angle=angle_loc and angle_loc:angle_to(self:parse_loc(angle_express.OtherLocation,e_target_type.point))
        -- 如果两个点坐标相同，则会返回nil
        if(angle~=nil)then
            return angle+ local_offset
        end
    end
    angle=self:parse_loc(angle_express.Location):get_facing()
    if angle~=nil then
        angle = angle + local_offset
    end
    return angle
end

---comment
---@param name string
---@param f function
function ref_param:event(name, f)
    base.event_register(self, name, f)
end

---comment
---@param event_subname string
function ref_param:post_event(event_subname)
    local event_name = '效果-'..event_subname
    base_game:event_notify(event_name, self)
    post_event(self.cache, event_name, self)
    post_event(self, event_name, self)
end

---comment
---@param new_target Unit
function ref_param:post_new_target(new_target)
    local new_target_unit = new_target:get_unit()
    if new_target_unit then
        new_target_unit:on_response("ResponseMissileImpact", base.response.e_location.Defender, self)
    end
    local caster = self:caster():get_unit()
    if caster then
        caster:on_response("ResponseMissileImpact", base.response.e_location.Attacker, self)
    end
    local event_name = '效果-'..e_sub_name.missile_impact
    base_game:event_notify(event_name, self, new_target)
    post_event(self.cache, event_name, self, new_target)
    post_event(self, event_name, self, new_target)
end

---comment
---@param link string
---@param target Target
---@return EffectParam
function ref_param:init_child_on(link, target)
    if(not target) then
        target=self.target
    end
    if(target and link and link~='')then
        local child_param=self:create_child()
        child_param:init(self.source,target)
        child_param:set_cache(link)
        return child_param
    end
end

function ref_param:execute()
    if self.result ~= e_cmd.Unknown then
        return e_cmd.AlreadyExecuted
    end
    return eff.execute(self)
end


---comment
---@param link string
---@param target Target?
---@return CmdResult
function ref_param:execute_child_on(link, target)
    if self.shared.closed then
        return e_cmd.NotSupported
    end
    if(not target) then
        target=self.target
    end
    if(target and link and link~='')then
        local child_param=self:create_child()
        child_param:init(self.source,target)
        child_param:set_cache(link)
        if self.loop_data and self.loop_data.it_index then
            child_param.child_index = self.loop_data.it_index + 1
        end
        if(child_param.cache)then
            return eff.execute(child_param)
        end
    end
    return e_cmd.Unknown
end

---comment
---@param mask table
---@param in_player Player
---@param scene string?
---@return integer[]
local function get_exclude(in_player, mask, scene)
    local exclude = {}
    --不要浪费时间
    if mask.Self and mask.Ally and mask.Enemy and not scene then
        return exclude
    end
    ---@type Player Description
    for player in base.each_player 'user' do
        if not in_player:match_mask(player, mask) then
            table.insert(exclude, player:get_slot_id())
        end
        --- TODO:对于持续性且sync的actor，不使用这个规则。
        if scene then
            if player:get_scene_name() ~= scene then
                table.insert(exclude, player:get_slot_id())
            end
        end
    end
    return exclude
end

---comment
---@param link string
---@param position Point?
---@param force_no_sync boolean?
---@return Actor?
function ref_param:create_actor(link, position, force_no_sync)
    ---@type Target Description
    local target = position or self.target
    if self.facing then
        target = target:get_point();
    end
    local cache = eff.cache(link)
    if not cache then
        return
    end


    local player  = self:creator_player()
    local exclude = {}

    local scene

    if target.type ~= 'unit' or cache.ForceOneShot == 1 then
        scene = self:get_scene()
    end

    if cache.CreationFilter and player then
        exclude = get_exclude(player, cache.CreationFilter, scene)
    end

    local actor
    if cache.ForceOneShot == 1 or force_no_sync then
        actor = base.actor(link, exclude, false)
    else
        actor = base.actor(link, exclude, true)
    end

    if not actor then
        return
    end

    if cache.AutoScale and self.radius then
        local model_cache
        if cache.Model then
            model_cache = eff.cache(cache.Model)
        elseif cache.Effect then
            model_cache = eff.cache(cache.Effect)
        end
        local base_radius = 128
        if model_cache then
            base_radius = model_cache.AutoScaleBaseRadius or base_radius
        end
        if type(self.radius) == "number" then
            local scale = self.radius / base_radius * (cache.Scale or 1)
            actor:set_scale(scale)
        elseif type(self.radius)  == "table" then
            local scaleX = self.radius.X and (self.radius.X / base_radius * (cache.Scale or 1)) or 1
            local scaleY = self.radius.Y and (self.radius.Y / base_radius * (cache.Scale or 1)) or 1
            local scaleZ = self.radius.Z and (self.radius.Z / base_radius * (cache.Scale or 1)) or 1
            actor:set_scale(scaleX, scaleY, scaleZ)
        end
    elseif cache.Scale then
        actor:set_scale(cache.Scale)
    end

    if self.missile and self.launch_unit and cache.NodeType == 'ActorAction' then
        if cache.LaunchSocketName and #cache.LaunchSocketName > 0 then
            actor:set_launch_site(self.launch_unit, cache.LaunchSocketName)
        end
        actor:attach_to(self.missile)
    elseif target.type == 'unit' then
        local socket = nil
        if cache.SocketName and #cache.SocketName> 0 then
            socket = cache.SocketName
        end
        actor:attach_to(target, socket)
        if cache.ShowShadow == false then
            actor:set_shadow(false)
        end
    else
        if player then
            actor:set_owner(self:creator_player():get_slot_id())
        end
        target = target:get_point()

        actor:set_bearings(target[1], target[2], target[3], self.facing, true)
    end

    if cache.NodeType == 'ActorBeam' then
        ---@type Unit|Point Description
        local launch_site = self.launch_unit or self.source
        if launch_site.type == 'unit' then
            local launch_socket = nil
            if cache.LaunchSocketName and #cache.LaunchSocketName > 0 then
                launch_socket = cache.LaunchSocketName
            end
            actor:set_launch_site(launch_site, launch_socket)
            actor:set_launch_position(cache.LaunchOffset.X, cache.LaunchOffset.Y, cache.LaunchOffset.Z)
        else
            launch_site = launch_site:get_point()
            actor:set_launch_position(launch_site[1] + cache.LaunchOffset.X, launch_site[2] + cache.LaunchOffset.Y)
            actor:set_launch_ground_z(cache.LaunchOffset.Z)
        end
    end

    actor:play()
    return actor
end

function ref_param:next_child()
    local node_type = self.cache.NodeType
    if base.ui_eff[node_type] and base.ui_eff[node_type].next_child then
        base.ui_eff[node_type].next_child(self)
    end
end

function ref_param:stop()
    if not self.stopped then
        self:post_event(e_sub_name.stop)
        if self.parent then
            self.parent:next_child()
        end
    end
    self.stopped = true
    if base.ui_eff[self.cache.NodeType].persist and self.actors then
        for _, actor in ipairs(self.actors) do
            actor:destroy(false);
        end
    end
end

---comment
---@param target Unit
---@param link string
---@param stack integer
---@param params table?
---@return EffectParam
function ref_param:add_buff(target, link, stack, params)
    --强行模拟一个EffectAddBuff效果，使得buff可以作为子效果存在
    local cache={
        ID='EffectAddBuff',
        NodeType='EffectAddBuff',
        BuffLink=link,
        Count=stack or 1,
    }
    local child_param=self:create_child()
    child_param:init(self.source,target)
    child_param.cache=cache
    child_param.link='EffectAddBuff'
    eff.EffectAddBuff.execute(child_param, params)
    return child_param
end

---comment
---@param target Unit
---@param type string
---@param amount number
---@param params table?
---@return EffectParam
function ref_param:damage(target, amount, type, params)
    local cache={
        ID='EffectDamage',
        NodeType='EffectDamage',
        Amount = function ()
            return amount
        end,
        DamageType = type,
    }
    local child_param=self:create_child()
    child_param:init(self.source,target)
    child_param.cache=cache
    child_param.link='EffectDamage'
    eff.EffectDamage.execute(child_param, params)
    return child_param
end

--param.loop_data
--@loop_flags
--@child_link
--@period
--@periodic_offset
--@count
------it_index(runtime)
------it_angle(runtime)
------timer(runtime)

---comment
---@param loop_data EPLoopData
function ref_param:loop(loop_data)
    if self.loop_data~=nil then
        print('Error: Trying to stack loop on the same node!')
        return
    end
    self.loop_data=loop_data
    self.loop_data.channel=loop_data.loop_flags.Channeling or loop_data.loop_flags.Channeled
    if(loop_data.loop_flags.Channeled)then
        local skill = self:skill()
        if skill then
            skill.channeled_count = skill.channeled_count or 0
            skill.channeled_count = skill.channeled_count + 1
            if skill.channeled_count == 1 then
                skill:stage_pause()
            end
        end
        loop_data.channeled=base.channeled:new()
        loop_data.channeled:start_channeling(self:get_channeler())
    end

    if(self.loop_data.channel)then
        self:get_channeler():register(self)
    end

    --初始效果
    self:execute_child_on(loop_data.init_link)

    --循环开始
    self.loop_data.it_index=0
    self.loop_data.activated=true
    if loop_data.periodic_offset then
        self.loop_data.it_angle=loop_data.periodic_offset.angle_start
    end
    local function tick()
        if(loop_data.child_link and loop_data.child_link~='')then
            local new_target=self.target
            if loop_data.periodic_offset~=nil then
                self.loop_data.it_angle=self.loop_data.it_angle + loop_data.periodic_offset.angle
                new_target=self.target:get_point():polar_to(
                    {self.loop_data.it_angle,loop_data.periodic_offset.distance}
                )
            end
            self:execute_child_on(loop_data.child_link,new_target)
        end
        self.loop_data.it_index=self.loop_data.it_index+1
    end

    local function early_out()
        self:loop_clear_up(false)
        log.error(self:debuginfo())
    end

    local tick_start

    local function safe_tick()
        xpcall(tick_start, early_out)
    end

    function tick_start()
        if(
            self.shared.flags.can_refresh_modifiers
            and loop_data.loop_flags.RefreshModifierPerLoop
            and self:caster()~=nil
            and self:caster().type=='unit'
        )then
            self:set_damage_modifiers(self.shared.modifier_source or self:caster())
        end

        if not self.loop_data.validator_trigger and self.cache and self.cache.PersistValidator then
            self.loop_data.validator_trigger=base_game:event('游戏-帧', function()
                if(self.loop_data.activated)then
                    local result = eff.execute_validators(self.cache.PersistValidator,self)
                    if(result~=e_cmd.OK)then
                        self:loop_clear_up(false)
                    end
                end
            end
            )
        end

        tick()

        if loop_data.count ~= -1 and self.loop_data.it_index>=loop_data.count then
            self:loop_clear_up(true)
            return
        end
        local rate=1
        if loop_data.loop_flags.UseHaste then
            rate=self.shared.attribute['急速']
        end
        self.loop_data.timer=base_wait(loop_data.period * 1000 / rate , safe_tick)
    end

    local rate=1
    if loop_data.loop_flags.UseHaste then
        rate=self.shared.attribute['急速']
    end

    if loop_data.period>0 then
        if(loop_data.loop_flags.IgnoreStartDelay)then
            safe_tick()
        else
            self.loop_data.timer=base_wait(loop_data.period * 1000 / rate , safe_tick)
        end
    elseif loop_data.period==0 then
        while (self.loop_data.it_index<loop_data.count)
        do
            tick()
        end
        self:loop_clear_up(true)
    end
end

---comment
function ref_param:on_channeler_cleared()
    if self.loop_data and self.loop_data.activated and self.loop_data.channel then
        self:loop_clear_up(false)
    end
    if self.buff_data and self.buff_data.buff and self.buff_data.is_channeling then
        self.buff_data.buff:remove()
    end
end

---comment
---@param complete boolean
function ref_param:loop_clear_up(complete)
    ---@type EPLoopData Description
    local loop_data=self.loop_data
    if(loop_data.timer)then
        loop_data.timer:remove()
        loop_data.timer=nil
    end
    if(loop_data.validator_trigger)then
        loop_data.validator_trigger:remove()
        loop_data.validator_trigger=nil
    end
    loop_data.activated=false
    if(self.loop_data.loop_flags.FinishStage and self:skill() and self:skill():get_stage()==stages.shot)then
        self:skill():stage_finish()
    end
    local skill = self:skill()
    if skill and skill.channeled_count then
        skill.channeled_count = skill.channeled_count - 1
        if skill.channeled_count <= 0 then
            skill:stage_resume()
        end
    end
    if(complete)then
        self:execute_child_on(loop_data.expire_link)
    end

    self:execute_child_on(loop_data.final_link)
    self:stop()
end

---comment
---@param name any
---@return any
function ref_param:get_node_in_module(name)
    local link = self.link
    if not link then
        link = self.shared.skill_id
    end
    if link then
        return eff.find_sibling(link, name)
    end
    return nil
end

---comment
---@param root EffectParam
---@return EffectParamShared
function ref_shared:new(root)
    local shared={root=root, user_data={}, attribute={}, flags={can_refresh_modifiers=true}, level=1}
    setmetatable(shared, self)
    return shared
end

function ref_shared:close()
    if not self.closed then
        self.closed = true
    end
end

function ref_shared:is_closed()
    return self.closed or false
end

---comment
---@param cast Cast
function ref_shared:set_skill(cast)
    self.skill = cast
    if not cast then
        return
    end
    -- if cast:is_cast() then
    --     self.cast = cast
    --     self.skill = cast:get_skill()
    -- end
    self.skill_phase = self.skill:get_phase() or 0
    self.skill_id = cast:get_name()
end

---comment
---@param level integer
function ref_shared:set_level(level)
    self.level=level
end

---comment
---@param weapon Skill
function ref_shared:set_weapon(weapon)
    self.weapon=weapon
    self.weapon_id=weapon:get_name()
end

---comment
---@param item Item
function ref_shared:set_item(item)
    if item then
        self.item = item
        self.item_id = item.link
    end
end


return {
    EffectParam = EffectParam,
    EffectParamShared = EffectParamShared
}