-- 客户端item实现
local item_map = {}
-- local node_mark_map = {}

Item = base.tsc.__TS__Class()
Item.name = 'Item'

local mt = Item.prototype

-- local e_base_data = {
--     link = 'sys_item_link',
--     mods = 'sys_item_mods',
--     rnds = 'sys_item_rnds',
--     stack = 'sys_item_stack',
--     quality = 'sys_item_quality',
--     unpowered = 'sys_item_unpowered',
-- }

-- local e_slot_data  = {
--     owner_id = 'sys_item_owner_id',
--     inv_index = 'sys_item_inv_index',
--     slot_index = 'sys_item_slot_index',
-- }

mt.type = 'item'
mt.unit = nil

function mt:__index(key) 
    if self.unit then
        local unit = self.unit
        if key == 'id' then
            return unit._id
        elseif key == 'link' then
            return unit._attribute.sys_item_link
        elseif key == 'mods' then
            return unit._attribute.sys_item_mods
        elseif key == 'mod_attrs' then
            return unit._attribute.sys_item_mod_attrs
        elseif key == 'rnds' then
            return unit._attribute.sys_item_rnds
        elseif key == 'stack' then
            return unit._attribute.sys_item_stack or 0
        elseif key == 'quality' then
            return unit._attribute.sys_item_quality
        elseif key == 'unpowered' then
            return unit._attribute.sys_item_unpowered
        elseif key == 'owner_id' then
            return unit._attribute.sys_item_owner_id or 0
        elseif key == 'active_skill_id' then
            return unit._attribute.sys_item_active_skill_id or 0
        elseif key == 'inv_index' then
            return unit._attribute.sys_item_inv_index or 0
        elseif key == 'slot' then
            return unit._attribute.sys_item_slot_index or 0
        elseif key == 'cache' then
            return base.eff.cache(self.link)
        end
    end
    return mt[key]
end

function mt:__tostring()
    return ('{item|%s|%d}'):format(self.link, self.id)
end

function base.item(id, silence)
    if item_map[id] then
        return item_map[id]
    end
    local unit = base.unit(id)
    if unit and unit:is_item() then
        local item = setmetatable({unit = unit}, mt)
        item_map[id] = item
        -- local node_mark = unit:get_node_mark()
        -- if node_mark then
        --     node_mark_map[node_mark] = item
        -- end
        return item
    end
    if silence then
        return nil
    end
    if unit then
        log_file.warn('尝试获取一个非物品单位', unit)
    else
        log_file.info('物品单位对当前客户端不可见，id:', id)
    end
    return nil
end

-- function base.get_default_item(node_mark)
--     return node_mark_map[node_mark]
-- end

function mt:get_owner()
    return base.unit(self.owner_id)
end

function mt:try_drop(callback)
    self._try_drop_callback = callback
    base.game:server'__item_try_drop'{
        item_id = self.id,
    }
end

function mt:get_attr_need()
    local attr_need = {}
    if self.cache and self.cache.UnitAttributeNeed then
        for prop_name,value in pairs(self.cache.UnitAttributeNeed) do
            if type(prop_name) == 'string' and prop_name ~= '' and type(value) == 'number' and value > 0 then
                table.insert(attr_need,{key = prop_name,value = value})
            end
        end
    end
    
    local sync_attr_need = self.attr_need
    if type(sync_attr_need) ~= 'table' then
        sync_attr_need = {}
    end
    for _,info in ipairs(sync_attr_need) do
        local prop_name = info.key
        local value = info.value
        local cover = false
        for _,data in ipairs(attr_need) do
            local key = data.key
            if key == prop_name then
                cover = true
                data.value = value
                break
            end
        end
        if not cover then
            table.insert(attr_need,{key = prop_name,value = value})
        end
    end
    return attr_need
end

--- @param func fun(key, value):boolean?
function mt:foreach_attr_need(func)
    local attr_need = self:get_attr_need()

    for k,info in ipairs(attr_need) do
        if func(info.key, info.value) then
            return
        end
    end
end

function mt:get_all_extra_mod(is_equip)
    local result = {}
    if self.mods and type(self.mods) ~="number" and self.mods[is_equip] then
        for key, value in pairs(self.mods[is_equip]) do
            table.insert(result, value)
        end
    end
    return result
end

function mt:get_rand_mod(buff_link, buff_idx, key, percentage)
    local result = nil
    if self.rnds and type(self.rnds) ~= "number" then
        local rnds = self.rnds
        local str = buff_link..'@'..buff_idx
        if rnds[str] and rnds[str][key] and rnds[str][key][tostring(percentage)] then
            result = rnds[str][key][tostring(percentage)]
        end
    end
    
    if result == nil then
        log_file.warn('函数 item:get_rand_mod 属性词条未固化或不存在')
    end
    return result
end

function mt:get_name()
    -- log_file.debug('testgetname')
    return self.link
end

local show_methods

local function try_load_show_methods()
    if show_methods then
        return
    end
    if base.eff and base.eff.has_cache_init() then
    local cache = base.eff.cache('$$.gameplay.dflt.root')
    local show_methods_link = cache and cache.ObjectShowMethods and cache.ObjectShowMethods.Item
    show_methods = base.eff.cache(show_methods_link)
    end
end

function mt:get_show_name()
    try_load_show_methods()
    self.cache = self.cache or base.eff.cache(self._name)
    if show_methods and show_methods.ShowNameMethod then
        return show_methods.ShowNameMethod(self)
    else
        return base.i18n.get_text(self.cache.Name)
    end
end

function mt:get_icon()
    try_load_show_methods()
    self.cache = self.cache or base.eff.cache(self._name)
    if show_methods and show_methods.IconMethod then
        return show_methods.IconMethod(self)
    else
        return self.cache.Icon
    end
end

function mt:get_tips()
    try_load_show_methods()
    self.cache = self.cache or base.eff.cache(self._name)
    if show_methods and show_methods.TipsMethod then
        return show_methods.TipsMethod(self)
    else
        return self.cache.Description == '' and '无描述' or base.i18n.get_text(self.cache.Description)
    end
end

function mt:get_current_cd()
    try_load_show_methods()
    if show_methods and show_methods.CoolDownMethod then
        return show_methods.CoolDownMethod(self)
    else
        return 0
    end
end

function mt:get_cd_max()
    try_load_show_methods()
    if show_methods and show_methods.MaxCoolDownMethod then
        return show_methods.MaxCoolDownMethod(self)
    else
        return 0
    end
end

function mt:get_stack()
    if self.stack then
        return base.math.floor(self.stack)
    else
        return 0
    end
    
end

return {
    Item = Item,
}