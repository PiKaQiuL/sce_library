
include 'base.p_ui'

-- 封装一个通用的按钮，尽量简洁
-- base.p_ui.new_btn { text = '这是一个按钮', on_click = function() log.alert('我被点击了!') end }


local new_btn = {}

function new_btn.prop()
    return {'image',"draw_level"}
end

function new_btn.event()
    return {'on_click'}
end

function new_btn.data()
    return {
        _layout = {
            grow_height = 1,
            grow_width = 1,
        },
    }
end

function new_btn:define()

    local prop = self._prop
    local layout = self._layout

    self:merge(prop.layout, layout)

    return base.ui.panel {
        static = false,
        color = self._color,    
        layout = layout,
        image = prop.image,
        draw_level = prop.draw_level,
        bind = {
            scale = 'scale',
            image = 'image',
            event = {
                on_click = 'click_over',
                on_mouse_down = 'click_start',
            }
        },
        prop[1],
    }

end

function new_btn:new_bind()
    return base.bind()
end

function new_btn:init()
    self._impl.click_start = function()
        self._impl.scale = 0.9
    end
    self._impl.click_over = function()
        self._impl.scale = 1
        self:emit('on_click')
    end
end

function new_btn:watch()
    return {
        image = function(v)
            self._impl.image = v
        end
    }
end

base.p_ui.register('new_btn', new_btn)