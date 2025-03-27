RegionRect = RegionRect or base.tsc.__TS__Class()
RegionRect.name = 'RegionRect'
-- base.tsc.__TS__ClassExtends(RegionRect, Region)

local mt = RegionRect.prototype

mt.type = 'rect'
mt._point = nil
mt._width = 0.0
mt._height = 0.0

function mt:get_scene()
    return self.scene
end

function mt:get_point()
    return self._point:copy()
end

function mt:get_scene_point()
    return self._point:copy_to_scene_point(self.scene)
end

function mt:get_start_point(pos,width)
    local x,y = pos:get_xy();
    return base.point(x - width/2,y)
end

function mt:get_start_scene_point(pos,width)
    return base.scene_point(pos[1] - width/2, pos[2], pos[3], pos.scene or self.scene)
end

function mt:get_width()
    return self._width
end

function mt:get_height()
    return self._height
end

function mt:random_point()
    local x0, y0 = self._point:get_xy()
    local x = x0 - self._width / 2.0 + math.random() * self._width
    local y = y0 - self._height / 2.0 + math.random() * self._height
    return base.point(x, y)
end

function mt:scene_random_point()
    return self:random_point():copy_to_scene_point(self.scene)
end

function mt:init_region()
    if not self.region then
        local x, y = self:get_width()/2, self:get_height()/2
        local cx, cy = self:get_point():get_xy()
        local region = base.region.polygon ({
            points = {
                base.point(cx + x, cy + y),
                base.point(cx + x, cy - y),
                base.point(cx - x, cy - y),
                base.point(cx - x, cy + y),
            }
        }, self.scene)
        if region then
        local rect = self
            function region:on_enter(unit)
                if unit:get_scene_name() == rect.scene then
                    base.event_notify(rect, "区域-进入", rect, unit)
                    base.game:event_notify("区域-进入", rect, unit)
                end
            end
            function region:on_leave(unit)
                if unit:get_scene_name() == rect.scene then
                    base.event_notify(rect, "区域-离开", rect, unit)
                    base.game:event_notify("区域-离开", rect, unit)
                end
            end
            self.region = region
        end
    end
end

function mt:remove_region()
    if self.region then
        self.region:remove()
        self.region = nil
    end
end

local default_scene = 'default'

function base.rect(...)
    local arg1, arg2, arg3, arg4 = ...
    local args = {arg1, arg2, arg3, arg4}
    local count = select('#', ...)
    while type(args[count]) == 'string' do
        count = count - 1
        if count == 0 then
            break
        end
    end
    local rect
    if count == 2 then
        local p1, p2, scene_name = ...
        local x1, y1 = p1:get_xy()
        local x2, y2 = p2:get_xy()
        if x1 > x2 then
            x1, x2 = x2, x1
        end
        if y1 > y2 then
            y2, y1 = y1, y2
        end
        local width = x2 - x1
        local height = y2 - y1
        local point = base.point(x1 + width / 2.0, y1 + height / 2.0)
        rect = setmetatable({ _point = point, _width = width, _height = height, scene = scene_name or default_scene}, mt)
    elseif count == 3 then
        local point, width, height, scene_name = ...
        rect = setmetatable({ _point = point, _width = width, _height = height, scene = scene_name or default_scene}, mt)
    end
    return rect
end

return {
    RegionRect = RegionRect
}