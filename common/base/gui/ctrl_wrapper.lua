-- 临时供ui编辑器使用
local component = require '@common.base.gui.component'
local bind = require '@common.base.gui.component'.bind
local control_util = require '@common.base.gui.control_util'
local move_to_new_parent = control_util.move_to_new_parent
local getset = component.getset
local function update_ui_static(ctrl, props)
    if not props then
        return
    end
    local ui = props
    if ui.static == nil and ui.enable == nil and ui.enable_scroll == nil and ui.type ~= 'viewport' and
        ui.enable_drag == nil and ui.enable_drop == nil
    then
        if not ui.event then
            return
        end
    end
    if ui.static == nil then
        ctrl.ui.static = nil
    end
end

local function create_array_component(array, template)
    local t, success, libs_components
    if string.find(template, '$$.') == 1 then
        success, libs_components = xpcall(require, function(err)
            log_file.info(string.format("引用依赖库组件失败：%s", err))
        end, "@@.gui.libs_components")
        if (success and libs_components and libs_components[template]) then
            if libs_components[template].is_page then
                success, t = xpcall(require, function(err)
                    log_file.info(string.format("引用ui页面失败：%s", err))
                end, libs_components[template].url)
            end
        end
    else
        success, t = xpcall(require, function(err)
            log_file.info(string.format("引用ui页面失败：%s", err))
        end, "@@.gui.page." .. template .. ".component")
    end

    return component 'CtrlArray' {
        base.ui.panel {
            layout = {
                width = bind.width,
                height = bind.height,
                direction = bind.direction,
                row_content = bind.row_content,
                col_content = bind.col_content,
                padding = bind.padding,
                grow_width = bind.grow_width,
                grow_height = bind.grow_height,
            },
            name = '__ctrl_array_container',
            array = bind.array,
            enable_scroll = bind.enable_scroll,
            scroll_direction = bind.scroll_direction,
            scroll_image = bind.scroll_image,
            scroll_color = bind.scroll_color,
            scroll_width = bind.scroll_width,
            t { name = '__ctrl_array_item' },
        },
        prop = {
            array = array,
        },
        method = {
            init = function(self)
            end,
            update_props = function(self)
                local layout = control_util.get_ctrl_prop(self.parent, { 'layout' })
                if layout then
                    self.direction = layout.direction
                    self.row_content = layout.row_content
                    self.col_content = layout.col_content
                    self.padding = layout.padding
                    self.width = layout.width
                    self.height = layout.height
                    self.grow_width = layout.grow_width
                    self.grow_height = layout.grow_height
                end
                self.enable_scroll = control_util.get_ctrl_prop(self.parent, { 'enable_scroll' })
                if self.enable_scroll then
                    local scroll_direction = control_util.get_ctrl_prop(self.parent, { 'scroll_direction' })
                    local scroll_image = control_util.get_ctrl_prop(self.parent, { 'scroll_image' })
                    local scroll_color = control_util.get_ctrl_prop(self.parent, { 'scroll_color' })
                    local scroll_width = control_util.get_ctrl_prop(self.parent, { 'scroll_width' })
                    if scroll_direction then
                        self.scroll_direction = scroll_direction
                    end
                    if scroll_image then
                        self.scroll_image = scroll_image
                    end
                    if scroll_color then
                        self.scroll_color = scroll_color
                    end
                    if scroll_width then
                        self.scroll_width = scroll_width
                    end
                end
                --     self:mark_dirty(2)
                -- end,
                -- update = function(self)
                --     if self.dirty > 0 then
                --         self.dirty = self.dirty - 1
                --         self:update_layout()
                --     end
                -- end,
                -- mark_dirty = function(self, count)
                --     self.dirty = count
                -- end,
                -- update_layout = function(self)
                --     local _, _, w, h = self.parent:xywh()
                --     local parent_layout = self.parent.layout or {}
                --     if not w or self.width == w and self.height == h then
                --         return
                --     end
                --     print(parent_layout, parent_layout.width, parent_layout.height)
                --     self.width = parent_layout.width and parent_layout.width > 0 and w or -1
                --     self.height = parent_layout.height and parent_layout.height > 0 and h or -1
                --     control_util.get_child_ui_if(self.ui, function(ui)
                --         if ui ~= self.ui and ui.name == '__ctrl_array_container' then
                --             local ctrl = control_util.get_final_ext_component(ui)
                --             ctrl:mark_dirty(2)
                --         end
                --     end)
            end
        },
    }
end

return {
    panel = component {
        base.ui.panel {},
        method = {
            init = function(self, template)
                update_ui_static(self, template)
                local array = template.Array
                if array and array.enable and array.array > 0 then
                    self:create_array_component(array.array, array.template)
                end
                self.__on_prop_changed = function(_, prop_name, value)
                    local prop_name_str = ''
                    if type(prop_name) == 'string' then
                        prop_name_str = prop_name
                    elseif type(prop_name) == 'table' and type(prop_name[1]) == 'string' then
                        prop_name_str = prop_name[1]
                    end
                    if prop_name_str == 'layout' then
                        self:update_props()
                    elseif prop_name_str == 'Array' then
                        local a = control_util.get_ctrl_prop(self, { 'Array' })
                        if a.enable then
                            if self.data.array_component and self.data.array_template == a.template then
                                self.data.array_component.array = a.array
                            else
                                self:create_array_component(a.array, a.template)
                            end
                        elseif self.data.array_component then
                            self:destory_array_component()
                        end
                    elseif string.sub(prop_name_str, 1, 6) == 'scroll' then
                        if prop_name_str == 'scroll' and self.data.array_component then
                            self.data.array_component.scroll = value
                        else
                            self:update_props()
                        end
                    end
                end
            end,
            destory_array_component = function(self)
                if self.data.array_component then
                    self.data.array_component:destroy()
                    self.data.array_component = nil
                    self.data.array_array = nil
                    self.data.array_template = nil
                end
            end,
            create_array_component = function(self, array, template)
                self:destory_array_component()
                self.data.array_component = create_array_component(array, template):new({ name = '__ctrl_array' })
                self.data.array_array = array
                self.data.array_template = template
                move_to_new_parent(self.data.array_component, self)
                self:update_props()
            end,
            update_props = function(self)
                if not self.data.array_component then
                    return
                end
                self.data.array_component:update_props()
            end
        }
    },
    label = component {
        base.ui.label {},
        method = {
            init = update_ui_static
        }
    },
    button = component {
        base.ui.button {},
        method = {
            init = update_ui_static
        }
    },
    progress = component {
        base.ui.progress {},
        method = {
            init = update_ui_static
        }
    },
    sprites = component {
        base.ui.sprites {},
        method = {
            init = update_ui_static
        }
    },
    input = component {
        base.ui.input {},
        method = {
            init = update_ui_static
        }
    },
    minimap_canvas = component {
        base.ui.minimap_canvas {},
        method = {
            init = update_ui_static
        }
    },
    particle = component {
        base.ui.particle {},
        method = {
            init = update_ui_static
        }
    },
    video = component {
        base.ui.video { bind = { video_id = '_video_id' } },
        prop = {
            video_id = getset {
                get = function(self) return self.bind._video_id end,
                set = function(self, v) self.bind._video_id = v end,
            }
        },
        method = {
            init = update_ui_static
        }
    },
}
