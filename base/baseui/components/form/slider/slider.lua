local theme = require 'baseui.theme.themes'
local basic = require 'baseui.components.basic.basic'
local border = require 'baseui.components.basic.border'
local slider = base.ui.component('appui_slider', basic)

local round_corner = require 'baseui.components.basic.round_corner'

function slider:define()
    self.props = {
        range = {
            default = {0, 1},
            setter = function(range, old)
                if not range then return old end
                if (range[1] < range[2]) == (self.props.value < range[2]) and (range[2] > range[1]) == (self.props.value > range[1]) then
                    local per = math.abs((self.props.value - range[1])/(range[2] - range[1]))
                    self.bind.h_percent = per
                else
                    self.props.value = self.props.value
                end
            end
        },
        show_handle_bar = {
            default = true,
            setter = function(v)
                self:update_style()
            end
        },
        enable = {
            default = true,
            setter = function(v)
                self:update_style()
            end
        },
        -- 新增属性, form里控件统一使用disabled, 不在form里的slider使用enable, 或者把enable统一改成disabled
        disabled = {
            defautl = false,
            setter = function(v)
                self.props.enable = not v
                self:update_style()
            end
        },
        step = {
            default = 0,
            setter = function (v, old)
                if math.abs(v) > math.abs(self.props.range[2] - self.props.range[1]) then
                    return old
                end
            end
        },
        value = {
            default = 0,
            setter = function(value, old)
                if not value then return 0 end
                local min, max = table.unpack(self.props.range)
                if (value > min) ~= (max > min) then
                    value = min
                elseif (value < max) ~= (min < max) then
                    value = max
                end

                if self.props.step ~= 0 and math.abs(self.props.step) < math.abs(max-min) then
                    local step = (max-min) / math.abs((max-min)/self.props.step)
                    local new_value = math.floor(value/step + 0.5)*step
                    value = new_value
                end

                local per = math.abs((value - min)/(max-min))
                self.bind.h_percent = per

                if value ~= old and self.trigger_update then
                    self.props.on_change(value)
                end
                return value
            end
        },
        style = {
            default = 'color_primary',
            setter = function(value, old, default)
                if not value then
                    self.props.style = old or default
                    return
                end
                if value ~= old then
                    self:update_style()
                end
            end
        },
        on_change = {
            default = function(value) end
        },
    }
    self.template = base.ui.panel {
        layout = {
            grow_width = 1,
            height = 10,
        },
        base.ui.panel {
            layout = {
                grow_height = 1,
                grow_width = 1,
            },
            event = {
                on_mouse_down = self.bind.on_mouse_down,
                on_mouse_up = self.bind.on_mouse_up,
            },
            border {
                border_radius = self.bind.corner_radius,
                color = self.bind.bg_color,
                layout = {
                    grow_width = 1,
                    grow_height = 0.8,
                },
            },

            base.ui.panel {
                layout = {
                    grow_height = 1,
                    grow_width = 1,
                    direction = 'row',
                    row_content = 'start',
                },
                base.ui.panel {
                    layout = {
                        grow_width = self.bind.h_percent,
                        grow_height = 0.8,
                        row_self = 'start',
                        padding = 2,
                    },
                    border {
                        color = self.bind.fg_color,
                        border_radius = self.bind.corner_radius,
                        layout = {
                            grow_height = 1,
                            grow_width = 1,
                            col_self = 'center',
                        }
                    },

                },
                base.ui.panel {
                    layout = {
                        width = 0,
                        grow_height = self.bind.handle_size,
                    },
                    border {
                        border_width = 1,
                        border_color = self.bind.handle_color,
                        color = self.bind.handle_color_inner,
                        border_radius = self.bind.corner_radius,
                        layout = {
                            ratio = {1, 1},
                            grow_height = 1,
                        },

                    },

                    bind = {
                        event = {
                            on_mouse_enter = 'on_handle_hover',
                            on_mouse_leave = 'on_handle_not_hover',
                        }
                    }
                },
            }
        }
    }
end

function slider:is_horizontal()
    return true
end

function slider:on_mouse_move()
    if not self.props.enable then return end
    local pos = base.screen:input_mouse()
    local x, y, w, h = self.ui:rect()
    local dx, dy = pos[1] - x, y + h - pos[2]
    local range = self.props.range[2] - self.props.range[1]
    local per = self:is_horizontal() and dx/w or dy/h
    --print('mouse_move',dx, dy, per)
    self.trigger_update = true
    self.props.value = self.props.range[1] + per * range
    self.trigger_update = false
end

function slider:handle_event()
    self.bind.on_mouse_down = function()
        self.pressed = true
        self:on_mouse_move()
    end

    self.bind.on_mouse_up = function()
        self.pressed = false
        self:update_style()
    end

    local trigger = base.game:event('鼠标-移动', function(trg)
        if self.pressed then
            self:on_mouse_move()
        end
    end)
    self:auto_remove(trigger)

    self.bind.on_handle_hover = function()
        self.hover = true
        self:update_style()
    end

    self.bind.on_handle_not_hover = function()
        self.hover = false
        self:update_style()
    end
end

function slider:update_style()
    if self:is_horizontal() then
        self.bind.v_percent = 1
    else
        self.bind.h_percent = 1
    end
    local style = theme.get_current_theme()
    self.bind.bg_color = style.background_color
    self.bind.fg_color = self.props.enable and style[self.props.style] or style.disabled_color
    self.bind.handle_color = style.background_color

    self.bind.handle_color_inner = (self.props.enable and (self.pressed or self.hover)) and style[self.props.style] or style.disabled_color

    self.bind.handle_size = self.props.show_handle_bar and 1 or 0
end

function slider:init()
    self.bind.corner_radius = 4
    self:update_style()
    self:handle_event()

    self:auto_remove(theme.on_theme_change(function()
        self:update_style()
    end))
end

return slider
