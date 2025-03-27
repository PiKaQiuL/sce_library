function unit_check(unit, disable_error)
    local __type = type(unit)
    if __type == 'function' then
        return true
    elseif unit == nil or (__type ~= 'table' and __type ~= 'userdata') or unit.type ~= 'unit' then
        if not disable_error then
            log.error("单位参数无效，请检测函数传入值。参数：", unit)
        end
        return false
    else
        return true
    end
end

function item_check (item, disable_error)
    local __type = type(item)
    if item == nil or (__type ~= 'table' and __type ~= 'userdata') or item.type ~= 'item' then
        if not(disable_error) then
            log.error("物品参数无效，请检测函数传入值。参数：", item)
        end
        return false
    else
        return true
    end
end

function skill_check(skill, disable_error)
    local __type = type(skill)
    if skill == nil or (__type ~= 'table' and __type ~= 'userdata') or skill.type ~= 'skill' then
        if not(disable_error) then
            log.error("技能参数无效，请检测函数传入值。参数:", skill)
        end
        return false
    else
        return true
    end
end

function player_check (player, disable_error)
    local __type = type(player)
    if player == nil or (__type ~= 'table' and __type ~= 'userdata') or player.type~='player' then
        if not(disable_error) then
            log.error("玩家参数为空，请检测函数传入值")
        end
        return false
    else
        return true
    end
end

function circle_check(obj, disable_error)
    if obj and type(obj) == 'table' and obj.type == 'circle' then
        return true
    else
        if not(disable_error) then
            log.error("圆形区域参数为空，请检测函数传入值")
        end
        return false
    end
end

function rect_check(obj, disable_error)
    -- log.error("obj：",obj)
    if obj and type(obj) == 'table' and obj.type == 'rect' then
        return true
    else
        if not(disable_error) then
            log.error("矩形区域参数为空，请检测函数传入值")
        end
        return false
    end
end

function area_check(obj, disable_error)
    if circle_check(obj, true) or rect_check(obj, true) then
        return true
    else
        if not(disable_error) then
            log.error("区域参数为空，请检测函数传入值")
        end
        return false
    end
end

function point_check (point, disable_error)
    local __type = type(point)
    if point == nil or (__type ~= 'table' and __type ~= 'userdata') or point.type ~= 'point' then
        if not(disable_error) then
            log.error("点参数无效，请检测函数传入值，参数：", point)
        end
        return false
    else
        return true
    end
end

function line_check (line, disable_error)
    local __type = type(line)
    if line == nil or (__type ~= 'table' and __type ~= 'userdata') or line.type ~= 'line' then
        if not(disable_error) then
            log.error("线参数无效，请检测函数传入值，参数：", line)
        end
        return false
    else
        return true
    end
end

function buff_check (buff, disable_error)
    local __type = type(buff)
    if buff == nil or (__type ~= 'table' and __type ~= 'userdata') or buff.type ~='buff' then
        if not(disable_error) then
            log_file.debug("Buff参数无效，请检测函数传入值，参数：", buff)
        end
        return false
    else
        return true
    end
end

function trigger_check (trigger, disable_error)
    local __type = type(trigger)
    if trigger == nil or __type ~= 'table' or trigger.type ~= 'trigger' then
        if not(disable_error) then
            log.error("触发器参数无效，请检测函数传入值，参数：", trigger)
        end
        return false
    else
        return true
    end
end

function timer_check (timer, disable_error)
    local __type = type(timer)
    if timer == nil or __type ~= 'table' or timer.type ~= 'timer' then
        if not(disable_error) then
            log.error("计时器参数无效，请检测函数传入值，参数：", timer)
        end
        return false
    else
        return true
    end
end

function any_unit_check(unit, disable_error)
    if unit == base.any_unit then
        return true
    else
        if not(disable_error) then
            log.error"任意单位参数无效，请检测函数传入值"
        end
        return false
    end
end

function any_skill_check(skill, disable_error)
    if skill == base.any_skill then
        return true
    else
        if not(disable_error) then
            log.error"任意技能参数无效，请检测函数传入值"
        end
        return false
    end
end

function any_player_check(player, disable_error)
    if player == base.any_player then
        return true
    else
        if not(disable_error) then
            log.error"任意效果参数无效，请检测函数传入值"
        end
        return false
    end
end

function id_check(obj_id, disable_error)
    if type(obj_id) == 'string' then
        return true
    else
        if not(disable_error) then
            log.error"id参数无效，请检测函数传入值"
        end
        return false
    end
end

function event_name_check(event_name, disable_error)
    if type(event_name) == 'string' then
        return true
    else
        if not(disable_error) then
            log.error"事件名称参数无效，请检测函数传入值"
        end
        return false
    end
end

function time_check(time, disable_error)
    if type(time) == 'number' then
        return true
    else
        if not(disable_error) then
            log.error"时间参数无效，请检测函数传入值"
        end
        return false
    end
end

local control_util = require'@common.base.gui.control_util'
function component_check(cmpt, disable_error)
    if control_util.is_ctrl(cmpt) and control_util.is_ctrl_exists(cmpt) then
        return true
    end
    if not(disable_error) then
        log.error('UI控件参数无效，请检测函数传入值')
    end
    return false
end

function base.gui_check(cmpt)
    return component_check(cmpt, true)
end

function base.gui_get_part_as(ts_type, cmpt, part_name)
    if (not ts_type) and (not part_name) then
        return base.gui_get_part(ts_type, cmpt)
    end
    local result = base.gui_get_part(cmpt, part_name)
    return result
end

function base.gui_get_parts_ts(ts_type, cmpt, part_name)
    if component_check(cmpt) then
        local p = cmpt.part[part_name]
        if type(p) == 'table' then
            return p
        end
        return nil
    end
    return nil
end

function base.gui_get_array_child(ts_type, cmpt)
    if component_check(cmpt) then
        if cmpt.data.array_component then
            local p = cmpt.data.array_component.part['__ctrl_array_item']
            if type(p) == 'table' then
                return p
            end
        end
        return nil
    end
    return nil
end

function base.gui_get_child_ui_by_name_as(ts_type, cmpt, child_name)
    if (not ts_type) and (not child_name) then
        return base.gui_get_child_ui_by_name(ts_type, cmpt)
    end
    local result = base.gui_get_child_ui_by_name(cmpt, child_name)
    return result
end

function base.gui_get_children(ctrl)
    return control_util.get_children(ctrl)
end

function base.gui_get_rect(ctrl)
    if control_util.is_component_ctrl(ctrl) then
        ctrl = ctrl.ui
    end
    if ctrl then
        local x, y, w, h = ctrl:get_ui_rect()
        return {x=x, y=y, w=w, h=h}
    end
end

function base.gui_get_parent(ctrl)
    return control_util.get_parent(ctrl)
end

local fade_ui = nil

function base.fade_in_out(fade_type, fade_time, is_wait, color, opacity, curve_type, z_index)
    color = color or '0, 0, 0'
    opacity = opacity or 100
    curve_type = curve_type or 'linear'
    z_index = z_index or 9999
    if fade_type == 'fade_in' then
        base.fade_in(fade_time, is_wait, color, opacity, curve_type, z_index)
    elseif fade_type == 'fade_out' then
        base.fade_out(fade_time, is_wait, color, opacity, curve_type, z_index)
    end
end

function base.fade_in(fade_time, is_wait, color, opacity, curve_type, z_index)
    local component = require '@common.base.gui.component'
    local bind = component.bind
    local template = component 'fade_panel' {
        base.ui.panel {
            layout = {
                grow_width = 1,
                grow_height = 1,
            },
            opacity = bind.opacity,
            transition = {
                opacity = {
                    time = 1000,
                    func = 'ease_in'
                }
            },
            color = 'rgba(255,255,255,1)'
        },
        prop = {
            opacity = 0,
        },
        method = {
            init = function(self)
            end,
            fade_in = function(self)
                self.opacity = 1
            end,
            fade_out = function(self)
                self.opacity = 0
            end
        }
    }
    if not fade_ui then
        fade_ui = template:new()
    end
    fade_ui.color = 'rgba('..color..', '..tostring(tonumber(opacity) * 0.01)..')'
    fade_ui.z_index = z_index
    fade_ui.transition.opacity = {
        time = fade_time * 1000,
        func = curve_type,
    }
    base.next(function()
        fade_ui:fade_in()
    end)
    if is_wait then
        coroutine.sleep(fade_time * 1000)
    end
end

function base.fade_out(fade_time, is_wait, color, opacity, curve_type, z_index)
    if not fade_ui then
        log_file.info('淡出无效，请先淡入。')
        return false
    end
    fade_ui.color = 'rgba('..color..', '..tostring(tonumber(opacity) * 0.01)..')'
    fade_ui.z_index = z_index
    fade_ui.transition.opacity = {
        time = fade_time * 1000,
        func = curve_type,
    }
    fade_ui:fade_out()
    base.wait(fade_time * 1000 + 1000, function()
        fade_ui:destroy()
        fade_ui = nil
    end)
    if is_wait then
        coroutine.sleep(fade_time * 1000)
    end
end