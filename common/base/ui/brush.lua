
local brush = {}

brush.__index = brush

function brush:create(canvas_id)
    local instance = {}
    setmetatable(instance, self)
    instance.id = canvas_id
    return instance
end

function brush:clear()
    ui.clear(self.id)
end

function brush:set_line_width(width)
    ui.set_line_width(self.id, width)
end

function brush:set_line_color(color)
    ui.set_line_color(self.id, color)
end

function brush:set_fill_color(color)
    ui.set_fill_color(self.id, color)
end

function brush:draw_line(x1, y1, x2, y2)
    ui.draw_line(self.id, x1, y1, x2, y2)
end

function brush:draw_circle(x, y, r)
    ui.draw_circle(self.id, x, y, r)
end

function brush:fill_circle(x, y, r)
    ui.fill_circle(self.id, x, y, r)
end

-- 顺时针 ==> polygon = { { 0, 0 }, { 0, 1 }, { 1, 1 }, { 1, 0 } }
function brush:draw_polygon(polygon)
    ui.draw_polygon(self.id, base.json.encode(polygon))
end

function brush:fill_polygon(polygon)
    ui.fill_polygon(self.id, base.json.encode(polygon))
end

function brush:draw_image(path, x, y, w, h)
    ui.draw_image(self.id, path, x, y, w, h)
end

function brush:rotate(x, y, angle)
    ui.rotate(self.id, x, y, angle)
end

function brush:path_line_to(x, y)
    ui.canvas_path_line_to(self.id, x, y)
end

function brush:path_stroke(close)
    ui.canvas_path_stroke(self.id, close)
end

---@overload fun(x2:number, y2:number, x3:number, y3:number)
---@overload fun(x2:number, y2:number, x3:number, y3:number, x4:number, y4:number)
function brush:path_bezier_curve_to(...)
    ui.canvas_path_bezier_curve_to(self.id, ...)
end

base.ui.brush = brush
