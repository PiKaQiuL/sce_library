
-- 和服务器请求的封装

local lobby = include 'base.lobby'

_G.updater_events = _G.updater_events or {}
_G.login_events = _G.login_events or {}

---@type table<string, any>
local dispatcher = {
    ['!'] = function(key, ...)
        base.game:event_notify(key, ...)
    end
}

_G.dispatch_request_event = function(request_id, ...)
    --log.info(('dispatch_request_event: %s request_id: %s, %s'):format(tostring(dispatcher), request_id, tostring(dispatcher[request_id])))
    if dispatcher[request_id] then
        dispatcher[request_id](...)
    else
        log.warn(('dispatcher[%s] is nil'):format(request_id))
    end
end

local request_id_top = math.random(100000000, 999999999)  -- 为了每次reload后, 不重复
log.info(('init request_id_top: %d'):format(request_id_top))

local function create_request_with_request_id(name)
    local request = {}

    request.__index = function(self, key)
        return function(...)
            request_id_top = request_id_top + 1
            local request_id = tostring(request_id_top)

            --log.info(('request name[%s] key[%s], request_id: %s'):format(name, key, request_id))

            local args = table.pack(...)
            table.move(args, 1, args.n, 2)
            args[1] = request_id
            args.n = args.n + 1
            local cb = args[args.n]

            if not lobby.is_entrance_connected() then
                base.next(function() cb(-1) end)
                return
            end

            -- 注册一下断开 entrance 事件
            local timeout
            local disconnect = lobby.register_once('断开连接', function()
                if timeout then timeout:remove() end
                if cb then
                    local cb_temp = cb
                    cb = nil
                    cb_temp(-1)
                end
            end)

            timeout = base.wait(5000, function()

                dispatcher[request_id] = nil
                disconnect:remove()
                log.info(('请求超时 %s.%s, request_id: %s '):format(name, key, request_id))
                if cb then
                    local cb_temp = cb
                    cb = nil
                    cb_temp(-2)
                end
            end)

            dispatcher[request_id] = function(...)
                dispatcher[request_id] = nil
                timeout:remove()
                disconnect:remove()
                --log.info(('called: %s'):format(request_id))
                if cb then
                    local cb_temp = cb
                    cb = nil
                    cb_temp(...)
                end
            end

            --log.info(("dispatcher1: %s, func: %s"):format(tostring(dispatcher), tostring(dispatcher[request_id])))

            args[args.n] = nil
            args.n = args.n - 1

            _G[name]['request_' .. key](table.unpack(args, 1, args.n))
        end
    end
    setmetatable(request, request)
    return request
end

local function create_request(name)
    return create_request_with_request_id(name)
end

base.game:event('on_map_update_notify', function(map, env, version)
    log.info(('on_map_update_notify, map[%s] env[%s] version[%s]'):format(map, env, version))
end)

return create_request