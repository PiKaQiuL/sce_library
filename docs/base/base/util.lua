---@meta _

---
--- SCE Library 实用工具函数
--- 提供各种常用的工具函数，用于数组操作、字符串处理和路径处理等
---

---在数组中查找指定值的索引位置
---@param array table 要搜索的数组
---@param value any 要查找的值
---@return number 如果找到则返回索引位置，否则返回-1
function array_find(array, value) end

---计算表中元素的数量
---@param array table 要计算元素数量的表
---@return number 表中元素的数量
function elem_count(array) end

---将字符串按指定分隔符分割成数组
---@param str string 要分割的字符串
---@param sep string|nil 分隔符，默认为空格
---@return table|nil 分割后的字符串数组，如果输入不是字符串则返回nil
function split(str, sep) end

---获取路径的最后一部分（文件名或最后一级目录名）
---@param path string 文件路径
---@return string|nil 路径的最后一部分，如果无法解析则返回nil
function path_last_part(path) end

---检查字符串是否以指定前缀开头
---@param str string 要检查的字符串
---@param prefix string 前缀字符串
---@return boolean 如果字符串以指定前缀开头则返回true，否则返回false
function is_prefix(str, prefix) end

---获取路径的父目录
---@param path string 文件路径
---@return string|nil 父目录路径，如果无法解析则返回nil
function path_parent(path) end

---过滤数组元素
---@param arr table 要过滤的数组
---@param f fun(item:any):boolean 过滤函数，返回true表示保留该元素
---@return table 过滤后的新数组
function filter(arr, f) end

---映射数组元素
---@param arr table 要映射的数组
---@param f fun(item:any):any 映射函数，将数组元素转换为新值
---@return table 映射后的新数组
function map(arr, f) end

---遍历树结构
---@param tree table 树结构
---@param f fun(node:table) 对每个节点执行的函数
function walk(tree, f) end