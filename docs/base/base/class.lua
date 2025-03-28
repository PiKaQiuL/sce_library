---@meta _

---
--- SCE Library 类系统
--- 提供面向对象编程支持，允许创建类、继承和实例化对象
---

---@class SCEContext
---@field ClassMap table 类映射表，存储所有类的继承关系

---@class ClassMetatable
---@field __cname string 类名
---@field __ctype number 类型(1:C++对象, 2:Lua对象)
---@field __index table 元表索引
---@field __supper_map table<table, boolean> 父类映射表
---@field super table|nil 父类
---@field class table 类引用
---@field ctor function 构造函数
---@field new function 创建实例的函数
---@field class_name function 获取类名的函数

---创建一个新类
---@param classname string 类名
---@param super table|string|function|nil 父类，可以是类对象、类名字符串或C++创建函数
---@return ClassMetatable 新创建的类
function class(classname, super) end

---检查对象是否是指定类的实例
---@param obj any 要检查的对象
---@param classname string 类名
---@return boolean 如果对象是指定类的实例则返回true，否则返回false
function iskindof(obj, classname) end

---获取类的名称
---@param obj any 类对象或实例
---@return string 类名
function classof(obj) end

---检查对象是否是指定类的直接实例（不包括子类）
---@param obj any 要检查的对象
---@param classname string 类名
---@return boolean 如果对象是指定类的直接实例则返回true，否则返回false
function instanceof(obj, classname) end