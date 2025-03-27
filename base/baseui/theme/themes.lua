---@class theme
local theme = {
    -- 正文字
    -- 正文字-强调 （bold）
    font_size_regular = 14,
    font_line_height_regular = 21,
    -- 标题字 （bold）
    font_size_heading = 16,
    font_line_height_heading = 24,
    -- 辅助文字
    font_size_secondary = 11,
    font_line_height_secondary = 17,

    -- 主色
    color_primary = '#948EFF',
    color_primary_2 = '#5A55AA',
    color_regular_1 = '#1BB05D',
    color_regular_2 = '#F4CA34',
    color_regular_3 = '#EE7357',
    color_regular_4 = '#F7649C',
    color_regular_5 = '#339CFE',
    color_regular_6 = '#08858D',

    -- 对话框标题栏颜色
    dialog_title_bar_color = '#191919',

    -- tab选中颜色
    tab_selected_color = '#000000',

    -- 图标色
    icon_color_primary = '#999999',
    icon_color_secondary = '#666666',

    icon_color_light = '#CCCCCC',
    icon_color_dark = '#0E0E0E',

    -- 文字色
    font_color_primary = '#E1E1E1',
    font_color_secondary = '#919191',


    -- 背景色
    background_color1 = '#0E0E0E',
    background_color2 = '#171717',
    background_color3 = '#232323',

    background_color = '#0E0E0E',
    panel_color = '#232323',

    -- 禁用色
    disabled_color = '#4F4F4F',
    warning_color = '#9B0038',

    line_color = '#1A1A1A',
    panel_split_line = '#111111',

    scroll_width = 5,
    visible_color = '#6657C7',
    invisible_color = '#494949',
}

local setmetatable, pairs = setmetatable, pairs
local default_theme = setmetatable({}, {
    __index = theme,
    __newindex = function() end
})

local event_map = setmetatable({}, { __mode = 'kv' })
local function on_theme_change(callback)
    if callback then
        event_map[callback] = true
    end
    return { remove = function(self)
        event_map[callback] = nil
    end }
end

local current_theme = default_theme
local function call_events()
    for callback, _ in pairs(event_map) do
        callback(current_theme)
    end
end

local theme_map = {}
local function change_theme(theme_name)
    local new_theme = theme_map[theme_name]
    if new_theme and new_theme ~= current_theme then
        current_theme = new_theme
        call_events()
    end
end

---@return theme
local function get_theme(theme_name)
    if not theme_name then
        return default_theme
    end
    if not theme_map[theme_name] then
        theme_map[theme_name] = setmetatable({}, { __index = theme })
    end
    return theme_map[theme_name]
end

---@return theme
local function get_current_theme()
    return current_theme
end

return {
    get_theme = get_theme,
    change_theme = change_theme,
    on_theme_change = on_theme_change,
    get_current_theme = get_current_theme,
}