return function (template, bind)
    local ui = base.ui.view {
        type = 'lite_code',
        name = template.name,
        id = template.id
    }

    base.ui.watch(ui, template, bind, 'lite_code_text')

    return ui
end
