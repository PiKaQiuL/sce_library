
local watch = base.ui.watch
local view = base.ui.view

return function(template, bind)
    local ui = view {
        type = 'viewport',
        name = template.name,
        id = template.id
    }
    base.ui.watch(ui, template, bind, 'name')
    base.ui.watch(ui, template, bind, 'viewport_name')
    base.ui.watch(ui, template, bind, 'viewport_msaa')
    return ui
end
