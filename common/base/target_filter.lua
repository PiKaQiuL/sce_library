local base=base

TargetFilters = TargetFilters or base.tsc.__TS__Class()
TargetFilters.name = 'TargetFilters'

base.target_filters = TargetFilters.prototype
base.target_filters.type = 'target_filters'

---@class TargetFilters
---@field required string[]
---@field excluded string[]
local mt=base.target_filters

local e_cmd=base.eff.e_cmd

base.target_filters.filters={
    ['自身'] = 0,
    ['同一玩家'] = 1,
    ['盟友'] = 2,
    ['中立'] = 3,  --TODO:中立的概念
    ['敌方'] = 4,
    ['可见'] = 5,
    ['镜像'] = 6,
    player_marks = 6,
    ['无敌'] = 7,
    ['魔免'] = 8,
    ['物免'] = 9,
    ['缴械'] = 10,
    ['定身'] = 11,
    ['免死'] = 12,
    ['失控'] = 13,
    ['蝗虫'] = 14,
    ['召唤'] = 15, --TODO:召唤必须是一个可变概念
    ['死亡'] = 16,
    state_marks = 16,
    ['单位'] = 17,
    ['英雄'] = 18,
    ['小兵'] = 19,
    ['首领'] = 20,
    ['建筑'] = 21,
    ['防御塔'] = 22,
    ['基地'] = 23,
    ['图腾'] = 24,
    ['物品'] = 25,
    ['弹道'] = 26,
}

local e_filter=base.target_filters.filters

---comment
---@param filter_string string
---@return TargetFilters
function mt:new(filter_string)
    filter_string = filter_string or ';'
    local filters={}
    local rt=base.split(filter_string,';')
    --特殊处理，';敌方'这样的情况应该分割为''和'敌方'
    if #rt == 1 and string.sub(filter_string, 1, 1)==';' then
        rt[2] = rt[1]
        rt[1] = ''
    end
    if(rt[1] and #rt[1] > 0)then
        filters.required={}
        local subs=base.split(rt[1],',')
        for _, sub in ipairs(subs) do
            table.insert(filters.required,sub)
        end
    end
    if(rt[2] and #rt[2] > 0)then
        filters.excluded={}
        local subs=base.split(rt[2],',')
        for _, sub in ipairs(subs) do
            table.insert(filters.excluded,sub)
        end
    end
    setmetatable(filters, self)
    return filters
end

function mt:from_string(filter_string)
    return self:new(filter_string)
end

function mt:from_data_field(filter_string)
    return self:new(filter_string)
end


function mt.make_cmd_result(filter, is_required)
    if(is_required)then
        return e_cmd.MustTargetCertainUnit, '必须以'..filter..'单位为目标'
    else
         return e_cmd.CannotTargetCertainUnit, '无法以'..filter..'单位为目标'
    end
end

---comment
---@param self TargetFilters
---@param caster Target
---@param target Unit
---@return CmdResult result
---@return string? ErrorText
function mt:validate(caster,target)
    if target.type~='unit' then
        return e_cmd.MustTargetUnit
    end
    if(self.excluded)then
        for _, filter in ipairs(self.excluded) do
            if(self.has_filter(caster, target, filter) == true)then
                return self.make_cmd_result(filter, false)
            end
        end
    end

    if(self.required)then
        for _, filter in ipairs(self.required) do
            if(self.has_filter(caster, target, filter) == false)then
                return self.make_cmd_result(filter, true)
            end
        end
    end

    return e_cmd.OK
end

---comment
---@param caster Target
---@param target Unit
---@param filter string
---@return boolean
function mt.filter_player(caster, target, filter)
    if(filter == '自身')then
        return caster == target
    end

    if(filter == '同一玩家')then
        return caster:get_owner() ==  target:get_owner()
    end

    if(filter == '盟友')then
        return caster:get_owner():is_ally(target:get_owner())
    end

    if(filter == '敌方')then
        return caster:get_owner():is_enemy(target:get_owner())
    end

    if(filter == '中立')then
        return caster:get_owner():is_neutral_to(target:get_owner())
    end

    if(filter == '可见')then
        return target:is_visible() -- 客户端认为都是可见
    end

    if(filter == '镜像')then
        return nil -- 客户端不知道
    end

    return false
end

---comment
---@param target Unit
---@param filter string
---@return boolean
function mt.filter_state(target,filter)
    if filter == '死亡' then
        return not target:is_alive() -- TODO: 客户端存活判断
    end
    return target:has_restriction(filter)
end

---comment
---@param target Target
---@param label string
---@return boolean
function mt.filter_label(target,label)
    return target:has_label(label)
end

local function is_custom_restruction(att)
    if not base.table.constant['单位状态'] then
        return false
    end
    -- 预设单位状态/标记有24种
    -- 序号大于24的单位状态为自定义状态
    if base.table.constant['单位状态'][att] and base.table.constant['单位状态'][att] > 24 then
        return true
    end
    return false
end

function mt.has_filter(caster,target,filter)
    if is_custom_restruction(filter) then
        return (target:get('sys_unit_mark_ex') or 0) & (1 << base.table.constant['单位状态'][filter]) > 0
    end

    if(not e_filter[filter])then
        return mt.filter_label(target, filter)
    end

    --玩家属性
    if(e_filter[filter]<=e_filter.player_marks)then
        return mt.filter_player(caster, target, filter)
    end

    --动态标记
    if(e_filter[filter]<=e_filter.state_marks)then
        return mt.filter_state(target, filter)
    end

    --静态标记
    return mt.filter_label(target, filter)
end
