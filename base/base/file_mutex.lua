

local file_mutex = {}
local co = require 'base.co'
local io_remove = io.remove

function file_mutex:get_lock_name()
    return tostring(self.path) .. '.lock'
end


function file_mutex:try_lock()
    local lock_file = self:get_lock_name()
    if io.exist_file(lock_file) then
        return false
    end
    self.lock = true
    io.write(lock_file, '')
    return true
end

function file_mutex:wait(ms)
    local _, main = coroutine.running()
    if not main then
        co.sleep(ms)
    end
end

function file_mutex:lock(spin)
    log.info('try lock', self.path)
    while not self:try_lock() do
        if not spin then
            self:wait(1000)
        end
    end
    log.info('lock', self.path)
end

function file_mutex:unlock()
    if self.lock then
        log.info('unlock', self.path)
        self.lock = false
        io_remove(self:get_lock_name())
    end
end

local function create(path)
    return setmetatable({ path = tostring(path)}, { __index = file_mutex, __gc = file_mutex.unlock})
end

return {
    create = create
}



