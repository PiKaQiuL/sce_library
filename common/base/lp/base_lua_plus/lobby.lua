--- lua_plus ---
function base.open_friend_info_page(player:player)
    ---@ui 打开玩家~1~个人资料面板
    ---@description 打开玩家个人资料面板
    ---@applicable action
    ---@belong lobby
    ---@keyword 游戏大厅 个人资料
    if player_check(player) then
        local lobby = require'@common.base.lobby'
        local map_name, map_kind, session_id = lobby.get_lobby_map_info()
        if and(map_name, map_kind, session_id) then
            lobby.game_enter_foreground(map_name, map_kind, session_id)
            lobby.send_luastate_broadcast('lobby_open_api', {
                api = 'open_ui',
                params = {
                    type = 'PageFriendInfo',
                    data = player._user_id
                }
            })
        end
    end
end

function base.return_to_lobby()
    ---@ui 打开玩家~1~个人资料面板
    ---@description 打开玩家个人资料面板
    ---@applicable action
    ---@belong lobby
    ---@keyword 游戏大厅 个人资料
    local lobby = require '@common.base.lobby'
    lobby.return_to_lobby()
end