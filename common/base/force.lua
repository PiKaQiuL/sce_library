local mt = {}
mt.__index = mt
mt.type = 'force'

mt._group = nil

function mt:insert(player)
    self._group:insert(player)
end

function mt:remove(player)
    self._group:remove(player)
end

function mt:has(player)
    return self._group:has(player)
end

function mt:len()
    return self._group:len()
end

function mt:random()
    return self._group:random()
end

function mt:ipairs()
    return self._group:ipairs()
end

function mt:clear()
    self._group:clear()
end

base.force = {}
setmetatable(base.force, base.force)

function base.force:__call(list)
    return setmetatable({ _group = base.group(list) }, mt)
end

local player_api = {
}

local function init()
    local list = {}
    local users = {}
    local computers = {}
    local teams = {}

    if base.table.config.player_setting then
        for id, data in pairs(base.table.config.player_setting) do
            local player = base.player(id)
            list[#list+1] = player
            local source, team = data[1], data[2]
            if source == 'computer' then
                computers[#computers+1] = player
            elseif source == 'user' then
                users[#users+1] = player
            end
            if not teams[team] then
                teams[team] = {}
            end
            teams[team][#teams[team]+1] = player
        end
    end

    base.force.all = base.force(list)
    base.force.computer = base.force(computers)
    base.force.user = base.force(users)
    base.force.team = {}
    for team, list in pairs(teams) do
        base.force.team[team] = base.force(list)
    end

    for _, api in ipairs(player_api) do
        mt[api] = function (self, ...)
            for _, player in self:ipairs() do
                player[api](player, ...)
            end
        end
    end
end

init()
