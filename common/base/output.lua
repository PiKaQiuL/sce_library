
local output = base.ui.panel {
    base.ui.label {
        font = { 
            color = '#00FF00', 
            size = 14, 
            family = 'Microsoft Yahei',
            align = 'left',
            vertical_align = 'top'
        },
        layout = {
            grow_width = 1,
            height = -1,
            col_self = 'start',
            row_self = 'start'
        },

        bind = {
            text = 'text'
        }
    },
    color = '#333333',
    layout = {
        grow_width = 1,
        grow_height = 1
    },
    bind = {
        scroll = 'scroll'
    },
    enable_scroll = true
}

local ui, bind = base.ui.create(output, '____output')

local text = ''
local function info(t)
    text = text .. '\r\n' .. t
    bind.text = text
    bind.scroll = 1
end

local function error(t)
    info('<#FF0000:' .. t .. ':>')
end

return {
    info = info,
    error = error
}
