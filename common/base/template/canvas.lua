local canvas_texture_set_name = ui.canvas_texture_set_name
local canvas_texture_set_size = ui.canvas_texture_set_size
local canvas_texture_set_fill_color = ui.canvas_texture_set_fill_color
local canvas_texture_fill_pixel = ui.canvas_texture_fill_pixel
local canvas_texture_fill_rect = ui.canvas_texture_fill_rect
local canvas_texture_clear_circle = ui.canvas_texture_clear_circle
local canvas_texture_fill_circle = ui.canvas_texture_fill_circle
local canvas_texture_get_pixel_color = ui.canvas_texture_get_pixel_color
local canvas_texture_set_compressed_data = ui.canvas_texture_set_compressed_data
local canvas_texture_get_compressed_data = ui.canvas_texture_get_compressed_data
local canvas_texture_set_blur = ui.canvas_texture_set_blur

local texture_brush = {}

local canvas_brush_map = setmetatable({}, { __mode = 'kv' })

local function get_brush(ui)
    local brush = canvas_brush_map[ui]
    if not brush and ui then
        brush = setmetatable({ id = ui.id }, texture_brush)
        canvas_brush_map[ui] = brush
    end
    return brush
end

texture_brush.__index = texture_brush

function texture_brush:set_name(name)
    return canvas_texture_set_name(self.id, name)
end

function texture_brush:set_size(w, h)
    return canvas_texture_set_size(self.id, w, h)
end

function texture_brush:set_fill_color(color)
    return canvas_texture_set_fill_color(self.id, color)
end

function texture_brush:fill_pixel(x, y)
    return canvas_texture_fill_pixel(self.id, x, y)
end

function texture_brush:fill_rect(x, y, w, h)
    return canvas_texture_fill_rect(self.id, x, y, w, h)
end

function texture_brush:clear_circle(x, y, r, smooth)
    return canvas_texture_clear_circle(self.id, x, y, r, smooth)
end

function texture_brush:fill_circle(x, y, r)
    return canvas_texture_fill_circle(self.id, x, y, r)
end

function texture_brush:get_pixel_color(x, y)
    return canvas_texture_get_pixel_color(self.id, x, y)
end

function texture_brush:set_compressed_data(data)
    return canvas_texture_set_compressed_data(self.id, data)
end

function texture_brush:get_compressed_data(callback)
    return canvas_texture_get_compressed_data(self.id, callback)
end

function texture_brush:set_blur(blur)
    return canvas_texture_set_blur(self.id, blur)
end

return function (template, bind)
    local ui = base.ui.view {
        type = 'canvas',
        name = template.name,
        id = template.id
    }
    ui.get_brush = get_brush
    return ui
end
