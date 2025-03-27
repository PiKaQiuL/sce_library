--- lua_plus ---
function base.player_local() player
    ---@ui 客户端本地玩家
    ---@description 获取客户端本地玩家
    ---@applicable value
    ---@belong player
    ---@keyword 玩家 本地
    return base.local_player()
end

function base.player_game_state(player:player) 玩家游戏状态
    ---@ui ~1~的游戏状态
    ---@arg1 base.player(1)
    ---@description 玩家的游戏状态
    ---@keyword 游戏状态
    ---@belong player
    ---@applicable value
    ---@name1 玩家
    if player_check(player) then
        return player:game_state()
    end
end

function base.player_get_attribute(player:player, state:玩家属性) number
    ---@ui ~1~的~2~属性
    ---@arg1 base.player(1)
    ---@description 玩家的属性
    ---@keyword 属性
    ---@belong player
    ---@applicable value
    ---@name1 玩家
    ---@name2 玩家属性
    ---@arg2 玩家属性[人口上限]
    if player_check(player) then
        return player:get(state)
    end
end

function base.player_get_hero(player:player) unit
    ---@ui ~1~的主控单位
    ---@arg1 base.player(1)
    ---@description 玩家的主控单位
    ---@keyword 主控单位
    ---@belong player
    ---@applicable value
    ---@name1 玩家
    if player_check(player) then
        return player:get_hero()
    end
end

function base.player_get_slot_id(player:player) integer
    ---@ui ~1~的槽位Id
    ---@arg1 base.player(1)
    ---@description 玩家的槽位Id
    ---@keyword 槽位
    ---@belong player
    ---@applicable value
    ---@name1 玩家
    if player_check(player) then
        return player:get_slot_id()
    end
end