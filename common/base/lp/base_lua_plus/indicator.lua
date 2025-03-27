--- lua_plus ---
function base.enable_select_indicator()
    ---@ui 启用选中指示器
    ---@description 启用选中指示器
    ---@keyword 指示器
    ---@applicable action
    ---@belong game
    base.select_indicator_enable = true
end

function base.disable_select_indicator()
    ---@ui 禁用选中指示器
    ---@description 禁用选中指示器
    ---@keyword 指示器
    ---@applicable action
    ---@belong game
    base.select_indicator_enable = false
    if base.select_indicator then
        base.select_indicator:destroy()
        base.select_indicator = nil
    end
end