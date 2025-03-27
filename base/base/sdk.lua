
include 'base.json'
local co = include "base.co"
local json_callbacks = {}

if not sdk then sdk = {} end
sdk.on_json_event = function(e, val)
    log.info('[sdk] json event', e, val)
    local args = base.json.decode(val)
    if json_callbacks[e] then
        if (json_callbacks[e](e, args)) then
            json_callbacks[e] = nil
        end
    else
        log.warn('[sdk] not found callback for', e)
    end
    return
end


local function on_json(...)
    local args = {...}
    if #args < 2 then 
        log.warn('reg json handler failed, args < 2')
        return 
    end

    local cb = args[#args]
    if type(cb) ~= 'function' then
        log.warn('reg json handler failed, the last arg is not a function')
        return
    end

    for i, v in ipairs(args) do
        log.info('[sdk] ', type(v))
        if type(v) == 'string' then
            json_callbacks[v] = cb
        end
    end
end

on_json('uninstall', function(_, info)
    log.info('[uninstall]',info.name)
    local maps_mgr = include 'uninstall.delete'
    coroutine.async(function()
        maps_mgr:delete(info.name, common.report_uninstall_progress, common.report_uninstall_result)
    end)
end)

on_json('query_game_size', function(_, ids) 
    coroutine.async(function()
        local local_version = require 'update.core.local_version'
        local refc = require 'uninstall.generate_count'
        refc.init()
        local res = local_version:query_game_size(ids)
        common.report_game_size(base.json.encode(res))
    end)
end)

on_json('query_all_game_size', function() 
    coroutine.async(function()
        local refc = require 'uninstall.generate_count'
        refc.init()
        local version = require 'update.core.local_version'
        local res = version:query_all_game_size()
        common.report_game_size(base.json.encode(res))
    end)
end)

on_json('remove_logs', function() 
    io.remove('logs')
end)

function get_async(url, cb) 
    log.info('[sdk] [http] get', url)
    local outstream = sce.httplib.create_stream()
    local header = account.generate_http_token_sign()
    sce.httplib.request ({ url = url, output = outstream, timeout = 4, header = header}, function(code, status) handle_http_response(url, code, status, outstream, cb) end)
end

function post_async(url, obj, cb)
    log.info('[sdk] [http] post', url)
    local outstream = sce.httplib.create_stream()
    local input = sce.httplib.create_stream()
    local raw = base.json.encode(obj.data)
    local header = account.generate_http_token_sign(obj.header)
    --log.info('[pay] [htt] post', url, raw)
    input:write(raw)
    input:feed_eof()
    sce.httplib.request ({ url = url, output = outstream, input = input, content_type = 'application/json', header = header, timeout = 4}, function(code, status_code) handle_http_response(url, code, status_code, outstream, cb) end)
end


local get = co.wrap(get_async)
local post = co.wrap(post_async)

if not base.http then
    base.http = {}
end



base.http.get = get
base.http.post = post
base.http.calc_http_server_address = base.calc_http_server_address



return {
    on_json = on_json,
    send_json_event = sdk.on_json_event,
}



