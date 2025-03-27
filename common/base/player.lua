Player = base.tsc.__TS__Class()
Player.name = 'Player'

---@class Player
local mt = Player.prototype
mt.__index = mt

mt.type = 'player'
mt._id = -1
mt._user_id = 0
mt._ptype = 'unknow'
mt._team = nil
mt._name = ''
mt._hero = nil
mt._hero_name = ''
mt._title = ''
mt._online = false
mt._type = nil
mt._loading_progress = 0
mt._vip_level = 0
mt._user_icon = ''
mt._user_border = ''

function mt:__tostring()
    local ptype = self._ptype
    if ptype == 'computer' then
        return ('{player|%q-%s-%s}'):format(self._id, self._ptype, self:get_team_id())
    else
        return ('{player|%q-%s-%s|%q|%q}'):format(self._id, self._ptype, self:get_team_id(), self:user_name(), self._user_id)
    end
end

local constant_map
local function init_one_player(id, ptype, team)
    assert(id >= 0 and math.tointeger(id))
    assert(ptype == 'user' or ptype == 'computer')
    assert(math.tointeger(team))
    if team < 0 then
        log.error('玩家'..tostring(id)..'队伍为'..tostring(team)..'。队伍编号必须大于0')
    end

    local user_id, name, title, title_color, user_team, online, player_type,
          vip_level, user_border, loading_progress, user_icon,
          bself,     slot_id,     click_hero_id,    hero_id = game.get_player_info(id)
    local lua_player_type  = {'none', 'user', 'ai', 'ob', 'commputer'}

    -- 服务器没同步过来的，预期是塞的ai，现在地图写n个玩家 ，app匹配时只请求一个 所以不会塞ai,别的槽位得填一下
    --TODO 等app匹配时填对地图人数 这里可以去掉
    if not user_id then
        player_type = 1
    end

    log_file.debug('init player', id, user_id, ptype, player_type, team)
    local player = setmetatable({
        _id      = id,
        _user_id = user_id,
        _ptype   = lua_player_type[player_type+1],
        _team    = team,
        _name    = name,
        _title   = title,
        _online  = online,
        _type    = player_type,

        _loading_progress = loading_progress,
        _vip_level        = vip_level,
        _user_border      = user_border,
        _user_icon        = user_icon,

        _attribute = {},
    }, mt)
    for _, key in pairs(constant_map) do
        player._attribute[key] = 0
    end
    return player
end

local player_map
local players
local function init_players()
    player_map = {}
    players = {}
    constant_map = {}
	local slots = {}
    for key, id in pairs(base.table.constant['玩家属性']) do
        constant_map[id] = key
    end
    local gamedata
    if base.eff.has_cache_init() then
        gamedata = base.eff.cache('$$.map_config.dflt.root')
    else
        gamedata = base.table.config
    end
    log_file.info('========start init players======', base.table.config.player_setting, gamedata.player_setting)
    for slot, player_config in pairs(gamedata.player_setting) do
        player_map[slot] = init_one_player(slot, player_config[1], player_config[2])
        players[slot] = player_map[slot]
    end

    log_file.info('========finish init players======')
    -- 改成用服务器下发的，因为无人操控的玩家服务器不会遍历到
    --[[
    for id, slot in pairs(game.get_player_list()) do
        log_file.debug(('player slot：[%q] --> [%q]'):format(id, slot))
        slots[slot] = id
    end
    for id in pairs(base.table.config.player_setting) do
		--slots[#slots+1] = id
    end
	table.sort(slots)
    for i, p in pairs(base.table.config.player_setting) do
        log_file.debug(i, p)
    end
    log_file.debug('=======初始化玩家=======')
    for i, id in pairs(slots) do
        log_file.debug(i, id)
        local data = base.table.config.player_setting[id]
        player_map[id] = init_one_player(id, data[1], data[2])
        players[i] = player_map[id]
    end
    log_file.debug('=======================')
    ]]
end

local function set_team_id(self, team)
    self._team = team
end

function mt:get_team_id()
    return self._team
end

function mt:get_team()
    return base.team(self._team)
end

local function set_hero(self, unit)
    self._hero = unit
end

function mt:get_hero()
    return self._hero
end

function mt:is_ally(other)
    return self:get_team_id() == other:get_team_id()
end

function mt:is_enemy(other)
    return
        self:get_team_id() ~= other:get_team_id()
        and (not self:is_neutral())
        and (not other:is_neutral())
end

---comment
---@param other Player
---@return boolean
function mt:is_neutral_to(other)
    if self:is_ally(other) then
        return false
    end
    return self:is_neutral() or other:is_neutral()
end

---comment
---@return boolean
function mt:is_neutral()
    return self:get('sys_player_neutral') > 0
end

---comment
---@return boolean
function mt:is_online()
    if self:controller() == 'ai' then
        return true
    end
    return self._online or false
end

function mt:set_hero_upper_body_facing(facing, sync_to_server)
    -- game.unit_set_upper_body_facing(2, facing, sync_to_server)
    if self._hero then
        game.unit_set_upper_body_facing(self._hero._id, facing, sync_to_server)
    else
        log.error('设置上半身朝向失败，没有英雄')
    end
end

function mt:cancel_hero_upper_body_facing(time)
    if self._hero then
        game.unit_cancel_upper_body_facing(self._hero._id, time)
    else
        log.error('取消上半身朝向失败，没有英雄')
    end
end

local function set_hero_name(self, name)
    self._hero_name = name
end

function mt:get_hero_name()
    return self._hero_name
end

function mt:get_hero_reborn()
    local total = self._attribute['复活时间上限']
    local target = self._attribute['复活时间']
    if total <= 0 then
        return 0, 0
    end
    return math.max(0, target - base.clock()), total
end

function mt:user_name()
    return self._name
end

function mt:user_title()
    return self._title
end

function mt:user_icon()
    return "image/LoadingHead/" .. self._user_icon .. ".png"
end

function mt:user_border()
    return "image/LoadingHeadBox/" .. self._user_border .. ".png"
end

function mt:get(key)
    return self._attribute[key]
end

function mt:get_slot_id()
    return self._id
end

function mt:controller()
    if self._ptype == 'computer' then
        return 'computer'
    end
    if self._type == 1 then
        return 'human'
    elseif self._type == 2 then
        return 'ai'
    end
    return 'none'
end

function mt:game_state()
    if self:controller() == 'none' then
        return 'none'
    end
    if self._online then
        return 'online'
    else
        return 'offline'
    end
end

function mt:loading_progress()
    return self._loading_progress
end

local function modify_table(ori_tbl, modify_tbl)
    for k, v in pairs(modify_tbl) do
        if type(v) == 'table' then
            if type(ori_tbl[k]) ~= 'table' then
                ori_tbl[k] = {}
            end
            modify_table(ori_tbl[k], v)
        else
            ori_tbl[k] = v
        end
    end
end

local function delete_table(ori_tbl, modify_tbl)
    for k, v in pairs(modify_tbl) do
        if type(v) == 'table' then
            if type(ori_tbl[k]) ~= 'table' then
                ori_tbl[k] = {}
            end
            delete_table(ori_tbl[k], v)
        else
            ori_tbl[k] = nil
        end
    end
end

local function set_by_sync(self, key, value)
    local attribute = self._attribute
    local ori_tbl = attribute[key]
    if type(ori_tbl) ~= 'table' then
        ori_tbl = {}
    end
    if value.delete then
        delete_table(ori_tbl, value.delete)
    end
    if value.modify then
        modify_table(ori_tbl, value.modify)
    end
    attribute[key] = ori_tbl
    return attribute[key]
end

local function set(self, key, value)
    local attribute = self._attribute
    local old = attribute[key] or 0
    if old == value then
        return false
    end
    attribute[key] = value
    return true
end

function mt:event_notify(name, ...)
	base.event_notify(self, name, ...)
	base.event_notify(base.game, name, ...)
end

function mt:event(name, f)
	return base.event_register(self, name, f)
end

local local_player
function base.local_player()
    if not local_player then
        local user_id = game.get_my_player_info()
        log_file.info(('local user：%q'):format(user_id))
        for player in base.each_player 'user' do
            log_file.info('player:',player)
            if player._user_id == user_id then
                local_player = player
                break
            end
        end
        log_file.info(('local player：%s'):format(local_player))
    end
    return local_player
end

function base.player(id)
    if not player_map then
        init_players()
    end
    return player_map[id]
end

function base.each_player(type)
	if not player_map then
        init_players()
    end
	local i = -1
	local function next()
		i = i + 1
		if not players[i] then
			return nil
		end
		if not type or players[i]._ptype == type then
			return players[i]
		else
			return next()
		end
	end
	return next
end

local function sort_pairs(t)
    local ks = {}
    for k in pairs(t) do
        table.insert(ks, k)
    end
    table.sort(ks)
    local i = 0
    return function ()
        i = i + 1
        local k = ks[i]
        return k, t[k]
    end
end

-- 这个事件在C++已经注掉，不会发生了，统一走下面的on_player_attributes_changed
-- function base.event.on_sync_player_hero(id, unit_id, hero_name)
--     log_file.info('on_sync_player_hero')
--     local player = base.player(id)
--     if not player then return end
--     set_hero_name(player, hero_name)
--     base.next(function()        
--         local hero = base.unit(unit_id)
--         set_hero(player, hero)
--         player:event_notify('玩家-改变英雄', player, hero)
--     end)
-- end

function base.event.on_player_table_attributes_changed(key_values)
    for id, attrs in pairs(key_values) do
        local player = base.player(id)
        for id, value in sort_pairs(attrs) do
            local key = constant_map[id]
            local new_value = set_by_sync(player, key, value)
            player:event_notify('玩家-属性变化', player, key, new_value)
        end
    end
end

function base.event.on_player_attributes_changed(key_values)
    -- log_file.info('on_player_attributes_changed')
    for id, attrs in pairs(key_values) do
        local player = base.player(id)
        if not player then
            log.warn('获得玩家属性变化事件，但玩家在客户端环境不存在，玩家槽位id:', id)
            goto continue
        end
        for id, value in sort_pairs(attrs) do
            local key = constant_map[id]            
            -- log_file.info('player:', player, 'attr:', key, id, 'value:', value)
            if not set(player, key, value) then -- 看有没改，改了的话才进下面。不过讲道理，没改的话服务器是不是不应该同步？
                goto CONTINUE
            end
            if key == '英雄ID' then
                log_file.info('sync player hero id:', value)
                base.next(function() -- 极端情况下客户端还没收到这个UnitID的数据，得这帧末才有，因此就下一帧再做这些处理吧
                    local hero_name = base.get_unit_name(value)
                    set_hero_name(player, hero_name)                         
                    local hero = base.unit(value)                    
                    set_hero(player, hero)
                    -- log_file.info('send a message that indicate change hero')
                    player:event_notify('玩家-改变英雄', player, hero)
                end)                
            elseif key == '英雄类型' then  -- 这种情况现在没有用              
                -- log_file.info('sync player hero type:', value)
                -- local hero = base.unit(value)
                -- set_hero(player, hero)
                -- player:event_notify('玩家-改变英雄', player, hero)
            elseif key == '队伍' then
                local team = player:get_team_id()
                set_team_id(player, value)
                player:event_notify('玩家-改变队伍', player, base.team(value))
            elseif key == '复活时间' then
            elseif key == '复活时间上限' then
                if value == 0 then
                    player:event_notify('玩家-英雄复活', player)
                else
                    player:event_notify('玩家-英雄死亡', player)
                end
            else
                player:event_notify('玩家-属性变化', player, key, value)
            end
            :: CONTINUE ::
        end
        ::continue::
    end
end

function base.event.on_loading_progress_notify(slot_id, progress)
    base.player(slot_id)._loading_progress = progress / 100
end

function mt:get_nick_name()
    local pn = self:get('sys_player_nick')
    if (not pn) or (pn == 0)  then
        local pn_key =  "[EntryNode][$$.map_config.dflt.root].Data.Game.player_setting["..self:get_slot_id().."].DisplayName"
        local locale = base.i18n.get_text(pn_key)
        if locale == pn_key then
            return '玩家 '.. self:get_slot_id()
        end
        return locale
    end
    local nick = tostring(pn)
    return nick
end

function mt:get_num(name, ...)
    local ret = self:get(name, ...);
    if type(ret) ~= "number" then
        log_file.warn("尝试用数字方法获取玩家的非数字属性"..name)
    end
    return ret
end

-- function base.event.on_slot_state_change(slot_id, user_id, user_name, _, online)
--     local player = base.player(slot_id)
--     player._user_id = user_id
--     player._name = user_name
--     if player._online ~= online then
--         player._online = online
--         if online then
--             player:event_notify('玩家-重连', player)
--         else
--             player:event_notify('玩家-断线', player)
--         end
--     end
-- end

return {
    Player = Player,
}
