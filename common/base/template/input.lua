local function deep_copy(t)
    if type(t) == 'table' then
        local new = {}
        for k, v in pairs(t) do
            new[k] = deep_copy(v)
        end
        return new
    else
        return t
    end
end

local function eq(a, b)
    local tp1, tp2 = type(a), type(b)
    if tp1 ~= tp2 then
        return false
    end
    if tp1 == 'table' then
        local mark = {}
        for k in pairs(a) do
            if not eq(a[k], b[k]) then
                return false
            end
            mark[k] = true
        end
        for k in pairs(b) do
            if not mark[k] then
                return false
            end
        end
        return true
    end
    return a == b
end

local function update_font(self, k, v)
    if not self.font then
        self.font = {}
    end
    if eq(self.font[k], v) then
        return
    end
    self.font[k] = v
    local data = {
        [k] = v
    }
    if k == 'size' then
        data[k] = math.ceil(data[k])
    end
    if base.ui.map[self.id] then
        base.ui.gui.set_font(self.id, data)
    end
end

return function (template, bind)
    local ui = base.ui.view {
        type = 'input',
        name = template.name,
        id = template.id
    }

    base.ui.watch(ui, template, bind, 'text')
    base.ui.watch(ui, template, bind, 'click_select')
    base.ui.watch(ui, template, bind, 'password_mask')
    base.ui.watch(ui, template, bind, 'return_key')

    ui.font = deep_copy(template.font)
    function bind.watch:font(k, v)
        update_font(ui, k, v)
    end

    if not template.font then
        template.font = {}
    end

    if not template.font.size then
        template.font.size = 14
    end

    -- 总是订阅输入输出事件
    ui:subscribe 'on_focus'
    ui:subscribe 'on_focus_lose'
    ui:subscribe 'on_input'

    return ui
end
