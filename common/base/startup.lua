
base.startup = {}


local callback_list = {}
local startup_modules = {}

function base.startup.register_pre_enter_foreground_callback(callback)
    callback_list[#callback_list + 1] = callback
end

function base.startup.register_startup_function(check_is_startup, startup_dialog)
    startup_modules[#startup_modules + 1] = {check_is_startup = check_is_startup, startup_dialog = startup_dialog}
end


local startup_module_list = {}
local function check_is_startup()
	startup_module_list = {}
	for i=1,#startup_modules do
		local m = startup_modules[i]
		if m and m.check_is_startup and m.check_is_startup() then
			startup_module_list[#startup_module_list + 1] = m
		end
	end
	return #startup_module_list > 0
end

local function startup_dialog()
	local function startup_dialog_func(index)
		if index > #startup_module_list then
			local lobby = require '@common.base.lobby'
			lobby.return_to_lobby()
			return
		end
		if startup_module_list[index] and startup_module_list[index].startup_dialog then
			startup_module_list[index].startup_dialog(function()
				startup_dialog_func(index + 1)
			end)
		else
			startup_dialog_func(index + 1)
		end
	end
	startup_dialog_func(1)
end

callback_list[#callback_list + 1] = function(confirm, cancel)
    local Game_Mode = common.get_value('Equipment_Game_Mode')
    if Game_Mode and Game_Mode ~= ""  then
        if Game_Mode == 'startup_dialog' then
            --不知道为什么之前能获取到的数据得延迟一帧才能获取到了 2024.7.18
            base.next(function()
                if check_is_startup() then
                    log_file.info('有自动弹窗，confirm')
                    confirm()
                else
                    log_file.info('没有自动弹窗，cancel')
                    cancel()
                end
            end)
        else
            log_file.info('是预加载，confirm')
            confirm()
        end
    else
        log_file.info('Game_Mode是空，cancel')
        if cancel then cancel() end
    end
end


base.game:event('游戏即将进入前台', function(_, confirm, cancel)
    local data = game.get_game_info();
    log_file.info("游戏即将进入前台, map_kind", data.map_kind)
    if data.map_kind and data.map_kind==2 then
        local callback_count = #callback_list
        local done_count = 0
    
        local function _confirm()
            done_count = done_count + 1
            if done_count >= callback_count then
                confirm()
            end
            local lobby = require '@common.base.lobby'
            lobby.send_luastate_broadcast('load_equipment_map_success' , {})
        end
    
        local function _cancel()
            cancel()
            local lobby = require '@common.base.lobby'
            lobby.send_luastate_broadcast('load_equipment_map_success' , {})
        end
    
        for _, callback in ipairs(callback_list) do
            callback(_confirm, _cancel)
        end
    end
end)

base.game:event('游戏进入前台', function()
    local data = game.get_game_info();
	-- 大厅跳大厅data是nil
	if not data then
		return
	end
    log_file.info("游戏进入前台, map_kind", data.map_kind)
    if data.map_kind and data.map_kind==2 then
        local Game_Mode = common.get_value('Equipment_Game_Mode');
        log_file.info('游戏进入前台',Game_Mode)
        if Game_Mode == "startup_dialog" then	--拼错了，但是将错就错
            startup_dialog()
        end
    end
end)