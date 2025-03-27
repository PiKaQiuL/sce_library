
local unit_tables_list = setmetatable({}, {__mode = 'k'})
local function get_items_table_mt(items_table_name, item_check, tables_list)
    local mt = {table_class = items_table_name, size = 0,}
    mt.__index = mt

    mt.item_check = item_check

    function mt:check_items_table(newtable)
        return  type(newtable) == 'table' and newtable.table_class == self.table_class
    end

    function mt:__add(newtable)
        local ret = self:copy()
        if self.item_check(newtable) then
            ret:add_item(newtable)
        elseif type(newtable) == 'table' then
            ret:add_items(newtable)
        end
        return ret
    end

    function mt:__sub(newtable)
        local ret = self:copy()
        if self.item_check(newtable) then
            ret:remove_item(newtable)
        elseif type(newtable) == 'table' then
            ret:remove_items(newtable)
        end
        return ret
    end

    function mt:__eq(newtable)
        if self:check_items_table(newtable) then
            if #self == #newtable then
                return #(self - newtable) == 0
            end
        end
        return false
    end

    function mt:__tostring()
        local ret = self.table_class..'{'
        for i = 1, #self do
            ret = ret..tostring(self[i])..', '
        end
        ret = ret..'}'
        return ret
    end

    function mt:add_item(item)
        if self.item_check(item) then
            if self.items_map[item] == nil then
                self.size = self.size + 1
                self[self.size] = item
                self.items_map[item] = self.size
                -- log.error('============== 物体组添加物体成功')
            end
        end
    end

    function mt:add_items(items)
        if type(items) == 'table' then
            for i = 1, #items do
                self:add_item(items[i])
            end
        end
    end

    function mt:_remove_item(item)
        if self.item_check(item) then
            if self.items_map[item] ~= nil then
                self[self.items_map[item]] = nil
                self.items_map[item] = nil
                --log_file.info('============== 物体组移除物体成功')
            end
        end
    end

    function mt:refresh()
        local j = 1
        local n = self.size
        local size = 0
        for i = 1, n do
            if self[i] == nil then
                j = math.max(j, i) + 1
                local target
                while j <= n do
                    if self[j] then
                        target = self[j]
                        break
                    end
                    j = j + 1
                end
                if target then
                    self[i] = target
                    self[j] = nil
                    self.items_map[target] = i
                    size = i
                end
            else
                size = i
            end
        end
        self.size = size
    end

    function mt:remove_item(item)
        self:_remove_item(item)
        self:refresh()
    end

    function mt:remove_items(items)
        if type(items) == 'table' then
            for i = 1, #items do
                self:_remove_item(items[i])
            end
        end
        self:refresh()
    end

    function mt:copy()
        local ret = mt.new()
        ret:add_items(self)
        return ret
    end

    function mt:contains(item)
        return self.items_map[item] ~= nil
    end

    function mt:union(newtable)
        local ret = mt.new()
        if self:check_items_table(newtable) then
            ret = self + newtable
        else
            log.error(string.format('"%s"只能与"%s"求并', self.table_class, self.table_class))
        end
        return ret
    end

    function mt:sub(newtable)
        local ret = mt.new()
        if self:check_items_table(newtable) then
            ret = self - newtable
        else
            log.error(string.format('"%s"只能与"%s"求减', self.table_class, self.table_class))
        end
        return ret
    end

    function mt:intersect(newtable)
        local ret = mt.new()
        if self:check_items_table(newtable) then
            local a_b = self - newtable
            local b_a = newtable - self
            ret = self + newtable
            ret = ret - a_b - b_a
        else
            log.error(string.format('"%s"只能与"%s"求交', self.table_class, self.table_class))
        end
        return ret
    end

    function mt:get_length()
        return self.size
    end

    function mt.new()
        local ret = setmetatable({items_map = {}}, mt)
        tables_list[ret] = true
        return ret
    end

    function mt:get_items_map()
        return self.items_map
    end

    -- 兼容v2
    function mt:add(item)
        self:add_item(item)
    end

    function mt:has(item)
        return self:contains(item)
    end

    function mt:delete(item)
        if self:contains(item) then
            self:remove_item(item)
        end
    end

    function mt:clear(item)
        local n = self.size
        self.size = 0
        self.items_map = {}
        for i = 1, n do
            self[i] = nil
        end
        self:refresh()
    end

    function mt:forEachEx(callbackfn)
        local n = self.size
        local image = {}
        for i = 1, n do
            image[#image+1] = self[i]
        end
        for i = 1, n do
            local element_1 = image[i]
            local element_2 = image[i + 1]
            if callbackfn(_, element_1, element_2) then
                return
            end
        end
    end

    function mt:random()
        return base.tsc.__TS__ArrayRandom(self)
    end

    function mt:randoms(number, duplicate)
        return base.tsc.__TS__ArrayRandoms(self, number, duplicate)
    end

    local Symbol = base.tsc.Symbol
    mt[Symbol.iterator] = function(self)
        return self:values()
    end
    function mt:values()
        local n = self.size
        local image = {}
        local index = 0     
        for i = 1, n do
            image[#image+1] = self[i]
        end
        return {
            next = function(self)
                index = index + 1
                local item = image[index]
                local result = {done = index > n, value = item}
                return result
            end
        }
    end
    return mt
end

local units_mt = get_items_table_mt('单位组', function(unit)
    -- log.error("unit.type:",unit.type)
    if  unit.type == 'unit' then
        -- type(unit) ~= 'userdata' 客户端的unit是个table 服务端的才是userdata
        return true
    else
        return false
    end
end, unit_tables_list)

-- local player_mt = get_items_table_mt('玩家组', function(self, player)
--     if or(type(player) ~= 'userdata', player.type ~= 'player') then
--         return false
--     else
--         return true
--     end
-- end)

function base.单位组(单位数组)
    local ret = units_mt.new()
    if 单位数组 then 
        ret:add_items(单位数组)
    end
    -- log.error('ret!!:',ret)
    return ret
end

function base.create_unit_group(units)
    local ret = units_mt.new()
    if units then
        if type(units) == 'table' then
            ret:add_items(units)
        else
            ret:add_item(units)
        end
    end
    return ret
end

-- function base.empty_unit_group() 单位组
--     ---@ui 空单位组
--     ---@belong 单位组
--     ---@keyword 单位组
--     local ret = units_mt.new()
--     return ret
-- end

base.game:event('单位-移除', function(_, unit)
    for unit_table, _ in pairs(unit_tables_list) do
        if unit_table then
            if unit_table:contains(unit) then
                --log_file.info('单位表尝试移除死亡单位')
                unit_table:remove_item(unit)
            end
        end
    end
    -- end)
end)
-- function base.玩家组(players:table<player>)
--     ---@ui 新建玩家组
--     ---@belong 玩家组
--     local ret = setmetatable({items_map = {}, size = 0}, player_mt)
--     if players then
--         ret:add_items(players)
--     end
--     return ret
-- end

function base.unit_group_random_unit(ug)
    local size = ug:get_length()
    if size == 0 then
        return nil
    else
        local target_index = math.random(size)
        return ug[target_index]
    end
end

function base.unit_group_random_units(ug, cnt)
    local size = ug:get_length()
    if cnt >= size then
        return ug:copy()
    else
        local result_ug = units_mt.new()
        local copy_ug = ug:copy()
        for i = 1, cnt do
            local s = copy_ug:get_length()
            local target_index = math.random(s)
            local target_unit = copy_ug[target_index]
            result_ug:add(target_unit)
            copy_ug:delete(target_unit)
        end
        return result_ug
    end
end

function base.unit_group_forEachEx(ug, callbackfn)
    -- local copy = ug:copy()
    ug:forEachEx(callbackfn)
end