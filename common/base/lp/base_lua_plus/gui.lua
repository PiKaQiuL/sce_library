--- lua_plus ---
local com = require '@common.base.gui.component'
local control_util = require'@common.base.gui.control_util'
local move_to_new_parent = control_util.move_to_new_parent
local get_child_ui_by_name = control_util.get_child_ui_by_name
local get_global_scale = require '@common.base.ui.auto_scale'.current_scale

function base.gui_new(name:string) $$.gui_ctrl.gui_ctrl
    ---@ui 创建一个~1~页面实例
    ---@description 新建页面实例
    ---@keyword 创建 页面
    ---@belong component
    ---@applicable value
    ---@name1 页面名
    if not(name) then
        return nil
    end
    local success, cmpt = xpcall(require, function(err) log.error(string.format("引用ui页面失败：%s", err)) end, "@@.gui.page."..name..".component")
    -- 先尝试创建本项目的页面
    if and(success, cmpt) then
        return cmpt:new()
    end
    return nil
end

function base.gui_new_component(name:string) $$.gui_ctrl.gui_ctrl
    ---@ui 创建一个~1~组件的实例
    ---@description 新建组件实例
    ---@keyword 创建 组件
    ---@belong component
    ---@applicable value
    ---@name1 组件类型名
    --尝试创建依赖库中的组件
    if not(name) then
        return nil
    end
    local success, libs_components = xpcall(require, function(err) log_file.info(string.format("引用依赖库组件失败：%s", err)) end, "@@.gui.libs_components")
    if and(success, libs_components, libs_components[name]) then
        if libs_components[name].is_page then
            local success, cmpt = xpcall(require, function(err) log_file.info(string.format("引用ui页面失败：%s", err)) end, libs_components[name].url)
            if and(success, cmpt) then
                return cmpt:new()
            end
        else
            return require(libs_components[name].url)[libs_components[name].com_name](libs_components[name].template):new()
        end
    end
    return nil
end

function base.gui_destory(cmpt:$$.gui_ctrl.gui_ctrl) boolean
    ---@ui 销毁控件实例~1~
    ---@description 销毁UI控件
    ---@keyword 销毁 控件
    ---@belong component
    ---@applicable both
    ---@name1 控件
    if component_check(cmpt) then
        com.destroy(cmpt)
        return true
    end
    return false
end

-- function base.gui_set_prop(cmpt:$$.gui_ctrl.gui_ctrl, prop:string, value)
--     ---@ui 设置控件~1~的属性~2~的值为~3~
--     ---@description 设置UI控件属性
--     ---@keyword 控件 属性
--     ---@belong component
--     ---@applicable action
--     ---@name1 控件
--     ---@name2 属性名
--     ---@name3 值
--     if component_check(cmpt) then
--         control_util.set_ctrl_prop(cmpt, prop, value)
--         return true
--     end
--     return false
-- end

--分割属性名称用
local function split(str)
    local ret = {}
    local pattern = "[^%.]+"
    for str in string.gmatch(str, pattern) do
        local num = tonumber(str)
        if num then
            table.insert(ret, num)
        else
            table.insert(ret, str)
        end
    end
    return ret
end

-- 界面中的设置控件属性实际会调用这个函数
function base.gui_set_prop(ctrl, prop_table)
    for prop_name, prop_value in pairs(prop_table) do
        if prop_name == 'Name' then
            prop_name = 'name'
        end
        local splited_name = split(prop_name)
        -- 类似relative这种属性设置的时候如果只设了一个值，那另一个会默认当作0。
        -- 触发里只能一个一个设置，所以这里要特判一下，这种属性要先把旧的值拿出来
        if splited_name[1] == 'layout' then
            if splited_name[2] == 'relative' then
                local old_relative = control_util.get_ctrl_prop(ctrl, {'layout', 'relative'})
                if type(old_relative) ~= 'table' then
                    old_relative = {}
                end
                old_relative[splited_name[3]] = prop_value
                prop_value = {old_relative[1], old_relative[2]}
                splited_name[3] = nil
            elseif splited_name[2] == 'position' then
                local old_position = control_util.get_ctrl_prop(ctrl, {'layout', 'position'})
                if type(old_position) ~= 'table' then
                    old_position = {}
                end
                old_position[splited_name[3]] = prop_value
                prop_value = {old_position[1], old_position[2]}
                splited_name[3] = nil
            end
        end
        control_util.set_ctrl_prop(ctrl, splited_name, prop_value)
    end
    return nil
end

function base.gui_set_prop2(ctrl, prop_name, prop_value)
    return control_util.set_ctrl_prop(ctrl, prop_name, prop_value)
end

function base.gui_get_prop(ctrl, prop_name)
    if prop_name == 'Name' then
        prop_name = 'name'
    end
    local splited_name = split(prop_name)
    return control_util.get_ctrl_prop(ctrl, splited_name)
end

function base.gui_get_part(cmpt:$$.gui_ctrl.gui_ctrl, part_name:string) $$.gui_ctrl.gui_ctrl
    if component_check(cmpt) then
        local p = cmpt.part[part_name]
        if type(p) == 'table' then
            return p[1]
        end
        return nil
    end
    return nil
end

function base.gui_get_child_ui_by_name(cmpt:$$.gui_ctrl.gui_ctrl, child_name:string) $$.gui_ctrl.gui_ctrl
    if component_check(cmpt) then
        return get_child_ui_by_name(cmpt, child_name)
    end
    return nil
end

function base.gui_get_main_page() $$.gui_ctrl.gui_ctrl
    ---@ui 获取主页面控件实例
    ---@description 获取主页面控件实例
    ---@keyword 控件 页面 主页面
    ---@belong component
    ---@applicable value
    return _G.__main_page
end

function base.gui_move_to_new_parent(source, target)
    ---@ui 移动控件~1~到新的父控件~2~
    ---@description 移动控件到新的父控件
    ---@keyword 控件 界面 主页面 移动
    ---@belong component
    ---@applicable action
    ---@name1 被移动控件
    ---@name2 新的父控件
    move_to_new_parent(source, target)
end

function base.gui_get_mouse_pos_x() integer
    ---@ui 鼠标在UI坐标系上的坐标X
    ---@description 鼠标在UI坐标系上的坐标X
    ---@keyword 控件 鼠标
    ---@belong component
    ---@applicable value
    local x, y = common.get_mouse_screen_pos()
    return math.floor(x / get_global_scale() + 0.5)
end
function base.gui_get_mouse_pos_y() integer
    ---@ui 鼠标在UI坐标系上的坐标Y
    ---@description 鼠标在UI坐标系上的坐标Y
    ---@keyword 控件 鼠标
    ---@belong component
    ---@applicable value
    local x, y = common.get_mouse_screen_pos()
    return math.floor(y / get_global_scale() + 0.5)
end

function base.gameui_attachable_panel_attach_to(cmpt:$$.gui_ctrl.gui_ctrl, target:unit)
    ---@ui 设置~1~的附着单位为~2~
    ---@description 设置可附着面板的附着单位
    ---@keyword 可附着面板 控件
    ---@belong component
    ---@applicable action
    ---@name1 可附着面板
    ---@name2 单位
    cmpt._attach_unit = target
end

function base.gamechatclient_send_message(text:string, user:string)
    ---@ui 输出聊天信息~1~，发送人用户名为~2~
    ---@description 输出信息到聊天窗口
    ---@keyword 局内聊天 发送信息
    ---@belong component
    ---@applicable action
    
    base.game:server 'gamechatclient_send_message' {user = user, text = text}
end