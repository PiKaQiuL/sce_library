local perf = require 'base.profiler'
local argv = require 'base.argv'
local setmetatable = setmetatable
local ipairs = ipairs
local pairs = pairs
local table_insert = table.insert
local math_max = math.max
local math_ceil = math.ceil
local math_floor = math.floor
local os_clock = os.clock
local FRAME = 1
local server_clock
local server_base_clock
local debug_traceback = debug.traceback
local debug_getinfo = debug.getinfo

local cur_frame = 0
local max_frame = 0
local cur_index = 0
local free_queue = {}
local timer = {}

local nexts = {}

local function update_next()
    local count = #nexts
    for i = 1, count do
        local next = nexts[i]
        if next then
            next.count = next.count + 1
            if next.count >= next.frame then
                nexts[i] = false
                next.cb()
            end
        end
    end

    for i = #nexts, 1, -1 do
        if nexts[i] == false then
            table.remove(nexts, i)
        end
    end
end

local function alloc_queue()
    local n = #free_queue
    if n > 0 then
        local r = free_queue[n]
        free_queue[n] = nil
        return r
    else
        return {}
    end
end

local function m_timeout(self, timeout, check_frame)
    if self.pause_remaining or self.running then
        return
    end
    local ti = cur_frame + timeout
    if check_frame and ti < max_frame then
        ti = math_ceil(max_frame) + 1
    end
    local q = timer[ti]
    if q == nil then
        q = alloc_queue()
        timer[ti] = q
    end
    self.timeout_frame = ti
    self.running = true
    self.current_time = 0     --计时器的流逝时间
    self.start_time = cur_frame --上次开始计时的时间
    q[#q + 1] = self
end

--不重置时间偏移量，使得用户通过api读取的时间保持正确
local function m_timeout_forSetTime(self, timeout)
    if self.pause_remaining or self.running then
        return
    end
    local ti = cur_frame + timeout
    local q = timer[ti]
    if q == nil then
        q = alloc_queue()
        timer[ti] = q
    end
    self.timeout_frame = ti
    self.running = true
    q[#q + 1] = self
end

local function m_wakeup(self)
    if self.removed then
        return
    end
    self.running = false
    if self.on_timer then
        self:on_timer()
    else
        -- TODO: 编辑器更新时, 有时会走到这里, 发现on_time是nil, 感觉像是哪个base.wait没有传回调函数进来
        log.error("@cxt, on_timer函数为空")
    end
    if self.removed then
        return
    end
    if self.timer_count then
        if self.timer_count > 1 then
            self.timer_count = self.timer_count - 1
            m_timeout(self, self.timeout)
        else
            self.removed = true
        end
    else
        m_timeout(self, self.timeout, self.loop_lazy)
    end
end

function get_remaining(self)
    if self.removed then
        return 0
    end
    if self.pause_remaining then
        return self.pause_remaining
    end
    if self.timeout_frame <= cur_frame then
        return 0
    end
    return self.timeout_frame - cur_frame
end

local function on_tick()
    local q = timer[cur_frame]
    if q == nil then
        cur_index = 0
        return
    end
    local q_len = #q
    for i = cur_index + 1, q_len do
        local callback = q[i]
        cur_index = i
        q[i] = nil
        if callback then
            xpcall(
                m_wakeup,
                function(err)
                    log.error(fmt("on_tick error: %s", debug_traceback(err)))
                end,
                callback
            )
        end
    end
    cur_index = 0
    timer[cur_frame] = nil
    free_queue[#free_queue + 1] = q
end

function base.clock()
    return cur_frame
end

function base.event.on_tick(delta)
    if cur_index ~= 0 then
        error 'cur_index ~= 0'
        cur_frame = cur_frame - 1 -- 上一逻辑帧没执行完, 退回1帧
        delta = delta + 1   -- 补1帧
    end
    max_frame = max_frame + delta
    while cur_frame < max_frame do
        cur_frame = cur_frame + 1
        on_tick()
    end
end

Timer = base.tsc.__TS__Class()
Timer.name = 'Timer'

local mt = Timer.prototype
mt.type = 'timer'

function mt:__tostring()
    return '[table:timer]'
end

function mt:remove()
    self.removed = true
end

function mt:pause()
    if self.removed or self.pause_remaining then
        return
    end
    self.current_time = self:get_current()
    self.start_time = -1
    self.pause_remaining = get_remaining(self)
    self.running = false
    local ti = self.timeout_frame
    local q = timer[ti]
    if q then
        for i = #q, 1, -1 do
            if q[i] == self then
                q[i] = false
                return
            end
        end
    end
end

function mt:resume()
    if self.removed or not self.pause_remaining then
        return
    end
    self.start_time = cur_frame - self.current_time
    self.current_time = nil
    local timeout = self.pause_remaining
    self.pause_remaining = nil
    m_timeout(self, timeout)
end

function mt:restart()
    if self.removed or self.pause_remaining or not self.running then
        return
    end
    local ti = self.timeout_frame
    local q = timer[ti]
    if q then
        for i = #q, 1, -1 do
            if q[i] == self then
                q[i] = false
                break
            end
        end
    end
    self.running = false
    m_timeout(self, self.timeout)
end

function mt:get_current()
    if self.start_time == -1 then --暂停时返回当前值
        return self.current_time
    end
    return cur_frame - self.start_time
end

function mt:get_current_time()
    return self:get_current() / 1000
end

function mt:set_current_time(NewTime)
    NewTime = NewTime * 1000
    local tmp = get_remaining(self) - (NewTime - self:get_current())
    if self.start_time == -1 then
        self.current_time = NewTime
    else
        self.start_time = cur_frame - NewTime
    end
    self:set_remaining_time(tmp / 1000)
end

function mt:get_remaining_time()
    return get_remaining(self)
end

function mt:get_remaining_time_new()
    return get_remaining(self) / 1000
end

function mt:set_remaining_time(NewTime)
    NewTime = NewTime * 1000
    if self.removed then
        return
    end
    if NewTime == self:get_remaining_time() then
        return
    end
    local q = timer[self.timeout_frame]
    if q then
        for i = #q, 1, -1 do
            if q[i] == self then
                q[i] = false
            end
        end
    end
    if NewTime <= 0 then
        self.timeout_frame = cur_frame
        m_wakeup(self)
    else
        self.running = false
        m_timeout_forSetTime(self, NewTime)
    end
end

if argv.has('inner') then
    function base.wait(timeout, on_timer, timer)
        local t = setmetatable({
            ['timeout'] = math_max(math_floor(timeout), 1),
            ['on_timer'] = on_timer,
            ['timer_count'] = 1,
            ['stack_info'] = {
                filename = debug_getinfo(2, 'S').source,
                line = debug_getinfo(2, 'l').currentline
            },
        }, mt)
        m_timeout(t, t.timeout)
        return t
    end

    ---@param timeout number
    ---@param on_timer fun()
    ---@return Timer
    function base.loop(timeout, on_timer)
        if timeout < FRAME then
            error('循环计时器周期不能小于一帧')
            return
        end
        local t = setmetatable({
            ['timeout'] = math_floor(timeout),
            ['on_timer'] = on_timer,
            ['stack_info'] = {
                filename = debug_getinfo(2, 'S').source,
                line = debug_getinfo(2, 'l').currentline
            },
        }, mt)
        m_timeout(t, t.timeout)
        return t
    end

    base.game:event('按键-松开', function(_, key)
        if key == 'F10' then
            log_file.info('dump timer info - begin')

            for frame, _ in pairs(timer) do
                -- log_file.info(frame)
                log_file.info('frame', frame)
                local q = timer[frame]
                if q ~= nil then
                    for i = 1, #q do
                        local callback = q[i]
                        if callback and not callback.removed then
                            log_file.info('timer info: ', callback.stack_info.filename, callback.stack_info.line)
                        end
                    end
                end
            end

            log_file.info('dump timer info - end')
        end
    end)
else
    function base.wait(timeout, on_timer)
        local t = setmetatable({
            ['timeout'] = math_max(math_floor(timeout), 1),
            ['on_timer'] = on_timer,
            ['timer_count'] = 1,
        }, mt)
        m_timeout(t, t.timeout)
        return t
    end

    ---@param timeout number
    ---@param on_timer fun()
    ---@return Timer
    function base.loop(timeout, on_timer)
        if timeout < FRAME then
            error('循环计时器周期不能小于一帧')
            return
        end
        local t = setmetatable({
            ['timeout'] = math_floor(timeout),
            ['on_timer'] = on_timer,
        }, mt)
        m_timeout(t, t.timeout)
        return t
    end
end

function base.loop_lazy(timeout, on_timer)
    local t = base.loop(timeout, on_timer)
    if t then
        t['loop_lazy'] = true
    end
    return t
end

function base.next(cb)
    table.insert(nexts, {
        count = 0,
        frame = 2,
        cb = cb
    })
end

function base.timer(timeout, count, on_timer)
    if count == 0 then
        return base.loop(timeout, on_timer)
    end
    if timeout < FRAME then
        error('循环计时器周期不能小于一帧')
        return nil
    end
    local t = setmetatable({
        ['timeout'] = math_floor(timeout),
        ['on_timer'] = on_timer,
        ['timer_count'] = count,
    }, mt)
    m_timeout(t, t.timeout)
    return t
end

local function utimer_initialize(u)
    if not u._timers then
        u._timers = {}
    end
    if #u._timers > 0 then
        return
    end
    u._timers[1] = base.loop(10000, function()
        local timers = u._timers
        for i = #timers, 2, -1 do
            if timers[i].removed then
                local len = #timers
                timers[i] = timers[len]
                timers[len] = nil
            end
        end
        if #timers == 1 then
            timers[1]:remove()
            timers[1] = nil
        end
    end)
end

function base.uwait(u, timeout, on_timer)
    utimer_initialize(u)
    local t = base.wait(timeout, on_timer)
    table_insert(u._timers, t)
    return t
end

function base.uloop(u, timeout, on_timer)
    utimer_initialize(u)
    local t = base.loop(timeout, on_timer)
    table_insert(u._timers, t)
    return t
end

function base.utimer(u, timeout, count, on_timer)
    utimer_initialize(u)
    local t = base.timer(timeout, count, on_timer)
    table_insert(u._timers, t)
    return t
end

local warning = 100
function base.set_timer_warning(w)
    warning = w
end

local function on_update(delta)
    delta = delta * 1000
    local p = perf.new()
    p:start()
    base.event.on_tick(delta)
    p:finish()
    local used = p:get_used()
    if used > warning then
        print(("调用定时器耗时过高 : %f ms"):format(used))
    end
    common.profile_begin_block('update_notify')
    base.game:event_notify('游戏-更新', delta)
    common.profile_end_block()
    common.profile_begin_block('on_ui_tick')
    base.event.on_ui_tick(delta)
    common.profile_end_block()
    common.profile_begin_block('update_next')
    update_next()
    common.profile_end_block()
end

local clocks = {}
function base.event.on_update(delta)
    -- local start = os_clock()
    on_update(delta)
    -- local finish = os_clock()
    -- local i = #clocks
    -- if i == 0 then
    -- 	clocks[1] = finish - start
    -- 	clocks.start = start
    -- 	clocks.finish = finish
    -- else
    -- 	clocks[i+1] = finish - start
    -- 	clocks.finish = finish
    -- end
end

function base.event.on_post_update(delta)
    base.game:event_notify('on_post_update', delta)
end

function base.event.on_prerender_update(delta)
    base.game:event_notify('on_prerender_update', delta)
end

function base.event.on_server_clock(clock)
    if not server_base_clock then
        -- 如果是第一帧，则记录基准时间
        server_base_clock = clock
    end
    server_clock = clock
end

function base.timer_info()
    return {
        timer = timer,
        clocks = clocks,
    }
end

return {
    Timer = Timer,
}
