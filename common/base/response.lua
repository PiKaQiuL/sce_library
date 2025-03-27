local base = base
local eff = base.eff
local e_cmd=eff.e_cmd

Response = base.tsc.__TS__Class()
Response.name = 'Response'

---@class Response
---@field is_responsing boolean
---@field owner Unit
---@field cache table
---@field link string
---@field location string
---@field it_target Target?
---@field ref_param EffectParam
---@field is_enabled boolean
---@field cooldown_timer? table
---@field remove fun(self)
base.response = Response.prototype
base.response.type = 'response'

base.response.e_location = {
    Attacker = 'Attacker',
    Defender = 'Defender',
}

---comment
---@param link string
---@return Response?
function base.response:new(link)
    local response = { is_responsing = false, is_enabled = true, }
    setmetatable(response, self)
    if response:set_cache(link) then
        return response
    end
    return nil
end

---comment
---@param link string
function base.response:set_cache(link)
    self.cache = eff.cache(link)
    if self.cache then
        self.link = link
        self.location = self.cache.Location
        return true
    end
    return false
end

---comment
---@param in_param EffectParam
function base.response:execute(in_param, ...)
    if self.is_responsing or not self.is_enabled or self.cooldown_timer then
        return
    end

    local cache = self.cache

    if not cache then
        return
    end

    self.is_responsing = true

    if not in_param then
        return
    end

    self.it_target = in_param:parse_loc(cache.ResponseTargetAtIncomingEffect)

    local chance = cache.Chance(self.ref_param)
    if chance < 1 then
        if math.random() > chance then
            self.is_responsing = false
            return
        end
    end

    self.ref_param.respond_args = self.ref_param.respond_args or {}
    self.ref_param.respond_args.eff_param = in_param

    if cache.NodeType == 'ResponseMissileImpact' then
        self.it_target = in_param.it_target or self.it_target
    end

    local target_unit = self.it_target:get_unit()
    if target_unit then
        ---@type TargetFilters Description
        local target_filter = base.target_filters:new(cache.TargetFilter)
        if target_filter:validate(self.ref_param:caster(), target_unit) ~= e_cmd.OK then
            self.is_responsing = false
            return
        end
    end

    local attacker = in_param:caster() and in_param:caster():get_unit()
    local defender = (in_param.it_target and in_param.it_target:get_unit()) or (in_param.target or in_param.target:get_unit())

    if cache.UnitLocalVarAttacker and #cache.UnitLocalVarAttacker > 0 then
        self.ref_param:set_var_unit(cache.UnitLocalVarAttacker, attacker)
    end

    if cache.UnitLocalVarAttacker and #cache.UnitLocalVarAttacker > 0 then
        self.ref_param:set_var_unit(cache.UnitLocalVarDefender, defender)
    end

    if cache.InComingEffectValidator then
        local result = eff.execute_validators(cache.InComingEffectValidator, in_param)
        if result ~= e_cmd.OK then
            self.is_responsing = false
            return
        end
    end

    if cache.Validator then
        local result
        if self[cache.NodeType].validate then
            result = self[cache.NodeType].validate(self, in_param, ...)
        else
            result = eff.execute_validators(cache.Validator, self.ref_param, in_param)
        end
        if result ~= e_cmd.OK then
            self.is_responsing = false
            return
        end
    end

    if self[cache.NodeType].exectue(self, in_param, ...) then
        self:start_cooldown()
        if cache and cache.ResponseActors and #cache.ResponseActors then
            for _, value in ipairs(cache.ResponseActors) do
                self.ref_param:create_actor(value, nil, true)
            end
        end
        if cache.ResponseEffect then
            self.ref_param:execute_child_on(cache.ResponseEffect, self.it_target)
        end
    end
    self.is_responsing = false
end

function base.response:response(...)
    log_file.debug('如果你执行到这里，就代表函数出错了,根响应该是抽象的，请使用实际有效的响应')
    return false
end


---comment
---@param a Response
---@param b Response
---@return boolean
local function response_compare(a, b)
    if not a or not b or not a.cache or not b.cache then
        return false
    end

    if a.cache.Priority == b.cache.Priority then
        return false
    end

    return a.cache.Priority > b.cache.Priority
end

---comment
---@param unit Unit
---@param ref_param EffectParam
function base.response:add(unit, ref_param)
    if unit then
        if not unit.response then
            unit.response = {}
        end

        if not unit.response[self.cache.NodeType] then
            unit.response[self.cache.NodeType] = {}
        end

        if not unit.response[self.cache.NodeType][self.location] then
            unit.response[self.cache.NodeType][self.location] = {}
        end

        local response_table = unit.response[self.cache.NodeType][self.location]

        table.insert(response_table, self)
        table.sort(response_table, response_compare)

        self.owner = unit
        if ref_param then
            self.ref_param = ref_param
        else
            self.ref_param = unit:get_creation_param()
        end
    end
end

function base.response:remove()
    if not self.owner then
        return
    end
    local response_table = self.owner.response[self.cache.NodeType][self.location]
    for i, it_response in ipairs(response_table) do
        if it_response == self then
            table.remove(response_table, i)
        end
    end
end

function base.response:enabled()
    self.is_enabled = true
end

function base.response:disabled()
    self.is_enabled = false
end

ResponseDamage = base.tsc.__TS__Class()
ResponseDamage.name = 'ResponseDamage'

---@class ResponseDamage:Response
---@field RemaningShield number
base.response.ResponseDamage = ResponseDamage.prototype

function base.response.ResponseDamage:validate(in_param, damage)
    local cache = self.cache
    return eff.execute_validators(cache.Validator, self.ref_param, in_param, damage.damage, damage.current_damage, damage)
end

---@param in_param EffectParam
---@param damage Damage
function base.response.ResponseDamage:exectue(in_param, damage)
    local cache = self.cache
    if not cache then
        return false
    end

    if not cache.DamageType[damage.damage_type] then
        return false
    end

    if cache.ResponseDamageFlags.Fatal and not damage.fatal then
        return false
    end

    if not cache.ResponseDamageFlags.Fatal and damage.fatal then
        return false
    end

    if damage.current_damage == 0 and not cache.ResponseDamageFlags.HandleNullifiedDamage then
        return false
    end

    if damage.damage == 0 and not cache.ResponseDamageFlags.HandleZeroDamage then
        return false
    end

    damage.current_damage = damage.current_damage + cache.Modification(self.ref_param, in_param, damage.damage, damage.current_damage, damage)
    damage.current_damage = damage.current_damage * cache.Multiplier(self.ref_param, in_param, damage.damage, damage.current_damage, damage)
    
    self.ref_param.respond_args.damage = damage

    if cache.ResponseDamageFlags.SetAsCrit then
        damage.crit_flag = true
    end
    return true
end

ResponseMissileImpact = base.tsc.__TS__Class()
ResponseMissileImpact.name = 'ResponseMissileImpact'

base.response.ResponseMissileImpact = ResponseMissileImpact.prototype

---@param in_param EffectParam
function base.response.ResponseMissileImpact:exectue(in_param)
    local cache = self.cache
    if not cache then
        return false
    end

    ---刻意判定0, 因为true和false都会销毁弹道。只有0不会
    if cache.Reflect ~= 0 and cache.Reflect ~= nil then
        local launch_point = in_param.missile:get_point()
        if #cache.temp_reflect_model > 0 and base.table.unit[cache.temp_reflect_model] then
            launch_point:create_effect(cache.temp_reflect_model)
        end
        in_param:missile_detach()
        ---目前设置为仅反射发射新建投射物单位的弹道，否则可能会把跳跃中的单位给干掉，有更好的方案，但目前暂且走这条最快路径
        if in_param.cache.Method ~= 'Exist' then
            in_param.missile:remove()
            if not in_param.reflected and self.it_target and cache.Reflect then
                local impact_point = in_param:origin():get_point()
                impact_point = launch_point:polar_to({launch_point:angle_to(impact_point), in_param.missile_data.missile_range})
                local target = impact_point
                local link = in_param.link
                local child_param=self.ref_param:create_child()
                child_param:init(self.ref_param.source,target)
                child_param.reflected = true
                child_param:set_cache(link)
                if(child_param.cache)then
                    eff.execute(child_param)
                end
            end
        end
    end

    return true
end

ResponseEffectImpact = base.tsc.__TS__Class()
ResponseEffectImpact.name = 'ResponseEffectImpact'

base.response.ResponseEffectImpact = ResponseEffectImpact.prototype

---@param in_param EffectParam
function base.response.ResponseEffectImpact:exectue(in_param)
    local cache = self.cache
    if not cache then
        return false
    end

    return in_param.link == cache.RequiredIncomingEffect
end

ResponseSpell = base.tsc.__TS__Class()
ResponseSpell.name = 'ResponseSpell'

base.response.ResponseSpell = ResponseSpell.prototype

---@param in_param EffectParam
---@param event string
---@param skill Skill
function base.response.ResponseSpell:exectue(in_param, event, skill)
    local cache = self.cache
    if not cache then
        return false
    end

    if event ~= cache.SpellEvent then
        return false
    end

    if skill and cache.AbilCategory and #cache.AbilCategory then
        ---@type TargetFilters
        local filter = base.target_filters:new(cache.AbilCategory)
        if skill:filter_categories(filter) then
            self.ref_param.respond_args.skill = skill
            return true
        end
    else
        self.ref_param.respond_args.skill = skill
        return true
    end

    return false
end

ResponseBuff = base.tsc.__TS__Class()
ResponseBuff.name = 'ResponseBuff'

base.response.ResponseBuff = ResponseBuff.prototype

---comment
---@param cache table
---@param category string
local function has_category(cache, category)
    local categories = cache and cache.Categories
    for _, value in pairs(categories) do
        if value == category then
            return true
        end
    end
    return false
end


---comment
---@param cache table
---@param category_filters TargetFilters
---@return boolean
local function filter_categories(cache, category_filters)
    if(category_filters.excluded)then
        for _, filter in ipairs(category_filters.excluded) do
            if has_category(cache, filter) then
                return false
            end
        end
    end
    if(category_filters.required)then
        for _, filter in ipairs(category_filters.required) do
            if not has_category(cache, filter) then
                return false
            end
        end
    end
    return true
end

---@param in_param EffectParam
---@param data table
function base.response.ResponseBuff:exectue(in_param, data)
    local cache = self.cache
    if not cache or not data then
        return false
    end

    local link = data.link

    local buff_cache = base.eff.cache(link)

    if not buff_cache then
        return
    end

    if cache.BuffCategory and #cache.BuffCategory then
        ---@type TargetFilters
        local filter = base.target_filters:new(cache.BuffCategory)
        if not filter_categories(buff_cache, filter) then
            return false
        end
    end

    data.prevent =  cache.Prevent

    if data.time and data.time > 0 then
        data.time = data.time + cache.Modification(self.ref_param)
        data.time = data.time * cache.Multiplier(self.ref_param)
    end

    return true
end

ResponseUnit = base.tsc.__TS__Class()
ResponseUnit.name = 'ResponseUnit'

base.response.ResponseUnit = ResponseUnit.prototype

---@param in_param EffectParam
---@param event string
function base.response.ResponseUnit:exectue(in_param, event)
    local cache = self.cache
    if not cache then
        return false
    end

    if event ~= cache.UnitEvent then
        return false
    end

    return true
end


function base.response:start_cooldown()
    local cache = self.cache
    if not cache then
        return false
    end
    local cd = cache.Cooldown and cache.Cooldown(self.ref_param)
    if not cd or cd <= 0 then
        return
    end
    cd = cd * 1000
    if self.cooldown_timer then
        if self.cooldown_timer:get_remaining_time() >= cd then
            return
        end
        self.cooldown_timer:remove()
    end
    self.cooldown_timer = base.wait(cd , function(timer)
        self.cooldown_timer = nil
        timer:remove()
    end)
end

return {
    Response = Response,
    ResponseDamage = ResponseDamage,
    ResponseMissileImpact = ResponseMissileImpact,
    ResponseEffectImpact = ResponseEffectImpact,
    ResponseSpell = ResponseSpell,
    ResponseBuff = ResponseBuff,
    ResponseUnit = ResponseUnit
}