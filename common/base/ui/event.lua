local event_list = {
    'on_click',
    'on_double_click',
    'on_mouse_enter',
    'on_mouse_leave',
    'on_mouse_down',
    'on_mouse_up',
    'on_real_click',
    'on_drag',
    'on_drop',
    'on_focus',
    'on_focus_lose',
    'on_input',
    'on_long_click',
    'on_long_click_release',
    'on_update_scroll',

    'on_scroll_rect_changed',

    -- 文本事件
    'on_text_click',

    -- 摇杆事件
    'on_vj_press',
    'on_vj_release',
    'on_vj_move_start',
    'on_vj_move',
    'on_vj_move_end',

    -- 窗口事件
    'on_virtual_window_dock',
    'on_virtual_window_release',
    'on_virtual_window_close',
    'on_virtual_window_enter_foreground',
    'on_virtual_window_enter_background',

    -- 曲线事件
    'on_spline_curve_popup_change',
    'on_spline_curve_points_change',
    'on_bezier_curve_points_change',

    -- 颜色拾取器事件
    'on_color_packer_change',

    -- 颜色面板事件
    'on_color_panel_change',

    -- web message event
    'on_web_message',
}

local function call_event(event_name, id, ...)
    local ui = base.ui.map[id]
    local callback = ui.event and ui.event[event_name]
    if not callback then
        return nil
    end
    if type(callback) == 'table' then
        callback.event_name = event_name
        callback.id = id
    end
    local suc, res = xpcall(callback, base.error, ...)
    if not suc then
        return nil
    end
    return ui, res
end

local proxy_map = {
    ['on_throw']  = 'on_drop',
    ['on_dropped'] = 'on_drop'
}
local proxy_pairs = {
    ['on_mouse_enter']    = 'on_mouse_leave',
    ['on_click']          = {'on_mouse_up', 'on_mouse_down'},
    ['on_mouse_up']       = 'on_mouse_down',
    ['on_drag']           = 'on_drop',
    ['on_focus']          = 'on_focus_lose',
    ['on_long_click']     = {'on_mouse_down', 'on_mouse_leave', 'on_mouse_up'}
}
local proxy_reflex = {}
for k, v in pairs(proxy_pairs) do
    if type(v) ~= 'table' then proxy_reflex[v] = k end
end
local function subscribe(self, name)
    if not self.event_subscribe then
        self.event_subscribe = {}
    end
    self.event_subscribe[name] = (self.event_subscribe[name] or 0) + 1
    if base.ui.map[self.id] and self.event_subscribe[name] == 1 then
        base.ui.gui.register_event(self.id, name)
    end
end

local function unsubscribe(self, name)
    self.event_subscribe[name] = self.event_subscribe[name] - 1
    if base.ui.map[self.id] and self.event_subscribe[name] == 0 then
        base.ui.gui.unregister_event(self.id, name)
    end
end

function base.ui.mt:subscribe(name)
    local name = proxy_map[name] or name
    subscribe(self, name)
    local pair = proxy_pairs[name] or proxy_reflex[name]
    if type(pair) == 'string' then
        subscribe(self, pair)
    elseif type(pair) == 'table' then
        for _, e in ipairs(pair) do
            subscribe(self, e)
        end
    end
end

function base.ui.mt:unsubscribe(name)
    local name = proxy_map[name] or name
    unsubscribe(self, name)
    local pair = proxy_pairs[name] or proxy_reflex[name]
    if type(pair) == 'string' then
        unsubscribe(self, pair)
    elseif type(pair) == 'table' then
        for _, e in ipairs(pair) do
            unsubscribe(self, e)
        end
    end
end

function base.ui.mt:subscribe_now()
    if not self.event_subscribe then
        return
    end
    for name, count in pairs(self.event_subscribe) do
        if count > 0 then
            base.ui.gui.register_event(self.id, name)
        end
    end
end

local function has_register(id, name)
    local ui = base.ui.map[id]
    local callback = ui.event and ui.event[name]
    if not callback then
        return false
    end
    return true
end

local function has_register_long_click(id)
    return has_register(id, 'on_long_click')
end

local long_click_interval = 1000
local function set_long_click_timeout(time)
    long_click_interval = time
end
local function init_long_click(id)
    if not has_register_long_click(id) then return end
    local ui = base.ui.map[id]
    ui._long_click_triggered = false
    ui._long_click_called = false
    ui._long_click_timer = base.wait(long_click_interval, function()
        ui_events['on_long_click'](id)
        ui._long_click_triggered = true
    end)
end
local function remove_long_click(id)
    if not has_register_long_click(id) then return end
    local ui = base.ui.map[id]
    if ui._long_click_timer then
        ui._long_click_timer:remove()
        ui._long_click_timer = nil
    end
end

local proxy = {}
function proxy.on_mouse_enter(self)
    local ui = base.ui.map[self]
    ui._mouse_enter = true
    call_event('on_mouse_enter', self)
end

function proxy.on_mouse_leave(self)
    remove_long_click(self)
    local ui = base.ui.map[self]
    ui._mouse_enter = nil
    call_event('on_mouse_leave', self)
end

function proxy.on_mouse_down(self, control_x, control_y, mouse)
    init_long_click(self)
    local ui = base.ui.map[self]
    if not ui._mouse_down then
        ui._mouse_down = {}
    end
    ui._mouse_down[mouse] = true
    ui.origin_x, ui.origin_y = ui:rect()
    call_event('on_mouse_down', self, mouse)
end

local function trigger_long_click_release(ui, self)
    if ui._long_click_triggered and not ui._long_click_called then 
        ui._long_click_called = true
        call_event('on_long_click_release', self)
    end
    return ui._long_click_triggered
end

function proxy.on_click(self, control_x, control_y, control_button)
    local ui = base.ui.map[self]
    local x, y = ui:rect()
    if ui.enable_drag and ui.origin_x ~= nil and (x ~= ui.origin_x or y ~= ui.origin_y) then
        return 
    end
    if trigger_long_click_release(ui, self) then
        return
    end
    call_event('on_click', self, control_button, control_x, control_y)
end

function proxy.on_mouse_up(self, control_x, control_y, control_button)
    remove_long_click(self)
    local ui = base.ui.map[self]
    if ui._mouse_down then ui._mouse_down[control_button] = nil end
    local x, y = ui:rect()
    if ui.enable_drag and ui.origin_x ~= nil and (x ~= ui.origin_x or y ~= ui.origin_y) then 
        trigger_long_click_release(ui, self)
        return 
    end
    if trigger_long_click_release(ui, self) then return end
    call_event('on_mouse_up', self, control_button, control_x, control_y)
end

function proxy.on_drag(self)
    local ui = base.ui.map[self]
    ui._drag = true
    remove_long_click(self)
    trigger_long_click_release(ui, self)
    call_event('on_drag', self, ui)
end

local DUMMY = {}
function proxy.on_drop(source, target)
    local ui = base.ui.map[source]
    ui._drag = nil
    local target_ui = base.ui.map[target]
    local source_ui = base.ui.map[source]
    local position = base.screen:input_mouse()
    --local point = position:get_point()
    local x, y = position:get_xy()
    if target_ui then
        call_event('on_dropped', target, source, x, y)
        call_event('on_drop', source, target_ui or DUMMY, x, y)
    else
        local position = base.screen:input_mouse()
        --local point = position:get_point()
        local x, y = position:get_xy()
        call_event('on_throw', source, source_ui,x,y)
    end
end

function proxy.on_focus(self)
    local ui = base.ui.map[self]
    ui.focus = true
    if ui.type == 'input' then
        base.game:event_notify('输入框-获得焦点', ui)
    end
    call_event('on_focus', self)
end

function proxy.on_focus_lose(self)
    local ui = base.ui.map[self]
    ui.focus = false
    if ui.type == 'input' then
        base.game:event_notify('输入框-失去焦点')
    end
    call_event('on_focus_lose', self)
end

function proxy.on_input(self, text, by_enter)
    local ui = base.ui.map[self]
    ui.text = text
    call_event('on_input', self, text, by_enter)
end

function proxy.on_update_scroll(self, scroll)
    call_event('on_update_scroll', self, scroll)
end

local function release_event(ui)
    local id = ui.id
    if ui._mouse_enter then
        proxy.on_mouse_leave(id)
    end
end

local function init()
    for _, event_name in ipairs(event_list) do
        ui_events[event_name] = function (id, ...)
            local ui = base.ui.map[id]
            if not ui then
                return
            end
            if proxy[event_name] then
                proxy[event_name](id, ...)
                return
            end
            call_event(event_name, id, ...)
        end
    end
end

init()

base.ui.event = {
    call = call_event,
    release_event = release_event,
    set_long_click_timeout = set_long_click_timeout
}
