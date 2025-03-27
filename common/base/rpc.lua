
local proto = require 'base.server'


function rpc_call(k, ...)
    base.game:server '__simple_rpc__' {name = k, args = {...}}
end


------这段服务器客户端一样---
local cb_id = 1
local rpc_impl = {}
local make_args
local rpc = {
    __index = function(t, k)
        return function( ...)
            rpc_call(k, make_args(nil, ...))
        end
    end,
    __newindex = function(t, k, v)
        rawset(rpc_impl, k, v)
    end
}

make_args = function (owner, ...)
    local args = {...}
    local xargs = {}
    for i,v in ipairs(args) do
        log_file.info(i, type(v), tostring(v))
        if type(v) == 'function' then
            xargs[i] = {__rpc_cb__ = cb_id}
            rpc[cb_id] = v
            cb_id = cb_id + 1
        elseif type(v) == 'table' and v.__rpc_cb__ then
            xargs[i] = function(...)
                if owner then
                    rpc.callback(owner, v.__rpc_cb__, ...)
                else
                    rpc.callback(v.__rpc_cb__, ...)
                end
            end
        else 
            xargs[i] = v
        end
    end
    for i,v in ipairs(xargs) do
        log_file.info(i, type(v), tostring(v))
    end
    return table.unpack(xargs)
end

function rpc_accept(owner, k, ...)
    if type(rpc_impl[k]) == 'function' then
        rpc_impl[k](make_args(owner, ...))
    end
end

setmetatable(rpc, rpc)
------这段服务器客户端一样---


rpc.callback = function(id, ...)
    rpc_accept(nil, id, ...)
end

function proto.__simple_rpc__(call)
    rpc_accept(nil, call.name, table.unpack(call.args))
end


return rpc


