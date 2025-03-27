return function (template, bind)
    local ui = base.ui.view {
        type = 'particle',
        name = template.name,
        id = template.id
    }

    base.ui.watch(ui, template, bind, 'effect')
    base.ui.watch(ui, template, bind, 'view_mode')
    base.ui.watch(ui, template, bind, 'play')
    base.ui.watch(ui, template, bind, 'stop')
    base.ui.watch(ui, template, bind, 'speed')
    base.ui.watch(ui, template, bind, 'particle_size')
    base.ui.watch(ui, template, bind, "direct_scale")
    base.ui.watch(ui, template, bind, "particle_endfly")
    base.ui.watch(ui, template, bind, "offset_percent")
    base.ui.watch(ui, template, bind, "auto_scale")
    base.ui.watch(ui, template, bind, "particle_scale")
    return ui
end
