
local watch = base.ui.watch
local view = base.ui.view

return function (template, bind)
    local ui = view {
        type = 'panel',
        name = template.name,
        id = template.id
    }

    watch(ui, template, bind, 'enable_scroll')
    watch(ui, template, bind, 'scroll_direction')
    watch(ui, template, bind, 'scroll_color')
    watch(ui, template, bind, 'scroll_image')
    watch(ui, template, bind, 'scroll_width')
    watch(ui, template, bind, 'scroll_elasticity')
    watch(ui, template, bind, 'scroll_deceleration')
    watch(ui, template, bind, 'scroll_threshold')
    watch(ui, template, bind, 'scroll')
    watch(ui, template, bind, 'group')
    watch(ui, template, bind, 'window_id')

    ui.array = template.array
    if template.array then
        local state1, state2 = bind:get_state()
        local fn = function(_, v)
            local state1, state2 = bind:switch_state(state1, state2)
            base.ui.set_array(ui, v, template, bind)
            bind:switch_state(state1, state2)
        end
        ui.__set_array = fn
        bind.watch.array = fn
    end

    return ui
end
