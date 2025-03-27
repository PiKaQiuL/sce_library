local tostring, pairs = tostring, pairs
local lua_file_format = '@%s.obj.localization.%s'
local localizations = {
    text = { file = 'localization', package_order = { '' }, package_map = {} },
    font = { file = 'font_localization', package_order = { '' }, package_map = {} },
}
local current_lang = 'Default'
local current_map = __MAIN_MAP__
local E = {}

local format_languages = { "zh_Hans", "zh_Hant", "en_GB","tl_PH","lo_LA","de_DE","ky_KG","fy_NL","bs_BA","fi_FI","gd_GB","bg_BG","el_GR","ar_AE","da_DK","kw_GB","be_BY","fo_FO","ak_GH","zh_CN","mn_MN","fr_FR","zh_TW","sn_ZW","Default","ms_SG","sq_AL","cy_GB","si_LK","sk_SK","gl_ES","bo_CN","as_IN","to_TO","nl_NL","ug_CN","hr_HR","af_ZA","it_IT","mk_MK","my_MM","ne_NP","kn_IN","ga_IE","vi_VN","uz_UZ","kk_KZ","ig_NG","is_IS","tr_TR","cs_CZ","th_TH","te_IN","ja_JP","sv_SE","dz_BT","en_US","es_ES","so_SO","sl_SI","ii_CN","sr_RS","rw_RW","gu_IN","ko_KP","lg_UG","ko_KR" }
local fallback_map = {
    zh_CN = { 'zh_TW', 'en_US', 'Default' },
    zh_TW = { 'zh_CN', 'en_US', 'Default' },
    zh_HK = { 'zh_TW', 'en_US', 'Default' },
    zh_SG = { 'zh_CN', 'en_US', 'Default' },
    zh_Hans = { 'zh_CN', 'zh_TW', 'en_US', 'Default' },
    zh_Hant = { 'zh_TW', 'zh_CN', 'en_US', 'Default' },
    Default = {},
}
local default_fallback = { 'en_US', 'Default' }

local function add_localization(localization_category, package_name, raw_data)
    localization_category.package_map[package_name] = raw_data or {}
    local id_count = 0
    for k, v in pairs(raw_data) do
        id_count = id_count + 1
    end
    if package_name == current_map then
        localization_category.package_order[1] = package_name -- 主地图优先
        log.info('加载主地图', package_name, '本地化文件', localization_category.file, ' 总Id数：', id_count)
    else
        table.insert(localization_category.package_order, 2, package_name) -- 后加载优先
        log.info('加载依赖库', package_name, '本地化文件', localization_category.file, ' 总Id数：', id_count)
    end
end

local function get_localization(localization_category, id, lang, package_name)
    -- 解析id: @package_name.real_id
    id = tostring(id)
    local real_pkg, real_id = id:match('@([^%.]+)%.(.+)')
    if real_pkg and real_id then
        package_name = real_pkg
    end
    lang = lang or current_lang
    local arg_lang = lang

    -- 有包名则只找此包名
    local package_order = package_name and { package_name } or localization_category.package_order
    for pi = 1, #package_order do
        local pkg_id_map = localization_category.package_map[package_order[pi]] or E
        local text = (pkg_id_map[real_id or id] or E)[lang]
        if text then
            -- log.debug(string.format('获取%s:%s %s %s "%s" from %s', localization_category.file, id, lang, package_name, text, package_order[pi]))
            return text, true
        end
    end
    local fallback_list = fallback_map[lang] or default_fallback
    for i = 1, #fallback_list do
        lang = fallback_list[i]
        for pi = 1, #package_order do
            local pkg_id_map = localization_category.package_map[package_order[pi]] or E
            local text = (pkg_id_map[real_id or id] or E)[lang]
            if text then
                -- log.debug(string.format('获取%s:%s %s %s "%s" from %s', localization_category.file, id, lang, package_name, text, package_order[pi]))
                return text, true
            end
        end
    end
    -- log.debug(string.format('获取%s失败:%s %s %s', localization_category.file, id, arg_lang, package_name))
    return id -- 返回id还是real_id?
end

base.i18n = {}

---@deprecated replaced by load_map
function base.i18n.load(raw, package_name)
    return add_localization(localizations.text, package_name, raw)
end

function base.i18n.load_font(raw, package_name)
    return add_localization(localizations.font, package_name, raw)
end

function base.i18n.load_map(package_name)
    for category, localization_category in pairs(localizations) do
        local ok, raw_data = pcall(require, lua_file_format:format(package_name, localization_category.file))
        if ok then
            add_localization(localization_category, package_name, raw_data)
        end
    end
end

---comment
---@param id string
---@param lang string
---@param pkg_name string
---@return string text
---@return boolean? has_loc_string
function base.i18n.get_text(id, lang, pkg_name)
    return get_localization(localizations.text, id, lang, pkg_name)
end

---comment
---@param id any
---@param lang any
---@param pkg_name any
---@return string
function base.i18n.get_text_ex(id, lang, pkg_name)
    local result = base.i18n.get_text(id, lang, pkg_name)
    return result
end

-- !只用于c++
function base.i18n.get_font(id)
    return get_localization(localizations.font, id)
end

function base.i18n.get_lang()
    return current_lang
end

function base.i18n.get_fallback_map(lan)
    return fallback_map[lan] or default_fallback
end

function base.i18n.set_lang(lang)
    current_lang = lang
    base.game:event_notify('本地化-改变语言', current_lang)
end

if common.get_system_language then
    local _get_system_language = common.get_system_language
    common.get_system_language = function()
        local system_language = _get_system_language()
        local match_set = {}
        for _, language in ipairs(format_languages) do
            local i = 1
            while i <= #language and i <= #system_language do
                if language:sub(i, i) ~= system_language:sub(i, i) then
                    break
                end
                i = i + 1
            end
            if i - 1 == #system_language then
                return system_language
            end
            if i > 1 then
                match_set[#match_set + 1] = { language = language, count = i - 1 }
            end
        end
        if #match_set == 0 then
            return system_language
        end
        table.sort(match_set, function(a, b)
            return a.count > b.count
        end)
        return match_set[1].language     
    end
end

current_lang = base.settings:get_option('game_languages')
if not current_lang then
    current_lang = require '@base.base.argv'.get('lang')
    if not current_lang or current_lang == '' then
        if common.get_system_language then
            current_lang = common.get_system_language()
        end
        if not current_lang or current_lang == '' then
            current_lang = 'Default'
        end
    end
end
log.infof('设置语言:%s', current_lang)