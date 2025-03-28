---@meta _

---
--- SCE Library JSON处理模块
--- 提供JSON数据的编码和解码功能
---

---将Lua对象编码为JSON字符串
---@param obj any 要编码的Lua对象
---@param pretty? boolean 是否格式化输出，默认为false
---@return string JSON字符串
function encode(obj, pretty) end

---将JSON字符串解码为Lua对象
---@param json_str string JSON字符串
---@return any 解码后的Lua对象
function decode(json_str) end

---将Lua对象保存为JSON文件
---@param obj any 要保存的Lua对象
---@param file_path string 文件路径
---@param pretty? boolean 是否格式化输出，默认为false
---@return boolean 是否保存成功
function save(obj, file_path, pretty) end

---从JSON文件加载Lua对象
---@param file_path string 文件路径
---@return any 加载的Lua对象
---@return string|nil 错误信息，如果加载成功则为nil
function load(file_path) end