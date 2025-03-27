Buff = base.tsc.__TS__Class()
Buff.name = 'Buff'

local mt = Buff.prototype
mt.__index = mt

mt.type = 'buff'
mt._index = nil
mt._name = nil
mt._removed = false
mt._owner = nil
mt._stack = nil
mt._target_clock = 0
mt._total_clock = 0

local buff_name_hash_map
local function get_buff_name_by_hash(hash)
    if not buff_name_hash_map then
        buff_name_hash_map = {}
        for name in pairs(base.table.buff) do
            local hash = common.string_hash(name)
            buff_name_hash_map[hash] = name
        end
    end
    return buff_name_hash_map[hash]
end

function mt:__tostring()
    return ('{buff|%s-%q} <- %s'):format(self:get_name(), self._index, self:get_owner() or '{未知}')
end

function mt:get_name()
    return self._name
end

local function set_remaining(self, remaining)
    if remaining < 0 then
        return
    end
    self:resume()
    self._target_clock = base.clock() + remaining
    self:update_paused()
end

function mt:get_remaining()
    local remaining
    if self._paused_clock then
        remaining = math.max(0, self._target_clock - self._paused_clock)
    else
        remaining = math.max(0, self._target_clock - base.clock())
    end
    return remaining / 1000
end

local function set_time(self, time)
    if time < 0 then
        return
    end
    self._total_clock = time
end

function mt:get_time()
    return self._total_clock / 1000
end

function mt:pause()
    if not self._paused_clock then
        self._paused_clock = base.clock()
    end
end

function mt:resume()
    if self._paused_clock then
        if self._target_clock then
            self._target_clock = self._target_clock - self._paused_clock + base.clock()
        end
        self._paused_clock = nil
    end
end

local game_time_paused = false

function mt:update_paused()
    local unit = self:get_owner()
    if not unit then return end
    local unit_paused = unit:has_restriction('暂停') or unit:has_restriction('暂停更新增益')
    if unit_paused then
        self:pause()
    elseif unit:has_restriction('免时停') then
        self:resume()
    elseif game_time_paused then
        self:pause()
    else
        self:resume()
    end
end

base.game:event('游戏-时间暂停', function()
    game_time_paused = true
    for unit_id, unit in pairs(base.unit_info().unit_map) do
        for buff in unit:each_buff() do
            buff:update_paused()
        end
    end
end)

base.game:event('游戏-时间继续', function()
    game_time_paused = false
    for unit_id, unit in pairs(base.unit_info().unit_map) do
        for buff in unit:each_buff() do
            buff:update_paused()
        end
    end
end)

function mt:get_owner()
    return self._owner
end

local function set_stack(self, stack , send_event)
    if stack < 0 then
        return
    end
    if self._stack == stack then
        return
    end
    self._stack = stack
    if send_event then
        local link = self and self:get_name()
        local cache = link and base.eff.cache(link)
        if cache then
            base.event_notify(cache, '状态-层数变化', self, stack, self._owner)
        end
        self:event_notify('状态-层数变化', self, stack, self._owner)
        self._owner:event_notify('单位-状态层数变化', self, stack, self._owner)
    end
end

function mt:get_stack()
    return self._stack
end

function mt:event_notify(name, ...)
    base.event_notify(self, name, ...)
    base.event_notify(base.game, name, ...)
end

function mt:event(name, f)
	return base.event_register(self, name, f)
end

function ac_buff(unit_id, hash, index)
    local unit = base.unit(unit_id)
    if unit then
        local name = get_buff_name_by_hash(hash)
        if not unit.buff[name] then
            unit.buff[name] = {}
        end
        local buff = unit.buff[name][index]
        if not buff then
            local buff_link = get_buff_name_by_hash(hash)
            buff = setmetatable({
                _owner = unit,
                _name = buff_link,
                _index = index,
                hash = hash,
                cache = base.eff.cache(buff_link)
            }, mt)
            unit.buff[name][index] = buff
        end
        return buff
    else
        return
    end
    
end

local show_methods

local function try_load_show_methods()
    if show_methods then
        return
    end
    if base.eff and base.eff.has_cache_init() then
    local cache = base.eff.cache('$$.gameplay.dflt.root')
    local show_methods_link = cache and cache.ObjectShowMethods and cache.ObjectShowMethods.Buff
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
        return self.cache.BuffIcon
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
        return self:get_remaining()
    end
end

function mt:get_cd_max()
    try_load_show_methods()
    self.cache = self.cache or base.eff.cache(self._name)
    if show_methods and show_methods.MaxCoolDownMethod then
        return show_methods.MaxCoolDownMethod(self)
    else
        return self:get_time()
    end
end

function base.event.on_buff_attached(unit_id, hash, index, time, remaining, stack)
    local buff = ac_buff(unit_id, hash, index)
    --log.alert(buff)
    set_remaining(buff, remaining)
    set_time(buff, time)
    set_stack(buff, stack , false)

    local link = buff and buff:get_name()
    local cache = link and base.eff.cache(link)
    if cache then
        base.event_notify(cache, '状态-获得', buff._owner, buff)
    end
    buff:event_notify('状态-获得', buff._owner, buff)
    buff._owner:event_notify('单位-获得状态', buff._owner, buff)
    -- 补丁式修改：之前状态获得的时候无法获得状态数据
    -- 修改事件顺序后，又会有先通知层数修改，再通知状态获得的情况
    -- 所以修改为：添加状态的时候，不会通知层数修改，但是通知完状态添加，再补充通知一次层数修改
    if cache then
        base.event_notify(cache, '状态-层数变化', buff, stack, buff._owner)
    end
    buff:event_notify('状态-层数变化', buff, stack, buff._owner)
    buff._owner:event_notify('单位-状态层数变化', buff, stack, buff._owner)
end

function base.event.on_buff_detached(unit_id, hash, index)
    local buff = ac_buff(unit_id, hash, index)
    buff._owner.buff[buff._name][buff._index] = nil

    local link = buff and buff:get_name()
    local cache = link and base.eff.cache(link)
    if cache then
        base.event_notify(cache, '状态-失去', buff._owner, buff)
    end
    buff:event_notify('状态-失去', buff._owner, buff)
    buff._owner:event_notify('单位-失去状态', buff._owner, buff)
end

function base.event.on_buff_update(unit_id, hash, index, time, remaining, stack)
    local buff = ac_buff(unit_id, hash, index)
    set_remaining(buff, remaining)
    set_time(buff, time)
    set_stack(buff, stack , true)
end



return {
    Buff = Buff,
}