-- 耗时统计

local function time()
    return common.get_system_time()
end

local profiler = {}

function profiler.new()
    return setmetatable({
        used = 0,
        last = 0,
        finished = false
    },{
        __index = profiler
    })
end

function profiler:start()
    self.finished = false
    self.last = time()
end

function profiler:finish()
    if self.finished then return end
    self.finished = true
    self.used = self.used + (time() - self.last)
    self.last = 0
end

function profiler:get_used()
    return self.used
end

function profiler:get_elapse()
    return time() - self.last
end

function profiler:reset()
    self.used = 0
    self.last = 0
    self:start()
end

return profiler

