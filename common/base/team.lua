Team = base.tsc.__TS__Class()
Team.name = 'Team'

local mt = Team.prototype

mt.type = 'team'
mt.id = nil

function mt:get_id()
    return self.id
end

function mt:each_player()
    local next_player = base.each_player()
    local function next()
        local player = next_player()
        if not player then
            return nil
        end
        if player:get_team_id() == self.id then
            return player
        else
            return next()
        end
    end
    return next
end

local all_teams = {}

local inited = false
local function init()
    if inited then
        return
    end
    inited = true
    for id, data in pairs(base.table.config.player_setting) do
        if not all_teams[id] then
            log_file.debug('初始化队伍', id)
            all_teams[id] = setmetatable({ id = id }, mt)
        end
    end
end

function base.team(id)
    init()
    return all_teams[id]
end

return {
    Team = Team,
}