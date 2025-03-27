return function (template, bind)
    local ui = base.ui.view {
        type = 'spine',
        name = template.name,
        id = template.id
    }

    base.ui.watch(ui, template, bind, 'resource')
    base.ui.watch(ui, template, bind, 'loop')
    base.ui.watch(ui, template, bind, 'animation')

    return ui
end