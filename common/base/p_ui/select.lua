
local co = include 'base.co'
include 'base.p_ui'

local select = {}

function select.prop()
    return {'options', 'selected'}
end

function select.event()
    return {'on_selected_changed'}
end

function select.data()
    return {
        _font = {
            color = '#444444',
            align = 'left',
            size = 20
        },
        _select_color = '#BBBBBB',
        _option_color = '#AAAAAA',
        _hover_option_color = '#999999',

        _hovered = nil,
        _selected = nil,
        _options = nil,
        
        _options_ui = {},

        _toggle = false
    }
end

function select:define()

    local prop = self._prop
    self._options = prop.options
    self._selected = prop.selected or ''

    local layout = {
        grow_width = 1,
        grow_height = 1
    }

    self:merge(prop.layout, layout)

    return base.ui.panel {
        layout = layout,
        z_index = prop.z_index,
        base.ui.label {
            color = self._select_color,
            layout = {
                grow_width = 1,
                grow_height = 1
            },
            font = self._font,
            text = self._selected,
            bind = {
                text = '__selected',
                event = {
                    on_click = '__on_select'
                }
            }
        },
        base.ui.panel {
            show = false,
            layout = {
                grow_width = 1,
                translate = {0, 1},
                height = -1,
                col_self = 'start',
                direction = 'col'
            },
            font = self._font,
            bind = {
                show = '__show_options'
            }
        }
    }

end

function select:new_bind()
    return base.bind()
end

function select:init()
    self:init_select()
    self:update_options()
end

function select:watch()
    return {
        selected = function(v)
            self._selected = v
            self._impl.__selected = v
        end,
        options = function(v)
            self._options = v
            self:update_options()
        end
    }
end

function select:init_select()
    self._impl.__on_select = function()
        self:toggle_options()
    end
end

function select:toggle_options()
    local impl = self._impl
    self._toggle = not self._toggle
    impl.__show_options = self._toggle
end

function select:update_options()

    if not self._options then return end

    local impl = self._impl

    co.async(function()

        local next = co.wrap(base.next)
        next()

        for _, option in ipairs(self._options_ui) do
            option[1]:remove()
        end

        while not self._ui.child[2] do
            next()
        end

        local option_container = self._ui.child[2]
        local x, y, w, h = self._ui:rect()

        for index, option in ipairs(self._options) do
            local tmpl = base.ui.label {
                color = self._option_color,
                static = false,
                layout = {
                    grow_width = 1,
                    height = h
                },
                text = option,
                font = self._font,
                bind = {
                    color = '__option_color',
                    event = {
                        on_click = '__on_option_select',
                        on_mouse_leave = '__on_option_leave',
                        on_mouse_enter = '__on_option_hover'
                    }
                }
            }

            local option_ui, bind = base.ui.create(tmpl, '__option_ui' .. index)
            option_container:add_child(option_ui)
            table.insert(self._options_ui, {option_ui, bind})

            bind.__on_option_hover = function()
                bind.__option_color = self._hover_option_color
            end
            bind.__on_option_leave = function()
                bind.__option_color = self._option_color
            end

            bind.__on_option_select = function()
                self:toggle_options()
                self:on_select_changed(option)
            end

        end

    end)
end

function select:on_select_changed(option)
    self:emit('on_selected_changed', self._selected, option)
    self._selected = option
    self._impl.__selected = option
end

base.p_ui.register('select', select)