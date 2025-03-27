local base=base
Snapshot = Snapshot or base.tsc.__TS__Class()
Snapshot.name = 'Snapshot'

---@class Snapshot:Target
---@field point Point
---@field name string
---@field facing number
---@field player Player
---@field cache table
base.snapshot = Snapshot.prototype
base.snapshot.type = 'snapshot'

---@type Snapshot Description
local mt = base.snapshot

function mt:new()
    local snapshot={}
    setmetatable(snapshot, self)
    return snapshot
end

---comment
---@return Snapshot
function mt:get_snapshot()
    return self
end

---comment
---@return Point
function mt:get_point()
    return self.point
end

---comment
---@return Unit?
function mt.get_unit(_)
    return nil
end

---comment
---@return string
function mt:get_name()
    return self.name
end

---comment
---@return Player
function mt:get_owner()
    return self.player
end

---comment
---@return integer
function mt:get_facing()
    return self.facing or 0
end

---comment
---@param dest Target
---@return boolean
function mt:is_ally(dest)
    return self:get_team_id() == dest:get_team_id()
end

---comment
---@param dest Player
---@return boolean
function mt:is_visible_to(dest)
    --先看看点是否可见，再计算玩家是否一致
    local result = self:get_point():is_visible(dest)
    if(not result)then
        result = self:get_team_id() == dest:get_team_id()
    end
    return result
end

---comment
---@return integer
function mt:get_team_id()
    return self:get_owner():get_team_id()
end

---comment
---@param restriction string
function mt:has_restriction(restriction)
    if not self.cache then
        return false
    end
    local t = self.cache.restriction
    for _, value in pairs(t) do
        if value == restriction then
            return true
        end
    end
    return false
end

---comment
---@param label string
function mt:has_label(label)
    if not self.cache then
        return false
    end
    local t = self.cache.filter
    for _, value in pairs(t) do
        if value == label then
            return true
        end
    end
    return false
end

---comment
function mt:get_attackable_radius()
    if not self.cache then
        return 0
    end
    return self.cache.AttackableRadius
end

return {
    SnapShot = Snapshot
}