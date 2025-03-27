
local watch = base.ui.watch
local view = base.ui.view

return function(template, bind)
    local ui = view {
        type = 'window',
        name = template.name,
        id = template.id
    }

    base.ui.watch(ui, template, bind, 'title_name')
    base.ui.watch(ui, template, bind, 'title_icon')
    base.ui.watch(ui, template, bind, 'dock_target')
    base.ui.watch(ui, template, bind, 'dock_type')
    base.ui.watch(ui, template, bind, 'dock_width')
    base.ui.watch(ui, template, bind, 'dock_height')
    base.ui.watch(ui, template, bind, 'dock_min_width')
    base.ui.watch(ui, template, bind, 'dock_min_height')
    base.ui.watch(ui, template, bind, 'drag_initial_horizontal')
    base.ui.watch(ui, template, bind, 'drag_initial_vertical')
    base.ui.watch(ui, template, bind, 'drag_step_horizontal')
    base.ui.watch(ui, template, bind, 'drag_step_vertical')
    base.ui.watch(ui, template, bind, 'fixed')
    base.ui.watch(ui, template, bind, 'dragable')
    base.ui.watch(ui, template, bind, 'window_type')

    return ui
end
