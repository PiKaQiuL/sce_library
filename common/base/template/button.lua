return function (template, bind)
    local ui = base.ui.view {
        type = 'button',
        name = template.name,
        id = template.id
    }

    base.ui.watch(ui, template, bind, 'hover_image')
    base.ui.watch(ui, template, bind, 'active_image')

    return ui
end
