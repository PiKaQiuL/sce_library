
local rpc = require 'base.rpc'
local on_json = include('base.sdk').on_json
local co = include "base.co"
local argv = require 'base.argv'

local calc_http_server_address = base.calc_http_server_address

if sdk.exit_voice_room and sdk.join_voice_room then
    function get_auth(appid,room, user_id)
        local host = calc_http_server_address('rtc-support-server', 8051)
        local res = base.http.get(host .. '/gen-auth?userid='..user_id..'&appid='..appid..'&room='..room)
        return res and res.auth or ''
    end

    function rpc.join_voice_room(room, team, range, cb)
        log_file.info('voice cb', tostring(cb))
        coroutine.async(function()
            sdk.exit_voice_room()
            log_file.info('exit room')
            local wait_json_event  = co.wrap(on_json)
            wait_json_event('exit_voice_room')
            log_file.info('exit room finished')
            local account = require '@common.base.account'
            local auth = get_auth('1400800020', room, account.latest_login_info.user_id)
            local retry_count = 10
            while tostring(auth):len() < 10 and retry_count > 0 do
                common.send_user_stat('voice_auth_failed', tostring(room) .. ':' .. tostring(account.latest_login_info.user_id))
                auth = get_auth('1400800020', room, account.latest_login_info.user_id) 
                retry_count = retry_count - 1
            end
            sdk.join_voice_room(room, team, auth, range)  
            local res = wait_json_event('join_voice_room')
            local lobby = require 'base.lobby'
            lobby.dispatch_all_vm("进入语音房间", room)
            base.game:event_notify('语音-开启')
            log_file.info('voice cb', tostring(cb))
            if cb then
                cb(res)
            end
        end)
    end

    function rpc.voice_black_list(p, mute)
        if sdk.mute_user_voice then
            sdk.mute_user_voice(p, mute)
        end
    end

    local user_voice_stream_level = {}
    sdk.voice_trigger_threshold = 0

    if game and game.get_game_info().map_kind == 0 and __lua_state_name == 'StateGame' then
        base.game:event('游戏-更新',function()
            if game.get_controled_unit_position and sdk.update_voice_position then
                sdk.update_voice_position(game.get_controled_unit_position())
            end
            if sdk.get_voice_user_stream_level then
                for userid, _ in pairs(user_voice_stream_level) do
                    local level = sdk.get_voice_user_stream_level(userid)
                    local has_audio = function(l) return l and l >= sdk.voice_trigger_threshold end
                    if has_audio(user_voice_stream_level[userid]) ~= has_audio(level) then
                        if has_audio(level) then
                            base.game:event_notify('语音-开始说话', userid)
                        else
                            base.game:event_notify('语音-停止说话', userid)
                        end
                    end
                    user_voice_stream_level[userid] = level
                end
            end
        end)
    end

    on_json('on_voice_user_enter', function(e, val)
        log_file.debug("on_voice_user_enter", val.userId)
        if val.userId then
            user_voice_stream_level[val.userId] = 0
            base.game:event_notify('语音-进入', val.userId)
        end
    end)

    on_json('on_voice_user_exit', function(e, val)
        log_file.debug("on_voice_user_exit", val.userId)
        if val.userId then
            user_voice_stream_level[val.userId] = nil
            base.game:event_notify('语音-退出', val.userId)
        end
    end)

    on_json('on_voice_user_has_audio', function(e, val)
        log_file.debug("on_voice_user_has_audio", val.userId)
        if val.userId then
            --base.game:event_notify('语音-开始说话', val.userId)
        end
    end)

    on_json('on_voice_user_no_audio', function(e, val)
        log_file.debug("on_voice_user_no_audio", val.userId)
        if val.userId then
            --base.game:event_notify('语音-停止说话', val.userId)
        end
    end)
end


return sdk
