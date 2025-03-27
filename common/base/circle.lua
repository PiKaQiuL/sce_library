RegionCircle = RegionCircle or base.tsc.__TS__Class()
RegionCircle.name = 'RegionCircle'      
-- base.tsc.__TS__ClassExtends(RegionCircle, Region)

local mt = RegionCircle.prototype

mt.type = 'circle'
mt._point = nil
mt._range = 0.0

function mt:get_point()
    return self._point:copy()
end

function mt:get_scene_point()
    return self._point:copy_to_scene_point(self.scene)
end

function mt:get_range()
    return self._range
end

function mt:random_point()
    local angle = math.random() * 360.0
    local distance = (math.random() * self._range * self._range) ^ 0.5
    return self._point:polar_to({angle, distance})
end

function mt:scene_random_point()
    return self:random_point():copy_to_scene_point(self.scene)
end

function mt:init_region(filter)
    if not self.region then
        local circle = self
        local region = base.region.circle({point = circle._point, radius = circle._range, filter = filter}, circle.scene)
        if region then
            function region:on_enter(unit)
                if unit:get_scene_name() == circle.scene then
                    base.event_notify(circle, "区域-进入", circle, unit)
                    base.game:event_notify("区域-进入", circle, unit)
                end
            end
            function region:on_leave(unit)
                if unit:get_scene_name() == circle.scene then
                    base.event_notify(circle, "区域-离开", circle, unit)
                    base.game:event_notify("区域-离开", circle, unit)
                end
            end
            circle.region = region
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



function base.circle(point, range, scene_name)
    local circle = setmetatable({ _point = point, _range = range, scene = scene_name or point.scene or default_scene}, mt)
    return circle
end


return {
    RegionCircle = RegionCircle
}