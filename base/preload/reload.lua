local table_insert = table.insert
local package_loaded = package.loaded
local ipairs = ipairs
local xpcall = xpcall
local to_unique_name = to_unique_name
local require = require

local reload_list = {}
local reloading = false
local reload_start = {}
local reload_finish = {}

local function raw_include(filename, lib_env)
    local _, unique_name, _ = to_unique_name(filename, lib_env)

    if not reload_list[unique_name] then
        local reload_info = {filename = filename, lib_env = lib_env}
        reload_list[#reload_list + 1] = reload_info
        reload_list[unique_name] = reload_info
    end

    -- 不管这个require是哪个lib的, 总之已经传了lib_env了, 用不到require的upvalue了
    if reloading then
        log.debug('reload: '.. unique_name)
    end
    return require(filename, lib_env)
end

local reload_event = function(name, on_start, on_finish)
    if not name then
        error "must input reload_event name!"
    end
    if on_start then
        local index = reload_start[name]
        if not index then
            index = #reload_start + 1
            reload_start[name] = index
        end

        reload_start[index] = on_start
    end

    if on_finish then
        local index = reload_finish[name]
        if not index then
            index = #reload_finish + 1
            reload_finish[name] = index
        end
        reload_finish[index] = on_finish
    end
end

local function reload()
    log.debug('---- Reloading start ----')
    reloading = true

    for _, func in ipairs(reload_start) do
        xpcall(func, log.error)
    end

    local list = reload_list
    reload_list = {}

    local call_list = {}

    for i, reload_info in ipairs(list) do
        local _, unique_name, _ = to_unique_name(reload_info.filename, reload_info.lib_env)
        package_loaded[unique_name] = nil
        table_insert(call_list, function()
            raw_include(reload_info.filename, reload_info.lib_env)
        end)
    end

    for _, call in ipairs(call_list) do
        xpcall(call, log.error)
    end

    for _, func in ipairs(reload_finish) do
        xpcall(func, log.error)
    end

    reloading = false
    log.debug('---- Reloading finish ----')
end

return {
    raw_include = raw_include,
    reload = reload,
    reload_event = reload_event,
}
