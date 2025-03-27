---@meta
--- 提供队列和双端队列的基础实现
--- @module 'base.deque'
--- @author xindong
--- @copyright SCE
--- @license MIT
_G.base = _G.base or {}

---双端队列类
---@class deque
---@field private _front number 前端索引
---@field private _back number 后端索引
---@field private _closed boolean 是否已关闭
---@field push_front fun(self:deque, elem:any) 将元素添加到队列前端
---@field pop_front fun(self:deque):any,string|nil 从队列前端取出元素
---@field push_back fun(self:deque, elem:any) 将元素添加到队列后端
---@field pop_back fun(self:deque):any,string|nil 从队列后端取出元素
---@field close fun(self:deque, clean:function|nil) 关闭队列
---@field closed fun(self:deque):boolean 检查队列是否已关闭
local deque = {
    _front = 1,
    _back = 2,
    _closed = false,
    push_back = function(self, elem)
        if self._closed then
            error 'deque has closed'
        end
        self[self._back] = elem
        self._back = self._back + 1
    end,
    push_front = function(self, elem)
        if self._closed then
            error 'deque has closed'
        end
        self[self._front] = elem
        self._front = self._front - 1
    end,
    pop_back = function(self)
        if self._back -1 > self._front then
            self._back = self._back - 1
            local ret = self[self._back]
            self[self._back] = nil
            return ret, nil
        else
            return nil, self._closed and 'closed' or 'empty'
        end
    end,
    pop_front = function(self)
        if self._front < self._back - 1 then
            self._front = self._front + 1
            local ret = self[self._front]
            self[self._front] = nil
            return ret, nil
        else
            return nil, self._closed and 'closed' or 'empty'
        end
    end,
    __len = function(self)
        return self._back - self._front - 1
    end,

    close = function(self, clean, recursive_clean)
        self._closed = true
        if clean then
            local pop = recursive_clean and self.pop_back or self.pop_front
            while #self > 0 do
                local elem = pop(self)
                if elem and type(clean) == 'function' then
                    xpcall(clean, log.error, elem)
                end
            end
        end
    end,

    closed = function(self)
        return self._closed
    end,

    back = function(self)
        return self[self._back - 1]
    end,

    front = function(self)
        return self[self._front + 1]
    end
}

deque.__index = deque
deque.pop = deque.pop_front
deque.push = deque.push_back

---@return deque
local function create_deque()
    return setmetatable({}, deque)
end

---队列类（单向队列）
---@class queue
---@field private _front number 前端索引
---@field private _back number 后端索引
---@field private _closed boolean 是否已关闭
---@field push fun(self:queue, elem:any) 将元素添加到队列
---@field pop fun(self:queue):any,string|nil 从队列取出元素
---@field close fun(self:queue, clean:function|nil) 关闭队列
---@field closed fun(self:queue):boolean 检查队列是否已关闭
local queue = {}
for k, v in pairs(deque) do
    queue[k] = v
end
queue.push_back = nil
queue.push_front = nil
queue.pop_back = nil
queue.pop_front = nil

---@return queue
local function create_queue()
    return setmetatable({}, queue)
end

base.queue = create_queue
base.deque = create_deque


---@class DequeModule
---@field create_deque fun():deque 创建一个双端队列
---@field create_queue fun():queue 创建一个队列（单向队列）

---@type DequeModule
return {
    create_deque = create_deque,
    create_queue = create_queue,
}