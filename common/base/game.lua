

local key_state = {}
local joystick_state = {
    -- 按键状态不常驻，触发时置为 1
    -- 左右摇杆 ∈ [-1, 1]，+X 向右，+Y 向下
    ['LeftX'] = 0.0,
    ['LeftY'] = 0.0,
    ['RightX'] = 0.0,
    ['RightY'] = 0.0,
    -- Trigger <= 0.0 表示不触发
    ['TriggerLeft'] = 0.0,
    ['TriggerRight'] = 0.0,
    -- 十字键状态 = DPadUp | DPadRight<<1 | DPadDown<<2 | DPadLeft<<3
    ['DPad'] = 0,
}
local mouse_point = base.point()
local selected_unit
local loading_dead_line = 0.0
local FOCUS
local winner
local hotkey
local voice_room_id
local voice_start_time

local argv = require 'base.argv'

local key_map = {
    [' ']               = '',

    ['LeftControl']     = 'LeftCtrl',
    ['RightControl']    = 'RightCtrl',
    ['zero']            = '0',
    ['one']             = '1',
    ['two']             = '2',
    ['three']           = '3',
    ['four']            = '4',
    ['five']            = '5',
    ['six']             = '6',
    ['seven']           = '7',
    ['eight']           = '8',
    ['nine']            = '9',
    ['Semicolon']       = ';',
    ['Equals']          = '=',
    ['Comma']           = ',',
    ['Underscore']      = '_',
    ['Period']          = '.',
    ['Slash']           = '/',
    ['Tilde']           = '`',
    ['LeftBracket']     = '[',
    ['RightBracket']    = ']',
    ['Backslash']       = '\\',
    ['Quote']           = '\'',

    ['Escape']          = 'Escape',

    ['NumPadZero']      = 'Num 0',
    ['NumPadone']       = 'Num 1',
    ['NumPadtwo']       = 'Num 2',
    ['NumPadthree']     = 'Num 3',
    ['NumPadfour']      = 'Num 4',
    ['NumPadfive']      = 'Num 5',
    ['NumPadsix']       = 'Num 6',
    ['NumPadseven']     = 'Num 7',
    ['NumPadeight']     = 'Num 8',
    ['NumPadnine']      = 'Num 9',
    ['Add']             = 'Num +',
    ['Subtract']        = 'Num -',
    ['Multiply']        = 'Num *',
    ['Divide']          = 'Num /',
    ['Decimal']         = 'Num .',
}

local comfirm_enter_foreground_id = 0

function base.game:__tostring()
    return 'Game Instance (Client)'
end

---@type table<integer, string>
local scene_hash_map = {}
---@type table<string, integer>
local scene_name_map = {}
---@type table<number, string>
local scene_names = {}
local scene_map_inited = false

local function init_scene_name_map()
    if scene_map_inited then return end

    if __lua_state_name ~= 'StateEditor' then
        local lobby = require '@common.base.lobby'
        if lobby.vm_name() == 'StateGame' then
            scene_names = game.get_all_template_scene_name()
        end
    end

    for index, scene_name in ipairs(scene_names) do
        local hash = base.hash(scene_name)
        scene_hash_map[hash] = scene_name
        scene_name_map[scene_name] = hash
    end
    scene_map_inited = true
end

base.game:event('场景-加载', function(_, scene_name)
    local hash = base.hash(scene_name)

    scene_hash_map[hash] = scene_name
    scene_name_map[scene_name] = hash
end)

---@param hash integer
---@return string
function base.get_scene_name_by_hash(hash)
    init_scene_name_map()
    return scene_hash_map[hash]
end

---@param name string
---@return integer
function base.get_scene_hash_by_name(name)
    init_scene_name_map()
    return scene_name_map[name]
end

------------------------ 方法 ------------------------
function base.game:hotkey()
    if not hotkey then
        hotkey = game.get_hot_key_list()
        for _, keys in pairs(hotkey) do
            for k, v in pairs(keys) do
                keys[k] = key_map[v] or v
            end
        end
    end
    return hotkey
end

function base.game:key_state(key)
    if key_state[key] and key_state[key] > 0 then
        return true
    else
        return false
    end
end

function base.game:selected_unit()
    return selected_unit
end

function base.game:chat(type, msg)
    if type == '全体' then
        game.send_chat_message(msg, 0)
        return
    elseif type == '队伍' then
        game.send_chat_message(msg, 1)
        return
    end
    error(('错误的消息对象[%s]'):format(type), 2)
end

function base.game:show_timer()
    return game.get_display_time_signed()
end

function base.game:set_game_scene(...)

    return game.set_game_scene(...)
end

function base.game:get_current_scene()

    return game.get_current_scene()
end

function base.game:lock_camera()
    game.lock_camera()
end

function base.game:unlock_camera()
    game.unlock_camera()
end

function base.game:set_camera_attribute(key, value, time)
    game.set_camera_attribute({[key] = value, time = time})
end

function base.game:input_mouse()
    local x, y, z = game.get_location_under_cursor()
    mouse_point = base.point(x, y, z)
    return mouse_point
end

function base.game:loading_left()
    local left = loading_dead_line - os.clock()
    if left < 0.0 then
        return 0.0
    else
        return left
    end
end

function base.game:select_unit(unit)
    if unit and unit:is_visible() then
        game.unit_touch(unit._id)
    end
end

function base.game:circle_selector(pos, radius, tag, ignore_center_pos)
    ignore_center_pos = ignore_center_pos ~= false
    -- local x, y = pos:get_xy()
    local res = {}
    -- local target = game.circle_selector(x, y, radius, '', ignore_center_pos)

    if pos.scene_hash == nil then
        log_file.warn('坐标点缺少场景标识')
    end

    local target = game.circle_selector(pos[1], pos[2], pos[3], pos.scene_hash, radius, '', ignore_center_pos)
    if not tag or tag == '' then
        for _, id in ipairs(target) do
            local u = base.unit(id)
            res[#res+1] = u
        end
    else
        local of_tag = {}
        if type(tag) == 'string' then
            of_tag[tag] = true
        elseif type(tag) == 'table' then
            for _, v in ipairs(tag) do
                of_tag[v] = true
            end
        end
        for _, id in ipairs(target) do
            local u = base.unit(id)
            if of_tag[u:get_tag()] then
                res[#res+1] = u
            end
        end
    end

    return res
end

function base.game:line_selector(pos, length, width, face, tag)
    -- local px, py = pos:get_xy()
    local fx, fy = face:get_xy()
    local res = {}
    
    if pos.scene_hash == nil then
        log_file.warn('坐标点缺少场景标识')
    end

    -- local target = game.line_selector(px, py, length, width, fx, fy)
    local target = game.line_selector(pos[1], pos[2], pos[3], pos.scene_hash, length, width, fx, fy)
    if not tag or tag == '' then
        for _, id in ipairs(target) do
            local u = base.unit(id)
            res[#res+1] = u
        end
    else
        local of_tag = {}
        if type(tag) == 'string' then
            of_tag[tag] = true
        elseif type(tag) == 'table' then
            for _, v in ipairs(tag) do
                of_tag[v] = true
            end
        end
        for _, id in ipairs(target) do
            local u = base.unit(id)
            if of_tag[u:get_tag()] then
                res[#res+1] = u
            end
        end
    end
    return res
end

function base.game:sector_selector(pos, radius, degree, face, tag)
    -- local px, py = pos:get_xy()
    local fx, fy = face:get_xy()
    local res = {}
    
    if pos.scene_hash == nil then
        log_file.warn('坐标点缺少场景标识')
    end
    
    -- local target = game.sector_selector(px, py, radius, degree, fx, fy)
    local target = game.sector_selector(pos[1], pos[2], pos[3], pos.scene_hash, radius, degree, fx, fy)
    if not tag then
        for _, id in ipairs(target) do
            local u = base.unit(id)
            res[#res+1] = u
        end
    else
        local of_tag = {}
        if type(tag) == 'string' then
            of_tag[tag] = true
        elseif type(tag) == 'table' then
            for _, v in ipairs(tag) do
                of_tag[v] = true
            end
        end
        for _, id in ipairs(target) do
            local u = base.unit(id)
            if of_tag[u:get_tag()] then
                res[#res+1] = u
            end
        end
    end
    return res
end

function base.game:get_winner()
    return winner
end

function base.game:get_winner_team()
    local winner_player = base.player(winner)
    local team = winner_player:get_team_id()
    return base.team(team)
end

function base.game:send_broadcast(...)
    local args = {...}
    local json = ''
    if #args ~= 0 then
        json = base.json.encode(args)
    end
    common.send_broadcast(json)
end


function base.game:camera_focus(unit)
	game.camera_focus(unit and unit._id or 0)
end
base.game:event('输入框-获得焦点', function (_, ui)
    FOCUS = ui
end)

base.game:event('输入框-失去焦点', function ()
    FOCUS = nil
end)

base.__default_unit_cache = {}
base.__default_unit_co = {}

-- 客户端从服务器获取默认地编单位
-- 只能在协程中使用
function base.game.get_default_unit(node_mark)
    if not base.__default_unit_cache[node_mark] then
        base.game:server'__get_default_unit'{
            node_mark = node_mark,
        }

        -- 挂起当前协程等待服务器返回结果
        local current = coroutine.running()
        base.__default_unit_co[node_mark] = base.__default_unit_co[node_mark] or {}
        table.insert(base.__default_unit_co[node_mark], current)
        coroutine.yield()

        -- 返回结果了
        if base.__default_unit_cache[node_mark] then
            return base.__default_unit_cache[node_mark].unit
        else
            return nil
        end
    else
        return base.__default_unit_cache[node_mark].unit
    end
end

---comment
---@param object table
---@param key string
---@param value any
function base.game.object_store_value(object, key, value)
    local t = type(object)
    if ((t == "table") or (t == 'userdata')) and key then
        object.__hashtable = object.__hashtable or {}
        object.__hashtable[key] = value
        return
    end
end

function base.game.object_restore_value(object, key)
    local t = type(object)
    if ((t == "table") or (t == 'userdata')) and key and type(object.__hashtable) == 'table' then
        return object.__hashtable[key]
    end
end

---------------------------- 事件 -------------------------------

function base.event.on_spell_cast_result(msg)
    base.game:event_notify('消息-技能', msg)
end

function base.event.on_error_tip(msg, time)
    base.game:event_notify('消息-错误', msg, time)
end

function base.event.on_system_message(msg, type, time)
    if type == 1 then
        base.game:event_notify('消息-公告', msg, time / 1000.0)
    elseif type == 2 then
        base.game:event_notify('消息-聊天', msg, time / 1000.0)
    elseif type == 3 then
        base.game:event_notify('消息-错误', msg, time / 1000.0)
    end
end

function base.event.on_notify_chat_message(player_slot_id, type, msg, time)
    base.game:event_notify('消息-聊天', player_slot_id, type, msg, time)
end

function base.event.on_unit_clicked(id)
    local local_player = base.local_player()
    -- 因为可能没有选的单位，所以这只能发到base.game
    base.game:event_notify('单位-点击', local_player, id and base.unit(id))
    if id then
        if selected_unit then
            selected_unit:event_notify('单位-取消选中', local_player, selected_unit)
            base.game:server'__client_cancel_select_unit'{
                player_id = local_player._id,
                unit_id = selected_unit._id
            }
        end
        selected_unit = base.unit(id)
        if not selected_unit then
            return
        end
        selected_unit:event_notify('单位-选中', local_player, selected_unit)
        base.game:server'__client_select_unit'{
            player_id = local_player._id,
            unit_id = id
        }
    else
        if not selected_unit then
            return
        end
        selected_unit:event_notify('单位-取消选中', local_player, selected_unit)
        base.game:server'__client_cancel_select_unit'{
            player_id = local_player._id,
            unit_id = selected_unit._id
        }
        selected_unit = nil
    end
end

function base.event.on_control_spell_assist(control, spell_id, type, shape, range, width, plane_range, id)
    base.game:event_notify('技能指示器-控制', control, spell_id, type, shape, range, width, plane_range, id)
end
--[[
-- 由于 事件：技能指示器-更新 涵盖了移动的事件，所以暂时不需要这个东西了
function base.event.on_move_spell_assist()
    base.game:event_notify('技能指示器-移动')
end
]]

function base.event.on_spell_assist_update(spell_id , time, id)
    base.game:event_notify('技能指示器-更新' , spell_id , time, id)
end

function base.event.on_game_will_enter_foreground()
    comfirm_enter_foreground_id = comfirm_enter_foreground_id + 1
    local current_id = comfirm_enter_foreground_id
    base.game:event_notify('游戏即将进入前台', function()
        if current_id == comfirm_enter_foreground_id then
            game.comfirm_enter_foreground()
        end
    end, function()
        if current_id == comfirm_enter_foreground_id then
            game.cancel_enter_foreground()
        end
    end)
end

function base.event.on_game_enter_foreground()
    local module_key = common.get_value('Equipment_Game_Mode')
    base.game:event_notify('游戏进入前台', module_key)
end

function base.event.on_game_enter_background()
    base.game:event_notify('游戏进入后台')
end

function base.event.on_click(screen_pos, actorsID, button)
    base.game:event_notify('游戏-点击', screen_pos, actorsID, button)
end

local lua_state_name = __lua_state_name
local key_focus = {}
local function key_down(key)
    if FOCUS == nil then
        base.game:event_notify('按键-按下', key)
        if lua_state_name == 'StateGame' then --只在游戏中转发
            base.game:server'__client_key_down'{
                player_id = base.local_player()._id,
                key = key
            }
        end
    else
        key_focus[key] = FOCUS
        -- 这个没找到实现，不知道有什么用
        -- ui_events.on_key_down(FOCUS.id, key)
    end
end

local function key_up(key)
    local focus = key_focus[key]
    if focus then
        key_focus[key] = nil
        -- 这个没找到实现，不知道有什么用
        -- ui_events.on_key_up(focus.id, key)
    else
        base.game:event_notify('按键-松开', key)
        if lua_state_name == 'StateGame' then --只在游戏中转发
            base.game:server'__client_key_up'{
                player_id = base.local_player()._id,
                key = key
            }
        end
    end
end

local function update_key_state(key, count)
    key_state[key] = (key_state[key] or 0) + count
    if count > 0 then
        if key_state[key] == 1 then
            key_down(key)
        end
    else
        if key_state[key] == 0 then
            key_state[key] = nil
            key_up(key)
        end
    end
end

function base.event.on_key_down(unkey)
    local key = key_map[unkey] or unkey

    if key_state[key] then
        return
    end
    key_state[key] = 1
    key_down(key)
    if key == 'LeftCtrl' or key == 'RightCtrl' then
        update_key_state('Ctrl', 1)
    elseif key == 'LeftAlt' or key == 'RightAlt' then
        update_key_state('Alt', 1)
    elseif key == 'LeftShift' or key == 'RightShift' then
        update_key_state('Shift', 1)
    end
end

function base.event.on_key_up(unkey)
    local key = key_map[unkey] or unkey

    if not key_state[key] then
        return
    end
    key_state[key] = nil
    key_up(key)
    if key == 'LeftCtrl' or key == 'RightCtrl' then
        update_key_state('Ctrl', -1)
    elseif key == 'LeftAlt' or key == 'RightAlt' then
        update_key_state('Alt', -1)
    elseif key == 'LeftShift' or key == 'RightShift' then
        update_key_state('Shift', -1)
    end
end

function base.event.on_mouse_down(button_type)
    base.game:event_notify('鼠标-按下', button_type)
    if lua_state_name == 'StateGame' then --只在游戏中转发
        base.game:server'__client_mouse_down'{
            player_id = base.local_player()._id,
            key = button_type
        }
    end
end

function base.event.on_mouse_up(button_type)
    base.game:event_notify('鼠标-松开', button_type)
    if lua_state_name == 'StateGame' then --只在游戏中转发
        base.game:server'__client_mouse_up'{
            player_id = base.local_player()._id,
            key = button_type
        }
    end
end

function base.event.on_mouse_move()
    base.game:event_notify('鼠标-移动')
    -- if lua_state_name == 'StateGame' then --只在游戏中转发 --感觉服务器不需要这个
    --     base.game:server'__client_mouse_move'{
    --         player_id = base.local_player()._id,
    --     }
    -- end
end

function base.event.on_wheel_move(delta_wheel)
    base.game:event_notify('滚轮-移动', delta_wheel)
    if lua_state_name == 'StateGame' then --只在游戏中转发
        base.game:server'__client_wheel_move'{
            player_id = base.local_player()._id,
            delta_wheel = delta_wheel
        }
    end
end

function base.event.on_joystick_button_down(button_name)
    if joystick_state[button_name] then
        return
    end
    joystick_state[button_name] = 1
    base.game:event_notify('手柄-按键按下', button_name)
    -- if lua_state_name == 'StateGame' then --只在游戏中转发
    --     base.game:server('__client_joystick_button_down'){
    --         player_id = base.local_player()._id,
    --         button = button_name
    --     }
    -- end
end

function base.event.on_joystick_button_up(button_name)
    if not joystick_state[button_name] then
        return
    end
    joystick_state[button_name] = nil
    base.game:event_notify('手柄-按键松开', button_name)
    -- if lua_state_name == 'StateGame' then --只在游戏中转发
    --     base.game:server('__client_joystick_button_down'){
    --         player_id = base.local_player()._id,
    --         button = button_name
    --     }
    -- end
end

function base.event.on_joystick_axis_move(axis_name, position)
    joystick_state[axis_name] = position
    -- 处理时最好设置死区，避免过于灵敏
    if (string.byte(axis_name) == 76) then
        base.game:event_notify('手柄-摇杆', 'Left', joystick_state.LeftX, joystick_state.LeftY)
    elseif (string.byte(axis_name) == 82) then
        base.game:event_notify('手柄-摇杆', 'Right', joystick_state.RightX, joystick_state.RightY)
    else
        base.game:event_notify('手柄-扳机', axis_name, position)
    end
    -- if lua_state_name == 'StateGame' then --只在游戏中转发
    --     base.game:server('__client_joystick_axis_move'){
    --         player_id = base.local_player()._id,
    --         axis = axis_name,
    --         pisition = position
    --     }
    -- end
end

function base.event.on_joystick_hat_move(state)
    joystick_state['DPad'] = state
    -- 可以监听'手柄-按键按下'获得所有按键信息
    -- 但是监听'手柄-十字键'更方便
    base.game:event_notify('手柄-十字键', state)
end

function base.event.on_start_loading(time)
    loading_dead_line = os.clock() + time
end

function base.event.on_enter_game()
    base.game.event_notify'游戏-初始化'
    base.game:event_notify'游戏-开始'
    log_file.info("on_enter_game")
end

function base.event.on_replay_stopped()
    log_file.info('on_replay_stopped')
    if argv.has('sendlogwhenreplaystopped') then
        log_file.info('will upload log')
        local upload_log = require 'base.upload_log'
        log_file.info('will call upload log')
        upload_log('replaylog', function()
            common.exit()
        end)
    elseif argv.has('exit_after_replay') then
        common.exit()
    else
        local scelobby   = include 'base.lobby'
        scelobby.send_luastate_broadcast('退出', {})
    end
end

function base.event.on_game_result(json)
    local info = base.json.decode(json)
    winner = info.GameData.Winner
    base.game:event_notify('游戏-结束')
end

function base.event.on_load_scene(scene_name)
    base.game:event_notify('场景-加载', scene_name)
end

function base.event.on_load_scene_over(scene_name)
    base.game:event_notify('场景-加载完成', scene_name)
end


local dir_index = {
    ['top'] = 1,
    ['left'] = 2,
    ['bottom'] = 3,
    ['right'] = 4,
}
function base.event.on_combined_scene_area_notify(...)
    local args = {...}
    local from_scene = args[1]
    local from_dir = args[2]
    local to_scene = args[3]
    local to_dir = args[4]
    
    log_file.info('on_combined_scene_area_notify', from_scene, from_dir, to_scene, to_dir)
    local data = base.get_game_attribute('scene_surrounding_data') or {}

    if from_dir~='' and to_dir~='' then
        log_file.info('跨越区域', from_scene, from_dir, to_scene, to_dir)
        --base.game:event_notify('联合场景-区域通知', ...)
        base.game:event_notify('联合场景-跨越区域', from_scene, from_dir, to_scene, to_dir)
    else
        if from_dir == '' then
            local info = data[to_scene]
            local pin_scene = nil
            if info and info[dir_index[to_dir]] then
                pin_scene = info[dir_index[to_dir]]
            end
            log_file.info('进入边界', to_scene, to_dir, pin_scene)
            base.game:event_notify('联合场景-进入区域', to_scene, to_dir, pin_scene)
        elseif to_dir == '' then
            local info = data[to_scene]
            local pin_scene = nil
            if info and info[dir_index[from_dir]] then
                pin_scene = info[dir_index[from_dir]]
            end
            log_file.info('离开边界', from_scene, from_dir, pin_scene)
            base.game:event_notify('联合场景-离开区域', from_scene, from_dir, pin_scene)
        else
            log.error('联合场景-区域通知信息错误')
            for k,v in pairs( args) do
                log_file.info( ' ', k, v)
            end
        end
    end
    
    base.game:event_notify('联合场景-区域通知', ...)
end

function base.event.on_game_setting_changed()
    hotkey = nil
    base.game:event_notify('游戏-设置变化')
end

function base.event.on_create_riseletter_failed(riselettertype,templatename)
    if not templatename  or #templatename==0 then
        log_file.warn(string.format('创建飘浮文字失败，创建类型为%d',riselettertype))
        return
    end
    log_file.warn(string.format('创建飘浮文字失败，创建类型为%s',templatename))
end


-- function param: map_name, map_kind, session_id, background_loading
function base.event.on_game_start(...)
    base.game:event_notify('加载地图', ...)
end

function base.event.on_game_loading(content, percent)
    base.game:event_notify('加载地图进度', content, percent)
end

-- function param: map_name, map_kind, session_id, background_loading
function base.event.on_game_started(...)
    base.game:event_notify('加载地图完成', ...)
end

-- function param: map_name, map_kind, session_id, background_loading
function base.event.on_game_exit(map_name, map_kind, session_id, ...)
    log_file.info('game_exit', map_name, map_kind, session_id, voice_room_id, session_id == voice_room_id, sdk.exit_voice_room)
    if sdk.exit_voice_room and session_id == voice_room_id then
        common.send_user_stat('voice_duration', os.time() - voice_start_time)
        voice_room_id = nil
        sdk.exit_voice_room()
    end
    base.game:event_notify('卸载地图', map_name, map_kind, session_id, ...)
end

function base.event.on_game_kick(...)
    base.game:event_notify('游戏踢人', ...)
end

function base.event.on_game_reconnected(...)
    base.game:event_notify('游戏重连', ...)
end

function base.event.on_url_launch(map_name)
    base.game:event_notify('url启动游戏', map_name)
end

-- 监测文件夹是否变化
function base.event.on_file_changed(file_path, file_name, change_list)
    base.game:event_notify('file_changed', file_path, file_name, change_list)
end

function base.event.on_broadcast(args)
    if args ~= '' then
        local info = base.json.decode(args)
        base.game:event_notify('广播', table.unpack(info))
    else
        base.game:event_notify('广播')
    end
end

local game_attribute = {}

function base.event.on_sync_custom_game_attribute(key, value)
    log_file.info('test',key,value)

    game_attribute[key] = value
    base.game:event_notify("游戏-属性变化", key, value)
end

function base.get_game_attribute(key)
    return game_attribute[key]
end

function base.event.on_actor_event(actor_id, msg, anim, start)
    if anim == '' then
        base.game:event_notify('表现-音效事件', actor_id, msg)
    else
        if start then
            base.game:event_notify('表现-动画事件开始', actor_id, msg, anim)
        else
            base.game:event_notify('表现-动画事件结束', actor_id, msg, anim)
        end
    end
end

function base.event.on_game_time_pause()
    base.game:event_notify('游戏-时间暂停')
end

function base.event.on_game_time_resume()
    base.game:event_notify('游戏-时间继续')
end

function base.event.on_actor_destroy(actor_id)
    local actor_map = base.actor_info().actor_map
    if actor_map then
        local actor = actor_map[actor_id]
        if actor then
            actor:release()
        end
    end
end

function base.event.on_debug_cheat(cheat_codes)
    base.forward_event_register('玩家-输入作弊码')
    local local_player = base.local_player()
    base.game:event_notify('玩家-输入作弊码', local_player, cheat_codes)
end

function base.event.on_actor_finish_animation(actor_id, anim, operation)
    base.game:event_notify('表现-动画结束', actor_id, anim, operation)
end

function base.event.on_unit_finish_animation(unit_id, anim, operation)
    base.game:event_notify('单位-动画结束', unit_id, anim, operation)
end

function base.event.on_game_sync_unit_attribute_config(attribute_config)
    --log_file.info('on_game_sync_unit_attribute_config',attribute_config)
    for key, name in pairs(attribute_config) do
        --log_file.info('on_game_sync_unit_attribute_config :',key,name)
        base.add_attribute_key(name,key)
    end
end


base.next(function()
    local lobby = require 'base.lobby'
    local sdk = require 'base.sdk'
    if lobby.vm_name() == 'StateApplication' then
        lobby.register_event('进入语音房间', function(room_id)
            voice_room_id = tostring(room_id)
            voice_start_time = os.time()
            --common.send_user_stat('enter_voice_room', room_id)
        end)
    end


end)

function base.game:on_kick(msg)
    -- msg暂时没有，以后弹窗提示要换成msg内容
    local confirm = require 'base.confirm'
    local co = include '@common.base.co'
    co.async(function()
        if msg == '' or msg == nil then
            msg = '你被踢出游戏'
        end
        --踢人用正经字体
        confirm.set_font_family('Regular')
        confirm.message(msg)
        lobby.send_luastate_broadcast('退出', cmsg_pack.pack{
            show_confirm = false
        })
    end)
end

base.game:event('游戏踢人', function(_, map_name, map_kind, session_id, background_loading, msg)
    log_file.info('server_kick', msg)
    local lobby = require 'base.lobby'
    if lobby.vm_name() == 'StateGame' then
        log_file.info('收到 游戏踢人')
        base.game:on_kick(msg)
    end
end)


function base.game.create_debug_draw_actor()
    local result,id,_ = game.create_debug_draw_actor() 
    if result then
        local actor = setmetatable({
            _type = nil,
            _id = id,
            _slot_id = nil,
            _name = nil,
            _server_id = nil,
        }, { __index = Actor.prototype })
        base.set_actor_map(actor)
        return actor
    else
        return nil
    end
end

function base.game.debug_draw_point(actor, point, color)
    game.debug_draw_point(actor._id, point[1], point[2], point[3], color)
end

function base.game.debug_draw_circle(actor, point, euler_alpha, euler_beta, euler_gamma, radius, color, solid)
    game.debug_draw_circle(actor._id, point[1], point[2], point[3], euler_alpha, euler_beta, euler_gamma, radius, color, solid)
end

function base.game.debug_draw_line(actor, s_point, e_point, color)
    game.debug_draw_line(actor._id, s_point[1], s_point[2], s_point[3], e_point[1], e_point[2], e_point[3],color)    
end

function base.game.debug_draw_sector(actor, point, euler_alpha, euler_beta, euler_gamma, radius, angle, color, solid)
    game.debug_draw_sector(actor._id, point[1], point[2], point[3], euler_alpha, euler_beta, euler_gamma, radius, angle, color, solid)
end

function base.game.debug_draw_text(actor, point, text, color, displayTop)
    game.debug_draw_text(actor._id, point[1], point[2],point[3], text, color, displayTop)
end

function base.game.debug_draw_rectangle(actor, v_point, w_point, h_point, color, solid)
    game.debug_draw_rectangle(actor._id, v_point[1], v_point[2], v_point[3], w_point[1], w_point[2], w_point[3], h_point[1], h_point[2], h_point[3], color, solid)
end

function base.game.clear_debug_draws(actor)
    game.clear_debug_draws(actor._id)
end

function base.get_current_fps()
    return common.get_current_fps()
end

function base.get_current_ping()
    return common.get_current_ping()
end

function base.set_use_right_click_move(use)
    game.set_use_right_click_move(use)
end

function base.get_use_right_click_move()
    return game.get_use_right_click_move()
end

function base.raycast_unit_at_screen_xy(x, y)
    local res = {}
    local actors = game.get_actors_at_screen_xy(x, y) or {}
    for index, id in ipairs(actors) do
        if id > 0 then
            res.unit = base.unit(id)
            if res.unit then
                break
            end
        end
    end
    if not res.unit then
        res.x, res.y, res.z = game.screen_to_world(x, y)
    end
    return res
end

--获取矩形区域内的所有单位  返回单位数组
function base.get_units_from_rect(point, width, height, face)
    face = face or 0
    local radians = face * (math.pi / 180)
    local list = base.game:line_selector(point, width, height, base.point(math.cos(radians), math.sin(radians), 0))
    return list
end

--获取扇形区域内的所有单位  返回单位数组
function base.get_units_from_sector(point,radius,arc,face)
    local radians = face * (math.pi / 180)
    local list = base.game:sector_selector(point, radius, arc,base.point(math.cos(radians),math.sin(radians)))
    return list
end


--显示拼接场景
function base.game.load_combined_map( scene, direction)
    game.load_combined_map( scene, direction)
end

--释放拼接场景
function base.game.purge_combined_map()
    game.purge_combined_map()
end

--创建拼接场景通行模型
function base.game.load_combined_map_deco( scene, direction)
    game.load_combined_map_deco( scene, direction)
end

--释放拼接场景通行模型
function base.game.purge_combined_map_deco()
    game.purge_combined_map_deco()
end

function base.game.load_scene_cache_and_combined( scene, direction)
    game.load_map_to_cache(scene, false, function()
        game.load_combined_map( scene, direction)
    end)
end

AnimPointInfo = base.tsc.__TS__Class()
function AnimPointInfo.prototype.____constructor(self, tbl)
    setmetatable(self, {__index = tbl})
end

-- 给触发用的api，用ts类包了一层
function base.game.get_model_anim_point_info(model_path, anim_name)
    local tbl = game.get_model_anim_point_info(model_path, anim_name)
    if tbl then
        return base.tsc.__TS__ObjectAssign(base.tsc.__TS__New(AnimPointInfo, { tbl }), {})
    end
    return nil
end

---@description 数编所有物品
---@return table
function base.get_obj_items()
    local datas = require ('@'..__MAIN_MAP__..'.obj.effect.item.data')
    local items = {}
    for key, value in pairs(datas) do
        table.insert(items, key .. '.root')
    end
    return items
end

---@description 获取所有技能ID
---@return table
function base.get_all_skills_id()
    local result = {}
    for id,_ in pairs(base.table.skill) do
        table.insert(result, id)
    end
    return result
end

---@description 获取所有buff表ID
---@return table
function base.get_all_buffs_id()
    local result = {}
    for id,_ in pairs(base.table.buff) do
        table.insert(result, id)
    end
    return result
end

---@description 获取所有单位ID
---@return table
function base.get_all_units_id()
    local result = {}
    for id,_ in pairs(base.table.unit) do
        table.insert(result, id)
    end
    return result
end

-- 创建游戏快捷方式
function base.game_shortcut()
    local platform = require'@common.base.platform'
    platform.create_shortcut()
end

--- @description Luatable的浅拷贝
--- @param tbl table
--- @return table
function base.shallow_copy(tbl)
    local result = {}
    for k, v in pairs(tbl) do
        result[k] = v
    end
    return result
end

function base.set_cursor_shape(path)
    common.set_cursor_shape('name', path)
    common.set_use_system_cursor(false)
end

function base.use_system_cursor()
    common.set_use_system_cursor(true)
end

function base.get_ground_z(x, y, bool)
    return game.get_ground_z(x, y, bool)
end

--- @param point Point
function base.get_ground_z_from_point(point, bool)
    return game.get_ground_z(point[1], point[2], bool)
end

local function init_gameplay()
    local default_gameplay_id = "$$.gameplay.dflt.root"
    local gameplay = base.eff.cache(default_gameplay_id)
    if gameplay and gameplay.CustomUnitAttribute then
        for attribute, link in pairs(gameplay.CustomUnitAttribute) do
            local eff = base.eff.cache(link)
            if eff then
                if eff.Format then
                    base.gameplay_custom_attribute_format = base.gameplay_custom_attribute_format or {}
                    base.gameplay_custom_attribute_format[attribute] = eff.Format
                end
            end
        end
    end
end
base.next(function()
    if base.eff.cache_init_finished() then
        init_gameplay()
    else
        base.game:event('Src-PostCacheInit', function()
            init_gameplay()
        end)
    end
end)

function base.get_platform()
    local platform = require 'base.platform'
    local res = ''
    if platform.is_win() then
        res = 'win'
    end
    if platform.is_web() then -- 包含下面的web 会覆盖
        res = 'web'
    end
    if platform.is_web_pc() then
        res = 'web_pc'
    end
    if platform.is_web_mobile() then
        res = 'web_mobile'
    end
    if platform.is_web_ios() then
        res = 'web_ios'
    end
    if platform.is_web_android() then
        res = 'web_android'
    end
    if platform.is_wx() then -- 包含下面的wx 会覆盖
        res = 'wx'
    end
    if platform.is_wx_ios() then
        res = 'wx_ios'
    end
    if platform.is_wx_android() then
        res = 'wx_android'
    end
    if platform.is_wx_devtool() then
        res = 'wx_devtool'
    end
    if platform.is_qq() then -- 包含下面的qq 会覆盖
        res = 'qq'
    end
    if platform.is_qq_ios() then
        res = 'qq_ios'
    end
    if platform.is_qq_android() then
        res = 'qq_android'
    end
    if platform.is_qq_devtool() then
        res = 'qq_devtool'
    end
    if platform.is_android() then
        res = 'is_android'
    end
    return res
end

function base.get_platform_is_app()
    local platform = require 'base.platform'
    return platform.is_app()
end

function base.start_game(map_name, is_to_test)
    local url = "'start-game://"..map_name
    if is_to_test then
        url = url.."&tag=test"
    end
    url = url.."'"
    common.open_url(url)
end