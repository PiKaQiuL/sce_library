return function (template, bind)
    local ui = base.ui.view {
        type = 'color_packer',
        name = template.name,
        id = template.id
    }

    base.ui.watch(ui, template, bind, 'color_rgb')
    base.ui.watch(ui, template, bind, 'color_hsv')

    return ui
end
