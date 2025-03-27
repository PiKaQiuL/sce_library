--- lua_plus ---
function base.game_exit(show_confirm:boolean)
    ---@ui 退出游戏（显示确认框：~1~）
    ---@description 退出游戏
    ---@applicable action
    ---@belong game
    ---@keyword 退出
    ---@arg1 false
    lobby.send_luastate_broadcast('退出', cmsg_pack.pack{ show_confirm = show_confirm })
end

function base.game_get_mouse_pos_x(touch_id:integer) integer
    ---@ui 鼠标~1~在屏幕上的坐标X
    ---@description 鼠标在屏幕上的坐标X
    ---@applicable value
    ---@belong game
    ---@keyword 鼠标 X
    local x, y = common.get_mouse_screen_pos(touch_id)
    return x
end

function base.game_get_mouse_pos_y(touch_id:integer) integer
    ---@ui 鼠标~1~在屏幕上的坐标Y
    ---@description 鼠标在屏幕上的坐标Y
    ---@applicable value
    ---@belong game
    ---@keyword 鼠标 y
    local x, y = common.get_mouse_screen_pos(touch_id)
    return y
end

function base.game_screen_to_world(screen_x:integer, screen_y:integer) point
    ---@ui 屏幕坐标~1~,~2~对应的场景坐标
    ---@description 通过屏幕坐标XY获取场景坐标
    ---@applicable value
    ---@belong game
    ---@keyword 屏幕 xy
    ---@arg1 base.game_get_mouse_pos_x()
    ---@arg2 base.game_get_mouse_pos_y()
    local x, y, z= game.screen_to_world(screen_x, screen_y)
    return base.point(x, y, z)
end

function base.game_world_to_screen_x(point:point) integer
    ---@ui 场景坐标~1~对应的屏幕坐标X
    ---@description 场景坐标对应的屏幕坐标X
    ---@applicable value
    ---@belong game
    ---@keyword 屏幕 xy
    local x, y = game.world_to_screen(point)
    return x
end

function base.game_world_to_screen_y(point:point) integer
    ---@ui 场景坐标~1~对应的屏幕坐标Y
    ---@description 场景坐标对应的屏幕坐标Y
    ---@applicable value
    ---@belong game
    ---@keyword 屏幕 xy
    local x, y = game.world_to_screen(point)
    return y
end

function base.game_get_resolution_width() integer
    ---@ui 获取画面分辨率宽度
    ---@description 获取画面分辨率宽度
    ---@applicable value
    ---@belong game
    ---@keyword 分辨率 宽度
    local width, height = base.screen:get_resolution()
    return width
end

function base.game_get_resolution_height() integer
    ---@ui 获取画面分辨率高度
    ---@description 获取画面分辨率高度
    ---@applicable value
    ---@belong game
    ---@keyword 分辨率 高度
    local width, height = base.screen:get_resolution()
    return height
end

function base.game_set_resolution(width:integer, height:integer)
    ---@ui 设置画面分辨率为(~1~, ~2~)
    ---@description 设置画面分辨率
    ---@applicable action
    ---@belong game
    ---@keyword 设置 分辨率
    base.screen:set_resolution(width, height)
end

function base.game_get_orientation() string
    ---@ui 获取屏幕方向
    ---@description 获取屏幕方向
    ---@applicable action
    ---@belong game
    ---@keyword 设置 分辨率

    --现在是string，以后也许要改成enum
    return base.screen:get_orientation()
end

function base.client_send_message(msg:string)
    ---@ui 向服务端发送消息：~1~
    ---@description 向服务端发送消息
    ---@keyword 服务端 消息
    ---@belong game
    ---@applicable action
    ---@name1 消息
    local player_id = base.local_player()._id
    base.game:server'__client_send_message'{
        msg = msg,
        player_id = player_id
    }
end

function base.use_light_group(path:string, time:number)
    ---@ui 切换到光照组：~1~，混合时间为~2~秒。
    ---@description 切换光照组
    ---@keyword 光照
    ---@belong game
    ---@applicable action
    ---@name1 光照
    ---@name2 混合时间
    ---@arg1 'Atmosphere/光照名.lightgroup'
    ---@arg2 2
    game.use_light_group(game.get_map_path()..'/'..path, time)
end

function base.get_current_scene() 场景
    ---@ui 当前场景
    ---@description 获取当前场景
    ---@keyword 场景
    ---@belong game
    ---@applicable value
    return base.game:get_current_scene()
end

function base.get_gamemode_key() string
    ---@ui 获取游戏模式
    ---@description 获取游戏模式
    ---@keyword 游戏模式
    ---@belong game
    ---@applicable value
    local gamemodestr = 'GameMode'
    local gamemode = base.get_game_attribute(gamemodestr)
    if gamemode == nil then
        return ""
    else
        return gamemode
    end
end

function base.load_map_to_cache(scene:场景)
    ---@ui 添加场景缓存~1~
    ---@description 添加场景缓存
    ---@keyword 场景
    ---@belong game
    ---@applicable action
    game.load_map_to_cache(scene)
end

function base.purge_map_from_cache(scene:场景)
    ---@ui 删除场景缓存~1~
    ---@description 删除场景缓存
    ---@keyword 场景
    ---@belong game
    ---@applicable action
    game.purge_map_from_cache(scene)
end