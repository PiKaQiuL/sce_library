local base=base

CmdResult = base.tsc.__TS__Class()
CmdResult.name = 'CmdResult'

---@class CmdResult
---@field result integer
---@field text string
---@field sound string
base.cmd_result = CmdResult.prototype

base.cmd_result.type = 'cmd_result'

local e_cmd=base.eff.e_cmd

---comment
---@return CmdResult
function base.cmd_result:new()
    local cmd_result={result=e_cmd.Unknown}
    setmetatable(cmd_result, self)
    return cmd_result
end

---comment
---@param other CmdResult
---@return boolean
function base.cmd_result:__eq(other)
    return self:get_value()==other:get_value()
end

---comment
---@param other CmdResult
---@return boolean
function base.cmd_result:__lt(other)
    return self:get_value()<other:get_value()
end

---comment
---@param other CmdResult
---@return boolean
function base.cmd_result:__le(other)
    return self:get_value()<=other:get_value()
end

---comment
---@return integer
function base.cmd_result:get_value()
    if(type(self))=='number'then
        return self
    end
    return self.result
end

function base.cmd_result:get_text()
    if(type(self))=='number'then
        return base.eff.e_cmd_str[self]
    end
    return self.text or base.eff.e_cmd_str[self.result]
end

return {
    CmdResult = CmdResult
}