return function (template, bind)
    local ui = base.ui.view {
        type = 'spline_curve',
        name = template.name,
        id = template.id
    }

    base.ui.watch(ui, template, bind, 'line_color')
    base.ui.watch(ui, template, bind, 'curve_margin')
    base.ui.watch(ui, template, bind, 'control_points')
    base.ui.watch(ui, template, bind, 'editable')
    base.ui.watch(ui, template, bind, 'user_opt')
    base.ui.watch(ui, template, bind, 'enable_negative')
    base.ui.watch(ui, template, bind, 'active_pt')

    return ui
end
