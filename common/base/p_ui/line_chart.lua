include 'base.p_ui'

--[[
数据的格式

每列的列名
columns_name = {'time', 'col1', 'col2', 'col3', 'col4'}
每列的颜色，第一个无用
columns_color = {'','#ffffff', '#ff00ff', '#ffff00', '#ff0000'}
要显示的数据
datas = {
    {'2019-12-1 20:00:00', 2,  3,  4,  5},
    {'2019-12-1 20:00:01', 7,  8,  9,  10},
    {'2019-12-1 20:00:02', 12, 13, 14, 15},
    {'2019-12-1 20:00:03', 17, 18, 19, 20}
}
第一列为x轴显示的信息 所有show_index从2开始
show_index = {2, 4}

可以通过绑定修改的属性：
//因为columns_name, columns_color, datas, show_index这四个属性b格式要一致，若通过bing修改其中一个属性就刷新数据显示，则数据格式不匹配会报错。所以约定在修改show_index时才刷新数据显示。
//add_data会刷新数据显示。
columns_name,
columns_color,
datas,
show_index,
caption,      // 折线图的名称
add_data      // 通过bind添加数据，格式与datas一致

不能bind的属性及其默认值，主要用来修改样式：
// 有font_size 属性可以覆盖所有font size的默认值
// 有font_color属性可以覆盖所有font color的默认值
x_info_max_count = 6,
x_info_height = 40,
x_info_font_size = 15,
x_info_font_color = '#ffffff',
x_info_top_margin = 15,

y_info_max_count = 6,
y_info_width = 50,
y_info_font_size = 15,
y_info_font_color = '#ffffff',
y_info_right_margin = 10,

caption_height = 50,
caption_font_size = 20,
caption_font_color = '#ffffff',

info_list_item_width = 100,
info_list_item_height = 30,
info_list_font_size = 15,
info_list_font_color = '#ffffff',

axis_x_right_margin = 50,
axis_y_top_margin = 20,
axis_color = '#111111',
axis_width = 3,
axis_arrow_size = 10,
axis_ruler_length = 8,
axis_ruler_width = 2,

line_width = 2,

bg_color = '#aaaaaa'
--]]

local line_chart = {}

function line_chart.prop()
    return {
        'columns_name', 'columns_color', 'datas', 'show_index', 'caption',
        'add_data'
    }
end

function line_chart.event()
    return {}
end

function line_chart.data()
    return {
        -- font_size 覆盖所有font size的默认值
        -- font_color 覆盖所有font color的默认值

        _prop_x_info_max_count = 6,
        _prop_x_info_height = 40,
        _prop_x_info_font_size = 15,
        _prop_x_info_font_color = '#ffffff',
        _prop_x_info_top_margin = 15,

        _prop_y_info_max_count = 6,
        _prop_y_info_width = 50,
        _prop_y_info_font_size = 15,
        _prop_y_info_font_color = '#ffffff',
        _prop_y_info_right_margin = 10,

        _prop_caption_height = 50,
        _prop_caption_font_size = 20,
        _prop_caption_font_color = '#ffffff',

        _prop_info_list_item_width = 100,
        _prop_info_list_item_height = 30,
        _prop_info_list_font_size = 15,
        _prop_info_list_font_color = '#ffffff',

        _prop_axis_x_right_margin = 50,
        _prop_axis_y_top_margin = 20,
        _prop_axis_color = '#111111',
        _prop_axis_width = 3,
        _prop_axis_arrow_size = 10,
        _prop_axis_ruler_length = 8,
        _prop_axis_ruler_width = 2,

        _prop_line_width = 2,

        _prop_bg_color = '#aaaaaa'
    }
end

function line_chart:define()
    self:read_custom_properties()

    return base.ui.panel{
        name = 'chart_template',
        layout = {grow_width = 1, grow_height = 1, direction = 'col'},
        base.ui.panel{
            name = 'chart_canvas_wrapper',
            layout = {grow_width = 1, grow_height = 1, direction = 'row'},
            base.ui.panel{
                name = 'chart_y_info_wrapper',
                layout = {grow_height = 1, direction = 'col'},
                self:create_template_y_info(),
                base.ui.panel{layout = {height = self._prop_x_info_height}}
            },
            self:create_template_canvas(),
            base.ui.panel{
                name = 'chart_info_list_wrapper',
                layout = {grow_height = 1},
                self:create_template_info_list()
            }
        },
        base.ui.panel{
            name = 'chart_x_info_wrapper',
            layout = {grow_width = 1, direction = 'row'},
            base.ui.panel{layout = {width = self._prop_y_info_width}},
            self:create_template_x_info()
        },
        self:create_template_caption()
    }
end

function line_chart:new_bind()
    return base.bind()
end

function line_chart:init()
    self._brush = base.ui.brush:create(self._canvas_id)

    base.next(function()
        self:show_data()
    end)

    base.game:event('画面-分辨率变化', function()
        base.next(function()
            self:show_data()
        end)
    end)
end

function line_chart:watch()
    return {
        columns_name = function(v)
            self._columns_name = v
        end,
        columns_color = function(v)
            self._columns_color = v
        end,
        datas = function(v)
            self._datas = v
        end,
        show_index = function(v)
            self._show_index = v
            self:show_data()
        end,
        caption = function(v)
            self._impl.caption_text = v
        end,
        add_data = function(v)

            for key, value in pairs(v) do
                table.insert(self._datas, value)
            end
            self:show_data()
        end
    }
end
-------------------------------------------------------------------------------
-- 辅助方法
---@param n number
local function round(n)
    return math.floor(n + 0.5)
end

local function contain(array, v)
    for _, value in ipairs(array) do
        if value == v then
            return true
        end
    end
    return false
end

local function remove(array, v)
    for i, value in ipairs(array) do
        if value == v then
            table.remove(array, i)
            return
        end
    end
end

---@param count integer
---@param max_count integer
---@return number step_size
---@return number step_count
local function get_step(count, max_count)
    for i = 1, count do
        if (count - 1) // i + 1 <= max_count then
            return i, (count - 1) // i + 1
        end
    end
end

---@param min number
---@param max number
---@param count integer
---@return number beautify_min
---@return number beautify_max
---@return integer step
---将从min max 取count个数  这些数为beautiful_number(1，2，5的...0.1, 1 ,10,...的倍数)的整数倍
local function beautify_step_range(min, max, count)
    -- 对step为1时进行判断
    local left, right = math.floor(min), math.ceil(max)
    if right - left < count - 1 then
        -- 若步伐过大，则缩小step，直到step_count大于count-1 返回上一次step
        local temp_left, temp_right, temp_step = left, right, 1
        local factor = 0.1
        while true do
            -- print('缩小step factor:', factor)
            left = min / factor
            right = max / factor
            for _, step in pairs({5, 2, 1}) do
                -- print('step:', step)
                left = left // step * step
                if right % step ~= 0 then
                    right = (right // step + 1) * step
                end

                if (right - left) / step > count - 1 then
                    -- 找到的step
                    return temp_left, temp_right, temp_step
                end
                temp_left = left * factor
                temp_right = right * factor
                temp_step = step * factor
            end
            -- 继续缩小step
            factor = factor * 0.1
        end
    else
        -- 若步伐过小，则扩大step，直到step_count小于等于count-1 返回当前step
        local factor = 1
        while true do
            -- print('扩大step factor:', factor)
            left = min / factor
            right = max / factor
            for _, step in pairs({1, 2, 5}) do
                -- print('step:', step)
                left = left // step * step
                if right % step ~= 0 then
                    right = (right // step + 1) * step
                end

                if (right - left) / step <= count - 1 then
                    -- 找到合适的step
                    return left * factor, right * factor, step * factor
                end
            end
            factor = factor * 10
        end
    end
end

local function test_beautify_step_range_single(min, max, count)
    print('(' .. min .. ', ' .. max .. ')', 'count:' .. count)
    local b_min, b_max, b_step = beautify_step_range(min, max, count)

    local v = b_min
    local str = '  '
    while v <= b_max do
        str = str .. v .. ', '
        v = v + b_step
    end
    print('(' .. b_min .. ', ' .. b_max .. ')', 'b_step:' .. b_step)
    print('count ' .. math.ceil((b_max - b_min) / b_step + 1) .. ':', str)
    print()
end

local function test_beautify_step_range()
    -- test_beautify_step_range_single(1.1, 2.9, 10)
    -- test_beautify_step_range_single(1.2, 68, 5)
    -- test_beautify_step_range_single(0.11, 2, 8)
    -- test_beautify_step_range_single(-11.1, -10.2, 7)
    -- test_beautify_step_range_single(-101, 122, 11)
    -- test_beautify_step_range_single(-0.1, 0.1, 6)
    -- test_beautify_step_range_single(12, 24, 7)
    -- test_beautify_step_range_single(2.2, 6.4, 7)
    test_beautify_step_range_single(3.3, 10210.1, 21)
    -- test_beautify_step_range_single(-10000.5, 354848, 14)
end

-------------------------------------------------------------------------------
local chart_count = 0
---@return table
---返回canvas模板
function line_chart:create_template_canvas()
    chart_count = chart_count + 1
    ---canvas的id 用于创建brush
    self._canvas_id = '__chart_canvas_id_' .. chart_count .. '__'
    return base.ui.canvas{
        name = 'chart_canvas',
        id = self._canvas_id,
        color = self._prop_bg_color,
        layout = {grow_width = 1, grow_height = 1},
        z_index = -1
    }
end

---@return table
---返回x轴上的信息
function line_chart:create_template_x_info()
    return base.ui.panel{
        name = 'chart_x_info',
        color = nil,
        layout = {
            grow_width = 1,
            height = self._prop_x_info_height,
            col_self = 'end'
        },
        base.ui.panel{
            name = "x_axis_name_wrapper",
            layout = {row_self = 'end', col_self = 'start'},
            base.ui.label{
                name = 'x_axis_name',
                layout = {
                    width = self._prop_axis_x_right_margin - 5,
                    row_self = 'end'
                },
                text = 'x',
                font = {
                    color = self._prop_x_info_font_color,
                    size = self._prop_x_info_font_size,
                    bold = true,
                    align = 'left'
                },
                bind = {text = 'x_axis_text'}
            }
        },
        array = 0,
        base.ui.panel{
            layout = {row_self = 'start'},
            base.ui.label{
                layout = {
                    width = 100,
                    height = self._prop_x_info_height,
                    margin = {top = self._prop_x_info_top_margin},
                    relative = {0, 0}
                },
                text = '',
                font = {
                    color = self._prop_x_info_font_color,
                    size = self._prop_x_info_font_size,
                    vertical_align = 'top'
                },
                bind = {
                    text = 'x_info_item_text',
                    layout = {
                        relative = 'x_info_item_relative',
                        width = 'x_info_item_width'
                    }
                }
            }
        },
        bind = {array = 'x_info_array'}
    }
end

---@return table
---返回y轴上的信息
function line_chart:create_template_y_info()
    return base.ui.panel{
        name = 'chart_y_info',
        color = nil,
        layout = {
            width = self._prop_y_info_width,
            grow_height = 1,
            row_self = 'start'
        },

        array = 0,
        base.ui.panel{
            layout = {row_self = 'end', col_self = 'end'},
            base.ui.label{
                layout = {
                    width = self._prop_y_info_width,
                    row_self = 'end',
                    relative = {0, 0},
                    margin = {right = self._prop_y_info_right_margin}
                },
                text = '',
                font = {
                    color = self._prop_y_info_font_color,
                    size = self._prop_y_info_font_size,
                    align = 'right'
                },
                bind = {
                    text = 'y_info_item_text',
                    layout = {relative = 'y_info_item_relative'}
                }
            }
        },
        bind = {array = 'y_info_array'}
    }
end

---@return table
---返回图表信息（标识每个线的名字、颜色）
function line_chart:create_template_info_list()
    return base.ui.panel{
        name = 'chart_info_list',
        color = nil,
        layout = {
            width = self._prop_info_list_item_width,
            grow_height = 1,
            row_self = 'end',
            col_content = 'start',
            direction = 'col'
        },
        array = 0,
        base.ui.panel{
            name = 'chart_info_list_item',
            layout = {
                grow_width = 1,
                height = self._prop_info_list_item_height,
                direction = 'row'
            },
            base.ui.panel{
                name = 'chart_info_list_item_color',
                layout = {
                    width = self._prop_info_list_item_height * 0.5,
                    height = self._prop_info_list_item_height * 0.5
                },
                bind = {
                    color = 'info_list_item_color',
                    opacity = 'info_list_item_opacity'
                }
            },
            base.ui.label{
                name = 'chart_info_list_item_text',
                layout = {grow_width = 1, grow_height = 1, margin = {left = 5}},
                text = '',
                font = {
                    color = self._prop_info_list_font_color,
                    size = self._prop_info_list_font_size,
                    align = 'start'
                },
                bind = {text = 'info_list_item_text'}
            },
            bind = {event = {on_click = 'info_list_item_on_click'}}
        },
        bind = {array = 'info_list_array'}
    }
end

---@return table
---返回标题栏
function line_chart:create_template_caption()
    return base.ui.label{
        name = 'chart_caption',
        color = self._prop_bg_color,
        z_index = -1,
        layout = {grow_width = 1, height = self._prop_caption_height},
        text = 'lines chart',
        font = {
            color = self._prop_caption_font_color,
            size = self._prop_caption_font_size
        },
        bind = {text = 'caption_text'}
    }
end

---@return table
---获取生成的canvas
function line_chart:get_canvas_ui()
    -- 改变分辨率后 reload 后这里self._ui.child[1]为空
    return self._ui.child[1].child[2]
end

---根据用户传入的属性来更改data中的默认值
function line_chart:read_custom_properties()
    -- test
    -- test_beautify_step_range()

    -- 保存可以bind的属性 (都是浅copy 可能会有问题)
    ---data中每一列的列名
    self._columns_name = self._prop.columns_name or {}
    ---data中每个折线的颜色
    self._columns_color = self._prop.columns_color or {}
    ---需要显示的数据 二维数组 第一列为行名
    self._datas = self._prop.datas or {}
    ---需要显示第几列的数据
    self._show_index = self._prop.show_index or {}
    ---标题
    self._caption = self._prop.caption or 'lines chart'

    -- 替换基础属性
    self:override_properties('font_size')
    self:override_properties('font_color')

    -- 逐个替换默认属性字段
    for key, value in pairs(self._prop) do
        if self['_prop_' .. key] ~= nil then
            self['_prop_' .. key] = value
        end
    end
end

---@param suffix string
---覆盖所有尾缀为suffix属性的默认值
function line_chart:override_properties(suffix)
    if self._prop[suffix] ~= nil then
        for key, _ in pairs(self) do
            local _, end_i = string.find(key, suffix)
            if end_i == #key then
                self[key] = self._prop[suffix]
            end
        end
    end
end

---显示数据
function line_chart:show_data()
    local _, _, w, h = self:get_canvas_ui():rect()

    ---原点坐标x
    self._origin_x = self._prop_y_info_width
    ---原点坐标y
    self._origin_y = h - self._prop_x_info_height
    ---x轴的长度
    self._axis_x_length = w - self._prop_y_info_width -
                              self._prop_axis_x_right_margin -
                              self._prop_axis_arrow_size
    ---y轴的长度
    self._axis_y_length = h - self._prop_x_info_height -
                              self._prop_axis_y_top_margin -
                              self._prop_axis_arrow_size

    self._brush:clear()

    self:count_delta()

    -- 先画线再画坐标
    self:draw_polyline()
    self:draw_axis()

    -- 显示所有文本信息
    self:show_x_info()
    self:show_y_info()
    self:show_info_list()
end

---根据数据中的最大最小值，有多少条数据，计算x轴和y轴的单位大小
function line_chart:count_delta()
    local count = #self._datas
    local max, min, step = math.mininteger, math.maxinteger, 1

    for _, i in pairs(self._show_index) do
        for _, row in pairs(self._datas) do
            local value = row[i]
            if value > max then
                max = value
            end
            if value < min then
                min = value
            end
        end
    end

    if #self._show_index == 0 then
        min, max, step = 0, 0, 0
    else
        -- 对 max 和 min 处理成方便查看的数据  如 1，2，5，10等的倍数
        min, max, step = beautify_step_range(min, max,
                                             self._prop_x_info_max_count)
    end
    ---x 轴一单位的长度
    self._axis_x_delta = (self._axis_x_length - 10) / (count - 1)
    ---y 轴一单位的长度 这里加10使最后一个刻度距离箭头10
    self._axis_y_delta = (self._axis_y_length - 10) / (max - min)
    ---y 轴上的最大值
    self._axis_y_max = max
    ---y 轴上的最小值
    self._axis_y_min = min
    ---y 轴上的step
    self._axis_y_step = step
end

---在canvas上画坐标系
function line_chart:draw_axis()
    self._brush:set_line_color(self._prop_axis_color)
    self:set_line_width(self._prop_axis_width)

    -- 画y轴
    self:draw_line(0, 0, 0, self._axis_y_length)

    self:draw_polygon({
        {0, self._axis_y_length + self._prop_axis_arrow_size},
        {self._prop_axis_arrow_size, self._axis_y_length},
        {-self._prop_axis_arrow_size, self._axis_y_length}
    })

    -- 画x轴
    -- 这里补掉x轴和y轴连接处了缺口 ：-self._prop_axis_width / 2
    self:draw_line(round(-self._prop_axis_width / 2), 0, self._axis_x_length, 0)
    self:draw_polygon({
        {self._axis_x_length + self._prop_axis_arrow_size, 0},
        {self._axis_x_length, -self._prop_axis_arrow_size},
        {self._axis_x_length, self._prop_axis_arrow_size}
    })
end

---在canvas上画折线
function line_chart:draw_polyline()
    self:set_line_width(self._prop_line_width)

    for _, i in pairs(self._show_index) do
        self._brush:set_line_color(self._columns_color[i])

        local x1, x2, y2 = 0
        local y1 = (self._datas[1][i] - self._axis_y_min) * self._axis_y_delta
        for j = 2, #self._datas do
            x2 = (j - 1) * self._axis_x_delta
            y2 = (self._datas[j][i] - self._axis_y_min) * self._axis_y_delta
            self:draw_line(x1, y1, x2, y2)
            x1, y1 = x2, y2
        end
    end
end

---显示x轴上的文本信息
function line_chart:show_x_info()
    if #self._datas == 0 then
        return
    end

    -- 每隔step显示一个
    local step, count = get_step(#self._datas, self._prop_x_info_max_count)

    local bind = self._impl
    bind.x_info_array = count
    bind.x_axis_text = self._columns_name[1] or 'x'

    base.next(function()
        self._brush:set_line_color(self._prop_axis_color)
        self:set_line_width(self._prop_axis_ruler_width)

        -- x info item 的下标
        local j = 1
        for i = 1, #self._datas, step do
            local x = (i - 1) * self._axis_x_delta
            -- 画刻度
            self:draw_line(x, 0, x, self._prop_axis_ruler_length)
            -- 显示文字
            bind.x_info_item_text[j] = self._datas[i][1]
            bind.x_info_item_relative[j] = {x, 0}
            bind.x_info_item_width[j] = self._axis_x_length / (count - 1) - 10
            j = j + 1
        end
    end)
end

---显示y轴上的文本信息
function line_chart:show_y_info()
    local bind = self._impl

    if #self._show_index == 0 then
        bind.y_info_array = 0
        return
    end

    local count = (self._axis_y_max - self._axis_y_min) / self._axis_y_step + 1
    bind.y_info_array = count

    base.next(function()
        self._brush:set_line_color(self._prop_axis_color)
        self:set_line_width(self._prop_axis_ruler_width)
        -- y info item 的下标
        local j = 1
        for i = self._axis_y_min, self._axis_y_max, self._axis_y_step do
            local y = (i - self._axis_y_min) * self._axis_y_delta
            -- 画刻度
            self:draw_line(0, y, self._prop_axis_ruler_length, y)
            -- 显示文字
            bind.y_info_item_text[j] = tostring(math.tointeger(i) or i)

            bind.y_info_item_relative[j] = {0, -y}
            j = j + 1
        end
    end)
end

---显示信息列表
function line_chart:show_info_list()
    local bind = self._impl
    local count = (#self._columns_name or 1) - 1

    bind.info_list_array = count
    base.next(function()
        for i = 1, count do
            bind.info_list_item_text[i] = self._columns_name[i + 1]
            bind.info_list_item_color[i] = self._columns_color[i + 1]
            bind.info_list_item_opacity[i] =
                contain(self._show_index, i + 1) and 1 or 0
            -- 绑定点击事件
            bind.info_list_item_on_click[i] =
                function()
                    if contain(self._show_index, i + 1) then
                        remove(self._show_index, i + 1)
                    else
                        table.insert(self._show_index, i + 1)
                    end
                    self:show_data()
                end
        end
    end)
end
-------------------------------------------------------------------------------
-- 这几个方法里 处理了坐标转换，转换为整数
---划线
function line_chart:draw_line(x1, y1, x2, y2)
    x1 = self._origin_x + x1
    y1 = self._origin_y - y1
    x2 = self._origin_x + x2
    y2 = self._origin_y - y2
    self._brush:draw_line(round(x1), round(y1), round(x2), round(y2))
end

---画多边形
function line_chart:draw_polygon(polygon)
    for i = 1, #polygon do
        polygon[i][1] = round(self._origin_x + polygon[i][1])
        polygon[i][2] = round(self._origin_y - polygon[i][2])
    end

    self:set_line_width(0)
    self._brush:draw_polygon(polygon)
    self:set_line_width(self._prop_axis_width)
end

---设置线宽
function line_chart:set_line_width(width)
    self._brush:set_line_width(round(width))
end
-------------------------------------------------------------------------------

base.p_ui.register('line_chart', line_chart)
