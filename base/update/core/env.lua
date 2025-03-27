
local env = 'test'

local function get()
    return env
end

local function set(e)
    env = e
end

return {
    get = get,
    set = set
}