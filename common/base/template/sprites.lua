return function (template, bind)
    local ui = base.ui.view {
        type = 'sprites',
        name = template.name,
        id = template.id
    }

    base.ui.watch(ui, template, bind, 'frame_count')
    base.ui.watch(ui, template, bind, 'row_frame_count')
    base.ui.watch(ui, template, bind, 'start_frame')
    base.ui.watch(ui, template, bind, 'end_frame')
    base.ui.watch(ui, template, bind, 'sprite_size')
    base.ui.watch(ui, template, bind, 'loop')
    base.ui.watch(ui, template, bind, 'interval')
    base.ui.watch(ui, template, bind, 'playing')

    return ui
end
