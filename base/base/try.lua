---@meta
--- 提供类似Python的异常处理机制
--- 支持try-catch-finally模式的异常处理
--- @module 'base.try'
--- @author Yuri
--- @copyright SCE
--- @license MIT

---@type fun(err:any):table 将错误转换为异常对象
local to_exception = require 'base.exception'.to_exception
---@type fun(msg:string) 抛出一个异常
local throw = require 'base.exception'.throw

local xpcall = xpcall
local error = error
local type = type

local table_pack = table.pack
local table_unpack = table.unpack

local FINALLY_RETURN = {}

---类似于Python的异常处理机制
---@class TryArgs
---@field [1] fun():any 要执行的主函数
---@field args? table 传递给主函数的参数
---@field catch? fun(err:any):any|nil 捕获异常的函数，如果返回nil或false则吃掉异常，否则重新抛出
---@field finally? fun():any 无论是否发生异常都会执行的清理函数

---执行try-catch-finally结构的函数
---如果catch想要吃掉异常，可以return nil或者false，如果想要重新抛出，可以return err
---不论怎样，finally都会被调用
---
---注意：因为Lua的返回值机制有些问题，比如多个返回值之间有nil的话，最终unpack时可能会出错，所以之后要用C++重写

---@param args_table TryArgs 包含try、catch和finally函数的参数表
local try = function(args_table)
    local err = nil

    local func = args_table[1]
    local args, args_beg = args_table.args, 1
    if not args then
        args = args_table
        args_beg = 2
    end


    if not func then
        throw("找不到try的实现函数")
    end

    local result = nil
    result = table_pack(xpcall(func, function(_err)
        err = to_exception(_err)
    end, table_unpack(args, args_beg, args.n)))

    --if err then
    --    print(err)
    --end

    local catch = args_table.catch
    if err and catch then
        xpcall(function()
            err = catch(err) -- 返回nil将吃掉err
        end,
                function(_err)
                    err = to_exception(_err)
                end
        )
    end

    local finally = args_table.finally

    if finally then
        local finally_result = table_pack(xpcall(finally,function(_err)
            err = to_exception(_err)
        end))

        if finally_result[2] == FINALLY_RETURN then
            result = finally_result
            result.start = 3  -- 1是bool, 2是FINALLY_RETURN, 3才是第一个返回值
        end
    end

    if err then
        error(err)  --- 如果仍然有err, 继续抛出
    end

    return table_unpack(result, result.start or 2, result.n)
end

---创建一个包装了try-catch-finally结构的函数
---@param args_table TryArgs 包含try、catch和finally函数的参数表
---@return fun(...):any 返回一个新函数，调用时会执行try-catch-finally结构
local function try_wrap(args_table)
    return function(...)
        return try(args_table)
    end
end

---@type fun(args_table:TryArgs):any 执行try-catch-finally结构的全局函数
_G.try = try
---@type fun(args_table:TryArgs):fun(...):any 创建包装了try-catch-finally结构的函数的全局函数
_G.try_wrap = try_wrap
---@type table 用于在finally中指定返回值的特殊标记
_G.FINALLY_RETURN = FINALLY_RETURN

---@class TryModule
---@field try fun(args_table:TryArgs):any 执行try-catch-finally结构的函数
---@field try_wrap fun(args_table:TryArgs):fun(...):any 创建包装了try-catch-finally结构的函数
---@field FINALLY_RETURN table 用于在finally中指定返回值的特殊标记

---@type TryModule
return {
    try = try,
    try_wrap = try_wrap,
    FINALLY_RETURN = FINALLY_RETURN,
}