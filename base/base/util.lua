---在数组中查找指定值的索引位置
---@param array table 要搜索的数组
---@param value any 要查找的值
---@return number 如果找到则返回索引位置，否则返回-1
    for i, cur in ipairs(array) do
        if cur == value then
            return i
        end
    end
    return -1;
end

---计算表中元素的数量
---@param array table 要计算元素数量的表
---@return number 表中元素的数量
local function elem_count(array)
    local count = 0
    for key, value in pairs(array) do
        count = count + 1
    end
    return count
end

---将字符串按指定分隔符分割成数组
---@param str string 要分割的字符串
---@param sep string|nil 分隔符，默认为空格
---@return table|nil 分割后的字符串数组，如果输入不是字符串则返回nil
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

---获取路径的最后一部分（文件名或最后一级目录名）
---@param path string 文件路径
---@return string|nil 路径的最后一部分，如果无法解析则返回nil
local function path_last_part(path)
    path = path:gsub('\\', '/')
    local li = split(path, '/')
    if #li > 0 then
        return li[#li]
    end

    return nil
end

---检查字符串是否以指定前缀开头
---@param str string 要检查的字符串
---@param prefix string 前缀字符串
---@return boolean 如果字符串以指定前缀开头则返回true，否则返回false
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

---获取路径的父目录
---@param path string 文件路径
---@return string|nil 父目录路径，如果无法解析则返回nil
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

---过滤数组元素
---@param arr table 要过滤的数组
---@param f fun(item:any):boolean 过滤函数，返回true表示保留该元素
---@return table 过滤后的新数组
local function filter(arr, f)
    local ret = {}
    for _, item in ipairs(arr) do
        if f(item) then
            ret[#ret + 1] = item
        end
    end
    return ret
end

---映射数组元素
---@param arr table 要映射的数组
---@param f fun(item:any):any 映射函数，将数组元素转换为新值
---@return table 映射后的新数组
local function map(arr, f)
    local ret = {}
    for _, item in ipairs(arr) do
        ret[#ret + 1] = f(item)
    end
    return ret
end

---遍历树结构
---@param tree table 树结构
---@param f fun(node:table) 对每个节点执行的函数
local function walk(tree, f)
    f(tree)
    for _, child in ipairs(tree) do
        walk(child, f)
    end
end


---@class UtilModule
---@field split fun(str:string, sep?:string):table|nil 将字符串按指定分隔符分割成数组
---@field filter fun(arr:table, f:fun(item:any):boolean):table 过滤数组元素
---@field map fun(arr:table, f:fun(item:any):any):table 映射数组元素
---@field walk fun(tree:table, f:fun(node:table)) 遍历树结构
---@field path_last_part fun(path:string):string|nil 获取路径的最后一部分
---@field path_parent fun(path:string):string|nil 获取路径的父目录
---@field indexOf fun(array:table, value:any):number 在数组中查找指定值的索引位置
---@field elem_count fun(array:table):number 计算表中元素的数量
---@field is_prefix fun(str:string, prefix:string):boolean 检查字符串是否以指定前缀开头

---@type UtilModule
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