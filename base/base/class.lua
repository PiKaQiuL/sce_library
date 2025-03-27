if _G.class then
    return  -- 不要重复注册
end

---@class SCEContext
---@field ClassMap table 类映射表，存储所有类的继承关系

---@type fun():SCEContext
local ImportSCEContext = ImportSCEContext
if not ImportSCEContext then
    print('ImportSCEContext is nil')
    ImportSCEContext = function()
        return { ClassMap = {} }
    end
end

---@type SCEContext
local SCE = ImportSCEContext()

---@type table<string, table> 类名到类对象的映射表
local class_name_map = {}

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
local function class(classname, super)
    local cls = {}

    local superType = type(super)
    if superType ~= "function" and superType ~= "table" and superType ~= 'string' then
        superType = nil
        super = nil
    end

    if superType == 'string' then
        local super_cls = class_name_map[super]
        if not super_cls then
            error(('cannot found super[%s] by string'):format(super))
        end

        super = super_cls
        superType = 'table'
    end

    if superType == "function" or (super and super.__ctype == 1) then
        -- inherited from native C++ Object  
        if superType == "table" then
            -- copy fields from super  
            for k, v in pairs(super) do cls[k] = v end
            cls.__create = super.__create
            cls.super    = super
        else
            cls.__create = super
            cls.ctor = function() end
        end

        cls.__cname = classname
        cls.__ctype = 1

        function cls.new(...)
            local instance = cls.__create(...)
            -- copy fields from class to native object  
            for k, v in pairs(cls) do instance[k] = v end
            instance.class = cls
            instance:ctor(...)
            return instance
        end

    else
        -- inherited from Lua Object  
        cls.super = super
        cls.class = cls
        cls.ctor = not super and function() end or nil
        cls.__cname = classname
        cls.__ctype = 2 -- lua  
        cls.__index = cls
        setmetatable(cls, { __index = super })

        function cls.new(...)
            local instance = setmetatable({}, cls)
            instance:ctor(...)
            return instance
        end

        cls.class_name = function()
            return cls.__cname
        end
    end

    cls.__supper_map = {}
    cls.__supper_map[cls] = true

    if superType == 'table' and super.__supper_map then
        for k, _ in pairs(super.__supper_map) do
            cls.__supper_map[k] = true
        end
    end

    if SCE.ClassMap[cls.__cname] then
        log.warn('redefine class:' .. cls.__cname)
        print('redefine class:' .. cls.__cname)
    end
    -- 更新继承树
    SCE.ClassMap[cls.__cname] = super and super.__cname or ''

    class_name_map[cls.__cname] = cls

    return cls
end

---检查对象是否是指定类或其子类的实例
---@param ins table 要检查的对象
---@param base table|string 基类或基类名
---@return boolean 如果对象是指定类的实例则返回true，否则返回false
local instance_of = function(ins, base)
    if type(ins) ~= 'table' or not ins.__supper_map then
        return false
    end

    if type(base) == 'string' then
        base = class_name_map[base]
        if base == nil then
            return false
        end
    end

    return ins.__supper_map[base] ~= nil
end

base.class = class
base.instance_of = instance_of

_G.class = class
_G.instance_of = instance_of