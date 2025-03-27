local result = base.ui.panel{
    show = false,
    static = true,
    layout = {
        height = 250,
        width = 600,
        col_self = 'center',
        row_self = 'center',
    },
    bind = {
        show = 'show',
    },
    image="image/结束界面/底板_矩形_低透明.png",
    color = '#aaaaaa',
    base.ui.label{
        --image="image/按钮_激活.png",
        layout = {
            grow_width = 1,
            grow_height = 0.5,
            col_self = 'start',
            row_self = 'start',
        },
        font = {
            size = 60,
            color = '#ffffff',
        },
        text = '游戏结束',
    },
    base.ui.label{
        image="image/结束界面/按钮_激活.png",
        --图片像素123*33
        --active_color = 'rgba(255,255,255,0.8)',
        --hover_color = 'rgba(125,125,125,0.8)',
        layout = {
            height = 33*2,
            width = 123*2,
            col_self = 'end',
            row_self = 'center',
            relative = {0, -40},
        },

        font = {
            size = 30,
            color = '#666666',
        },
        text = "确定",
        bind = {
            color = 'color',
            font = {
                color = 'font_color',
            },
            event = {
                on_click = 'on_click',
                on_mouse_enter='on_mouse_enter', --鼠标进入
                on_mouse_leave='on_mouse_leave', --鼠标离开
            },
        },
    },

}

local ui,bind=base.ui.create(result, "玩家游戏结束")
bind.on_mouse_enter=function()
    bind.color="rgba(125,125,125,0.8)"
    bind.font_color="#ffffff"
end
bind.on_mouse_leave=function()
    bind.color='rgba(255,255,255,0.8)'
    bind.font_color="#666666"
end
bind.on_click = function()
    local lobby = require '@common.base.lobby'
    lobby.send_luastate_broadcast('退出', {})
end

local function get_camera_display_position()
	local current_camera = game.get_camera()
	local position = current_camera.position
	local x, y, z = position[1], position[2], position[3]
	local rotation = current_camera.rotation
	local pitch, row, roll = rotation[1], rotation[2], rotation[3]
	local distance = current_camera.focus_distance - 800
	local pi = math.pi
	log_file.info('get camera display position', pitch, math.sin(pitch/180*pi), math.cos(pitch/180*pi), current_camera.focus_distance)
	return x - (math.cos(pitch/180*pi) * distance), y - 350, 0 - (math.sin(pitch/180*pi) * distance)
end

base.proto.default_game_result = function(data)
	common.set_bloodstrip_canvas_visible(false)
	base.wait(1000, function()
		game.lock_camera()
		local actor_name = "$$.actor.胜利特效.root"
		if data.result ~= 'win' then
			actor_name = "$$.actor.失败特效.root"
		end
		local actor = base.actor(actor_name)
		actor:set_position(get_camera_display_position())
		actor:play()

		base.wait(2000, function()
			-- actor:destroy()·
			local over_bind = base.ui.bind["玩家游戏结束"]
			over_bind.show = true
		end)
	end)
end

base.proto.lobby_game_exit = function(data)
	local show_confirm = data.show_confirm
    lobby.send_luastate_broadcast('退出', cmsg_pack.pack{
        show_confirm = show_confirm
    })
end

base.proto.__one_more_round = function(data)
	base.game:send_broadcast('one_more_round',data)
end

base.game.one_more_round = function()
	base.game:server '__one_more_round' {}
end