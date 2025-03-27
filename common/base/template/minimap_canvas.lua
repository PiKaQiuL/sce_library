local minimap_to_world = ui.minimap_to_world
local function get_point(self, position)
    local x, y
    if minimap_to_world and position and self then
        x, y = minimap_to_world(self.id, position[1], position[2])
    end
    return base.point(x, y)
end

local world_to_minimap = ui.minimap_to_screen
local function get_position(self, point)
    local x, y
    if world_to_minimap and point and self then
        x, y = world_to_minimap(self.id, point[1], point[2])
    end
    return base.position(x, y)
end

return function (template, bind)
    local ui = base.ui.view {
        type = 'minimap_canvas',
        name = template.name,
        id = template.id
    }

    base.ui.watch(ui, template, bind, 'follow_target_id')
    base.ui.watch(ui, template, bind, 'map_ratio')
    base.ui.watch(ui, template, bind, 'map_rotate')
    base.ui.watch(ui, template, bind, 'map_circle_scissor')

    ui.get_point = get_point
    ui.get_position = get_position

    ui.get_point_on_minimap = get_point

    return ui
end
