local function create_list_pool()
    local list_pool = {}
    local using_list = {}
    local list_pool_len = 0

    local function list_release(list)
        if using_list[list] then
            using_list[list] = nil
        end
        return list
    end

    local function list_resize(list, size)
        for i = size + 1, #list do
            list[i] = nil
        end
        return list
    end

    local function get_list(not_lock)
        local list
        for i = 1, list_pool_len + 1 do
            local l = list_pool[i]
            if not using_list[l] then
                list = l break
            end
        end
        if not list then
            list = {
                release = list_release,
                resize = list_resize,
            }
            list_pool_len = list_pool_len + 1
            list_pool[list_pool_len] = list
        end
        if not not_lock then
            using_list[list] = true
        end
        return list
    end
    return get_list
end

local function cache_table(get_value, default)
    local t = {}
    return setmetatable(t, {
        __index = function(self, k)
            if k == nil then return default end
            local v = get_value(k)
            if v == nil then v = default end
            self[k] = v
            return v
        end,
    })
end

return {
    create_list_pool = create_list_pool,
    cache_table = cache_table,
}