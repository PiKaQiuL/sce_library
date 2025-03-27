--- lua_plus ---
function base.point_angle(point:point, target:point) angle
    ---@ui ~1~到~2~的连线的角度
    ---@description 两点连线的角度
    ---@belong point
    ---@keyword 角度
    ---@applicable value
    ---@name1 点1
    ---@name2 点2
    if point_check(point) then
        return point:angle(target)
    end
end

function base.point_copy(point:point) point
    ---@ui 复制点~1~
    ---@description 复制点
    ---@belong point
    ---@keyword 复制
    ---@applicable value
    ---@name1 点
    if point_check(point) then
        return point:copy()
    end
end

function base.point_distance(point:point, target:point) number
    ---@ui ~1~到~2~的距离
    ---@description 两点间的距离
    ---@keyword 距离
    ---@belong point
    ---@applicable value
    ---@name1 点1
    ---@name2 点2
    if point_check(point) then
        return point:distance(target)
    end
end

function base.point_get_x(point:point) number
    ---@ui ~1~的X坐标
    ---@description 点的X坐标
    ---@keyword X 坐标
    ---@belong point
    ---@applicable value
    ---@name1 点
    if point_check(point) then
        return point[1]
    end
end

function base.point_get_y(point:point) number
    ---@ui ~1~的Y坐标
    ---@description 点的Y坐标
    ---@keyword Y 坐标
    ---@belong point
    ---@applicable value
    ---@name1 点
    if point_check(point) then
        return point[2]
    end
end

function base.point_is_block2(point:point, prevent_bits:碰撞类型, required_bits:碰撞类型) boolean
    ---@ui 点~1~是否符合条件：(有标记~2~，没有标记~3~)的碰撞
    ---@description 点的某类碰撞类型检测
    ---@belong point
    ---@keyword 碰撞 阻挡
    ---@applicable value
    ---@name1 点
    ---@name2 碰撞类型1
    ---@name3 碰撞类型2
    if point_check(point) then
        return point:is_block(point:get_scene(), prevent_bits, required_bits)
    end
end

function base.point_move(point:point, angle:angle, distance:number) point
    ---@ui ~1~向角度~2~移动距离~3~后的点
    ---@description 点的极坐标偏移
    ---@belong point
    ---@keyword 角度 距离
    ---@applicable value
    ---@name1 点
    ---@name2 角度
    ---@name3 距离
    if point_check(point) then
        return point:polar_to({angle, distance})
    end
end

function base.line_get(line:line, index:integer) point
    ---@ui 线~1~上的第~2~个点
    ---@description 线上的点
    ---@belong point
    ---@applicable value
    ---@name1 线
    ---@name2 位置
    if line_check(line) then
        return line:get(index)
    end
end

function base.pathing_way_points(st:point, ed:point) line
    ---@ui 点~1~到点~2~的通行路径
    ---@description 两点间的通行路径
    ---@belong point
    ---@applicable value
    ---@name1 起点
    ---@name2 终点
    ---@keyword 点 线
    if and (point_check(st), point_check(ed)) then
        if and (st:get_scene(), st:get_scene() == ed:get_scene()) then
            local current_scene = st:get_scene()
            local _, points = base.game.pathing_way_points(st, ed, 0, st:get_scene())
            if points then
                local ret = {}
                for i = 1, #points do
                    table.insert(ret, base.scene_point(points[i].x, points[i].y, nil, current_scene))
                end
                return base.line(ret)
            else
                log_file.info(string.format('无法获取点[%s]到点[%s]的路径', st, ed))
            end
        else
            log_file.info(string.format('无法获取点[%s]到点[%s]的路径', st, ed))
        end
    end
end
