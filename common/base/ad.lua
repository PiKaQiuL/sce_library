
local proto = require 'base.server'
local rpc = require 'base.rpc'
local on_json = include('base.sdk').on_json
local co = include "base.co"
local argv = require 'base.argv'
local component = require 'base.gui.component'

local calc_http_server_address = base.calc_http_server_address

local lock = nil
local function show_reward_video_ad(reward, reward_amount, extra, cb)
    local _cb = cb
    cb = function(val)
        _cb(val)
        if not val.result then
            common.send_user_stat('ad_failed', val.msg)
        end
    end

    if lock then
        log.error('ad pendding')
        cb({result = false, msg = 'pendding'})
        return
    else
        lock = extra
    end

    on_json('show_reward_video_ad', function(e, val)
        coroutine.async(function()
            if not val.result and val.msg == 'api not open' then
                local host = calc_http_server_address('tap-adn-server', 8050)
                local res = base.http.get(host .. '/create-media-for-game?game='..argv.get('game')..'&landscape='.. tostring(argv.has('portrait') and 0 or 1))
                log_file.info('[ad] update payload', tostring(res and res.error or 'failed'))
                val.msg = 'ad params missing, try restart app'
            end

            if not val.result and (val.msg == 'fetch failed' or val.msg == 'unsupported platform') then
                local lobby = require 'base.lobby' 
                log_file.info('show custom ad', lobby.vm_name())
                val = co.wrap(lobby.app_lua.play_custom_ad)()
            end

            log_file.info(val.msg)
            if cb then
                cb(val)
            end
            lock = nil
        end)
    end)
    if sdk.show_reward_video_ad then
        sdk.show_reward_video_ad(reward, reward_amount, extra and tostring(extra) or '')
    elseif cb then
        cb({result = false, msg = 'no api'})
    end
end

rpc.show_reward_video_ad = show_reward_video_ad

return {
    show_reward_video_ad = show_reward_video_ad,
}

