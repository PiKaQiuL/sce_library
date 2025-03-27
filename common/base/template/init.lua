local ui_types = {
    'button',
    'canvas',
    'dock_area',
    'input',
    'label',
    'panel',
    'particle',
    'progress',
    'scene',
    'spine',
    'sprites',
    'viewport',
    'virtual_joystick',
    'virtual_joystick_listener',
    'virtual_joystick_slider',
    'window',
    'color_packer',
    'color_panel',
    'lite_code',
    'minimap_canvas',
    'video',
    'scroll_rect',
    'spline_bg',
    'spline_curve',
    'bezier_curve',
    'webview',
}

local ui = base.ui
local template = base.ui.template
for i = 1, #ui_types do
    local ui_type = ui_types[i]
    ui[ui_type] = template(include('base.template.' .. ui_type), ui_type)
end