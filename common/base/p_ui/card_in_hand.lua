include 'base.p_ui'

-- 注意
-- 1.参数单位不统一，需要注意各个参数的单位
-- 2.（已解决）用户传进来的ui如果不是static，则无法拖动（拖动事件暂时还无法向上传递）
-- 3.（已解决）文字不能随着旋转缩放（之后再做）
-- 4.若要用子ui的bind.xx 则需要这样使用 bind.card[i].xx

-- 1. card_in_hand控件会撑满整个父节点
-- 2. 为自动适配分辨率 有些属性单位设置为card_in_hand的宽度或高度。例如当card_in_hand在某分辨率下宽度为800，radius = 2，则radius实际为2*800像素
-- 3. 卡片们会在card_in_hand正下方radius处以半径radius为扇心向两边展开， 两张相邻卡片间距小于max_interval的情况下占满card_in_hand，否则以两张相邻卡片间距为max_interval向两边展开
-- 4. 当radius为0时，表示水平排列，此时max_interval单位为card的宽度
-- 5. 卡片高度为card_in_hand的高度
local card_in_hand = {}

-- -->自定义控件方法-------------------------------------------------------------------------------
---定义控件属性
function card_in_hand.prop()
    return {
        -- 属性---
        -- 两张相邻卡片组成的弧对应的圆心角的最大值。 单位degree 或 card_in_hand的宽度
        'max_interval',
        -- 所有卡片组成的弧对应的半径。 单位为card_in_hand的宽度
        'radius',
        -- 卡片width/height
        'card_ratio',
        -- 鼠标悬浮时卡片放大的倍数
        'card_scale',
        -- 卡片悬浮时y相对于card_in_hand的位置。 单位为card_in_hand的高度
        'hover_up_pos',
        -- 鼠标悬停时卡片向两边挤的幅度。 单位为卡片的宽度
        'squeeze_offset',
        -- 鼠标悬停多少ms触发on_mouse_hover事件
        'hover_time',

        -- 操作---
        -- 卡片数量 可以修改此值添加或删除card，在末尾位置添加或移除。
        'array',
        -- 添加卡片 传入 {index=下标，count=数量，ui=子ui} 下标默认末尾， 数量默认1  ui默认card_in_hand中第一个子ui
        'add_card',
        -- 删除卡片 传入 下标 或 下标数组
        'remove_card',
    }
end

---定义控件事件
function card_in_hand.event()
    return {
        -- 传入card对应的下标、ui、bind
        'on_mouse_enter_card',
        -- 传入card对应的下标、ui、bind
        'on_mouse_leave_card',
        -- 传入card对应的下标、ui、bind
        'on_mouse_hover_card',
        -- 传入card对应的下标、ui、bind
        -- 'on_drag_in',
        -- 拖出card_in_hand并松开鼠标时 传入card对应的下标、ui、bind
        -- 'on_drag_out',
    }
end

---定义控件的内部数据  self.访问
function card_in_hand.data()
    return {
        _max_interval = 10,
        _radius = 2,
        _card_ratio = 0.7,
        _card_scale = 1.3,
        _hover_up_pos = 0.4,
        _squeeze_offset = 0.5,
        _rotate_speed = 0.3,
        _scale_speed = 0.3,
        _hover_time = 500,

        ---保存所有卡片的信息 有card_wrapper_ui, card_ui, index, position, rotate
        _cards = {},
        ---保存所有卡片bind，并暴露给用户
        _card_binds = {},
        ---保存card的宽高
        _card_size = {},
        ---用户传入的第一个card_ui
        _user_template_card = nil,
    }
end

-- 用户传入的属性默认值通过 self._prop
---定义控件
function card_in_hand:define()
    local prop = self._prop

    self._radius = prop.radius or self._radius
    if self._radius == 0 then
        self._max_interval = prop.max_interval or 0.5
    else
        self._max_interval = prop.max_interval or self._max_interval
    end
    self._card_ratio = prop.card_ratio or self._card_ratio
    self._card_scale = prop.card_scale or self._card_scale
    self._hover_up_pos = prop.hover_up_pos or self._hover_up_pos
    self._squeeze_offset = prop.squeeze_offset or self._squeeze_offset
    self._hover_time = prop.hover_time or self._hover_time

    -- 获取模板
    if #prop > 0 then self._user_template_card = prop[1] end

    return base.ui.panel{
        layout = {
            grow_width = 1,
            grow_height = 1,
        },
    }
end

---初始化
function card_in_hand:init()
    local array = self._prop.array
    --  添加卡片
    if array and array > 0 then
        for _ = 1, array do
            self:add_card(self._user_template_card)
        end
    else
        for _, user_ui in ipairs(self._prop) do
            self:add_card(user_ui)
        end
    end

    -- 并暴露给用户所有卡片bind，
    self._impl.cards = self._card_binds

    -- todo 可以考虑用c++提供事件
    -- 动态调整布局 每20ms检测一次 及 分辨率变化时调整一次
    base.next(function ()
        self:adjust_layout()
        local x_temp, y_temp, width_temp, height_temp  = self._ui:rect()
        base.loop(30, function (timer)
            if self == nil then timer:remove() end
            local x, y, width, height = self._ui:rect()
            -- 发现大小改变
            if x ~= x_temp or y ~= y_temp or width ~= width_temp or height ~= height_temp then
                x_temp, y_temp, width_temp, height_temp  = x, y, width, height
                self:adjust_layout()
            end
        end)
    end)
    base.game:event('画面-分辨率变化', function ()
        self:adjust_layout()
    end)
end

---监视外部属性变化
function card_in_hand:watch()
    return {
        array = function (arg)
            local card_count = #self._cards
            if arg > card_count then
                -- 添加
                for i = 1, arg - card_count do
                    self:add_card(self._user_template_card)
                end
            elseif arg < card_count then
                -- 删除
                for i = card_count, arg + 1, -1 do
                    self:remove_card(i)
                end
            end
            self:adjust_layout()
        end,
        add_card = function (arg)
            local index = base.math.clamp(arg.index or #self._cards + 1, 1, #self._cards + 1)
            local count = math.max(arg.count or 1, 0)
            local ui = arg.ui or self._user_template_card

            for i = 1, count do
                self:add_card(ui, index)
            end
            self:adjust_layout()
        end,
        remove_card = function (arg)
            if type(arg) == 'number' then
                self:remove_card(arg)
            elseif type(arg) == 'table' then
                local indexes = {}
                -- 删除溢出的下标
                for _, i in pairs(arg) do
                    if i > #self._cards then
                        log_file.warn('card_in_hand:remove index out of range :' .. i)
                    else
                        table.insert(indexes, i)
                    end
                end
                -- 逆向排序
                table.sort(indexes, function (a, b)
                    return a > b
                end)
                --删掉重复值
                for i = #indexes, 2, -1 do
                    if indexes[i] == indexes[i - 1] then
                        table.remove(indexes, i)
                    end
                end

                -- 删除
                for _, i in pairs(indexes) do
                    self:remove_card(i)
                end
            end
            self:adjust_layout()
        end,

        max_interval = function (arg)
            if arg == nil then return end
            self._max_interval = math.max(0, arg)
            self:adjust_layout()
        end,
        radius = function (arg)
            if arg == nil then return end
            self._radius = math.max(0, arg)
            self:adjust_layout()
        end,
        card_ratio = function (arg)
            if arg == nil then return end
            self._card_ratio = math.max(0, arg)
            self:adjust_layout()
        end,
        card_scale = function (arg)
            if arg == nil then return end
            self._card_scale = math.max(0, arg)
            self:adjust_layout()
        end,
        hover_up_pos = function (arg)
            if arg == nil then return end
            self._hover_up_pos = math.max(0, arg)
            self:adjust_layout()
        end,
        squeeze_offset = function (arg)
            if arg == nil then return end
            self._squeeze_offset = math.max(0, arg)
            self:adjust_layout()
        end,
    }
end

-- 注册控件对象
base.p_ui.register('card_in_hand', card_in_hand)
-- -->自定义控件方法-------------------------------------------------------------------------------


---添加卡片
function card_in_hand:add_card(user_card_ui, index)
    local templay_card = base.ui.panel {
        user_card_ui,
        static = false,
        enable_drag = true,  -- 可拖动
        scale = 1,
        bind = {
            scale = '__scale',
            layout = {
                width = '__width',
                height = '__height',
            },
            event = {
                on_mouse_enter = '__on_mouse_enter',
                on_mouse_leave = '__on_mouse_leave',
                -- on_drag = '__on_drag',
                -- on_drop = '__on_drop',
            },
        },
    }
    ---包裹一层用于操作card 位置 缩放 旋转 宽高等
    local template_card_wrapper = base.ui.panel {
        templay_card,
        transition = {
            position = {
                time = 200,
                func = 'linear',
            },
        },
        bind = {
            layout = {
                position = '__position',  -- 调整card的位置
            },
            rotate = '__rotate',
            z_index = '__z_index',  -- 调整card之间的层级关系
        },
    }

    local card_wrapper_ui, card_wrapper_bind = base.ui.create(template_card_wrapper, '__card_wrapper__')
    local card_data =  {
        wrapper_ui = card_wrapper_ui,
        ui = card_wrapper_ui.child[1].child[1],

        -- 需要实时更新的参数
        index = 0,
        position = {0, 0},
        rotate = 0,
        scale = 1,
        destroyed = false,
        mouse_on = false, --鼠标是否在card上
    }

    if index == nil then
        index = #self._cards + 1
    end
    index = base.math.clamp(index, 1, #self._cards + 1)

    table.insert(self._cards, index, card_data)
    table.insert(self._card_binds, index, card_wrapper_bind)
    self._ui:add_child(card_wrapper_ui)

    -- 绑定鼠标事件
    card_wrapper_bind.__on_mouse_enter = function ()
        self:enter_card(card_data.index)
    end
    card_wrapper_bind.__on_mouse_leave = function ()
        self:leave_card(card_data.index)
    end
end

---删除卡片 要删除卡片的下标
function card_in_hand:remove_card(i)
    self._cards[i].wrapper_ui:remove()
    self._cards[i].wrapper_ui = nil
    self._cards[i].ui = nil
    self._cards[i].destroyed = true
    self:remove_card_rotate_timer(i)
    self:remove_card_scale_timer(i)
    self:remove_hover_card_timer(i)
    table.remove(self._card_binds, i)
    table.remove(self._cards, i)
end

-- -->事件相关方法---------------------------------------------------------------------------------
---鼠标进入第index的card
function card_in_hand:enter_card(index)
    -- 设置状态
    local card_data = self._cards[index]
    local card_bind = self._card_binds[index]
    card_data.mouse_on = true
    self:set_cards_position()
    self:card_rotate_to(index, 0)
    self:card_scale_to(index, self._card_scale)
    card_bind.__z_index = 9999

    -- 触发事件
    self:hover_card(index)
    self:emit_mouse_enter(index, card_data.ui, card_bind)
end

---鼠标离开第index的card
function card_in_hand:leave_card(index)
    -- 还原状态
    local card_data = self._cards[index]
    local card_bind = self._card_binds[index]
    card_data.mouse_on = false
    self:set_cards_position()
    self:card_rotate_to(index, card_data.rotate)
    self:card_scale_to(index, 1)
    card_bind.__z_index = index

    -- 触发事件
    self:remove_hover_card_timer(index)
    self:emit_mouse_leave(index, card_data.ui, card_bind)
end

---设置悬停事件
function card_in_hand:hover_card(index)
    self:remove_hover_card_timer(index)
    local card_data = self._cards[index]

    -- 设置定时器
    card_data.hover_card_timer = base.wait(self._hover_time, function ()
        if card_data.destroyed then
            return
        end
        self:emit_mouse_hover(index, card_data.ui, self._card_binds[card_data.index])
    end)
end

---删除悬停事件计时器
function card_in_hand:remove_hover_card_timer(index)
    local card_data = self._cards[index]
    if card_data.hover_card_timer ~= nil then
        card_data.hover_card_timer:remove()
        card_data.hover_card_timer = nil
    end
end
-- <--事件相关方法---------------------------------------------------------------------------------


-- -->属性过渡动画相关方法--------------------------------------------------------------------------
---第index card旋转到degree
function card_in_hand:card_rotate_to(index, degree)
    self:card_attribute_to('rotate', index, degree, self._rotate_speed)
end

---将第index card缩设置为scale
function card_in_hand:card_scale_to(index, scale)
    self:card_attribute_to('scale', index, scale, self._scale_speed)
end

function card_in_hand:remove_card_rotate_timer(index)
    self:remove_card_attribute_timer('rotate', index)
end

function card_in_hand:remove_card_scale_timer(index)
    self:remove_card_attribute_timer('scale', index)
end

---设置属性过渡 使第index个card的属性attribute 以速度speed向值to移动（目前是插值移动）
function card_in_hand:card_attribute_to(attribute, index,  to, speed)
    -- 删除之前的过渡
    self:remove_card_attribute_timer(attribute, index)

    local attribute_timer = attribute .. '_loop'
    local card_data = self._cards[index]
    local card_bind = self._card_binds[index]

    -- 创建属性过渡
    card_data[attribute_timer] = base.loop(15, function ()
        local bind_name = '__' .. attribute
        -- todo 目前是插值过渡
        card_bind[bind_name] = base.math.lerp(card_bind[bind_name], to, speed)

        if math.abs(card_bind[bind_name] - to) < 0.1 then
            -- 停止过渡
            card_bind[bind_name] = to
            card_data[attribute_timer]:pause()
        end
    end)
end

---删除属性过渡
function card_in_hand:remove_card_attribute_timer(attribute, index)
    local attribute_timer = attribute .. '_loop'
    local card_data = self._cards[index]
    if card_data[attribute_timer] then
        card_data[attribute_timer]:remove()
        card_data[attribute_timer] = nil
    end
end
-- <--属性过渡动画相关方法--------------------------------------------------------------------------


-- -->布局信息相关方法-----------------------------------------------------------------------------
---计算所有卡片的大小、位置、旋转、索引信息
function card_in_hand:count_cards_data()
    local count = #self._cards
    if count == 0 then return end

    local _, _, width, height = self._ui:rect()

    -- 计算卡片大小
    self._card_size.width = height * self._card_ratio
    self._card_size.height = height

    -- 一张卡片的情况
    if count == 1 then
        self._cards[1].index = 1
        self._cards[1].rotate = 0
        self._cards[1].position = {width / 2, -height / 2}
        return
    end

    -- 水平排列
    if self._radius == 0 then
        local delta = math.min(width / (count - 1), self._max_interval * self._card_size.width) -- todo 统一单位
        for i, card_data in ipairs(self._cards) do
            -- 向右移动几个delta  =  -(count - 1)/2 + (i - 1) = i - (count + 1)/2
            local part = i - (count + 1) / 2

            card_data.index = i
            card_data.rotate = 0
            card_data.position = {width / 2 + delta * part, height / 2}
        end
        return
    end

    -- 弧形排列
    local delta_angle = self._max_interval
    if width < self._radius * width * 2 then    --todo 统一单位
        local total_angle = base.math.asin(width / (2 * self._radius * width)) * 2
        delta_angle = math.min(total_angle / (count - 1), delta_angle)
    end
    for i, card_data in ipairs(self._cards) do
        -- 向右移动几个delta  =  -(count - 1)/2 + (i - 1) = i - (count + 1)/2
        local part = i - (count + 1) / 2

        local degree = delta_angle * part
        local card_x = width / 2 + base.math.sin(degree) * self._radius * width
        local card_y = height / 2 + (1 - base.math.cos(degree)) * self._radius * width

        card_data.index = i
        card_data.rotate = degree
        card_data.position = {card_x, card_y}
    end
end

---ui上根据card_data设置bind，设置所有card的位置position，若有鼠标悬停则向上移动并向两边挤
function card_in_hand:set_cards_position()
    local enter_card_index = 0
    for i, card_data in ipairs(self._cards) do
        if card_data.mouse_on then
            enter_card_index = i
            break
        end
    end

    if enter_card_index == 0 then
        -- 鼠标没有悬浮在card上
        for i, card_data in ipairs(self._cards) do
            self._card_binds[i].__position = card_data.position
        end
    else
        -- 鼠标悬浮在card上
        for i, card_data in ipairs(self._cards) do
            local offset_x = 0
            local y = card_data.position[2]

            if i ~= enter_card_index then
                offset_x = self._squeeze_offset / (i - enter_card_index) * self._card_size.width
            else
                y = -self._hover_up_pos
            end
            self._card_binds[i].__position = {card_data.position[1] + offset_x, y}
        end
    end
end

---ui上根据card_data设置bind，设置所有card的z_index
function card_in_hand:set_cards_z_index()
    for i, card_data in ipairs(self._cards) do
        if not card_data.mouse_on then
            self._card_binds[i].__z_index = card_data.index
        end
    end
end

---ui上根据card_data设置bind, 设置所有card的rotate
function card_in_hand:set_cards_rotate()
    for i, card_data in ipairs(self._cards) do
        if not card_data.mouse_on then
            self._card_binds[i].__rotate = card_data.rotate
        end
    end
end

---计算并设置卡片的大小
function card_in_hand:set_cards_size()
    for _, card_bind in ipairs(self._card_binds) do
        card_bind.__width = self._card_size.width
        card_bind.__height = self._card_size.height
    end
end

---调整整个布局
function card_in_hand:adjust_layout()
    base.next(function ()
        self:count_cards_data()
        self:set_cards_position()
        self:set_cards_z_index()
        self:set_cards_rotate()
        self:set_cards_size()
    end)
end
-- <--布局信息相关方法-----------------------------------------------------------------------------


-- -->触发事件-------------------------------------------------------------------------------------
function card_in_hand:emit_mouse_enter(index, ui, bind)
    self:emit('on_mouse_enter_card', index, ui, bind)
end

function card_in_hand:emit_mouse_leave(index, ui, bind)
    self:emit('on_mouse_leave_card', index, ui, bind)
end

function card_in_hand:emit_mouse_hover(index, ui, bind)
    self:emit('on_mouse_hover_card', index, ui, bind)
end

-- function card_in_hand:emit_drag_in(index, ui, bind)
--     self:emit('on_drag_in', index, ui, bind)
-- end

-- function card_in_hand:drag_out(index, ui, bind)
--     self:emit('on_drag_out', index, ui, bind)
-- end
-- <--触发事件-------------------------------------------------------------------------------------