
local watch = base.ui.watch
local view = base.ui.view

return function (template, bind)
    local ui = view {
        type = 'webview',
        name = template.name,
        id = template.id
    }

    watch(ui, template, bind, 'url')
    watch(ui, template, bind, 'html')
    watch(ui, template, bind, 'run_js')
    watch(ui, template, bind, 'web_message')
    watch(ui, template, bind, 'web_type')
    watch(ui, template, bind, 'web_dev_tools')

    return ui
end
