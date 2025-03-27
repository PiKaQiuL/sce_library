return function (template, bind)
    local ui = base.ui.view {
        type = 'bezier_curve',
        name = template.name,
        id = template.id
    }

    base.ui.watch(ui, template, bind, 'bezier_line_color')
    base.ui.watch(ui, template, bind, 'bezier_control_points')
    base.ui.watch(ui, template, bind, 'bezier_curve_margin')

    return ui
end
