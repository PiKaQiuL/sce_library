return function (template, bind)
    local ui = base.ui.view {
        type = 'virtual_joystick_listener',
        name = template.name,
        id = template.id
    }
    return ui
end
