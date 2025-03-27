---@return number
local function indexOf(array, value)
    for i, cur in ipairs(array) do
        if cur == value then
            return i
        end
    end
    return -1;
end

local function elem_count(array)
    local count = 0
    for key, value in pairs(array) do
        count = count + 1
    end
    return count
end

local function split(str, sep)
    if type(str) ~= 'string' then
        return nil
    end
    sep = sep or ' '
    local reg = '[^%' .. sep .. ']+'
    local result = {}
    for sub in string.gmatch(str, reg) do
        table.insert(result, sub)
    end
    if #result == 0 then result = {str} end
    return result
end

local function path_last_part(path)
    path = path:gsub('\\', '/')
    local li = split(path, '/')
    if #li > 0 then
        return li[#li]
    end

    return nil
end

local function is_prefix(str, prefix)
    if type(str) ~= "string" or type(prefix) ~= "string" then
        return false
    end
    -- 获取前缀和字符串的长度
    local str_len = #str
    local prefix_len = #prefix
    -- 如果前缀的长度大于字符串的长度，则不可能是前缀
    if prefix_len > str_len then
        return false
    end
    if str:sub(1, prefix_len) ~= prefix then
        return false
    end
    return true
end

local function path_parent(path)
    path = path:gsub('\\', '/')
    local len = #path
    for i = len, 1, -1 do
        if path:sub(i,i) == '/' and i ~= len then
            local res = path:sub(1, i-1)
            if res == "" then
                return nil
            else
                return res
            end
        end
    end
    return nil
end

local function filter(arr, f)
    local ret = {}
    for _, item in ipairs(arr) do
        if f(item) then
            ret[#ret + 1] = item
        end
    end
    return ret
end

local function map(arr, f)
    local ret = {}
    for _, item in ipairs(arr) do
        ret[#ret + 1] = f(item)
    end
    return ret
end

local function walk(tree, f)
    f(tree)
    for _, child in ipairs(tree) do
        walk(child, f)
    end
end


return {
    split = split,
    filter = filter,
    map = map,
    walk = walk,
    path_last_part = path_last_part,
    path_parent = path_parent,
    indexOf = indexOf,
    elem_count = elem_count,
    is_prefix = is_prefix
}