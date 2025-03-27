---@meta
--- 提供JSON解析功能
--- @module 'base.json_load'
--- @copyright SCE
--- @license MIT

---@type table LPeg库，用于解析表达式语法
local lpeg = require 'lpeglabel'
---@type boolean|nil 是否保持键的排序
local save_sort
---@type function 打包表参数的函数
local table_pack = table.pack

local P = lpeg.P
local S = lpeg.S
local R = lpeg.R
local V = lpeg.V
local C = lpeg.C
local Ct = lpeg.Ct
local Cg = lpeg.Cg
local Cc = lpeg.Cc
local Cp = lpeg.Cp
local Cs = lpeg.Cs

---转义字符映射表
---@type table<string, string>
local EscMap = {
    ['t']  = '\t',
    ['r']  = '\r',
    ['n']  = '\n',
    ['"']  = '"',
    ['\\'] = '\\',
}

---布尔值字符串映射表
---@type table<string, boolean>
local BoolMap = {
    ['true']  = true,
    ['false'] = false,
}

---哈希表元表，用于保持键的排序
---@class HashTableMetatable
---@field __pairs fun(self:table):function 迭代器函数
---@field __newindex fun(self:table, k:any, v:any) 设置新索引的函数
---@field __debugger_extand fun(self:table):table 调试器扩展函数

---@type HashTableMetatable
local hashmt = {
    ---自定义pairs迭代器，按照插入顺序遍历
    ---@param self table 哈希表
    ---@return function 迭代器函数
    __pairs = function (self)
        local i = 1
        local function next()
            i = i + 1
            local k = self[i]
            if k == nil then
                return
            end
            local v = self[k]
            if v == nil then
                return next()
            end
            return k, v
        end
        return next
    end,
    
    ---自定义设置新索引的行为，保持插入顺序
    ---@param self table 哈希表
    ---@param k any 键
    ---@param v any 值
    __newindex = function (self, k, v)
        local i = 2
        while self[i] do
            i = i + 1
        end
        rawset(self, i, k)
        rawset(self, k, v)
    end,
    
    ---调试器扩展函数
    ---@param self table 哈希表
    ---@return table 扩展后的列表
    __debugger_extand = function (self)
        local list = {}
        for k, v in pairs(self) do
            k = tostring(k)
            list[#list+1] = k
            list[k] = v
        end
        return list
    end,
}

local tointeger = math.tointeger
local tonumber = tonumber
local setmetatable = setmetatable
local rawset = rawset

---创建一个哈希表解析器
---@param patt any LPeg模式
---@return function 解析函数
local function HashTable(patt)
    return C(patt) / function (_, ...)
        local hash = table_pack(...)
        local n = hash.n
        hash.n = nil
        if save_sort then
            local max = n // 2
            for i = 1, max do
                local key, value = hash[2*i-1], hash[2*i]
                hash[key] = value
                hash[i+1] = key
            end
            hash[1] = nil
            for i = max+2, max*2 do
                hash[i] = nil
            end
            return setmetatable(hash, hashmt)
        else
            local max = n // 2
            for i = 1, max do
                local a = 2*i-1
                local b = 2*i
                local key, value = hash[a], hash[b]
                hash[key] = value
                hash[a] = nil
                hash[b] = nil
            end
            return hash
        end
    end
end

local Token = P
{
    V'Value' * Cp(),
    Nl     = P'\r\n' + S'\r\n',
    Sp     = S' \t',
    Spnl   = (V'Sp' + V'Nl')^0,
    Bool   = C(P'true' + P'false') / BoolMap,
    Int    = C('0' + (P'-'^-1 * R'19' * R'09'^0)) / tointeger,
    Float  = C(P'-'^-1 * ('0' + R'19' * R'09'^0) * '.' * R'09'^0) / tonumber,
    Null   = P'null' * Cc(nil),
    String = '"' * Cs(V'Char'^0) * '"',
    Char   = V'Esc' + (1 - P'"' - P'\t' - V'Nl'),
    Esc    = P'\\' * C(S'tnr"\\') / EscMap,
    Hash   = V'Spnl' * '{' * V'Spnl' * HashTable(V'Object'^-1 * (P',' * V'Object')^0) * V'Spnl' * P'}'^-1 * V'Spnl',
    Array  = V'Spnl' * '[' * V'Spnl' * Ct(V'Value'^-1 * (P',' * V'Spnl' * V'Value')^0) * V'Spnl' * P']'^-1 * V'Spnl',
    Object = V'Spnl' * V'Key' * V'Spnl' * V'Value' * V'Spnl',
    Key    = V'String' * V'Spnl' * ':',
    Value  = V'Hash' + V'Array' + V'Bool' + V'Null' + V'String' + V'Float' + V'Int',
}

return function (str, save_sort_)
    save_sort = save_sort_
    local table, pos = Token:match(str)
    if not table or pos <= #str then
        pos = tonumber(pos) or 1
        error(('没匹配完[%s]\n%s'):format(pos, str:sub(pos, pos+100)))
    end
    return table
end
