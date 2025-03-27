--- lua_plus ---
-- function base.item_rnd_value(item:item, buff_id:buff_id, prop_name:单位属性)
--     ---@ui 物品~1~的词条~2~中~3~属性的随机结果
--     ---@belong item
--     ---@description 物品的词条随机结果
--     ---@keyword 词条
--     ---@applicable value
--     if item_check(item) then
--         return item:randomized_value(buff_id, prop_name)
--     end
-- end

function base.item_unit(item:item) unit
    ---@ui 物品~1~的物品单位
    ---@belong item
    ---@description 物品在地上时的单位
    ---@keyword 单位
    ---@applicable value
    if item_check(item) then
        return item.unit
    end
end

function base.item_unit_get_item(unit:unit) item
    ---@ui 物品单位~1~对应的物品对象
    ---@belong item
    ---@description 物品单位对应的物品对象
    ---@keyword 单位
    ---@applicable value
    if unit_check(unit) then
        local item = base.item(unit._id)
        if item == nil then
            log_file.debug("只有物品单位可获取物品对象")
            return nil
        end
        return item
    end
end

function base.item_get_name(item:item) item_id
    ---@ui 物品~1~的Id
    ---@belong item
    ---@description 物品的Id
    ---@keyword 类型
    ---@applicable value
    if item_check(item) then
        return item.link
    end
end

function base.item_get_stack(item:item) integer
    ---@ui 物品~1~的使用次数
    ---@belong item
    ---@description 物品的使用次数
    ---@keyword 次数
    ---@applicable value
    if item_check(item) then
        return or(item.stack, 0)
    end
end

-- function base.item_grant_tag(item:item) string
--     ---@ui 物品~1~被赋予的标签
--     ---@belong item
--     ---@description 物品被赋予的标签
--     ---@keyword 标签
--     ---@applicable value
--     if and(item_check(item), item.granted_tag) then
--         return item.granted_tag
--     end
--     return ''
-- end

function base.item_get_owner(item:item) player
    ---@ui 物品~1~的拥有者玩家
    ---@belong item
    ---@description 物品的持有者玩家
    ---@keyword 持有者 玩家
    ---@applicable value
    if item_check(item) then
        return item.unit:get_owner()
    end
end

function base.item_get_holder(item:item) unit
    ---@ui 物品~1~的持有者单位
    ---@belong item
    ---@description 物品的持有者单位
    ---@keyword 持有者 单位
    ---@applicable value
    if item_check(item) then
        return base.unit(item.owner_id)
    end
end

function base.item_get_inventory(item:item) number
    ---@ui 物品~1~所在的背包编号
    ---@belong item
    ---@description 物品的背包编号
    ---@keyword 物品 背包
    ---@applicable value
    if item_check(item) then
        return item.inv_index
    end
end

function base.item_get_inventory(item:item) number
    ---@ui 物品~1~所在的格子编号
    ---@belong item
    ---@description 物品的格子编号
    ---@keyword 物品 格子
    ---@applicable value
    if item_check(item) then
        return item.slot
    end
end

function base.unit_try_pick_item(unit:unit, item:item, callback:function<boolean>)
    ---@ui 令单位~1~尝试拾取物品~2~，根据结果执行~3~
    ---@belong item
    ---@description 单位拾取物品
    ---@keyword 物品 拾取
    ---@applicable action
    
    if and(unit_check(unit), item_check(item)) then
        unit:try_pick_item(item, callback)
    end
end

function base.try_drop_item(item:item, callback:function<boolean>)
    ---@ui 尝试卸下物品~1~，根据结果执行~2~
    ---@belong item
    ---@description 卸下物品
    ---@keyword 卸下 物品
    ---@applicable action
    if item_check(item) then
        return item:try_drop(callback)
    end
end

function base.get_unit_item(unit:unit) table<number>
    ---@ui 单位~1~身上所有的物品的编号
    ---@belong item
    ---@description 单位身上所有的物品的编号
    ---@keyword 单位 物品
    ---@applicable value
    ---@selectable false
    if unit_check(unit) then
        return or(unit._attribute.sys_inv_items, {})
    end
    return {}
end