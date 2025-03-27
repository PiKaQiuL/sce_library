local platform = include 'base.platform'
base.screen = {}

local mouse_position = base.position()

------------------------------ API ------------------------------
function base.screen:get_orientation()
    return common.get_orientation()
end

function base.screen:get_resolution()
    return common.get_resolution()
end

function base.screen:set_resolution(width, height)
    width, height = math.floor(width), math.floor(height)
    if platform.is_mobile() then
        log_file.info('set_logic_view ===> ', width, height)
        common.set_logic_view(width, height)
    else
        log_file.info('set_resolution ===> ', width, height)
        common.set_resolution(width, height)
    end
end

---TODO:delete
function base.screen:get_bangs_height()
    return common.get_bangs_height()
end

function base.screen:input_mouse(touch_id)
    local x, y = common.get_mouse_screen_pos(touch_id)
    mouse_position = base.position(x, y)
    return mouse_position
end


function base.screen:set_cursor_visible(visible)
    common.set_cursor_visible(visible)
end

function base.screen:get_safe_insets()
    local inserts = { 0, 0, 0, 0 }
    if platform.is_wx() or platform.is_qq() then
        local system_info = base.wx.call('get_system_info')
        if system_info and system_info.safeArea then
            local area, ratio = system_info.safeArea, system_info.pixelRatio
            inserts[1] = ratio * area.left
            inserts[2] = ratio * area.top
            inserts[3] = ratio * (area.right - area.width)
            inserts[4] = ratio * (area.bottom - area.height)
        end
    elseif platform.is_mobile() then
        local scale = base.ui.auto_scale.current_scale()
        inserts[1], inserts[2], inserts[3], inserts[4] = common.get_safe_area_insets(true) -- 放到c++计算viewScale
        for i = 1, 4 do
            inserts[i] = math.ceil(inserts[i] / scale)
        end
    end
    log_file.info('safe insets: ', inserts[1], inserts[2], inserts[3], inserts[4])
    return { left = inserts[1], top = inserts[2], right = inserts[3], bottom = inserts[4] }
end

local enable_safe_area = false

function base.screen:enable_safe_area(enable)
    enable_safe_area = enable
    base.ui.gui.set_layout('main', {
        margin = enable and base.screen:get_safe_insets() or 0
    })
end

base.game:event('画面-分辨率变化', function()
    base.screen:enable_safe_area(enable_safe_area)
end)

------------------------------ 事件 ------------------------------
function base.event.on_screen_resolution_changed(w, h)
    log_file.info('画面-分辨率变化', w, h, base.screen:get_orientation())
    base.game:event_notify('画面-分辨率变化', w, h)
end

function base.event.on_orientation_changed(orientation)
    log_file.info('画面-朝向变化', orientation, base.screen:get_orientation())
    if orientation == 'Portrait' then
        local w, h = common.get_resolution()
        if w > h then
            base.screen:set_resolution(h,w)
            log.info('分辨率错误 自动纠正为',h,w)
        end
        base.next(function()
            base.game:event_notify('画面-分辨率变化', common.get_resolution())
        end)
    else
        base.game:event_notify('画面-分辨率变化', common.get_resolution())
    end
end