return function (template, bind)
    local ui = base.ui.view {
        type = 'color_panel',
        name = template.name,
        id = template.id
    }

    base.ui.watch(ui, template, bind, 'point_color')
    base.ui.watch(ui, template, bind, 'point_alpha')
    base.ui.watch(ui, template, bind, 'point_percent')
    base.ui.watch(ui, template, bind, 'panel_editable')
    base.ui.watch(ui, template, bind, 'panel_colors')
    base.ui.watch(ui, template, bind, 'panel_alphas')

    return ui
end
