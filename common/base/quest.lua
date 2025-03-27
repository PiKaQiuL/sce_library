local base = base

Quest = Quest or base.tsc.__TS__Class()
Quest.name = 'Quest'
QuestCondition = QuestCondition or base.tsc.__TS__Class()
QuestCondition.name = 'QuestCondition'

base.quest = Quest.prototype
base.quest_condition = QuestCondition.prototype

local quest = base.quest
local quest_condition = base.quest_condition

quest.type = 'quest'
quest_condition.type = 'quest_condition'

quest.active_state = {
    inactive    = 'inactive',
    active      = 'active',
}

quest.complete_state = {
    none        = 'none',
    complete    = 'complete',
    failed      = 'failed',
}

function base.print_table(t)
    if type(t) == "table" then
        local s = "{"
        for k, v in pairs(t) do
            s = s..base.print_table(k).."="..base.print_table(v)..", "
        end
        s = s.."}"
        return s
    elseif type(t) == "string" then
        return '"'..t..'"'
    else
        return tostring(t)
    end
end

function quest_condition:new(tbl)
    log_file.debug("quest_condition:new", self, base.print_table(tbl))
    local link = tbl.link
    local cache = link and base.eff.cache(link)
    local owner = tbl.owner_id and base.unit(tbl.owner_id)
    local new_quest_condition = {}
    setmetatable(new_quest_condition, self.__index)
    new_quest_condition.empty = true
    if not cache or not owner then
        return new_quest_condition
    end
    new_quest_condition:update(tbl)
    return new_quest_condition
end

function quest_condition:update_remaining_time(remaining_time)
    if not remaining_time or not remaining_time.remaining_time then
        self._finish_time_update_time = nil
        self._finish_time = nil
        return
    end
    if remaining_time.current_time == self._finish_time_update_time then
        return
    end
    self._finish_time_update_time = remaining_time.current_time
    self._finish_time = remaining_time.remaining_time + base.clock()
end

function quest_condition:get_remaining_time()
    local remaining
    if self._finish_time then
        remaining = math.max(0, self._finish_time - base.clock())
    else
        remaining = 0
    end
    return remaining / 1000
end

function quest_condition:update(tbl)
    log_file.debug("quest_condition:update", self, base.print_table(tbl))
    -- log_file.debug(debug.traceback())
    if self.empty then
        -- 初始化
        local link = tbl.link
        local cache = link and base.eff.cache(link)
        local owner = tbl.owner_id and base.unit(tbl.owner_id)
        if not cache or not owner then
            return
        end
        self.empty = false

        local father
        if tbl.father.is_quest then
            father = owner.quests[tbl.father.id]
            if not father then
                father = quest:new({})
                owner.quests[tbl.father.id] = father
            end
        else
            father = owner.quest_conditions[tbl.father.id]
            if not father then
                father = quest_condition:new({})
                owner.quest_conditions[tbl.father.id] = father
            end
        end

        local q = owner.quests[tbl.quest]
        if not q then
            q = quest:new({})
            owner.quests[tbl.quest] = q
        end
        self.link = link
        self.id = tbl.id
        self.cache = cache
        self.quest = q
        self.owner = owner
        self.father = father
        self.active = tbl.active
        self.complete = tbl.complete
        self.progress = tbl.progress
        self.progressTotal = tbl.progressTotal
        self.can_submit = tbl.can_submit
        self.properties = tbl.properties

        if tbl.conditions then
            self.conditions = {}
            for index, condition_id in pairs(tbl.conditions) do
                local qc = owner.quest_conditions[condition_id]
                if not qc then
                    qc = quest_condition:new({})
                    owner.quest_conditions[condition_id] = qc
                end
                self.conditions[index] = qc
            end
        end

        if self.properties and self.properties.remaining_time then
            self:update_remaining_time(self.properties.remaining_time)
            if self.cache.ShowOnQuest then
                self._time_condition = self
            end
        end
        if self._time_condition then
            self.father._time_condition = self._time_condition
        end
    else
        self.progress = tbl.progress
        self.active = tbl.active
        self.complete = tbl.complete
        self.can_submit = tbl.can_submit
        self.properties = tbl.properties

        if self.properties and self.properties.remaining_time then
            self:update_remaining_time(self.properties.remaining_time)
            if self.cache.ShowOnQuest then
                self._time_condition = self
            end
        end
        if self._time_condition then
            self.father._time_condition = self._time_condition
        end
    end
end

function quest_condition:remove()
    self.removed = true
end

function quest_condition:submit()
    if self.empty or self.removed or not self.can_submit then
        return
    end
    base.game:server 'quest_condition_submit' {
        unit_id = self.owner._id,
        quest_condition_id = self.id,
    }
end

local default_quest_descriptions = {
    ['QuestConditionKill'] = '击杀<#FEE75C:%s~0~:>',
    ['QuestConditionUnitAttribute'] = '主控单位<#FEE75C:%s:>达<#FEE75C:~0~:>',
    ['QuestConditionPlayerAttribute'] = '<#FEE75C:%s:>达<#FEE75C:~0~:>',
    ['QuestConditionItem'] = '<#FEE75C:~0~:>个<#FEE75C:%s:>',
    ['QuestConditionTime'] = '在限时内完成<#FEE75C:~0~:>',
    ['QuestConditionSet'] = '完成所有目标<#FEE75C:~0~:>',
    ['QuestConditionEffect'] = '执行<#FEE75C:%s~0~:>次',
    ['QuestConditionCustomBool'] = '达成进度<#FEE75C:~0~:>',
    ['QuestConditionCustomNumber'] = '达成进度<#FEE75C:~0~:>',
}

function quest_condition:get_description()
    -- log_file.debug("get_desc", self, self.empty, self.removed, debug.traceback())
    if self.empty or self.removed then
        return nil
    end
    if not self._desc_array then
        local string_ui = self.cache.Description and base.i18n.get_text(self.cache.Description)
        if not string_ui or string_ui == '' then
            local node_type = self.cache.NodeType
            string_ui = default_quest_descriptions[node_type] or ''
            if node_type == 'QuestConditionKill' then
                if self.cache.VictimPicker == 'UnitLink' then
                    local unit_name = self.cache.VictimTypes and self.cache.VictimTypes[1]
                    unit_name = unit_name and base.eff.cache(unit_name)
                    unit_name = unit_name and base.i18n.get_text(unit_name.Name)
                    string_ui = string.format(string_ui, unit_name or '')
                else
                    string_ui = string.format(string_ui, '')
                end
            elseif node_type == 'QuestConditionUnitAttribute' then
                string_ui = string.format(string_ui, self.cache.UnitAttribute)
            elseif node_type == 'QuestConditionPlayerAttribute' then
                string_ui = string.format(string_ui, self.cache.PlayerAttribute)
            elseif node_type == 'QuestConditionItem' then
                local condition_mode = self.cache.ConditionMode
                string_ui = (condition_mode == 'Hold' and '持有' or '获取') .. string_ui
                local item_name = self.cache.ItemTypes and self.cache.ItemTypes[1]
                item_name = item_name and base.eff.cache(item_name)
                item_name = item_name and base.i18n.get_text(item_name.Name)
                string_ui = string.format(string_ui, item_name or '')
            elseif node_type == 'QuestConditionEffect' then
                local eff_name = self.cache.EffectLink
                eff_name = eff_name and base.eff.cache(eff_name)
                eff_name = eff_name and base.i18n.get_text(eff_name.Name)
                string_ui = string.format(string_ui, eff_name or '')
            end
        end
        local ret = {}
        while true do
            local l, r = string.find(string_ui, "~%d+~")
            if l == nil then
                table.insert(ret, string_ui)
                break
            else
                if l ~= 1 then
                    table.insert(ret, string.sub(string_ui, 1, l-1))
                end
                local rank = tonumber(string.sub(string_ui, l+1, r-1))
                table.insert(ret, rank)
                string_ui = string.sub(string_ui, r+1)
            end
            if #string_ui == 0 then
                break
            end
        end
        self._desc_array = ret
    end
    local ret = ""
    for i, desc in ipairs(self._desc_array) do
        if type(desc) == "string" then
            ret = ret..desc
        elseif type(desc) == "number" then
            if desc == 0 then
                -- [x/x]
                ret = ret .. "（" .. tostring(math.min(self.progress, self.progressTotal or self.progress)) .. (self.progressTotal and ("/" .. tostring(self.progressTotal)) or '') .. "）"
            else
                local qc = self.conditions and self.conditions[desc]
                if qc then
                    ret = ret .. qc:get_description()
                end
            end
        end
    end
    log_file.debug("get_desc return", ret)
    return ret
end

function quest:new(tbl)
    log_file.debug("quest:new", base.print_table(tbl))
    local link = tbl.link
    local cache = link and base.eff.cache(link)
    local owner = base.unit(tbl.owner_id)
    local new_quest = {}
    setmetatable(new_quest, self.__index)
    new_quest.empty = true
    if not cache or not owner then
        return new_quest
    end
    new_quest:update(tbl)
    return new_quest
end

function quest:update(tbl)
    log_file.debug("quest:update", self, base.print_table(tbl))
    -- log_file.debug(debug.traceback())
    local events = {}
    if self.empty then
        -- 初始化
        local link = tbl.link
        local cache = link and base.eff.cache(link)
        local owner = base.unit(tbl.owner_id)
        if not cache or not owner then
            return
        end
        self.empty = false

        self.link = link
        self.id = tbl.id
        self.cache = cache
        self.owner = owner
        self.active = tbl.active
        self.complete = tbl.complete
        self.progress = tbl.progress
        self.progressTotal = tbl.progressTotal
        self.conditions = {}
        self.can_submit = tbl.can_submit
        self.properties = tbl.properties
        self.is_score = tbl.is_score
        self.removed = tbl.removed
        self.receive_time = tbl.receive_time

        for index, condition_id in pairs(tbl.conditions) do
            local qc = owner.quest_conditions[condition_id]
            if not qc then
                qc = quest_condition:new({})
                owner.quest_conditions[condition_id] = qc
            end
            self.conditions[index] = qc
        end

        if not tbl.removed and tbl.complete ~= 'completed' and tbl.complete ~= 'failed' then
            table.insert(events, {'任务-获得', self})
        end
    else
        if self.complete == 'none' and tbl.complete == 'completed' then
            table.insert(events, {'任务-完成', self})
        end
        if self.complete == 'none' and tbl.complete == 'failed' then
            table.insert(events, {'任务-失败', self})
        end
        if not self.removed and tbl.removed then
            table.insert(events, {'任务-移除', self})
        end
        self.progress = tbl.progress
        self.active = tbl.active
        self.complete = tbl.complete
        self.can_submit = tbl.can_submit
        self.properties = tbl.properties
        self.removed = tbl.removed
    end
    return events
end

function quest:remove()
    self.removed = true
end

function quest.update_quests(unit, tbl, change_table)
    if not change_table then
        change_table = {modify = tbl}
    end
    if unit:get_owner() ~= base.local_player() then
        return
    end
    local events = {}
    if change_table.modify then
        local quest_conditions_change = change_table.modify.quest_conditions
        local quests_change = change_table.modify.quests
        if not unit.quests then
            unit.quests = {}
            unit.quest_conditions = {}
        end
        if change_table.modify.is_hero ~= nil then
            unit.is_hero = change_table.modify.is_hero
        end
        if change_table.modify.tracking_quest_id then
            unit.tracking_quest_id = change_table.modify.tracking_quest_id
        end
        if quest_conditions_change then
            for id, quest_condition_change in pairs(quest_conditions_change) do
                if not unit.quest_conditions[id] then
                    unit.quest_conditions[id] = quest_condition:new(tbl.quest_conditions[id])
                else
                    local i_events = unit.quest_conditions[id]:update(tbl.quest_conditions[id])
                    if i_events then
                        for _, i_event in ipairs(i_events) do
                            table.insert(events, i_event)
                        end
                    end
                end
            end
        end
        if quests_change then
            for id, quest_change in pairs(quests_change) do
                if not unit.quests[id] then
                    unit.quests[id] = quest:new(tbl.quests[id])
                else
                    local i_events = unit.quests[id]:update(tbl.quests[id])
                    if i_events then
                        for _, i_event in ipairs(i_events) do
                            table.insert(events, i_event)
                        end
                    end
                end
            end
        end
    end
    if change_table.delete then
        local quests_delete = change_table.modify.quests
        local quest_conditions_delete = change_table.modify.quest_conditions
        if not unit.quests then
            unit.quests = {}
            unit.quest_conditions = {}
        end
        if quest_conditions_delete then
            for id, quest_condition_delete in pairs(quest_conditions_delete) do
                if quest_condition_delete == true then
                    unit.quest_conditions[id]:remove()
                end
            end
        end
        if quests_delete then
            for id, quest_delete in pairs(quests_delete) do
                if quest_delete == true then
                    unit.quests[id]:remove()
                end
            end
        end
    end
    for _, i_event in ipairs(events) do
        base.game:event_notify(table.unpack(i_event))
    end
end

-- if base.test then
--     function quest:__tostring()
--         return ('{quest|%08X|%s-%d} <- %s'):format(base.test.topointer(self), self.link, self.id, tostring(self.owner))
--     end
--     function quest_condition:__tostring()
--         return ('{quest_condition|%08X|%s-%d} <- %s'):format(base.test.topointer(self), self.link, self.id, tostring(self.father))
--     end
-- else
    function quest:__tostring()
        return ('{quest|%s-%s} -> %s'):format(self.link, tostring(self.id), tostring(self.owner))
    end
    function quest_condition:__tostring()
        return ('{quest_condition|%s-%s} -> %s'):format(self.link, tostring(self.id), tostring(self.father))
    end
-- end

return {
    Quest = Quest,
    QuestCondition = QuestCondition,
}
