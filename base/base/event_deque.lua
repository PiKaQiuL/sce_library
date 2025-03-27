---@meta
--- 提供事件队列和双端队列功能
--- @module 'base.event_deque'
--- @author xindong
--- @copyright SCE
--- @license MIT

--[[
使用示例：

-- 创建事件双端队列
local ed = base.event_deque()

-- 在协程中等待元素
coroutine.wrap(function()
    local elem = ed:co_pop()  -- 阻塞直到有元素可用
    run(elem)
end)()

-- 推送元素到队列
ed:push("some_event")
]]--

---@type fun():table 创建队列
local create_queue = require 'base.deque'.create_queue
---@type fun():table 创建双端队列
local create_deque = require 'base.deque'.create_deque

---@type fun(f:function):function 包装函数为协程函数
local co_wrap = require 'base.co'.wrap

---事件双端队列类
---@class event_deque
---@field private _elem_deque table 元素双端队列
---@field private _callback_queue table 回调函数队列
---@field push_front fun(self:event_deque, elem:any) 将元素添加到队列前端
---@field pop_front fun(self:event_deque, timeout:number|nil, callback:fun(ret:any, err:string|nil)|nil):any,string|nil 从队列前端取出元素
---@field push_back fun(self:event_deque, elem:any) 将元素添加到队列后端
---@field pop_back fun(self:event_deque, timeout:number|nil, callback:fun(ret:any, err:string|nil)|nil):any,string|nil 从队列后端取出元素
---@field co_pop_back fun(self:event_deque, timeout:number|nil):any,string|nil 在协程中从队列后端取出元素
---@field co_pop_front fun(self:event_deque, timeout:number|nil):any,string|nil 在协程中从队列前端取出元素
---@field close fun(self:event_deque, clean:function|nil) 关闭队列
---@field closed fun(self:event_deque):boolean 检查队列是否已关闭
---@field push fun(self:event_deque, elem:any) 将元素添加到队列（push_back的别名）
---@field pop fun(self:event_deque, timeout:number|nil, callback:fun(ret:any, err:string|nil)|nil):any,string|nil 从队列取出元素（pop_front的别名）
---@field co_pop fun(self:event_deque, timeout:number|nil):any,string|nil 在协程中从队列取出元素（co_pop_front的别名）
local event_deque = {
    push_front = function(self, elem)
        while #self._callback_queue > 0 do
            local f = self._callback_queue:pop()
            if f then
                f(elem, nil)
                return
            end
        end

        self._elem_deque:push_front(elem)
    end,

    push_back = function(self, elem)
        while #self._callback_queue > 0 do
            local f = self._callback_queue:pop()
            if f then
                f(elem, nil)
                return
            end
        end

        self._elem_deque:push_back(elem)
    end,

    _pop_front = function(self, timeout, callback)
        if #self._elem_deque > 0 then
            local elem, err = self._elem_deque:pop_front()
            if callback then
                callback(elem, err)
            end
            return elem, err
        end

        if self:closed() then
            if callback then
                callback(nil, 'closed')
            end
            return nil, 'closed'
        end

        if callback then
            self:_push_callback(timeout, callback)
        end
        return nil, 'empty'
    end,

    _pop_back = function(self, timeout, callback)
        if #self._elem_deque > 0 then
            local elem, err = self._elem_deque:pop_back()

            if callback then
                callback(elem, err)
            end
            return elem, err
        end

        if self:closed() then
            if callback then
                callback(nil, 'closed')
            end
            return nil, 'closed'
        end

        if callback then
            self:_push_callback(timeout, callback)
        end
        return nil, 'empty'
    end,

    co_pop_back = function(self, timeout)
        local new_f = co_wrap(self._pop_back)
        return new_f(self, timeout)
    end,

    co_pop_front = function(self, timeout)
        local new_f = co_wrap(self._pop_front)
        return new_f(self, timeout)
    end,

    close = function(self, clean)
        self._elem_deque:close(clean)
        self._callback_queue:close(function(callback)
            callback(nil, 'closed')
        end)
    end,

    closed = function(self)
        return self._elem_deque:closed()
    end,

    __len = function(self)
        return #self._elem_deque
    end,

    _push_callback = function(self, timeout, callback)
        local called = false
        local cb = function(...)
            if called then
                return
            end
            called = true
            callback(...)
        end

        self._callback_queue:push(cb)
        if timeout then
            local back_index = self._callback_queue._back - 1  -- HACK the queue
            base.wait(timeout, function()
                self._callback_queue[back_index] = nil
                cb(nil, 'timeout')
            end)
        end
    end,
}

event_deque.__index = event_deque
event_deque.pop_front = event_deque._pop_front
event_deque.pop_back = event_deque._pop_back
event_deque.push = event_deque.push_back
event_deque.pop = event_deque._pop_front
event_deque.co_pop = event_deque.co_pop_front

---创建一个事件双端队列
---@return event_deque 新创建的事件双端队列
local function create_event_deque()
    return setmetatable({
        _elem_deque = create_deque(),
        _callback_queue = create_queue(),
    }, event_deque)
end

---事件队列类（单向队列）
---@class event_queue
---@field private _elem_deque table 元素双端队列
---@field private _callback_queue table 回调函数队列
---@field push fun(self:event_queue, elem:any) 将元素添加到队列
---@field pop fun(self:event_queue, timeout:number|nil, callback:fun(ret:any, err:string|nil)|nil):any,string|nil 从队列取出元素
---@field co_pop fun(self:event_queue, timeout:number|nil):any,string|nil 在协程中从队列取出元素
---@field __len fun(self:event_queue):number 获取队列长度
---@field close fun(self:event_queue, clean:function|nil) 关闭队列
---@field closed fun(self:event_queue):boolean 检查队列是否已关闭
local event_queue = {}
for k, v in pairs(event_deque) do
    event_queue[k] = v
end
event_queue.push_front = nil
event_queue.push_back = nil
event_queue.pop_front = nil
event_queue.pop_back = nil
event_queue.co_pop_front = nil
event_queue.co_pop_back = nil

event_queue.__index = event_queue

---创建一个事件队列（单向队列）
---@return event_queue 新创建的事件队列
local function create_event_queue()
    return setmetatable({
        _elem_deque = create_deque(),
        _callback_queue = create_queue(),
    }, event_queue)
end

base.event_queue = create_event_queue
base.event_deque = create_event_deque

---@class EventDequeModule
---@field create_event_deque fun():event_deque 创建一个事件双端队列
---@field create_event_queue fun():event_queue 创建一个事件队列（单向队列）

---@type EventDequeModule
return {
    create_event_deque = create_event_deque,
    create_event_queue = create_event_queue,
}