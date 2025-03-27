local language = ''

function _G.set_language(localization_language)
    language = localization_language
    -- 启动的时候，设置那边会立马置一下语言，这时会触发去cache Res目录下的本地化文件夹
    common.set_localization_language(language)
end

local function get_default_language()
    return common.get_default_language()
end

local function get_language()
    return language
end

local function add_resource_path()
    -- 当更新的时候会添加Res和Reslobby，以及Script文件夹，也顺便再cache一下
    common.set_localization_language(language)
end

local function get_text(key)
    --读表返回文本
end

return {
    set_language = set_language,
    get_language = get_language,
    add_resource_path = add_resource_path,
    get_text = get_text
}