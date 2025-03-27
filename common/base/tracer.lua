
local profiler = include 'base.profiler'

local depth = {}

function depth.new(arg)
    return setmetatable({
        limit = arg.limit or 100,
        current = 0,
        max = 0,
    }, {__index = depth})
end

local tracer = {}

local function default_filter(time) 
    return time > 0 
end

function tracer.new(arg)
    arg = arg or {}
    return setmetatable({
        depth = depth.new(arg.depth or {}),
        filter = arg.filter or default_filter,
        tree = { children = { } },
        current = nil
    }, {__index = tracer})
end

function tracer:process(obj, level)
    local array = {}
    local col_len = math.min(self.depth.limit, self.depth.max) * 2 + 20
    for k, v in pairs(obj) do
        array[#array+1] = v
    end
    table.sort(array, function(a, b) return a.profiler:get_used() > b.profiler:get_used() end)
    for _, v in pairs(array) do
        local used = v.profiler:get_used()
        if self.filter(used) then
            self.result = self.result .. '\r\n'
            local line = ''
            for i = 1, level do
                line = line .. '--'
            end
            line = line .. ' ' .. v.name
            if line:len() < col_len then
                for i = line:len(), col_len do
                    line = line .. ' '
                end
            end
            line = ('%s\t%.2fms\t%d'):format(line, used, v.count)
            self.result = self.result .. line
            if v.children then
                self:process(v.children, level + 1)
            end
        end
    end
end

function tracer:output()
    self.result = ''
    self:process(self.tree.children, 0)
    log_file.info(self.result)
    print(self.result)
end

function tracer:pause()
    local current = self.current
    while current and current.profiler do
        current.profiler:finish()
        current = current.parent
    end
end

function tracer:resume()
    local current = self.current
    while current and current.profiler do
        current.profiler:start()
        current = current.parent
    end
end

local max = math.max

function tracer:__hook(e)

    self:pause()
    local current = self.current
    local info = debug.getinfo(3, 'nS')
    local name = (info.name or 'null') .. ':' .. info.linedefined
    local depth = self.depth

    if e == 'call' or e == 'tail call' then
        -- print('--> ', name)
        depth.current = depth.current + 1
        depth.max = max(depth.max, depth.current)
        if depth.current > depth.limit then return end
        local children = current.children
        if children[name] then
            self.current = children[name]
            local current = self.current
            current.count = current.count + 1
        else
            local child = { name = name, children = { } }
            child.parent = self.current
            child.count = 1
            child.profiler = profiler.new()
            self.current.children[name] = child
            self.current = child
        end
        self:resume()
    elseif e == 'return' then
        -- print('<--', name)
        if depth.current == 0 then return end
        depth.current = depth.current - 1
        if depth.current + 1 > depth.limit then return end
        self.current = current.parent
    end
end

function tracer:start()
    self.current = self.tree
    local proxy = function(e) self.__hook(self, e) end
    debug.sethook(proxy, 'cr')
end

function tracer:finish()
    debug.sethook()
    while self.current ~= self.tree do
        self.current.profiler:finish()
        self.current = self.current.parent
    end
    self:output()
end

return tracer