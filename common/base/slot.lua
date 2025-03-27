local base = base

Slot = Slot or base.tsc.__TS__Class()
Slot.name = 'Slot'

local mt = Slot.prototype
mt.type = 'slot'
mt.item = nil
mt.Excluded = {}
mt.Required = {}
mt.ui_custom = {}
mt.Icon = nil
mt.is_equip = false

function mt:new()
    local slot = {}
    setmetatable(slot, self)
    mt.type = 'slot'
    mt.item = nil
    mt.Excluded = {}
    mt.Required = {}
    mt.ui_custom = {}
    mt.Icon = nil
    mt.is_equip = false
    return slot
end

function base.create_slot()
    return mt:new()
end

function mt:get_item()
    return self.item
end

-- ItemClassLink 是数编Id：物品分类
local function get_item_class(ItemClassLink)
    local ItemClass = base.eff.cache(ItemClassLink)
    return ItemClass and ItemClass.Name
end


function mt:get_Excluded()
    return self.Excluded or {}
end

function mt:has_Excluded(ItemClassLink)
    local ItemClass = get_item_class(ItemClassLink)
    return self.Excluded[ItemClass] ~= nil
end


function mt:get_Required()
    return self.Excluded or {}
end

function mt:has_Required(ItemClassLink)
    local ItemClass = get_item_class(ItemClassLink)
    return self.Required[ItemClass] ~= nil
end

function mt:test_1()
    return "2"
end

return {
    Slot = Slot
}