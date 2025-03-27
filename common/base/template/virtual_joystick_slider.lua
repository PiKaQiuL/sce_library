return function (template, bind)
    -- 添加事件监听部分
    if #template == 0 then
        table.insert(template, base.ui.virtual_joystick_listener {
            -- color = '#000033',
            layout = {
                grow_height = 1,
                grow_width = 1,
            },
            name = 'vj_listener'
        })
    end
    local ui = base.ui.view {
        type = 'virtual_joystick_slider',
        name = template.name,
        id = template.id
    }

    base.ui.watch(ui, template, bind, 'vj_is_main_slider')
    base.ui.watch(ui, template, bind, 'vj_toggle_show')
    base.ui.watch(ui, template, bind, 'vj_move_radius')
    base.ui.watch(ui, template, bind, 'vj_move_ratio')

    return ui
end
