---@meta
--- 提供Promise模式的异步编程支持
--- @module 'base.promise'
--- @author xindong
--- @copyright SCE
--- @license MIT

--[[
使用示例：

-- 示例1: 基本用法
local p = promise.new()
p:set_result("success")
local result = p:co_result() -- 获取结果

-- 示例2: 异步操作
local p = promise.new()
some_async_function(function(result, error)
    p:set(result, error)
end)
local result, err = p:co_get() -- 协程中等待结果

-- 示例3: 错误处理
local p = promise.new()
p:set_error("failed")
local success, err = pcall(function()
    p:co_result() -- 会抛出异常
end)

-- 示例4: 超时处理
local p = promise.new()
local result, err = p:co_get(1000) -- 等待1秒后超时
]]

---@type fun():table 创建事件队列
local create_event_queue = require 'base.event_deque'.create_event_queue
---@type fun(f:function):function 包装函数为协程函数
local wrap = require 'base.co'.wrap
---@type fun(f:function):function 包装函数为异步函数
local async = require 'base.co'.async
---@type fun(err:any):table 将错误转换为异常对象
local to_exception = require 'base.exception'.to_exception
local setmetatable = setmetatable
local xpcall = xpcall
local table_pack = table.pack

---Promise类，提供异步编程支持
---@class promise
---@field private _ret any 存储的结果值
---@field private _error any 存储的错误值
---@field private _ready boolean 是否已就绪
---@field private _eq table 事件队列
---@field get fun(self:promise, timeout:nil|number, callback:fun(ret:any, err:any)|nil):any,any 获取Promise的结果，可以通过回调或直接返回值
---@field co_get fun(self:promise, timeout:nil|number):any,any 在协程中获取Promise的结果
---@field set fun(self:promise, value:any, err:any):nil 设置Promise的结果和错误
---@field try_set fun(self:promise, value:any, err:any):boolean 尝试设置Promise的结果和错误，如果已设置则返回false
---@field set_result fun(self:promise, value:any):boolean 设置Promise的结果
---@field try_set_result fun(self:promise, value:any):boolean 尝试设置Promise的结果，如果已设置则返回false
---@field set_error fun(self:promise, err:any):boolean 设置Promise的错误
---@field try_set_error fun(self:promise, err:any):boolean 尝试设置Promise的错误，如果已设置则返回false
---@field co_result fun(self:promise, timeout:nil|number):any 在协程中获取Promise的结果，如果有错误则抛出异常
---@field co_error fun(self:promise, timeout:nil|number):any 在协程中获取Promise的错误
---@field ready fun(self:promise):boolean 检查Promise是否已就绪
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