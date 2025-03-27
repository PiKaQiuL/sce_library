local base = base

Riseletter = Riseletter or base.tsc.__TS__Class()
Riseletter.name = 'Riseletter'

base.riseletter = Riseletter.prototype
local mt = Riseletter.prototype
mt.type = 'riseletter'
mt.id = nil
mt.unit = nil

function mt:new(unit, id)
    local riseletter = {}
    setmetatable(riseletter, self)
    riseletter.id = id
    riseletter.unit = unit
    return riseletter
end

function mt:get_id()
    return self.id
end

function mt:get_unit()
    return self.unit
end

function mt:remove()
    base.remove_riseletter(self.id)
end

function mt:set_screen_position(position)
    base.set_riseletter_position(self.id, position)
end

function mt:set_world_position(position)
    base.set_riseletter_world_position(self.id, position)
end

function mt:set_unit(unit)
    self.unit = unit
    base.set_riseletter_unit(self.id, unit)
end