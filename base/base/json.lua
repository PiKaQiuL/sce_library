
---@meta
--- 提供JSON编码和解码功能
--- @module 'base.json'
--- @copyright SCE
--- @license MIT

---@type fun(t:table, needSort?:boolean):string 将表编码为JSON字符串
local old_encode = require 'base.json_save'
---@type fun(json_str:string, save_sort?:boolean):table 将JSON字符串解码为表
local old_decode = require 'base.json_load'
---@type fun(json_str:string):table|nil 将JSON字符串解码为表（新实现）
local new_decode = common.json_decode
if not new_decode then
    log.info('old_decode')
    new_decode = old_decode
end

base.json = {
    decode = function(json_str, save_sort)
        if save_sort then
            return old_decode(json_str, save_sort)
        end
        return new_decode(json_str)
    end,
    encode = function(t, needSort) return common.json_encode and common.json_encode(t, needSort ~= false) or old_encode(t) end
}
