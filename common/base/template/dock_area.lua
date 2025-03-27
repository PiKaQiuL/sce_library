
local watch = base.ui.watch
local view = base.ui.view

return function(template, bind)
    local ui = view {
        type = 'dock_area',
        name = template.name,
        id = template.id
    }

    return ui
end
