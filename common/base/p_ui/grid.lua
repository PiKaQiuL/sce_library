include 'base.p_ui'

local grid = {}

-- 定义自定义控件的属性
function grid.prop()
    return {'has_toolbar', 'row', 'col', 'row_height', 'text', 'custom_btn'}
end

-- 定义自定义控件的事件
function grid.event()
    return {'on_row_selected'}
end

-- 定义控件的内部数据，可以理解为成员变量，可以通过 self.变量名 来访问
function grid.data()
    return {
        _row = 2,
        _col = 2,
        _row_height = 0.2,
        _text = 'cell',
        _selected_row_index = nil,
        _row_color = '#00FF00',
        _selected_row_color = '#0000FF'
    };
end

-- 定义控件是如何渲染的
-- self._prop 是用户传入的属性表
function grid:define()

    local prop = self._prop

    self._row = prop.row or self._row
    self._col = prop.col or self._col

    -- 返回具体的控件实现
    return base.ui.panel {
        layout = {
            grow_width = 1,
            grow_height = 1,
            col_content = 'start',
            padding = { top = 100 }
        },
        base.ui.panel {
            layout = {
                grow_width = 1,
                grow_height = 1,
                direction = 'col',
                col_content = 'start',
            },
            enable_scroll = true,
            scroll_color = '#333333',
            array = self._row,
            bind = {
                array = '__internal_row'  -- 绑定属性，后面 watch 方法会用到
            },
            base.ui.panel {
                color = self._row_color,
                static = false,
                layout = {
                    margin = 5,
                    grow_width = 1,
                    grow_height = self._row_height,
                    direction = 'row'
                },
                array = self._col,
                bind = {
                    color = '__internal_row_color',
                    array = '__internal_col',
                    layout = {
                        grow_height = '__internal_row_height'
                    },
                    event = {
                        on_click = 'on_row_click'
                    }
                },
                base.ui.label {
                    -- color = '#0000FF',
                    layout = {
                        margin = 5,
                        grow_width = 1,
                        grow_height = 1
                    },
                    text = self._text,
                    font = {
                        color = '#FF0000',
                    },
                    bind = {
                        text = '__internal_text'
                    }
                },
                prop[1],
            }
        }
    }
end

-- 控件初始化，在这个方法里可以做一些初始化操作，比如动态添加子控件，绑定内部控件的事件，派发自定义事件等
-- self._ui 是根据 define 定义创建的根控件
-- self._impl 是实际创建的根控件对应的绑定对象
function grid:init()
    self:add_tool_bar()
    self:init_row_select_event()
end

-- 动态添加工具栏
function grid:add_tool_bar()
    local ui = self._ui
    local impl = self._impl

    if self._prop.has_toolbar then
        for i = 0, 10 do
            local label = base.ui.label {
                text = 'btn' .. i,
                layout = {
                    position = {i * 52, 0},
                    width = 50,
                    height = 50
                },
                color = '#AABBCC'
            }
            local label_ui = base.ui.create(label, 'tool_btn'..i)
            ui:add_child(label_ui)
        end
    end
end

-- 处理行选中事件
function grid:init_row_select_event()

    local ui = self._ui
    local impl = self._impl

    -- 处理行选中事件
    for i = 1, self._row do
        impl.on_row_click[i] = function()

            -- 改变选中行颜色
            if self._selected_row_index then
                impl.__internal_row_color[self._selected_row_index] = self._row_color
            end
            impl.__internal_row_color[i] = self._selected_row_color
            self._selected_row_index = i

            -- 派发行选中事件
            self:emit('on_row_selected', i)
        end
    end

end

-- 监视外部属性变化，并实现具体逻辑
-- self._ui 是根据 define 定义创建的根控件
-- self._impl 是实际创建的根控件对应的绑定对象
function grid:watch()

    local impl = self._impl

    return {

        -- 监视行数变化，并修改实际控件的属性
        row = function(v)
            self._row = v
            impl.__internal_row = v
            self:init_row_select_event()
        end,

        -- 监视列数变化
        col = function(v)
            self._col = v
            -- 由于 ac 内部实现问题，行数修改没有实时更新，延迟执行修改列数的操作
            -- 实际逻辑想怎么写就怎么写，对使用者来说是个黑盒，可以封装一些 ac 的坑
            base.next(function()
                for i = 1, self._row do
                    impl.__internal_col[i] = v
                end
            end)
        end,

        -- 监视每行行高的变化，此属性是个一维数组
        -- 对于一维数组属性，会多一个索引参数
        row_height = function(i, v)
            impl.__internal_row_height[i] = v
        end,

        -- 监视每个单元格的文本变化
        -- 对于二维数组属性，会多两个索引参数
        text = function(i, j, v)
            impl.__internal_text[i][j] = v
        end
    }

end

-- 注册自定义控件对象
base.p_ui.register('grid', grid)