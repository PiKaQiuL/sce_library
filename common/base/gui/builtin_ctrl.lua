local component = require '@common.base.gui.component'
local new = component.new
local bind = component.bind
local bibind = component.bibind
local alias = component.alias
local slot = component.slot
local array = component.array
local util = require '@common.base.gui.control_util'
local set_ctrl_prop = util.set_ctrl_prop
local get_ctrl_prop = util.get_ctrl_prop
local move_to_new_parent = util.move_to_new_parent
local is_component_ctrl = util.is_component_ctrl
local t = require '@common.base.gui.typed'

local cxx_set_layout_prop = t.getset {
    get = function()
        -- body
    end,
    set = function()
        -- body
    end,
}

local Layout = t.typed {
    --owner = ,
    width = cxx_set_layout_prop,
    height = cxx_set_layout_prop,
}

local panel = component 'SCE::panel' {
    base.ui.panel {
    },
    prop = {
        layout = Layout {

        }
    },
    method = {
        init = function()
            
        end,
    },
    event = {
        -- on_click = ,
    },
}
-- .layout = {}, .layout.pos = {} 当被修改后触发c++修改事件