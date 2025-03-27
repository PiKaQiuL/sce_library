-- local mt={}
-- 获取地编区域
function base.get_scene_area(scene, area_type, area_name, present)
    local area = (present and present[scene] and present[scene][area_type] and present[scene][area_type][area_name])
    if area then
        area.scene = area.scene or scene
    end
    return area
end

function base.circle(point, range, scene_name)
    local circle = setmetatable({ _point = point, _range = range, scene = scene_name or point.scene or default_scene}, mt)
    return circle
end

function base.get_area_player_type_unit_group(area, player, unit_id_name, target_filter_string)
    local units = base.get_area_unit(area)
    local ret = {}
    for i = 1, #units do
        local unit = units[i]
        -- 判断是否区域和物体是否在同一区域
        if area.scene ~= unit:get_scene() then
            return "区域和物体不在同一场景，请检查。"
        end
        if ((unit_id_name == base.any_unit_id or unit:get_name() == unit_id_name) and (player == base.any_unit or unit:get_owner() == player)) then
            ret[#ret+1] = unit
        end
    end
    if type(target_filter_string) == "table" then
        return base.unit_group_filter_group(base.单位组(ret), target_filter_string)
    end
    return base.unit_group_filter_group(base.单位组(ret), base.target_filters:new(target_filter_string))
end

function base.get_area_unit(area)
    if circle_check(area, true) then
        return base.get_circle_area_unit(area)
    elseif rect_check(area, true) then
        return base.get_rect_area_unit(area)
    else
        area_check(area)
    end
end

function base.get_circle_area_unit(circle)
    if circle_check(circle) then
        return base.game:circle_selector(circle:get_scene_point(),circle:get_range(),'',false)
    else
        return {}
    end
end


function base.get_rect_area_unit(rect)
    if rect_check(rect) then
        local point = rect:get_point()
        local height = rect:get_height() --height对应的是width
        local width = rect:get_width() --width对应的是length
        return base.game:line_selector(rect:get_start_scene_point(point,width),width,height,base.point(1,0),'')
    else
        return {}
    end
end



function base.get_scene_scale_area()
    ---@ui 场景~1~的整个区域
    ---@description 场景的整个区域
    ---@belong area
    ---@applicable value
    ---@name1 场景名
    -- local x, y = base.game.get_scene_scale(scene_name)
    -- base.rect(base.point(0, 0), base.point(x, y), scene_name)
    return '1'
end


function base.is_unit_in_area(unit, area)
    if unit_check(unit) then
        if area then
            return base.is_point_in_area(base.unit_get_point(unit), area)
        else
            log.error"区域参数无效，请检测函数传入值"
            return false
        end
    else
        log.error"单位参数无效，请检测函数传入值"
        return false
    end
end

function base.is_point_in_circle(point, circle)
    ---@ui ~1~是否在圆形区域~2~内
    ---@description 点是否在圆形区域内
    ---@belong area
    ---@applicable value
    ---@selectable false
    if circle_check(circle) then
        local dist, err = circle:get_scene_point():distance(point)
        if err then
            log_file.info(string.format('点[%s]不在园所处场景内', point))
            return false
        else
            return (circle:get_scene_point():distance(point)) <= circle:get_range()
        end
    else
        return false
    end
end

function base.is_point_in_rect(point, rect)
    ---@ui ~1~是否在矩形区域~2~内
    ---@description 点是否在矩形区域内
    ---@belong area
    ---@applicable value
    ---@selectable false
    if rect_check(rect) then
        if rect:get_scene() ~= point:get_scene() then
            log_file.info(string.format('点[%s]不在矩形所处场景内', point))
            return false
        end
        local dx, dy = rect:get_width()/2, rect:get_height()/2
        local rx, ry = rect:get_point():get_xy()
        local px, py = point:get_xy()
        return math.abs(rx - px) <= dx and math.abs(ry - py) <= dy
    else
        return false
    end
end

function base.is_point_in_area(point, area)
    if area_check(area) then
        if circle_check(area, true) then
            return base.is_point_in_circle(point, area)
        elseif rect_check(area, true) then
            return base.is_point_in_rect(point, area)
        end
        return false
    end
end