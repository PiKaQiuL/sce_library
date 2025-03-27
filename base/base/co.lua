
---@meta
--- 提供协程相关的功能，支持异步编程
--- @module 'base.co'
--- @copyright SCE
--- @license MIT

local table_pack = table.pack
local table_unpack = table.unpack
local coroutine_running = coroutine.running
local coroutine_create = coroutine.create
local coroutine_yield = coroutine.yield
local coroutine_resume = coroutine.resume
local coroutine_wrap = coroutine.wrap
local error = error
local type = type
local tostring = tostring
local xpcall = xpcall
local base_next = base.next
local base_wait = base.wait
local debug_traceback = debug.traceback
local print = print
local debug_sethook = debug.sethook

--local old_log_error = log.error
--log.error = function(s)
--    old_log_error('123')
--    old_log_error(debug.traceback(tostring(s), 2))
--end

log = log or {}
log.error = log.error or function(...) print(...) end
local log_error = log.error

local error_pending_kill = base.error_pending_kill or {}
base.error_pending_kill = error_pending_kill

local function check(func)
    if type(func) ~= 'function' then
        log_error(debug_traceback('param 1 is not a function'))
        return false
    end
    return true
end

local function coroutine_resume_with_check(co, ...)
    local ok, err = coroutine_resume(co, ...)
    if ok or err == error_pending_kill then
        return
    end
    log_error(debug_traceback(co, tostring(err)))
    if debug_bp then
        debug_bp()
    end
end

-- 将异步回调转换为协程
---包装函数为协程函数，提供错误处理
---@param func function 要包装的函数
---@return function 包装后的协程函数
local function wrap(func)
    return function(...)
        --if not check(func) then return false end
        local co, main = coroutine_running()
        if main then
            error ('cannot wrap coroutine by main thread!!!')
            return func
        end

        local has_yield = false
        local ret = nil
        local called = false
        local cb = function(...)
            if called then
                return
            end
            called = true
            if not has_yield then
                ret = table_pack(...)
                return
            end
            --local curr = coroutine.running()
            --log.info(('\n>>>0\nresume\niiid: %d, curr: [thread:%d] :%s\nco: [thread:%d]:%s\n<<<0\n'):format(iiid, get_tm(curr), debug.traceback(curr), get_tm(co), debug.traceback(co)))
            --log.info(('\n>>>1\nreturn: %s\niiid: %d, co: [thread:%d] :%s\n<<<1\n'):format(tostring(result), iiid, get_tm(co), debug.traceback(co)))
            return coroutine_resume_with_check(co, ...)
        end
        local args = table_pack(...)
        args[args.n + 1] = cb
        func(table_unpack(args, 1, args.n + 1))
        if ret then
            --log.info(('\n>>>2\nimmediately return\niiid: %d, co: [thread:%d]'):format(iiid, get_tm(co)))
            -- 如果func调用时在内部立即调用了cb, 则不能等yield返回, 应该立即return
            return table_unpack(ret, 1, ret.n)
        end
        has_yield = true
        --log.info(('\n>>>2\nyield\niiid: %d, co: [thread:%d] :%s\n<<<2\n'):format(iiid, get_tm(co), debug.traceback(co)))
        return coroutine_yield()
    end
end

---在协程中调用函数，提供错误处理
---@param func function 要调用的函数
---@param ... any 传递给函数的参数
---@return any ... 函数的返回值
local function call(func, ...)
    return wrap(func)(...)
end

---包装函数为异步函数，在新协程中执行
---@param fn function 要包装的函数
---@param ... any 传递给函数的参数
local function async(fn, ...)
    local co = coroutine_create(fn)
    return coroutine_resume_with_check(co, ...)
end

local async_next = (function(fn, ...)
    local args = table_pack(...)
    base_next(function()
        async(fn, table_unpack(args, 1, args.n))
    end)
end)

---在协程中休眠指定时间
---@param timeout number 休眠时间（毫秒）
local sleep = function(timeout)
    local _sleep = wrap(base_wait)
    return _sleep(timeout)
end

---在协程中休眠一帧
---@return any 下一帧的返回值
local sleep_one_frame = function()
    local _sleep_one_frame = wrap(base_next)
    return _sleep_one_frame()
end

---将函数转换为异步执行的函数
---@param func function 要转换的函数
---@return function 转换后的异步函数
local will_async = function(func)
    return function(...)
        async(func, ...)
    end
end

coroutine.co_wrap = wrap
coroutine.call = call
coroutine.async = async
coroutine.will_async = will_async
coroutine.async_next = async_next
coroutine.sleep = sleep
coroutine.sleep_one_frame = sleep_one_frame

---@type table<thread, Coroutine>
local thread_pool = {}
setmetatable(thread_pool, {__mode = "kv"})

---@type table<Coroutine, thread>
local tsCo_pool = {}
setmetatable(tsCo_pool, {__mode = "kv"})

---@class Coroutine
---@field IsMain boolean
---@field prototype table
local Coroutine = base.tsc.__TS__Class()
Coroutine.name = "Coroutine"

local thread, curr_is_main = coroutine.running()
local main_thread
if not curr_is_main then
    main_thread = thread
end

---comments
---@param tr thread?
---@param is_main boolean?
---@return Coroutine?
local function thread_to_tsCo(tr, is_main)
    if not tr then
        return nil
    end

    if thread_pool[tr] then
        return thread_pool[tr]
    end

    ---@type Coroutine
    local tsCo = base.tsc.__TS__New(
        Coroutine,
        {}
    )
    tsCo.IsMain = is_main or (main_thread == tr)
    tsCo_pool[tsCo] = tr
    thread_pool[tr] = tsCo
    return tsCo
end

---comment
---@param tsCo Coroutine?
---@return thread?
local function tsCo_to_thread(tsCo)
    if not tsCo then
        return nil
    end
    return tsCo_pool[tsCo]
end


function Coroutine.prototype.____constructor(self)
    ---comments
    ---@return boolean
    self.Yield = function()
        local tr = tsCo_to_thread(self)
        if not tr then
            return false
        end
        local success, _ = coroutine.yield(tr)
        return success
    end

    ---comments
    ---@return boolean
    self.Resume = function()
        local tr = tsCo_to_thread(self)
        if not tr then
            return false
        end
        local success, _ = coroutine.resume(tr)
        return success
    end

    self.Stop = function ()
        local tr = tsCo_to_thread(self)
        if not tr then
            return false
        end
        if self.Status == "dead" then
            return false
        end
        debug_sethook(tr, function()error(error_pending_kill)end, "l")
        self.__force_killed = true
        return true
    end
end

base.tsc.__TS__ObjectDefineProperty(
    Coroutine,
    "Current",
    {get = function()
        return thread_to_tsCo(coroutine.running())
    end}
)

base.tsc.__TS__SetDescriptor(
    Coroutine.prototype,
    "Status",
    {get = function(self)
        local tr = tsCo_to_thread(self)
        if not tr or self.__force_killed then
            return "dead"
        end
        return coroutine.status(tr)
    end},
    true
)

---@class CoModule
---@field wrap fun(func:function):function 包装函数为协程函数，提供错误处理
---@field call fun(func:function, ...):any 在协程中调用函数，提供错误处理
---@field async fun(fn:function, ...):any 包装函数为异步函数，在新协程中执行
---@field async_next fun(fn:function, ...) 在下一帧异步执行函数
---@field will_async fun(func:function):function 将函数转换为异步执行的函数
---@field sleep fun(timeout:number) 在协程中休眠指定时间
---@field sleep_one_frame fun():any 在协程中休眠一帧
---@field tsCo_to_thread fun(tsCo:Coroutine?):thread? 将Coroutine对象转换为thread
---@field thread_to_tsCo fun(tr:thread?, is_main:boolean?):Coroutine? 将thread转换为Coroutine对象
---@field Coroutine Coroutine 协程类

---@type CoModule
return {
    wrap = wrap,
    call = call,
    async = async,
    async_next = async_next,
    will_async = will_async,
    sleep = sleep,
    sleep_one_frame = sleep_one_frame,
    tsCo_to_thread = tsCo_to_thread,
    thread_to_tsCo = thread_to_tsCo,
    Coroutine = Coroutine,
}
