return function (template, bind)
    local ui = base.ui.view {
        type = 'spline_bg',
        name = template.name,
        id = template.id
    }

    base.ui.watch(ui, template, bind, 'bg_margin')
    return ui
end
