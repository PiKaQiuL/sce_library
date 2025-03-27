--- lua_plus ---
function base.skill_get_attribute(skill:skill, attr:string) number
    ---@ui 技能~1~的~2~属性值
    ---@belong skill
    ---@description 技能的自定义属性值
    ---@keyword 属性
    ---@applicable value
    if skill_check(skill) then
        return skill:get(attr)
    end
end

function base.skill_get_level(skill:skill) integer
    ---@ui 技能~1~的等级
    ---@belong skill
    ---@description 技能的等级
    ---@keyword 等级
    ---@applicable value
    if skill_check(skill) then
        return skill:get_level()
    end
end

function base.skill_get_owner(skill:skill) unit
    ---@ui 技能~1~的拥有者
    ---@belong skill
    ---@description 技能的拥有者
    ---@keyword 拥有者
    ---@applicable value
    if skill_check(skill) then
        return skill:get_owner()
    end
end

function base.skill_get_name(skill:skill) skill_id
    ---@ui 技能~1~的Id
    ---@belong skill
    ---@description 技能的Id
    ---@keyword Id
    ---@applicable value
    if skill_check(skill) then
        return skill:get_name()
    end
end

function base.unit_find_skill_by_name(unit:unit, id:skill_id, include_level_zero:是否) skill
    ---@ui ~1~的一个~2~技能（包含等级为0的技能：~3~）
    ---@description 单位身上一个指定Id的技能
    ---@applicable value
    ---@keyword 获取 Id
    ---@belong unit
    ---@arg1 base.player_get_hero(base.player_local())
    ---@arg3 是否.否
    ---@name1 单位
    ---@name2 技能Id
    ---@name3 是否
    
    if unit_check(unit) then
        return unit:find_skill(id, include_level_zero)
    end
end

function base.unit_find_skill_by_slot(unit:unit, slot:number) skill
    ---@ui ~1~身上槽位~2~的技能
    ---@description 单位身上指定槽位的技能
    ---@applicable value
    ---@keyword 获取 槽位
    ---@belong unit
    ---@arg1 e.unit
    ---@arg2 1
    ---@name1 单位
    ---@name2 槽位
    
    if unit_check(unit) then
        return unit:find_skill(slot, '英雄')
    end
end

function base.skill_get_tip(skill:skill) string
    ---@ui 技能~1~的提示信息
    ---@belong skill
    ---@description 技能的提示信息
    ---@keyword 提示信息
    ---@applicable value
    if skill_check(skill) then
        return skill:get_tip()
    end
end