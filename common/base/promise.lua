---
--- Generated by EmmyLua(https://github.com/EmmyLua)
--- Created by xindong.
--- DateTime: 2021/2/5 17:25
---

--_G.ac = _G.ac or {}

--[[
-- example 1:



-- example 2:

example 3:

example 4:

]]

local create_event_queue = require 'base.event_deque'.create_event_queue
local wrap = require 'base.co'.wrap
local async = require 'base.co'.async
local to_exception = require 'base.exception'.to_exception
local setmetatable = setmetatable
local xpcall = xpcall
local table_pack = table.pack

---@class promise
---@field get fun(self: promise, timeout: nil|number, callback: fun(ret: any, err: any)): any, any
---@field co_get fun(self: promise, timeout: nil|number): any, any
---@field set fun(self: promise, value: any, err: any): nil
---@field try_set fun(self: promise, value: any, err: any): boolean
---@field set_result fun(self: promise, value: any): boolean
---@field try_set_result fun(self: promise, value: any): boolean
---@field set_error fun(self: promise, err: any): boolean
---@field try_set_error fun(self: promise, err: any): boolean
---@field co_result fun(self: promise, timeout: nil|number): any      如果被设置为err了, 此函数返回时会抛出一个异常
---@field co_error fun(self: promise, timeout: nil|number): any
---@field ready fun(self: promise): boolean
local promise = {
    _ret = nil,
    _error = nil,
    _ready = nil,

    get = function(self, timeout, callback)
        if self._ready then
            if callback then
                callback(self._ret, self._error)
                return
            else
                return self._ret, self._error
            end
        end

        if callback then
            local proxy_callback = function(ret, err)
                if self._ready then
                    callback(self._ret, self._error)
                else
                    callback(ret, err) -- 这时候ret应该是nil
                end
            end
            self._eq:pop(timeout, proxy_callback)
            return
        else
            return nil, 'empty'
        end
    end,

    co_result = function(self, timeout)
        local ret, err = self:co_get(timeout)
        if err then
            error(to_exception(err))
        end

        return ret
    end,

    co_error = function(self, timeout)
        local _, err = self:co_get(timeout)
        return err
    end,

    co_get = function(self, timeout)
        local new_f = wrap(self.get)
        return new_f(self, timeout)
    end,

    set = function(self, value, err)
        if not self:try_set(value, err) then
            error 'promise has set result'
        end
    end,

    try_set = function(self, value, err)
        if self._ready then
            return false
        end

        self._ret = value
        self._error = err
        self._ready = true

        self._eq:close()
        return true
    end,

    set_result = function(self, v)
        return self:set(v)
    end,

    try_set_result = function(self, v)
        return self:try_set(v)
    end,

    set_error = function(self, err)
        return self:set(nil, err)
    end,

    try_set_error = function(self, err)
        return self:try_set(nil, err)
    end,

    ready = function(self)
        return self._ready
    end
}

promise.__index = promise

---@return promise
function promise:__call()
    return setmetatable({
        _eq = create_event_queue()
    }, self)
end

setmetatable(promise, {__call=promise.__call})

---@class multi_promise
---@field get fun(self: promise, timeout: nil|number, callback: fun(ret: any, err: any)): any, any
---@field co_get fun(self: promise, timeout: nil|number): any, any
---@field ready fun(self: promise): boolean
local multi_promise = {
    _join_type = 'any_failed',   ---@type "all_finish"|"any_finish"|"any_failed"
    _promise = nil,  ---@type promise
    _promise_list = nil,   ---@type promise[]

    get = function(self, timeout, callback)
        return self._promise:get(timeout, callback)
    end,

    co_get = function(self, timeout)
        return self._promise:co_get(timeout)
    end,

    ---@param promise_list promise[]
    _start = function(self, promise_list, timeout)
        local all_count = #promise_list
        local finished_count = 0

        for i = 1, all_count do
            local pro = promise_list[i]
            pro:get(timeout, function(ret, err)
                if self._promise:ready() then
                    return
                end
                finished_count = finished_count + 1
                if self._join_type == 'any_failed' then
                    if all_count == finished_count or err ~= nil then
                        self._promise:set(ret, err)
                    end
                elseif self._join_type == 'any_finish' then
                    self._promise:set(ret, err)
                else  -- all_finish
                    if all_count == finished_count then
                        self._promise:set(ret, err)
                    end
                end
            end)
        end
    end,

    ready = function(self)
        return self._promise:ready()
    end
}
multi_promise.__index = multi_promise

---@return multi_promise
function multi_promise:__call(promise_list, join_type, timeout)
    local ins = setmetatable({
        _join_type = join_type,
        _promise_list = promise_list,
        _promise = promise(),
    }, self)   ---@type multi_promise

    ins:_start(promise_list, timeout)
    return ins
end

setmetatable(multi_promise, {__call=multi_promise.__call})

---@return promise
local as_promise = function(f, ...)
    local pro = promise()
    async(function(...)
        local _, ret = xpcall(f, function(err)
            pro:set(nil, to_exception(err))
        end, ...)

        if not pro:ready() then
            pro:set(ret, nil)
        end
    end, ...)

    return pro
end

base.promise = promise
coroutine.promise = promise

base.multi_promise = multi_promise
coroutine.multi_promise = multi_promise

base.as_promise = as_promise
coroutine.as_promise = as_promise

return {
    promise = promise,
    multi_promise = multi_promise,
    as_promise = as_promise,
}