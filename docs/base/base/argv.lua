---@meta _

---
--- SCE Library 命令行参数处理模块
--- 提供命令行参数的解析和处理功能
---

---获取命令行参数
---@param name string 参数名称
---@param default_value? any 默认值，当参数不存在时返回此值
---@return any 参数值或默认值
function get_arg(name, default_value) end

---检查命令行参数是否存在
---@param name string 参数名称
---@return boolean 如果参数存在则返回true，否则返回false
function has_arg(name) end

---获取所有命令行参数
---@return table 包含所有参数的表，键为参数名，值为参数值
function get_all_args() end

---解析命令行参数
---@param args string[] 命令行参数数组
---@return table 解析后的参数表
function parse_args(args) end