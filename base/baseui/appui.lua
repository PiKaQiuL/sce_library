local require = require
---@class appui
local appui = {
    theme = require 'baseui.theme.themes',
    ui={
        loading_icon = require 'baseui.components.basic.loading_icon',
        slider = require 'baseui.components.form.slider.slider',
    }

}

return appui
