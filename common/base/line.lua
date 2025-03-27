Line = Line or base.tsc.__TS__Class()
Line.name = 'Line'

---TODO: 设置类型
---base.tsc.__TS__ClassExtends(Line, Array<Point>)

local mt = Line.prototype
mt.type = 'line'

function mt:get(i)
    if self[i] then
        return self[i]
    end
    log.error(string.format('错误的索引[%s](%s)', i, type(i)))
end

function mt:get_length()
    return #self
end

function base.line(points)
    return setmetatable(points, mt)
end

---获取地编线
function base.get_scene_line(scene, area_name, present)
    if (present[scene] and present[scene]['line'][area_name]) then
        for i = 1, # present[scene]['line'][area_name] do
            if not(present[scene]['line'][area_name][i]:get_scene()) then
                present[scene]['line'][area_name][i] = present[scene]['line'][area_name][i]:copy_to_scene_point(scene)
            end
        end
        present[scene]['line'][area_name].scene = scene
    end
    return (present[scene] and present[scene]['line'][area_name])
end

return {
    Line = Line
}