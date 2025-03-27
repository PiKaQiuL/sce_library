
-- 状态定义
-- weight 代表在进度中的权重
--- @class Common_Status
local mt = {
    {
        desc = '查询',
        weight = 0.1
    },
    {
        desc = '下载',
        weight = 0.6
    },
    {
        desc = '解压',
        weight = 0.3
    },
    {
        desc = '完成',
        weight = 0
    }       
}

mt.__index = mt
mt.__len = function() return #mt end

function mt:init()
    self.status = 1
end

function mt:next()
    self.status = self.status + 1
end

function mt:desc()
    return self[self.status].desc
end

function mt:progress(current)
    local count = self.status - 1
    local progress = 0
    if count > 0 then
        for i = 1, count do
            progress = progress + self[i].weight
        end
    end
    return progress + current * self[self.status].weight
end

function mt:finish()
    self.status = #self
end

return function()
    return setmetatable({}, mt)
end

