return function (template, bind)
    local ui = base.ui.view {
        type = 'virtual_joystick',
        name = template.name,
        id = template.id
    }

    base.ui.watch(ui, template, bind, 'vj_press_region_type')
    base.ui.watch(ui, template, bind, 'vj_active_percent')
    base.ui.watch(ui, template, bind, 'vj_center')
    base.ui.watch(ui, template, bind, 'vj_is_press_center')
    base.ui.watch(ui, template, bind, 'vj_is_release_reset')
    base.ui.watch(ui, template, bind, 'vj_auto_move')
    base.ui.watch(ui, template, bind, 'vj_auto_skill')

    return ui
end
