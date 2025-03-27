local binding_prop_map = {
    {format = '%.0f'},
    {format = '%.1f'},
    {format = '%.2f'},
    {format = '%.0f%%', multiple = 100},
    {},
}


local function set_prop(selectors, key, value)
    local index = selectors.index or #binding_prop_map
    local f = binding_prop_map[index].format or selectors.format
    if type(value) == 'number' then
        value = value * (binding_prop_map[index].multiple or 1)
    end
    local selector = selectors.selector
    local label
    xpcall(
        function (...)
            label = f and value and string.format(f, value) or value
        end,
        function (err)
            label = value
            log_file.info()
            log_file.warn('属性绑定格式化失败!', '属性:', key, '格式:', f, err)
        end
    )
    selector:set(label)
    if #selector:collect_ctrl(true) == 0 then
        table.remove(selectors, i)
    end
end

local function get_value(k, v, f, index)
    index = index or #binding_prop_map
    f = binding_prop_map[index].format or f
    if type(v) == 'number' then
        v = v * (binding_prop_map[index].multiple or 1)
    end
    xpcall(
        function (...)
            v = f and v and string.format(f, v) or v
        end,
        function (err)
            log_file.warn('属性绑定格式化失败!', '属性:', k, '格式:', f, err)
        end
    )
    return v
end

return {
    set_prop = set_prop,
    get_value = get_value,
}