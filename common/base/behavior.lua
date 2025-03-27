base.proto.unit_get_interaction_spell = function(msg)
    local unit = base.unit(msg.unit_id)
    if unit then
        unit.interact_skill_name = msg.skill_link
    end
    if unit ~= base.local_player():get_hero() then
        return
    end
    unit:event_notify('单位-获得交互技能', msg.skill_link)
end

base.proto.unit_remove_interaction_spell = function(msg)
    local unit = base.unit(msg.unit_id)
    if unit then
        unit.interact_skill_name = msg.skill_link
    end
    if unit ~= base.local_player():get_hero() then
        return
    end
    unit:event_notify('单位-失去交互技能')
end

function base.refresh_interact_joystick ()
    local hero = base.local_player():get_hero()
    if hero then
        if hero.interact_skill_name then
            hero:event_notify('单位-获得交互技能', hero.interact_skill_name)
        else
            hero:event_notify('单位-失去交互技能')
        end
    end
end

local cursor_shape, unit_highlight

local get_first_unit = function(pos)
    local first_unit
    local units = base.get_units_from_screen_xy(pos)
    for _, v in ipairs(units) do
        if not v:is_item() then
            first_unit = v
            break
        end
    end
    return first_unit
end



----------------------------------------------------------------------------
local function init()
    local default_gameplay_id = "$$.gameplay.dflt.root"
    local gameplay = base.eff.cache(default_gameplay_id)
    if gameplay and gameplay.HighlightConfig then
        base.game:event('鼠标-移动', function ()
            -- log.error(common.get_system_cursor())
            if not game then
                return
            end
            local first_unit = get_first_unit(base.mouse_screen_pos())
            local local_player = base.player_local()
            local other_player = first_unit and first_unit:get_owner() or nil
            local status
            if not first_unit then
                status = ''
            elseif other_player == local_player then
                status = '选中自身单位'
            elseif local_player:is_ally(other_player) then
                status = '选中友方单位'
            elseif local_player:is_enemy(other_player) then
                status = '选中敌方单位'
            else
                status = '选中中立单位'
            end
            if first_unit ~= unit_highlight then
                if gameplay.HighlightConfig[status] then
                    local highlight = gameplay.HighlightConfig[status]
                    base.set_unit_highlight_on(first_unit, highlight[1], highlight[2], highlight[3], highlight[4], -1)
                    base.set_unit_highlight_off(unit_highlight)
                    unit_highlight = first_unit
                end
            end
            
            local cursor_image
            if gameplay.CursorConfig then
                cursor_image = gameplay.CursorConfig[status]
            end
            if cursor_shape ~= cursor_image then
                cursor_shape = cursor_image
                if cursor_shape then
                    common.set_cursor_shape(status, cursor_shape)
                    common.set_use_system_cursor(false)
                else
                    common.set_use_system_cursor(true)
                end
            end
        end)
    end
    
    --------------------------------------------------------------------------
    if gameplay and gameplay.PCRightButtonActor then
        local pc_actor
        base.game:event('鼠标-按下', function (_, key)
            if not game then
                return
            end
            local local_player = base.player_local()
            if not local_player or not local_player:get_hero() then
                return
            end
            if key == 'button_right' then
                local default_gameplay_id = "$$.gameplay.dflt.root"
                local screen_pos = base.mouse_screen_pos()
                local first_unit, point = get_first_unit(screen_pos), screen_pos:get_point()
                local unit_point = first_unit and first_unit:get_point()
                local _x, _y = unit_point and unit_point[1] or point[1], unit_point and unit_point[2] or point[2]
                base.game:server '__use_skill' {
                    id = first_unit and first_unit._id or nil,
                    x = _x,
                    y = _y
                }
                if first_unit then
                    return
                end
                if pc_actor then
                    pc_actor:destroy(true)
                end
                pc_actor = base.create_actor_at(
                    gameplay.PCRightButtonActor,
                    point,
                    true
                )
                if pc_actor then
                    pc_actor:play()
                end
            end
        end)
    end
end
if base.eff.cache_init_finished() then
    init()
else
    base.game:event('Src-PostCacheInit', function()
        init()
    end)
end