
include 'base.p_ui'

local checkbox = {}

function checkbox.prop()
    return { 'checked', 'layout', 'color', 'font', 'text' }
end

function checkbox.event()
    return { 'on_checked' }
end

function checkbox.data()
    local default_color = '#AABBFF'
    return {
        _checked = false,
        _checked_color = '#5566FF',
        _color = default_color,
        _font = {
            align = 'left',
            size = 15,
            color = default_color
        },
        _layout = {
            grow_width = 1,
            grow_height = 1,
            direction = 'row'
        },
        _on_check_handle = '',
        _check_text_handle = '',
        _checkbox = nil,
        _text = nil
    }
end

function checkbox:define()

    local prop = self._prop
    
    self:merge(prop.layout, self._layout)
    if prop.color then self._color = prop.color end
    if prop.font then self._font = prop.font end
    if prop.checked ~= nil then self._checked = prop.checked end
    if prop.checked_color then self._checked_color = prop.checked_color end

    return base.ui.panel {
        layout = self._layout
    }

end

function checkbox:init()

    local parent = self._ui

    local ui, bind = base.ui.create(base.ui.panel {
        static = false,
        color = self._color,
        layout = {
            ratio = {1, 1},
            grow_height = 1
        },
        bind = {
            color = '__color',
            event = {
                on_click = '__on_check'
            }
        }
    }, '__checkbox')
    self._checkbox = bind
    parent:add_child(ui)

    ui, bind = base.ui.create(base.ui.label {
        text = self._prop.text,
        layout = {
            margin = { left = 5 },
            grow_width = 1,
            grow_height = 1
        },
        font = self._font,
        -- text = prop.text,
        bind = {
            text = '__text'
        }
    }, '__text')
    self._text = bind
    parent:add_child(ui)

    self:update_check_status()

    self._checkbox.__on_check = function()
        self._checked = not self._checked
        self:update_check_status()
        self:emit('on_checked', self._checked)
    end
    
end

function checkbox:update_check_status()
    if self._checked then
        self._checkbox.__color = self._checked_color
    else
        self._checkbox.__color = self._color
    end
end

function checkbox:watch()
    local impl = self._impl
    return {
        text = function (v) 
            self._text.__text = v 
        end,
        checked = function (v) 
            self._checked = v
            self:update_check_status()
            self:emit('on_checked', self._checked)
        end
    }
end

base.p_ui.register('checkbox', checkbox)