
include 'base.p_ui'
include 'base.co'

local tree = {}

local function clone(t)
    local c = {}
    for k, v in pairs(t) do
        c[k] = v
    end
    return c
end

function tree.prop()
    return {'data'}
end

function tree.event()
    return {'on_node_click'}
end

function tree.data()
    return {
        _layout = {
            grow_width = 1,
            grow_height = 1,
            direction = 'col',
            col_content = 'start'
        },
        _panel_layout = {
            grow_width = 1,
            height = -1,
            direction = 'col'
        },
        _label_layout = {
            grow_width = 1,
            height = -1,
            -- margin = 2
        },
        _color = 'rgb(100, 200, 255)',
        _hover_color = 'rgb(0, 0, 255)',
        _font = {
            color = 'rgb(255, 255, 255)',
            align = 'left',
            size = 14
        },
        _indent = 20
    }
end

function tree:define()

    local prop = self._prop
    local layout = self._layout
    self._indent = prop.indent or self._indent

    self:merge(prop.layout, layout)

    return base.ui.panel { 
        layout = layout,
        static = false,
        opacity = prop.opacity or 1,
        -- color = '#FF0000',
        color = self._color,
        enable_scroll = true
    }

end

function tree:new_bind()
    return base.bind()
end

function tree:init()

    local data = self._prop.data
    self:flush(data)

end

function tree:flush(data)

    local root = self._ui

    if not data then return end

    for _, item in ipairs(data) do
        self:build(root, item, 0)
    end

end

function tree:build(root, data, level)

    if not data then return end
    data.text = data.text or data.name or ''

    local node, bnode, container, cbind = self:new_node(data, level)
    data._node = node
    data._bnode = bnode
    root:add_child(node)

    if #data > 0 then
        for _, child_data in ipairs(data) do
            self:build(container, child_data, level + 1)
        end
    end

end

function tree:new_node(data, level)

    local node_layout = clone(self._panel_layout)

    node_layout.margin = {
        left = level * self._indent,
        top = 5
    }

    local node = base.ui.panel {
        layout = node_layout,
        static = false,
        -- color = 'rgb(0, 0, 255)',
        base.ui.label {
            name = data.text,
            layout = self._label_layout,
            font = self._font,
            static = false,
            text = data.text,
            -- color = 'rgb(0, 255, 0)',
            bind = {
                event = {
                    on_double_click = 'on_double_click',
                    on_click = 'on_label_click',
                    on_mouse_enter = 'on_mouse_enter',
                    on_mouse_leave = 'on_mouse_leave'
                },
                color = 'color'
            }
        }
    }

    local show_childs = data.expand or false
    local container = base.ui.panel {
        show = show_childs,
        static = false,
        layout = {
            grow_width = 1,
            height = -1,
            direction = 'col'
        },
        bind = {
            show = 'show_childs'
        },
        transition = {
            show = {
                time = 200,
                func = 'linear'
            }
        }
    }

    local nui, nbind = base.ui.create(node)
    local cui, cbind = base.ui.create(container)
    nui:add_child(cui)

    nbind.on_double_click = function()
        show_childs = not show_childs
        cbind.show_childs = show_childs
    end

    nbind.on_label_click = function()
        if self._selected then
            self._selected.color = 'rgba(0, 0, 0, 0)'
        end
        nbind.color = self._hover_color
        self._selected = nbind
        self:emit('on_node_click', data)
    end

    nbind.on_mouse_enter = function()
        nbind.color = self._hover_color
    end

    nbind.on_mouse_leave = function()
        if nbind ~= self._selected then
            nbind.color = 'rgba(0, 0, 0, 0)'
        end
    end

    return nui, nbind, cui, cbind
end

function tree:watch()
    return {
        data = function(v)
            while #self._ui.child > 0 do
                self._ui.child[1]:remove()
            end
            base.next(function()
                self:flush(v)
            end)
        end
    }
end

base.p_ui.register('tree', tree)