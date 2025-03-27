--[[
- virtual_joystick(父UI)
    - vj_press_region_type     可点击区域类型（0方 1圆）
    - vj_active_percent        主摇杆 超过其move_radius多少时 才触发move事件
    <!-- - vj_disable_press         是否禁用点击(技能cd或沉默时使用，若在按下期间设置为true, 触发on_vj_release，breaked=true) （todo 感觉用不到） -->
    - vj_auto_move             c++处理移动
    - vj_auto_skill            c++处理技能指示器
    - event
        on_vj_press on_vj_release on_vj_move_start on_vj_move on_vj_move_end 参数(x, y, percent)

- virtual_joystick_slder(子UI, 摇杆，可以以某点为中心跟随鼠标移动)
    - vj_is_main_slider        是否是主摇杆(用来计算数据x,y,percent)
    - vj_release_set_position  松开的时候怎么设置位置  0 不设置 1 设置到按下的位置 2 设置到按下之前的位置
    - vj_toggle_show           是否在按下和松开的时候改变visible
    - vj_is_press_center       是否以按下时的位置为中心
    - vj_move_radius           移动范围半径(当vj_is_press_center=false时，会将按下前位置作为中心；当为true时，以按下的位置为中心. 按父节点高来算可能好些？)
    - vj_move_ratio            相对于鼠标移动的多少，默认是1。即若鼠标移动100，UI会在移动范围内移动100 * vj_move_percent
]]--

function base.control.move_virtual_joystick_template(body, background, slider)
    body.vj_press_region_type = 1
    body.vj_auto_move = true

    slider.vj_is_main_slider = true
    slider.vj_release_set_position = 2
    slider.vj_move_radius = 0.5

    table.insert(body, base.ui.virtual_joystick_slider(background))
    table.insert(body, base.ui.virtual_joystick_slider(slider))
    return base.ui.virtual_joystick(body)
end

function base.control.move_virtual_joystick_press_center_template(body, background, slider)
    body.vj_press_region_type = 0
    body.vj_auto_move = true

    background.vj_release_set_position = 2
    background.vj_toggle_show = true
    background.vj_is_press_center = true

    slider.vj_is_main_slider = true
    slider.vj_release_set_position = 2
    slider.vj_toggle_show = true
    slider.vj_is_press_center = true
    -- slider.vj_move_radius = 0.5  外部传进来

    table.insert(body, base.ui.virtual_joystick_slider(background))
    table.insert(body, base.ui.virtual_joystick_slider(slider))
    return base.ui.virtual_joystick(body)
end

function base.control.spell_virtual_joystick_template(body, background, skill_icon, slider)
    body.vj_press_region_type = 1
    body.vj_auto_skill = true

    background.vj_toggle_show = true

    slider.vj_is_main_slider = true
    slider.vj_release_set_position = 2
    slider.vj_toggle_show = true
    slider.vj_move_radius = 0.5

    table.insert(body, base.ui.virtual_joystick_slider(background))
    table.insert(body, base.ui.virtual_joystick_slider(skill_icon))
    table.insert(body, base.ui.virtual_joystick_slider(slider))
    return base.ui.virtual_joystick(body)
end

function base.control.spell_virtual_joystick_press_center_template(body, background, skill_icon, slider)
    body.vj_press_region_type = 0
    body.vj_auto_skill = true

    background.vj_release_set_position = 2
    background.vj_toggle_show = true
    background.vj_is_press_center = true

    skill_icon.vj_is_press_center = true
    skill_icon.vj_release_set_position = 2

    slider.vj_is_main_slider = true
    slider.vj_release_set_position = 2
    slider.vj_toggle_show = true
    slider.vj_is_press_center = true
    -- slider.vj_move_radius = 0.5  外部传进来

    table.insert(body, base.ui.virtual_joystick_slider(background))
    table.insert(body, base.ui.virtual_joystick_slider(skill_icon))
    table.insert(body, base.ui.virtual_joystick_slider(slider))
    return base.ui.virtual_joystick(body)
end