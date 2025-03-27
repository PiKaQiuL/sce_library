local base=base
local log=log
local caches={ dict = {}, has_inited = false}

---@class Mover
---@field remove fun()

---@class Target Unit|Point
---@field get_point fun(self:Target):Point
---@field get_unit fun(self:Target):Unit
---@field get_snapshot fun(self:Target):Snapshot
---@field get_name fun(self:Target):string
---@field get_owner fun(self:Target):Player
---@field get_facing fun(self:Target):integer
---@field get_team_id fun(self:Target):integer
---@field get_attackable_radius fun(self:Target):number
---@field is_ally fun(self:Target, target:Unit|Player):boolean
---@field is_visible_to fun(self:Target, target:Player):boolean
---@field has_restriction fun(self:Target, restriction:string):boolean
---@field has_label fun(self:Target, label:string):boolean
---@field polar_to fun(self:Target, offset:table)
---@field get_scene fun(self:Target):string?
---@field follow fun(self:Target, mover_table:table)
---@field type string

---@class LocExpress
---@field Effect string
---@field Value string
---@field LocalVar string

---@class PlayerExpress
---@field TargetLocation LocExpress
---@field Value string

---@class AngleExpress
---@field LocalOffset number
---@field Location LocExpress
---@field OtherLocation LocExpress
---@field Method string

base.eff={}

local eff=base.eff

base.eff.e_cmd = {
    Unknown = -1,
    OK = 0,
    NotSupported = 1,
    Error = 2,
    MustTargetUnit = 3,
    NotEnoughTarget = 4,
    NotEnoughRoomToPlace = 5,
    InvalidUnitType = 6,
    InvalidPlayer = 7,
    NothingToExecute = 8,
    MustTargetCertainUnit = 9,
    CannotTargetCertainUnit = 10,
    TargetIsOutOfRange = 11,
    TargetIsTooClose = 12,
    NoIntermediateUnit = 13,
    AlreadyExecuted = 14,
    CannotTargetThat = 15,
    NotEnoughCharges = 16,
    NotEnoughResource = 17,
    CannotPlaceThere = 18,
    InvalidItemType = 19,
    InvalidRange = 20,
}

base.eff.e_cmd_str = {
    '不支持',
    '错误',
    '必须以单位为目标',
    '目标数量不足',
    '放置空间不足',
    '无效的单位Id',
    '无效的玩家',
    '没有可供执行的对象',
    '必须以特定种类的单位为目标',
    '无法以特定种类的单位为目标',
    '目标超出射程',
    '目标太近了',
    '缺少中间单位',
    '效果已经执行过了',
    '无法以那个为目标',
    '使用次数不足',
    '资源不足',
    '无法在那里建造',
}

base.eff.e_site={
    default = 'Default',
    caster = 'Caster',
    launch = 'Launch',
    target = 'Target',
    missile = 'Missile',
    source = 'Source',
    origin = 'Origin',
    main_target = 'MainTarget',
    inter_unit = 'IntermediateUnit',
    local_var_unit = 'UnitLocalVar',
    local_var_point = 'PointLocalVar',
}

base.eff.e_sub_name = {
    start = '开始',
    activated = '已启动',
    stop = '结束',
    missile_impact = '弹道命中单位',
    teleport_start = '瞬移开始',
    teleport_finish = '瞬移完成',
}

base.eff.e_target_type={
    point='Point',
    unit='Unit',
    any = 'Any',
}

base.eff.e_stage={
    unknown=-1,
    idle=0,
    start=1,
    channel=2,
    shot=3,
    finish=4,
}

local e_cmd=eff.e_cmd
--local e_site=eff.e_site
local e_target_type=eff.e_target_type
local e_sub_name = eff.e_sub_name

function eff.init_cache()
    if caches.has_inited then
        return
    end

    if not __MAIN_MAP__ then
        return
    end
    local start_time = os.clock()
    eff.cache_init_started = true
    local obj = require ("@"..__MAIN_MAP__..".obj.effect")
    if not obj or not obj.dict or not next(obj.dict) then
        log.error('错误：地图中缺少数编数据！')
        return
    end
    log_file.info("地图数编加载时间：%s", os.clock() - start_time);
    caches = obj
    caches.has_inited = true
    base.game:event_notify("Src-PostCacheInit")
end

function eff.merge_cache(in_cache)
    for key, value in pairs(in_cache.dict) do
        caches.dict[key] = value
    end
    for key, value in pairs(in_cache) do
        if (key ~= 'dict') then
            caches[key] = value
        end
    end
end

function eff.has_cache_init()
    return eff.cache_init_started or (caches and caches.has_inited)
end

function eff.cache_init_finished()
    return caches and caches.has_inited
end

---comment
---@param node_type string
function eff.caches(node_type)
    return caches[node_type]
end

function eff.all_caches(node_type)
    local ty = type(node_type)
    if ty == "string" then
        node_type = string.gsub(node_type, "$$.", "")
    elseif ty == "table" then
        node_type = ((node_type.typeArguments or {})[1] or {}).literal
        if node_type then
            node_type = string.gsub(node_type, "_id", "")
        end
    end
    local result
    local t = eff.caches(node_type)
    if t then
        result = {}
        for key, _ in pairs(t) do
            local it_link = key..'.root'
            table.insert(result, it_link)
        end
    end
    return result
end

---comment
---@param link string
---@return table?
function eff.cache(link)
    if link and (not caches.dict or not next(caches.dict)) then
        log.error('游戏地图数据为空，请确保数据已经载入')
    end
    return caches.dict[link]
end

---comment
---@param link string
---@return table?
function eff:cache_ts(link)
    return eff.cache(link)
end

function eff.get_node_type(node_type)
    if node_type and node_type.NodeTypeLink then
        return node_type.NodeTypeLink
    end
end

function eff.cache_as(link, node_type)
    if link and #link > 0 and (not caches.dict or not next(caches.dict)) then
        log.error('游戏地图数据为空，请确保数据已经载入')
    end
    local ret = caches.dict[link]
    if eff.get_node_type(ret) == node_type then
        return ret
    end
end

function eff.original_data()
    return caches
end

---comment
---@param link string
---@return table
function eff.get_namespace(link)
    return string.match(link, '^($$.+)%.([^%.]+)$')
end

---comment
---@param link string
---@param name string
---@return table
function eff.find_sibling(link, name)
    local target_link = eff.get_namespace(link)..'.'..name
    return eff.cache(target_link)
end

---comment
---@param ref_param EffectParam
---@param do_cache boolean
---@return CmdResult
---@return string?
function eff.validate(ref_param, do_cache)
    local cache=ref_param.cache
    if (not cache) then
        return e_cmd.NotSupported
    end
    local target
    if cache.TargetLocation and cache.TargetType then
        target = ref_param:parse_loc(cache.TargetLocation,cache.TargetType)
    else
        target = ref_param:main_target()
    end

    if(not target)then
        log.error('目标配置错误:'..ref_param:debuginfo()..'，请确认节点的目标配置是正确的。（比如效果目标原本是一个点，但却目标类型却设置成了单位就会出错）')
        return e_cmd.Error
    end
    local class_validator = base.ui_eff[cache.NodeType] and base.ui_eff[cache.NodeType].validate
    if(class_validator)then
        local result, info = class_validator(ref_param, do_cache)
        if result~=e_cmd.OK then
            return result, info
        end
    end
    return eff.execute_validators(cache.Validators, ref_param)
end

function eff.execute_validators(validators, ref_param, ...)
    if not validators then
        return e_cmd.OK
    end

    return validators(ref_param, ...)
end

---comment
---@param ref_param EffectParam
---@return CmdResult
local function execute_internal(ref_param)
        --特殊处理，缓存搜索结果
        local cache = ref_param.cache
        if (not cache) or (not base.ui_eff[cache.NodeType]) then
            log.error('不存在节点类型'.. (cache and cache.NodeType or cache or 'nil'))
            return e_cmd.NotSupported
        end

        ref_param:calc_target()

        local result, info = eff.validate(ref_param, true)
        ref_param.result = result
        if ref_param.result ~= e_cmd.OK then
            ref_param:logfail(result, info)
            return ref_param.result
        end
        if cache.Chance then
            local chance = cache.Chance(ref_param)
            if chance < 1 then
                if math.random() > chance then
                    return e_cmd.OK
                end
            end
        end
        --[[ To do: 行为拦截
        if cache.CanBeBlocked then
            ref_param:post_event('拦截测试')
            if(ref_param.nullified) then
                return e_cmd.OK
            end
        end ]]
        ref_param:post_event(e_sub_name.start)
        if ref_param.result~=e_cmd.OK then
            ref_param:logfail(ref_param.result)
            return ref_param.result
        end

        base.ui_eff[cache.NodeType].execute(ref_param)
        local target_unit = ref_param.target:get_unit()
        local caster_unit = ref_param:caster():get_unit()
        if caster_unit and caster_unit:is_valid() then
            caster_unit:on_response("ResponseEffectImpact", base.response.e_location.Attacker, ref_param)
        end
        if target_unit and target_unit:is_valid() then
            target_unit:on_response("ResponseEffectImpact", base.response.e_location.Defender, ref_param)
        end
        if caster_unit
        and caster_unit:is_valid()
        and target_unit
        and target_unit:is_valid()
        and cache.ResponseFlags
        and (cache.ResponseFlags.Acquire or cache.ResponseFlags.Flee) then
            target_unit:on_provoke(caster_unit, cache.ResponseFlags)
        end

        --将actor创建时机后延，使其能获取到效果节点创建的内容，如单位和弹道。

        local store = base.ui_eff[cache.NodeType].persist
        if store then
            ref_param.actors =  ref_param.actors or {}
        end
        local force_no_sync = not store
        if cache.ActorArray then
            for _, value in ipairs(cache.ActorArray) do
                local actor = ref_param:create_actor(value, nil, force_no_sync)
                if actor and store then
                    table.insert(ref_param.actors, actor)
                end
            end
        end


        ref_param:post_event(e_sub_name.activated)
        if log.log_eff_success then
            log_file.info(ref_param:debuginfo().." 执行成功");
        end
        if not base.ui_eff[cache.NodeType].persist or ref_param.stopped then
            ref_param:stop()
        end
        return e_cmd.OK
end
---comment
---@param ref_param EffectParam
---@return CmdResult
function eff.execute(ref_param)
    local result = execute_internal(ref_param)
    return result
end