return function (template, bind)
    local ui = base.ui.view {
        type = 'scroll_rect',
        name = template.name,
        id = template.id
    }

    base.ui.watch(ui, template, bind, 'sr_movement_type')
    base.ui.watch(ui, template, bind, 'sr_elasticity')
    base.ui.watch(ui, template, bind, 'sr_sensitivity')
    base.ui.watch(ui, template, bind, 'sr_deceleration')
    base.ui.watch(ui, template, bind, 'sr_inertia')
    base.ui.watch(ui, template, bind, 'sr_vertical')
    base.ui.watch(ui, template, bind, 'sr_horizontal')
    base.ui.watch(ui, template, bind, 'sr_normalized_position')

    return ui
end
