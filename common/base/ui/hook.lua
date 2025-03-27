
local platform = include 'base.platform'
local argv = include 'base.argv'

-- 修改字体
local function hook_font(data)
    if data.__ui_type ~= 'label' and data.__ui_type ~= 'input' then return end
    if data.font == nil then
        data.font = {}
    end
    if platform.is_wx() or platform.is_qq() or argv.has('custom_font') then
        data.font.family = 'Custom'
    -- else
    --     data.font.family = 'Microsoft Yahei'
    end
end

-- 把分辨率宽高修改成固定宽高
local r_size_id = 0
local function hook_r_size(data)

    local layout = data.layout
    if not layout or (not layout.r_width and not layout.r_height) then return end

    local ow, oh = common.get_resolution()
    local has_r_size = false
    local id = ''
    if layout then
        if layout.r_width then
            layout.width = math.floor(ow * layout.r_width)
            has_r_size = true
            if layout.ratio and not layout.r_height then
                layout.height = layout.ratio[2] / layout.ratio[1] * layout.width
            end
        end
        if layout.r_height then
            layout.height = math.floor(oh * layout.r_height)
            has_r_size = true
            if layout.ratio and not layout.r_width then
                layout.width = layout.ratio[1] / layout.ratio[2] * layout.height
            end
        end
        if has_r_size then
            r_size_id = r_size_id + 1
            data.id = '____r_size__' .. r_size_id
            id = data.id
        end
    end

    base.game:event('画面-分辨率变化', function(w, h)
        local w, h = common.get_resolution()
        if not layout then return end
        if layout.r_width then
            layout.width = math.floor(w * layout.r_width)
            if layout.ratio and not layout.r_height then
                layout.height = layout.ratio[2] / layout.ratio[1] * layout.width
            end
        end
        if layout.r_height then
            layout.height = math.floor(h * layout.r_height)
            if layout.ratio and not layout.r_width then
                layout.width = layout.ratio[1] / layout.ratio[2] * layout.height
            end
        end
        if has_r_size then
            if base.ui_info().ui_map[id] then
                base.ui.gui.set_layout(id, layout)
            end
        end
    end)
end

-- 修改字体大小移动到c++了, 先不删下面的代码, 因为c++里缩放时没考虑custom_font, 等之后看看怎么做

-- 修改字体大小
local function hook_font_size(data)

    -- 微信和qq不修改字体大小
    if platform.is_qq() or platform.is_wx() or argv.has('custom_font') then return end

    if not data.font then return end
    local ow, oh = common.get_resolution()
    local font = data.font
    local origin_font_size
    if font then
        origin_font_size = font.size or 14
    end

    -- print(data.id)
    local id = data.id

    base.game:event('画面-分辨率变化', function(w, h)
        local w, h = common.get_resolution()
        if origin_font_size then
            local new_size = math.floor(w / ow * origin_font_size)
            local ui_map = base.ui_info().ui_map
            if ui_map[id] then
                base.ui.gui.set_font(id, {size = math.ceil(new_size)})
            end
        end
    end)

end

local pre_hooks = { hook_font, hook_r_size }

local function process_control(data, hooks)
    for _, hook in ipairs(hooks) do
        hook(data)
    end
    for _, child in ipairs(data) do
        process_control(child, hooks)
    end
end

local create = base.ui.create
base.ui.create = function (data, name, ...)
    process_control(data, pre_hooks)
    return create(data, name, ...)
end
