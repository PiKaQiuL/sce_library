local lni = require 'lni'

local name_map = {
    skill    = 'SpellData',
    unit     = 'UnitData',
    actor    = 'ActorData',
    buff     = 'ClientBuff',
    constant = 'Constant',
    item     = 'ItemData',
    attack   = 'CommonSpellData',
    sound    = 'ActorSoundData',
    model    = 'ActorModelData',
    lightning= 'Lightning',
    config   = '../config',
    map      = 'MapInfo',
    spell    = 'ClientSpell',
}

local function SDBMHash(str)
    local hash = 0
    for _, b in ipairs {string.byte(str, 1, #str)} do
        hash = b + (hash << 6) + (hash << 16) - hash
    end
    return hash & 0xfffffff
end

local table_init = {}
base.table = setmetatable({}, {
    __index = function (self, name)
        local suc
        local res
        if (table_init[name] == nil) then
            table_init[name] = true
            log_file.debug(('初始化表[%s]...'):format(name))
            if not game then return {} end
            suc, res = xpcall(game.get_game_table, log.error, name_map[name] or name)
            if not suc or not res then
                res = {}
                log.error(('初始化表[%s]失败！'):format(name))
            else
                log_file.debug(('初始化表[%s]完成！'):format(name))
            end
            --ClientSpell及SpellData特殊处理，其中SpellData在客户端中分别被存了两处（skill和SpellData）
            if (name == name_map.skill or name == 'skill') then
                log_file.debug('尝试为数编加载spell_data')
                local success, effect_root = xpcall(require, function(str)
                    log.error('数编加载spell_data失败\n', str)
                end, '@@.obj.spell.spell_data')
                if (success == true) then
                    log_file.debug('成功为数编加载spell_data')
                    for key, value in pairs(effect_root) do
                        res[key] = value
                    end
                end
            elseif (name == name_map.spell) then
                log_file.debug('尝试为数编加载client_spell')
                local success, effect_root = xpcall(require, function(str)
                    log.error('数编加载client_spell失败\n', str)
                end, '@@.obj.spell.client_spell')
                if (success == true) then
                    log_file.debug('成功为数编加载client_spell')
                    for key, value in pairs(effect_root) do
                        res[key] = value
                    end
                end
            elseif (name == name_map.buff or name == 'buff') then
                log_file.debug('尝试为数编加载client_buff')
                local success, effect_root = xpcall(require, function(str)
                    log.error('数编加载client_buff失败\n', str)
                end, '@@.obj.buff.buff')
                if (success == true) then
                    log_file.debug('成功为数编加载client_buff')
                    for key, value in pairs(effect_root) do
                        res[key] = value
                    end
                end
            elseif (name == name_map.unit or name == 'unit') then
                log_file.debug('尝试为数编加载unit_data')
                local success, effect_root = xpcall(require, function(str)
                    log.error('数编加载unit_data失败\n', str)
                end, '@@.obj.unit.unit')
                if (success == true) then
                    log_file.debug('成功为数编加载unit_data')
                    for key, value in pairs(effect_root) do
                        res[key] = value
                    end
                    local names = {}
                    local used = {}
                    for unit_name, data in pairs(res) do
                        local id = data.UnitTypeID
                        if id == nil then
                            names[#names+1] = unit_name
                        else
                            used[id] = true
                        end
                    end
                    table.sort(names)
                    for _, unit_name in ipairs(names) do
                        local id = SDBMHash(unit_name)
                        if used[id] then
                            for i = id+1, id+1000000 do
                                if not used[i] then
                                    id = i
                                    break
                                end
                            end
                        end
                        used[id] = true
                        res[unit_name].UnitTypeID = id
                    end
                end
            elseif (name == name_map.actor or name == 'actor') then
                log_file.debug('尝试为数编加载actor')
                local success, effect_root = xpcall(require, function(str)
                    log.error('数编加载actor失败\n', str)
                end,'@@.obj.actor.actor')
                if (success == true) then
                    log_file.debug('actor')
                    for key, value in pairs(effect_root) do
                        res[key] = value
                    end
                end
            elseif (name == name_map.model or name == 'actormodel') then
                log_file.debug('尝试为数编加载actormodel')
                local success, effect_root = xpcall(require, function(str)
                    log.error('数编加载actormodel失败\n', str)
                end,'@@.obj.model.model')
                if (success == true) then
                    log_file.debug('model')
                    for key, value in pairs(effect_root) do
                        res[key] = value
                    end
                end
            elseif (name == name_map.sound or name == 'actorsound') then
                log_file.debug('尝试为数编加载actorsound')
                local success, effect_root = xpcall(require, function(str)
                    log.error('数编加载actorsound失败\n', str)
                end,'@@.obj.sound.sound')
                if (success == true) then
                    log_file.debug('sound')
                    for key, value in pairs(effect_root) do
                        res[key] = value
                    end
                end
            elseif (name == 'Camera') then
                log_file.debug('尝试为数编加载camera')
                local success, effect_root = xpcall(require, function(str)
                    log.error('数编加载camera失败\n', str)
                end,'@@.obj.camera_property.camera_property')
                if (success == true) then
                    log_file.debug('camera_property')
                    for key, value in pairs(effect_root) do
                        res[key] = value
                    end
                end
            elseif (name == 'spellassisant') then
                log_file.debug('尝试为数编加载目标指示器')
                local success, effect_root = xpcall(require, function(str)
                    log.error('数编加载目标指示器失败\n', str)
                end, '@@.obj.target_indicator.target_indicator')
                if (success == true) then
                    log_file.debug('target_indicator')
                    for key, value in pairs(effect_root) do
                        res[key] = value
                    end
                end
            end
            self[name] = res
        else
            res = self[name]
        end
        return res
    end,
})

function base.skill_table(name, level, key)
    if not base.table.skill[name] then
        return nil
    end
    local values = base.skill[name][key]
    if not values then
        return nil
    end
    local value = values[level]
    return value
end

function base.unit_table(name, key)
    local data = base.table.unit[name]
    if not data then
        return nil
    end
    local value
    local tp = type(key)
    if tp == 'string' then
        value = data[key]
    elseif tp == 'table' then
        for _, key in ipairs(key) do
            value = value[key]
            if value == nil then
                return nil
            end
        end
    end
    return value
end

function base.buff_table(name, key)
    local data = base.table.buff[name]
    if not data then
        return nil
    end
    local value = data[key]
    if value == nil then
        return nil
    end
    return value
end

function base.attack_table(name, key)
    local data = base.table.attack[name]
    if not data then
        return nil
    end
    local value
    local tp = type(key)
    if tp == 'string' then
        value = data[key]
    elseif tp == 'table' then
        for _, key in ipairs(key) do
            value = value[key]
            if value == nil then
                return nil
            end
        end
    end
    return value
end

function base.item_table(name, key)
    local data = base.table.item[name]
    if not data then
        return nil
    end
    local value = data[key]
    if value == nil then
        return nil
    end
    return value
end


function base.spell_table(name, key)
    if not base.table.spell[name] then
        return nil
    end
    local value = base.table.spell[name][key]
    if not value then
        return nil
    end
    return value
end