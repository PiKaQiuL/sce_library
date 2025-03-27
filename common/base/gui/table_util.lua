local type = type

local function iterate_table_recursively_bf(t, fn)
    local queue = {{0, nil, t}}
    local queue_begin = 1
    while queue_begin <= #queue  do
        local front = queue[queue_begin]
        local parent_idx = front[1]
        local key = front[2]
        local t = front[3]

        if fn(key, t, queue[parent_idx], queue) then
            if type(t) == 'table' then
                for key, value in pairs(t) do -- 下一层
                    if key ~= '__index' and type(key) == 'string' then
                        table.insert(queue, {queue_begin, key, value})
                    end
                end
            end
        end

        queue_begin = queue_begin + 1
    end
end

local function get_prop(t, prop_name)
    local prop_type = type(prop_name)
    if prop_type == 'string' then
        prop_name = {prop_name}
    elseif prop_type ~= 'table' then
        return
    end
    if #prop_name == 0 then
        return t
    end
    local target = t
    local i = 0
    local endi = #prop_name
    while type(target) == 'table' do
        i = i + 1
        target = target[prop_name[i]]
        if i >= endi  then
            return target
        end
    end
    return nil
end


return {
    iterate_table_recursively_bf = iterate_table_recursively_bf,
    get_prop = get_prop,
}
