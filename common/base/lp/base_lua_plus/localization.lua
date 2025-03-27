--- lua_plus ---
function base.set_language(language:string)
    ---@ui 设置客户端语言为~1~
    ---@description 设置客户端语言
    ---@applicable action
    ---@belong game
    ---@keyword 语言
    base.i18n.set_lang(language)
end

function base.get_language() string
    ---@ui 获取客户端语言
    ---@description 获取客户端语言
    ---@applicable value
    ---@belong game
    ---@keyword 语言
    return base.i18n.get_lang()
end

function base.get_text(id:string) string
    ---@ui 获取~1~的本地化文本
    ---@description 获取本地化文本
    ---@applicable value
    ---@belong game
    ---@keyword 语言
    return base.i18n.get_text(id)
end