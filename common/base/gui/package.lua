local component = require '@common.base.gui.component'
local module = {
    kGUID = {},
    kVersion = {},
    kPageNames = {},
}

local UI_LOAD_DIR = '/ui/script/gui/page/'
local UI_SAVE_DIR = '/ui/src/gui/page/'

module.gui_page_pkg = 'gui.page'

module.get_text = function()
    if not __gui_editor_loading then
        return nil
    end
    return function(str)
        return '@'..str..'@'
    end
end

function module.load_component(page_names, lib_env)
    for name, require_url in pairs(page_names) do
        local c = require(require_url, lib_env)
        local package_name = string.match(require_url, '@([^.]+)')
        if package_name == nil then
            if lib_env then
                package_name = lib_env.__lib_env_name
            else
                log.error('load_component 失败，传入参数不符合要求')
                goto CONTINUE
            end
        end
        c.package_name = package_name
        c.package_url = '@'..package_name..'.component'
        c:rename(name)
        c.require_url = require_url
        page_names[name] = c
    ::CONTINUE::
    end
    return page_names
end

function module.page_pkg(lib_env, pkg_info)
    if lib_env then
        for _, page_name in ipairs(pkg_info[module.kPageNames]) do
            local c = require('gui.page.'..page_name..'.component', lib_env)
            pkg_info[page_name] = c
            table.insert(pkg_info, c)
        end
        return pkg_info
    end
end

function module.require_template(lib_env, type_name)
    if lib_env then
        return require('gui.page.'..type_name..'.template', lib_env).template
    end
end

function module.page_template(o)
    local flatten_template = rawget(o, 'flatten_template')
    if flatten_template then
        -- 是由编辑器生成的模板
        local ctrl_templates = {}
        local parent_indices = {}
        for i = 1, #flatten_template, 2 do
            table.insert(ctrl_templates, flatten_template[i])
            table.insert(parent_indices, flatten_template[i+1])
        end
        for i, t in ipairs(ctrl_templates) do
            local parent_idx = parent_indices[i]
            if parent_idx == 0 then
                goto CONTINUE
            end
            table.insert(ctrl_templates[parent_idx], t)
        ::CONTINUE::
        end
        template = ctrl_templates[1]
        rawset(o, 'template', template)
    end
    return o
end

return module