
--[[
    local lobby = require 'base.lobby'
    local co = require 'base.co'

    -- 注册事件
    lobby.register_event('加入房间', function(user_id)
        logger.info('用户' .. user .. '加入房间!')
    end)

    -- 调用接口
    lobby.create_team(map_name, room_name, player_count, function(error_code, room_id)
        if error_code == 0 then
            -- 成功
        else
            -- 失败
        end
    end)
]]

local platform      = require 'base.platform'
local web           = require 'base.web'
local json          = require 'json'
local argv = require 'base.argv'
include 'base.localization' 
local co = include 'base.co' 
local dialog = require 'base.confirm'

local table_insert = table.insert
local table_unpack = table.unpack
local string_gsub = string.gsub

local events = {}
local once_events = {}

local event_handle = {}

local game_tag = argv.get('tag')
if common.has_arg('game_tag') then
    game_tag = common.get_argv('game_tag')
end
log.info('lobby game_tag: ', game_tag)

function event_handle:remove()
    local event_list = events[self.name]
    if event_list then
        event_list[self.index] = false
    end
end

event_handle.__index = event_handle

local lua_state_name = __lua_state_name
local function vm_name()
    return lua_state_name  -- 两种, StateGame, StateApplication
end

local function new_handle(name, index)
    return setmetatable({name = name, index = index}, event_handle)
end

local function register(name, callback)
    if not events[name] then events[name] = {} end
    local event_list = events[name]
    event_list[#event_list + 1] = callback
    return new_handle(name, #event_list)
end

local function register_once(name, callback)
    local obj = register(name, callback)
    local event_list = events[name]
    once_events[name .. #event_list] = true
    return obj
end

local function dispatch(name, ...)
    if not events[name] then
        --log.warn('没有注册 ' .. name .. ' 事件')
        return
    end
    for index, callback in ipairs(events[name]) do
        if callback then
            callback(...)
        end
        if once_events[name .. index] then
            once_events[name .. index] = false
            events[name][index] = false
        end
    end
end


-- C++ 层面会来这个全局的table里找回调
_G.lobby_events = _G.lobby_events or {}

-- function param: error_code, map_name, map_kind, session_id, background_loading
lobby_events.on_start_game_notify = function(...)
    log.info('开始游戏')
    dispatch('开始游戏', ...)
end

lobby_events.on_game_connected = function()
    log.info('建立游戏连接')
    dispatch('建立游戏连接')
end

lobby_events.on_game_disconnected = function()
    log.info('断开游戏连接')
    dispatch('断开游戏连接')
end

lobby_events.on_game_connect_failed = function()
    log.info('游戏连接失败')
    dispatch('游戏连接失败')
end

lobby_events.on_game_login_error = function(error_code)
    log.info(('游戏登录异常 error_code: %s'):format(error_code))
    dispatch('游戏登录异常', error_code)
end

lobby_events.on_join_team_notify = function(user_id)
    log.info(('加入队伍, user_id: %s'):format(user_id))
    dispatch('加入队伍', user_id)
end

lobby_events.on_leave_team_notify = function(user_id, is_kicked)
    log.info('离开队伍, user_id: %s, is_kicked: %s', user_id, is_kicked)
    dispatch('离开队伍', user_id, is_kicked)
end

lobby_events.on_user_tag_notify = function(count,tags)
    log.info('收到usertag信息%d,%s',count,tags)
    for key, value in pairs(tags) do
        log.info('收到usertag信息key :%s,value :%s',key,value)
    end
    dispatch('收到usertag信息', count, tags)
end


lobby_events.on_team_invited_notify = function(from, invite_key, team_custom_data, invite_custom_data)
    log.info('收到队伍邀请')
    dispatch('收到队伍邀请', from, invite_key, team_custom_data, invite_custom_data)
end

local match_status_change_callbacks = {
    start = function(params)
        log.info('开始匹配, 操作者: %s, 地图: %s', params.operator_user_id, params.map_name)
        dispatch('开始匹配', params)
    end,
    failed = function(error_code)
        log.info(('匹配失败: error_ode: %s'):format(error_code))
        dispatch('匹配失败', error_code)
    end,
    cancelled = function()
        log.info('取消匹配')
        dispatch('取消匹配')
    end,
    success = function()
        log.info('匹配成功')
        dispatch('匹配成功')
    end,
}

lobby_events.on_match_info_changed_notify = function(event, ...)
    log.info('收到匹配状态通知')
    local cb = match_status_change_callbacks[event]
    if cb then
        cb(...)
    end
end

lobby_events.on_team_current_status_notify = function(params)
    log.info('收到队伍状态通知')
    dispatch('收到队伍状态通知', params)
end

lobby_events.on_team_master_changed_notify = function(params)
    log.info('收到队长更换通知')
    dispatch('收到队长更换通知', params)
end

local requests = {}

lobby_events.on_can_reconnect_response = function(request_id, error_code, map_info_list)
    log.info('是否可以重连返回 ', request_id, error_code, map_info_list)
    if requests[request_id] then
        requests[request_id](error_code, map_info_list)
    end
end

lobby_events.on_reconnect_response = function(request_id, error_code)
    log.info('重连返回', request_id, error_code)
    if requests[request_id] then
        requests[request_id](error_code)
    end
end

lobby_events.on_cancel_reconnect_response = function(request_id, error_code)
    log.info('取消重连返回', request_id, error_code)
    if requests[request_id] then
        requests[request_id](error_code)
    end
end

lobby_events.on_create_team_response = function(request_id, error_code, team_id)
    log.info('创建队伍返回', request_id, error_code, team_id)
    if requests[request_id] then
        requests[request_id](error_code, team_id)
    end
end

lobby_events.on_join_team_response = function(request_id, error_code)
    log.info('加入队伍返回', request_id, error_code)
    if requests[request_id] then
        requests[request_id](error_code)
    end
end

lobby_events.on_modify_team_info_response = function(request_id, error_code, is_private, team_custom_data)
    log.info('队伍自定义数据改变', is_private)
    if requests[request_id] then
        requests[request_id](error_code, is_private, team_custom_data)
    end
end

lobby_events.on_team_info_response = function(request_id, team_info)
    log.info('查询队伍数据返回', request_id)
    if requests[request_id] then
        requests[request_id](team_info)
    end
end

lobby_events.on_leave_team_response = function(request_id, error_code)
    log.info('离开队伍返回', request_id, error_code)
    if requests[request_id] then
        requests[request_id](error_code)
    end
end

lobby_events.on_start_match_response = function(request_id, error_code)
    log.info('匹配返回', request_id, error_code)
    if requests[request_id] then
        requests[request_id](error_code)
    end
end

lobby_events.on_team_start_game_response = function(request_id, error_code)
    log.info('组队开局返回', request_id, error_code)
    if requests[request_id] then
        requests[request_id](error_code)
    end
end

lobby_events.on_cancel_match_response = function(request_id, error_code)
    log.info('取消匹配返回', request_id, error_code)
    if requests[request_id] then
        requests[request_id](error_code)
    end
end

lobby_events.on_join_team_notify = function(request_id, error_code)
    log.info('加入队伍通知', request_id, error_code)
    if requests[request_id] then
        requests[request_id](error_code)
    end
    dispatch('加入队伍', request_id)
end

lobby_events.on_team_invite_response = function(request_id, error_code, agree)
    log.info('邀请返回', request_id, error_code, agree)
    if requests[request_id] then
        requests[request_id](error_code, agree)
    end
end

lobby_events.on_accept_invite_response = function(request_id, error_code, room, users)
    log.info('接受邀请返回', request_id, error_code, base.json.encode(room), base.json.encode(users))
    if requests[request_id] then
        requests[request_id](error_code, room, users)
    end
end

lobby_events.on_team_kick_user_response = function (request_id, error_code)
    log.info('请求队伍踢人返回', request_id, error_code)
    if requests[request_id] then
        requests[request_id](error_code)
    end
end

lobby_events.on_join_middle_game_response = function (request_id, error_code)
    log.info('加入中途局返回', request_id, error_code)
    if requests[request_id] then
        requests[request_id](error_code)
    end
end

lobby_events.on_user_current_status_response = function(request_id, params)
    log.info('玩家当前信息返回', request_id)
    local error_code = 0  -- 永不失败
    if(requests[request_id]) then
        requests[request_id](error_code, params)
    end
end

lobby_events.on_world_id_response = function(request_id, error_code, world_id, remote_path)
    log.info('申请world_id信息返回', request_id, error_code, world_id, remote_path)
    if(requests[request_id]) then
        requests[request_id](error_code, world_id, remote_path)
    end
end

lobby_events.on_prewarm_world_response = function(request_id, error_code, remote_path)
    log.info('预热世界返回', request_id, error_code, remote_path)
    if(requests[request_id]) then
        requests[request_id](error_code, remote_path)
    end
end

lobby_events.on_world_finish_response = function(request_id, error_code)
    log.info('删除世界返回', request_id, error_code)
    if(requests[request_id]) then
        requests[request_id](error_code)
    end
end

lobby_events.on_other_user_state_response = function(request_id, user_state_list)
    log.info('玩家当前信息返回', request_id)
    local error_code = 0  -- 永不失败
    if(requests[request_id]) then
        for i = 1, #user_state_list do
            local s = user_state_list[i]
            local j = json.decode(s)    -- 里面的元素类似这样: {"gaming":"promotion", "matching":"mover_td", "login_id":"12343"}
            user_state_list[i] = j  -- 将原本的string改成json
        end
        requests[request_id](error_code, user_state_list)
    end
end

lobby_events.on_team_list_response = function(request_id, team_list)
    if(requests[request_id]) then
        requests[request_id](team_list)
    end
end

lobby_events.on_did_enter_foreground = function()
    log.info('进入前台')
    dispatch('进入前台')
end

lobby_events.on_luastate_notify = function(key, data_str)
    log.info(('on_luastate_notify, key[%s], #data_str[%d]'):format(key, #data_str))
    local data = cmsg_pack.unpack(data_str)

    dispatch('luaState广播', key, data)
end

lobby_events.on_sync_user_game_status_notify = function(user_id, game_type, session_id)
    -- 只考虑team就行了
    log.debug('收到本队人员游戏状态更新', user_id, game_type, session_id)
    dispatch('收到本队人员游戏状态更新', user_id, game_type, session_id)
end

lobby_events.on_sync_user_match_status_notify = function(user_id, matching)
    -- 只考虑team就行了
    log.debug('收到本队人员匹配状态更新', user_id, matching)
    dispatch('收到本队人员匹配状态更新', user_id, matching)
end

lobby_events.on_lobby_game_inactive = function()
    dispatch('大厅局失活')
end

lobby_events.on_game_status_tips = function(visible, tips_type)
    dispatch('游戏状态提示', visible, tips_type)
end

lobby_events.on_simple_loading_panel_visible = function(visible)
    --dispatch('简单加载界面可见性', visible)
end

lobby_events.on_host_login_response_failed = function(...)
    log.warn('收到登录host失败的返回', ...)
    dispatch('游戏服登录失败', ...)
end

local luaState_events = {}
register('luaState广播', function(name, ...)
    log.debug(('luaState广播, name: %s'):format(name))
    if not luaState_events[name] then
        return
    end
    for _, callback in ipairs(luaState_events[name]) do
        if callback then
            callback(...)
        end
    end
end)
local register_luaState_event = function(name, callback)
    log.debug(('register_luaState_event: %s'):format(name))
    if not luaState_events[name] then luaState_events[name] = {} end
    local event_list = luaState_events[name]
    event_list[#event_list + 1] = callback
end

local function send_luastate_broadcast(key, data)
    local data_str = cmsg_pack.pack(data)
    lobby.send_luastate_broadcast(key, data_str)
end

local function return_to_lobby()
    log.info('return_to_lobby:',debug.traceback())
    lobby.return_to_lobby()
end

local function dispatch_all_vm(name, ...) 
    dispatch(name, ...)
    send_luastate_broadcast('dispatch_all_vm', {name = name , args = {...}})
end

register_luaState_event('dispatch_all_vm', function(data) 
    dispatch(data.name, table.unpack(data.args))
end)

local app_lua = {
    __index = function(t, k)
        return function( ...)
            local args = {...}
            log.info(k)
            for i, v in ipairs(args) do
                log.info(i, v)
                if type(v) == 'function' then
                    rawset(t, '__cb__'..tostring(i), v)
                    args[i] = {__cb__= i}
                end
            end
            for i, v in ipairs(args) do
                log.info(i, v)
            end
            send_luastate_broadcast('lua_vm_rpc', {name = k, args = args})
        end
    end,
    __newindex = function(t, k, v)
        if vm_name() == 'StateApplication' then
            log.info('reg vm rpc', k)
            rawset(t, k, v)
        end
    end
}

setmetatable(app_lua, app_lua)


register_luaState_event('lua_vm_rpc', function(call) 
    if type(rawget(app_lua, call.name)) == 'function' then
        log.info(call.name)
        local args = call.args
        for i, v in ipairs(args) do
            log.info(i, v)
            if type(v) == 'table' and v.__cb__ then
                args[i] = function(...) 
                    app_lua['__cb__'..i](...)
                end
            end
        end
        co.async(function()
            app_lua[call.name](table.unpack(call.args))
        end)
    else
        log.info('not found ', call.name, 'maybe not in this vm')
    end
end)

--[[ 这个定义放到script的lobby里
app_lua.play_custom_ad = function(cb) 
    local component = require '@del_common.base.gui.component'
    local template = component {
        base.ui.panel {
            layout = {
                grow_width = 1,
                grow_height = 1,
            },
            swallow_event = true,
            color = 'rgba(0, 0, 0, 0.7)',
            base.ui.panel {
                layout = {
                    grow_width = 0.8,
                    grow_height = 0.8,
                    direction = 'col',
                },
                round_corner_radius = 8,
                static = false,
                color = '#2A2D3C',
                base.ui.panel{
                    layout = {
                        grow_width = 1,
                        height = 24 * 1.5,
                    },
                    base.ui.label {
                        z_index = 99999,
                        layout = {
                            width = 24 * 1.5,
                            height = 24 * 1.5,
                            margin = 4,
                            row_self = 'start',
                            col_self = 'start',
                        },
                        bind = {
                            text = 'remain_secs'
                        },
                    },
                    base.ui.label {
                        text = '跳过',
                        layout = { 
                            row_self = 'end',
                            width = 24 * 1.5,
                            height = 24 * 1.5,
                            margin = 5 
                        },
                        show = false,
                        --image = 'image/close.png',
                        bind = {
                            show = 'show_skip',
                            event = {
                                on_click = 'click_close',
                            },
                        },
                    },

                },
                base.ui.webview {
                    layout = {
                        grow_width = 1,
                        grow_height = 1,
                    },
                    bind = {
                        url = 'url',
                        html = 'html',
                        event = {
                            on_web_message = 'on_web_message',
                        }
                    }
                },

                base.ui.panel {
                    layout = {
                        grow_width = 1,
                        height = 24 * 1.5,
                    },
                    base.ui.label {
                        layout = { 
                            row_self = 'end',
                            margin = 5 
                        },
                        text = '游戏详情>>',
                        bind = {
                            event = {
                                on_click = 'on_open_detail'
                            }
                        }
                    }
                }

            }
        }
    }

    local ui = template:new()

    local jump_link = {
        promotion2 = 'https://www.taptap.cn/craft/29',
        endlesscorridors = 'https://www.taptap.cn/craft/25',
        demo_s18a = 'https://www.taptap.cn/craft/37',
    }

    local filtered = {}
    for k, v in pairs(jump_link) do
        log.info(k, v)
        if k ~= argv.get('game') then
            log.info('add', k, v)
            filtered[#filtered + 1] = {
                name = k,
                link = v
            }
        end
    end
    local t = os.time()
    local h = #filtered
    local idx = (t%h) + 1
    log.info(t, h, idx)
    local ad_source = filtered[idx]
    ui.bind.html = '<video autoplay width="100%" height="100%"  webkit-playsinline playsinline controlsList="noplaybackrate nodownload nofullscreen noremoteplayback" disablePictureInPicture="true" muted style="object-fit:fill"> <source src="https://custom-ad.spark.xd.com/MP4/'..ad_source.name .. '.mp4" type="video/mp4"/>'
    --ui.bind.html = '<button type="button">click</button> <script> document.querySelector("button").addEventListener("click",()=>{ window.scelua.send_string("hello scelua")})</script>'
    local closed = false 
    local time_secs = 60

    ui.bind.on_open_detail = function() 
        common.open_url(ad_source.link)
    end
    ui.bind.click_close = function() 
        closed = true
        ui:destroy()
        cb({result = true, msg = 'skip', is_custom=true})
    end
    ui.bind.remain_secs = time_secs
    co.async(function()
        while time_secs > 0 do
            co.sleep(1000)
            time_secs = time_secs - 1
            ui.bind.remain_secs = time_secs

            if time_secs <= 30 then
                ui.bind.show_skip = true
            end
        end
        if not closed then
            ui:destroy()
            cb({result=true, msg='finish', is_custom=true})
        end
    end)
end]]

local function start_game()
    log.info('请求开始游戏')
    lobby.request_start_game()
end

local function can_reconnect(timeout, callback)
    local request = lobby.request_can_reconnect(timeout)
    log.info('请求是否可以重连', request, '超时时间', timeout)
    requests[request] = callback
end

--连上entrance时，延迟一下去查询lobby状态，如果存在还没释放的entrance-host连接,会下发一个通知这时候不用去连接
local function has_old_session(timeout, callback)
    local timeout = base.wait(timeout, function()
        callback(lobby.has_old_session())
    end)
end

local function reconnect(map_type, map_name, session_id, timeout, callback)
    local request = lobby.request_reconnect(map_type, map_name, session_id, timeout)
    log.info('请求重连', request, '超时时间', timeout)
    requests[request] = callback
end

local function cancel_reconnect(map_type, map_name, session_id, timeout, callback)
    local request = lobby.request_cancel_reconnect(map_type, map_name, session_id, timeout)
    log.info('请求取消重连', request)
    requests[request] = callback
end

local function create_team(max_count, custom_data, is_private, password, callback)
    local request = lobby.request_create_team(max_count, custom_data, is_private, password)
    log.info('请求创建房间', request, max_count, is_private)
    requests[request] = callback
end

local function leave_team(callback)
    local request = lobby.request_leave_team()
    log.info('请求离开房间', request)
    requests[request] = callback
end

local function start_match(params, callback)
    if game_tag and game_tag ~= '' then
        params.tag = game_tag
    end
    local request = lobby.request_start_match(params)
    log.info('请求匹配', request, params.map_name, fmt('region: %s', params.region_list and params.region_list[1] or 'none'))
    requests[request] = callback
end

local function team_start_game(params, callback)
    if game_tag and game_tag ~= '' then
        params.tag = game_tag
    end
    local request = lobby.request_team_start_game(params)
    log.info('请求组队开局', request, params.map_name, fmt('region: %s', params.region_list and params.region_list[1] or 'none'))
    requests[request] = callback
end

local function cancel_match(callback)
    local request = lobby.request_cancel_match()
    log.info('请求取消匹配', request)
    requests[request] = callback
end

local function team_invite(user_id, invite_custom_data, callback)
    local request = lobby.request_team_invite(user_id, invite_custom_data)
    log.info('请求队伍邀请', request, user_id)
    requests[request] = callback
end

local function team_invite_v2(params, callback)
    local li = {params.user_id, params.invite_custom_data}
    if params.timeout then
        table_insert(li, params.timeout)
    end

    local request = lobby.request_team_invite(table_unpack(li))
    log.info('请求队伍邀请v2', request, params.user_id, params.timeout)
    requests[request] = callback
end

local function accept_invite(from, agree, password, callback)
    local request = lobby.request_accept_invite(from, agree, password)
    log.info('请求接受邀请', request, from, agree)
    requests[request] = callback
end

local function team_join(target_user_id, team_id, password, callback)
    local request = lobby.request_team_join(target_user_id, team_id, password)
    log.info('请求加入队伍', request, target_user_id, team_id)
    requests[request] = callback
end

local function team_kick_user(user_id, callback)
    local request = lobby.request_team_kick_user(user_id)
    log.info('请求踢出队伍用户', request, user_id)
    requests[request] = callback
end

local function modify_team_info(team_custom_data, is_private, password, callback)
    local request = lobby.modify_team_info(team_custom_data, is_private, password)
    log.info('请求修改组队数据', request)
    requests[request] = callback
end

local function request_team_info(team_id, callback)
    local request = lobby.request_team_info(team_id)
    log.info('请求组队数据', request, team_id)
    requests[request] = callback
end

local function join_middle_game(args, callback)
    args.mode_args = args.mode_args or {}
    if game_tag and game_tag ~= '' then
        args.tag = game_tag
    end
    if not args.region_list then
        if common.GetRegionSelect then
            local region = common.GetRegionSelect("single")  -- lobby都是单人局
            args.region_list = {region}
        else
            args.region_list = {}
        end
    end
    local request = lobby.request_join_middle_game(args)
    log.info('请求加入中途局', request, args.map_name, fmt('region: %s', args.region_list[1]))
    requests[request] = callback
end

local function quick_start_game(args, callback)
    args.is_quick_start = true
    return join_middle_game(args, callback)
end

local function request_world_id(map_name, world_type, world_id, env, callback)
    local request = lobby.request_world_id(map_name, world_type, world_id, env)
    log.info('请求world_id', map_name, world_type, world_id, env, request)
    requests[request] = callback
end

local function prewarm_world(world_id, env, region, callback)
    local request = lobby.prewarm_world(world_id, env, region)
    log.info('预热世界', world_id, env, region, request)
    requests[request] = callback
end

local function finish_world(map_name, world_type, world_id, callback)
    local request = lobby.finish_world(map_name, world_type, world_id)
    log.info('结束删除世界', map_name, world_type, world_id, request)
    requests[request] = callback
end

local function user_current_status(callback)
    local request = lobby.request_user_current_status()
    log.info('请求玩家Lobby状态', request)
    requests[request] = callback
end

local function request_team_list(params,callback)
    local request = lobby.request_team_list(params)
    requests[request] = callback
end

local function is_sdk()
    if platform.is_web() then
        return web.is_sdk()
    elseif platform.is_wx() or platform.is_qq() then
        return true
    else
        return lobby.is_sdk()
    end
end

local function request_sdk_login()
    if platform.is_web() then
        local token = web.get_token()
        local sdk = web.get_sdk()
        log.info('sdk', sdk)
        local type = web.get_sdk_type(sdk)
        local token = web.get_token() .. '&sdk=' .. type .. '&map=' .. LOBBY_MAP
        local output = 'current sdk :' .. sdk .. ', type : ' .. type .. ', token : ' .. token
        log.info(output)
        js.execute(('console.log("%s")'):format(output))
        lobby.request_token_login(type, token)
    elseif platform.is_wx() or platform.is_qq() then
        lobby.wx_login()
    else
        return lobby.request_sdk_login()
    end
end

local function request_change_login_tag(tag)
    log.info('request change login tag :', tag)
    lobby.request_change_login_tag(tag)
end

local function _apply_token(apply_reason)
    local pro = base.promise()
    sce.map_publisher.apply_upload_token('', {
        ok = function(...)
            pro:try_set({true, ...})
        end,
        timeout = function()
            pro:try_set({false, 'timeout'})
        end,
        error = function(e)
            pro:try_set({nil, e})
        end
    }, apply_reason or 'Just Do It!')

    local suc, token, host, port = table.unpack(pro:co_result())
    return suc, token, host, port
end

local apply_token_pending_map = {top = 0}
if vm_name() == 'StateApplication' then
    register('_lobby_请求token', function(req)
        coroutine.async(function()
            local suc, token, host, port = _apply_token(req.reason)
            send_luastate_broadcast('_response_lobby_请求token', {req.request_id, result = {suc, token, host, port}})
        end)
    end)
else
    register('_response_lobby_请求token', function(res)
        local promise = apply_token_pending_map[res.request_id]
        if promise then
            promise:try_set(res.result)
        end
    end)
end

--- 如果成功, 则返回{True, token, host, port}, 否则返回{False, err}
---@return boolean, string|any, string|nil, number|nil
local function apply_token(apply_reason)
    if vm_name() == 'StateApplication' or vm_name() == 'StateEditor' then
        return _apply_token(apply_reason)
    else
        local promise = coroutine.promise()
        send_luastate_broadcast('_lobby_请求token', apply_reason, promise)
        apply_token_pending_map.top = apply_token_pending_map.top + 1
        local request_id = apply_token_pending_map.top
        apply_token_pending_map[request_id] = promise
        local ret, err = promise:co_get(10000)
        apply_token_pending_map[request_id] = nil
        if err then
            return false, err
        end

        return table.unpack(ret)
    end
end

----- lobby status ----------
---@class LobbyStatus
local lobby_status_cache = {
    --[[
    message LobbyUserInfo{
  required int64 user_id = 1;
  required bool online = 2;
  optional int64 team_id = 3;
  optional int64 room_id = 4;
  optional bool in_matching = 5;
  optional bool in_gaming = 6;
  optional bool in_middle_gaming = 7;
}]]--

--[[
message CurrentTeamStatus{
  required int64 team_id = 1;
  repeated LobbyUserInfo user_list = 2;
  required int64 master = 3;
}--]]

--[[message CurrentRoomStatus{

}]]--

--[[message CurrentMatcherStatus{
  required string map_name = 1;
  required string match_info = 2;
  required int64 operator_user_id = 3;
  repeated LobbyUserInfo user_list = 4;
}--]]

--[[message CurrentGameStatus{
  required int64 game_session_id = 1;
  repeated LobbyUserInfo user_list = 2;
}--]]

--message ResponseUserCurrentStatus{
  --required LobbyUserInfo user = 1;
    user = {
        user_id = 'user_id_3',
        online = false,
        team_id = '',
        room_id = '',
        matching = false,
        gaming = false,
        middle_gaming = false,
    },

    --optional CurrentTeamStatus team = 2;
    team = {
        team_id = '',
        master = 'user_id_1',
        user_list = {
            {user_id = 'user_id_1', online = true, matching = false, gaming = false, middle_gaming = false},
            {user_id = 'user_id_2', online = true, matching = false, gaming = false, middle_gaming = false},
            {user_id = 'user_id_3', online = true, matching = false, gaming = false, middle_gaming = false},
            {user_id = 'user_id_4', online = true, matching = false, gaming = false, middle_gaming = false},
        },
        team_custom_data = nil,
    },

    --optional CurrentMatcherStatus matcher = 4;
    match = {
        map_name = 'mover_td',
        match_info = '',
        operator_user_id = 'user_id_3',  -- 谁点的开始匹配
        user_list = {
            {user_id = 'user_id_3', online = true},  -- 队伍里你(user_id_3)和user_id_4一起匹配, 另外两个人在干别的
            {user_id = 'user_id_4', online = true},
        }
    },

    --optional CurrentGameStatus game =5;
    game = {
        game_session_id = '123456',
        user_list = {
            {user_id = 'user_id_3', online = true},
            {user_id = 'user_id_2', online = true},
            {user_id = 'user_id_10086', online = true},
            {user_id = 'user_id_123456', online = true},  -- 队伍里的你(user_id_3)和user_id_2与其他人在一起游戏  注意, 这只是示例, 正常情况下你不可能即在game里, 又在匹配中
        }
    },

    --optional CurrentGameStatus middle_game = 6;
    middle_game = {
        game_session_id = '654321',
        user_list = {
            {user_id = 'user_id_3', online = true},  -- 允许你在匹配或者gaming时, 仍然加入middle_game
        }
    }
--}
}
local get_lobby_status_cache=function()
    return lobby_status_cache;
end
local update_lobby_status_cache = function(err)
    if not err or err == 0 then
        local request_user_current_status = coroutine.co_wrap(user_current_status)
        local error_code, data = request_user_current_status()
        if error_code ~= 0 then
            log.error(('request_user_current_status failed. error_code: %s'):format(error_code))
        end

        lobby_status_cache = data  -- 替换缓存
        dispatch('玩家大厅状态改变', '获取大厅状态')
    end
end

local other_user_state = function(params, callback)
    local request = lobby.request_other_user_state(params.user_list)  -- user_list是一个数组, 如{"12345", "45677"}
    log.info('请求玩家Lobby状态', request)
    requests[request] = callback
end

if vm_name() == 'StateGame' then
    coroutine.async(update_lobby_status_cache)
end

-- 每次断线重连都来这么一下...
if vm_name() ~= 'StateEditor' then
    register('登录', coroutine.will_async(update_lobby_status_cache))
end

register('离开队伍', function(user_id)
    if lobby_status_cache and lobby_status_cache.team and lobby_status_cache.team.user_list then
        if lobby_status_cache.user.user_id == user_id then
            lobby_status_cache.team = nil
            if lobby_status_cache.user then
                lobby_status_cache.user.team_id = 0
            end
            dispatch('玩家大厅状态改变', '离开队伍')
            return
        else
            local user_list = lobby_status_cache.team.user_list
            for i = #user_list, 1, -1 do
                if user_list[i].user_id == user_id then
                    table.remove(user_list, i)
                end
            end
            dispatch('玩家大厅状态改变', '离开队伍')
        end
    end
end)

register('加入队伍', function(user_id)
    if lobby_status_cache and lobby_status_cache.team and lobby_status_cache.team.user_list then
        local user_list = lobby_status_cache.team.user_list
        table.insert(user_list, {user_id=user_id, online=true})
        dispatch('玩家大厅状态改变', '加入队伍')
    end
end)

local on_match_finish = function(reason)
    if lobby_status_cache and lobby_status_cache.match then
        lobby_status_cache.match = nil
        lobby_status_cache.user.matching = false
        dispatch('玩家大厅状态改变', reason)
    end
end

register('匹配成功', function() on_match_finish('匹配成功') end)
register('匹配失败', function() on_match_finish('匹配失败') end)
register('取消匹配', function() on_match_finish('取消匹配') end)

register('开始匹配', function(params)
    if lobby_status_cache then
        lobby_status_cache.match = params
        if lobby_status_cache.user then
            lobby_status_cache.user.matching = true
        end
        dispatch('玩家大厅状态改变', '开始匹配')
    end
end)

register('收到队伍状态通知', function(params)
    print('收到队伍状态通知', params)
    print('收到队伍状态通知', params.team_id)
    if lobby_status_cache then
        log.info(("replace team status: %s"):format(json.encode(params)))
        lobby_status_cache.team = params
        dispatch('玩家大厅状态改变', '收到队伍状态通知')
    end
end)

register('收到队长更换通知', function(params)
    print('收到队长更换通知', params)
    print('收到队长更换通知', params.team_id)
    if lobby_status_cache and lobby_status_cache.team then
        log.info(("replace team master: %s"):format(json.encode(params)))
        lobby_status_cache.team.master = params.new_master
        dispatch('玩家大厅状态改变', '收到队长更换通知')
    end
end)

register('玩家大厅状态改变', function(reason)
    log.info(('玩家大厅状态改变, reason: %s, 当前状态: %s'):format(reason, json.encode(get_lobby_status_cache())))
end)

register('收到本队人员游戏状态更新', function(user_id, game_type, session_id)
    if lobby_status_cache and lobby_status_cache.team and lobby_status_cache.team.user_list then
        for _, user in ipairs(lobby_status_cache.team.user_list) do
            if user.user_id == user_id then
                if game_type == 0 then
                    user.gaming = (session_id ~= 0)
                else
                    user.middle_gaming = (session_id ~= 0)
                end

                break
            end
        end
        dispatch('玩家大厅状态改变', '收到本队人员游戏状态更新')
    end
end)

register('收到本队人员匹配状态更新', function(user_id, matching)
    if lobby_status_cache and lobby_status_cache.team and lobby_status_cache.team.user_list then
        for _, user in ipairs(lobby_status_cache.team.user_list) do
            if user.user_id == user_id then
                user.matching = matching
                break
            end
        end
        dispatch('玩家大厅状态改变', '收到本队人员匹配状态更新')
    end
end)


require 'base.utility' 
local base_calc_server_address = base.calc_server_address
local lobby_set_entrance_port = lobby.set_entrance_port
local lobby_set_entrance_protocol = lobby.set_entrance_protocol
local lobby_set_entrance_ip = lobby.set_entrance_ip

local force_entrance_address = argv.has("entrance") and argv.get("entrance") or nil
log.info(('force_entrance_address: %s'):format(force_entrance_address))
local string_match = string.match

local function parse_url(url)
    -- 使用模式匹配来提取URL的各个部分
    -- 先尝试匹配带协议的URL
    local schema, domain, port, path = string_match(url, "^(%w+)://([^:/]+):?(%d*)(/?[^#?]*)")

    -- 如果没有匹配到协议，尝试匹配不带协议的URL
    if not schema then
        domain, port, path = url:match("^([^:/]+):?(%d*)(/?[^#?]*)")
        schema = nil -- 没有协议时设置为nil
    end

    -- 如果端口没有指定，默认为''
    port = port and tonumber(port) or nil
    -- 如果路径没有指定，默认为根路径 '/'
    path = path ~= '' and path or '/'

    return schema, domain, port, path
end

local function set_entrance_address()
    local port = 1001
    local ip = _G.IP
    local use_wss = true
    if argv.has('use_wss') then
        use_wss = argv.get('use_wss') ~= '0'  -- 默认用wss, 除非  -use_wss=0
    end
    local protocol = 'tcp'

    if force_entrance_address then
        local schema, domain, port_, path = parse_url(force_entrance_address)
        schema = schema or (use_wss and 'wss' or nil)
        log.info(("protocol[%s], domain[%s], port_[%s], path[%s], use_wss[%s]"):format(schema, domain, port_, path, use_wss))
        if schema then
            if lobby_set_entrance_protocol then
                if schema == 'ws' then
                    port = port_ or 1002
                elseif schema == 'wss' then
                    port = port_ or 443
                end
            else
                error(("lobby_set_entrance_connection_protocol not exists. protocol[%s]"):format(schema))
            end
        end

        ip = domain
        protocol = schema

    else
        if use_wss then
            if lobby_set_entrance_protocol then  -- 如果set_entrance_port不存在, 说明客户端二进制是老版, 现在还是要用1001
                local matched
                ip, matched = base_calc_server_address('entrance-new', 1002, use_wss)  -- 通常1002是不会连的, 都是连443, 1002是本地起entrance的情况
                if matched then
                    port = 443
                    protocol = 'wss'
                else
                    port = 1002
                    protocol = 'ws'
                end
            else
                log.warn('use_wss but lobby_set_entrance_connection_protocol not exists')
            end
        end
    end

    lobby_set_entrance_ip(ip)

    if lobby_set_entrance_protocol then
        lobby_set_entrance_port(port)
        lobby_set_entrance_protocol(protocol)
    --else
        --if use_wss then
        --    log.error("lobby.set_entrance_port not exists, but startup command apply use_wss")
        --end
    end
end

local calc_http_server_address = base.calc_http_server_address

---@class Lobby
local interface = {
    current_map_name = '',
    reconnecting = false,
    logined = false,
    entrance_flag = 0,


    register_event = register,
    register_once = register_once,
    start_game = start_game,

    is_sdk = is_sdk,
    request_sdk_login = request_sdk_login,
    request_change_login_tag = request_change_login_tag,

    can_reconnect = can_reconnect,
    reconnect = reconnect,
    can_reconnect_timeout = can_reconnect_timeout,
    reconnect_timeout = reconnect_timeout,
    cancel_reconnect = cancel_reconnect,
    create_team = create_team,
    leave_team = leave_team,
    start_match = start_match,
    team_start_game = team_start_game,
    cancel_match = cancel_match,
    team_invite = team_invite,
    team_invite_v2 = team_invite_v2,
    accept_invite = accept_invite,
    team_join = team_join,
    team_kick_user = team_kick_user,
    modify_team_info = modify_team_info,
    request_team_info = request_team_info,
    join_middle_game = join_middle_game,
    quick_start_game = quick_start_game,
    request_world_id = request_world_id,
    prewarm_world = prewarm_world,
    finish_world = finish_world,
    send_luastate_broadcast = send_luastate_broadcast,
    vm_name = vm_name,
    apply_token = apply_token,
    register_luaState_event = register_luaState_event,
    user_current_status = user_current_status,
    request_team_list = request_team_list,
    other_user_state = other_user_state,
    get_lobby_status_cache=get_lobby_status_cache,
    has_old_session = has_old_session,
    calc_http_server_address = calc_http_server_address,
    dispatch = dispatch,
    dispatch_all_vm = dispatch_all_vm,
    app_lua = app_lua,
    set_entrance_address = set_entrance_address,
    return_to_lobby = return_to_lobby,
}


function interface:is_in_game()
	log.debug('is_in_game', self.current_map_name,':', lobby.get_lobby_map())
    return self.current_map_name and self.current_map_name ~= '' and self.current_map_name ~= lobby.get_lobby_map() 
end

base.game:event('加载地图', function(_, map_name)
	log.debug('current map', map_name)
    interface.current_map_name = map_name
end)

lobby_events.on_game_info_update = function(map_name)
	log.debug('change map', map_name)
    interface.current_map_name = map_name
end

lobby_events.on_return_to_startup = function()
    dispatch('返回启动页')
end

lobby_events.on_entrance_connected = function()
    log.info('连接上 entrance')
    interface.reconnecting = false
    dispatch('已连接')
end

lobby_events.on_entrance_disconnected = function()
    log.info('与 entrance 断开连接')
    interface.logined = false
    dispatch('断开连接')
end

lobby_events.on_entrance_connect_error_catched = function(error_code, message)
    log.info('连接 entrance 错误', error_code, message)
    interface.logined = false
    dispatch('连接错误', error_code, message)
end

lobby_events.on_login_response = function(error_code, ...)
    log.info('登录', error_code)
    interface.logined = error_code == 0
    dispatch('登录', error_code, ...)
end

lobby_events.on_login_at_other_place_notify = function()
    log.info('异地登录')
    interface.logined = false
    dispatch('异地登录')
end

lobby_events.on_notify_service_stopped = function(flag, reason, in_white_list)
    log.info('全平台维护状态：',flag,reason,in_white_list)
    interface.entrance_flag = flag
    dispatch('维护状态',flag,reason,in_white_list)
end

lobby_events.on_host_downloading_map_notify = function()
    log.info('服务端-加载地图')
    dispatch('服务端-加载地图')
end

lobby_events.on_logout = function()
    log.info('登出')
    interface.logined = false
    dispatch('登出')
end

lobby_events.on_sdk_login_result = function(code, login_way, client_id, client_id2, token_or_error, token_ext)
    dispatch('sdk登录结果', code, login_way, client_id, client_id2, token_or_error, token_ext)
end

lobby_events.on_ams_debug_lua_info = function(level, message)
    
    log.debug('收到ams调试log')
    dispatch('ams调试log', level, message)
end

lobby_events.on_echo_test_response = function(buf, message_key, the_lua_state_name)
    if lua_state_name == the_lua_state_name then
        log.debugf('收到echo_test response, buf[%s], message_key[%s], the_lua_state_name[%s] lua_state_name[%s]', buf, message_key, the_lua_state_name, lua_state_name)
        dispatch('echo_test_response', buf, message_key)
    end
end


---@return Lobby
return setmetatable(interface, {
    __index = function(self, key)
        if not lobby[key] then return nil end
        return function(...)
            return lobby[key](...)
        end
    end
})

