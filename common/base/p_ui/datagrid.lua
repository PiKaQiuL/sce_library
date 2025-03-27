
-- 直接根据 table 生成表格

include 'base.p_ui'

local datagrid = {}

function datagrid.props()
    return {'title', 'show_title', 'show_col_title', 'content', 'row_height', 'font'}
end

function datagrid.event()
    return {'on_row_selected', 'on_cell_selected'}
end

function datagrid.data()
    return {
        _font = {
            align = 'center',
            color = '#EEEEEE'
        },
        _layout = {
            grow_width = 1,
            grow_height = 1,
            direction = 'col',
            col_content = 'start',
        },
        _cur_row = nil,
        _cur_cell = nil,
        _bg = '#222222',
        _title_bg = '#333333',
        _col_title_bg = '#444444',
        _row_color = '#666666',
        _cur_row_color = '#444444',
        _scroll_color = 'rgba(50, 50, 50, 1)',
        _row_height = 50,
        _row_count = 0,
        _col_count = 0,
        _content = nil
    }
end

function datagrid:define()

    local prop = self._prop

    self._row_height = prop.row_height or self._row_height
    self._font = prop.font or self._font

    self:merge(prop.layout, self._layout)

    local show_title = true
    if prop.show_title ~= nil then show_title = prop.show_title end
    local show_col_title = true
    if prop.show_col_title ~= nil then show_col_title = prop.show_col_title end

    return base.ui.panel {
        color = self._bg,
        layout = self._layout,
        -- title
        base.ui.label {
            color = self._title_bg,
            text = prop.title,
            show = show_title,
            layout = {
                grow_width = 1,
                height = self._row_height
            },
            font = self._font,
            bind = {
                text = '__title'
            }
        },
        -- content
        base.ui.panel {
            layout = {
                grow_width = 1,
                grow_height = 1,
                direction = 'col',
                row_self = 'start'
            },
            -- 列头
            base.ui.panel {
                array = 1,
                color = self._col_title_bg,
                show = show_col_title,
                layout = {
                    grow_width = 1,
                    height = self._row_height,
                    direction = 'row'
                },
                bind = {
                    array = '__title_col'
                },
                base.ui.label {
                    layout = {
                        grow_width = 1,
                        grow_height = 1,
                    },
                    font = self._font,
                    bind = {
                        text = '__col_title'
                    }
                }
            },
            -- 内容
            base.ui.panel {
                layout = {
                    grow_width = 1,
                    grow_height = 1,
                    direction = 'col',
                    col_content = 'start'
                },
                enable_scroll = true,
                scroll_color = self._scroll_color,
                array = 1,
                bind = {
                    scroll = '__scroll',
                    array = '__row'
                },
                base.ui.panel {
                    array = 1,
                    color = self._row_color,
                    layout = {
                        margin = { top = 1 },
                        grow_width = 1,
                        height = self._row_height,
                        direction = 'row'
                    },
                    bind = {
                        array = '__col',
                        color = '__row_color',
                    },
                    base.ui.label {
                        static = false,
                        layout = {
                            grow_width = 1,
                            grow_height = 1,
                        },
                        font = self._font,
                        bind = {
                            text = '__cell_text',
                            event = {
                                on_click = '__on_cell_selected'
                            }
                        }
                    }
                }
            }
        }
    }
end

function datagrid:init()
    self:init_cell_select_event()
    base.next(function ()
        self._not_first_frame = true
    end)
end

function datagrid.new_bind()
    return base.bind()
end

function datagrid:init_cell_select_event()
    local impl = self._impl
    for i = 1, self._row_count do
        for j = 1, self._col_count do
            impl.__on_cell_selected[i][j] = function()
                if self._cur_row then
                    impl.__row_color[self._cur_row] = self._row_color
                end
                self._cur_row = i
                impl.__row_color[i] = self._cur_row_color
                self:emit('on_row_selected', i, self._content[i + 1])
                self:emit('on_cell_selected', i, j, self._content[i + 1][j])
            end
        end
    end
end

function datagrid:watch()
    local impl = self._impl
    return {
        title = function(v)
            impl.__title = v
        end,
        content = function(v)
            self._content = v
            if self._not_first_frame then
                self:show_content()
            else
                base.next(function ()
                    self:show_content()
                end)
            end
        end
    }
end

function datagrid:show_content()
    local impl = self._impl
    local v = self._content
    if #v < 1 then
        -- log.alert('数据非法，不包含表头数据')
        return
    end
    local col_titles = v[1]
    local row = #v - 1
    local col = #col_titles
    impl.__row = row
    self._row_count = row
    self._col_count = col
    self:init_cell_select_event()
    impl.__title_col = col
    for i, col_title in ipairs(col_titles) do
        impl.__col_title[i] = col_title
    end
    for i = 2, #v do
        impl.__col[i-1] = col
        impl.__row_color[i-1] = self._row_color
        for j = 1, col do
            impl.__cell_text[i-1][j] = tostring(v[i][j])
        end
    end
    base.next(function() impl.__scroll = 0 end)
end

base.p_ui.register('datagrid', datagrid)
