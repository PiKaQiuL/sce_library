
include 'base.p_ui'

-- 封装一个通用的按钮，尽量简洁
-- base.p_ui.btn { text = '这是一个按钮', on_click = function() log.alert('我被点击了!') end }


local btn = {}

function btn.prop()
    return {'text'}
end

function btn.event()
    return {'on_click'}
end

function btn.data()
    return {
        _layout = {
            width = -1,
            height = -1,
            padding = 5,
            margin = 5
        },
        _color = 'rgb(100, 200, 255)',
        _hover_color = 'rgb(0, 0, 255)',
        _font = {
            color = 'rgb(255, 255, 255)',
            align = 'left',
            size = 20,
            align = 'center'
        }
    }
end

function btn:define()

    local prop = self._prop
    local layout = self._layout

    self:merge(prop.layout, layout)

    return base.ui.panel {
        color = self._color,    
        layout = layout,
        bind = {
            color = 'color',
            event = {
                on_click = 'on_click',
                on_mouse_enter = 'on_hover',
                on_mouse_leave = 'on_leave'
            }
        },
        static = false,
        base.ui.label {
            layout = {
                width = -1,
                height = -1
            },
            font = self._font,
            text = prop.text,
            bind = {
                text = 'text'
            }
        }
    }

end

function btn:new_bind()
    return base.bind()
end

function btn:init()
    self._impl.on_click = function()
        self:emit('on_click')
    end
    self._impl.on_hover = function()
        self._impl.color = self._hover_color
    end
    self._impl.on_leave = function()
        self._impl.color = self._color
    end
end

function btn:watch()
    return {
        text = function(v)
            self._impl.text = v
        end
    }
end

base.p_ui.register('btn', btn)