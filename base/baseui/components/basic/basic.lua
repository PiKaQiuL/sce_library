-- 提供一些公共方法
---@class appui_basic
local basic = base.ui.component('appui_basic')

local current_index = 100
function basic.get_z_index()
    current_index = current_index + 1
    return current_index
end

local event_prop = {
    default = function(e) end,
    setter = function(value, old, default, raw_set)
        if not value then
            raw_set(default)
        end
    end
}
function basic:event_prop()
    return event_prop
end

function basic:proxy_prop(prop_name, default)
    return {
        default = default,
        setter = function(value)
            self.bind[prop_name] = value
        end
    }
end

function basic:safe_next(callback)
    base.next(function()
        if self.ui then
            callback()
        end
    end)
end

---找此ui所属的root节点
function basic:get_root_ui()
    local root = self.ui

    local get_ui_root = base.ui.get_ui_root
    if get_ui_root then
        local root = get_ui_root(root.id)
        if root then
            return root
        end
    end

    while root and root.parent do
        root = root.parent
    end

    if get_ui_root then
        local root = get_ui_root(root.id)
        if root then
            return root
        end
    end

    return root
end

function basic:after_define()
    -- 减少调用c++
    self.change_bind = setmetatable({}, {
        __index = function(_, k)
            return setmetatable({}, {
                __newindex = function(_, idx1, v)
                    if self.bind[k][idx1] ~= v then
                        self.bind[k][idx1] = v
                    end
                end,
            })
        end,
        __newindex = function(_, k, v)
            if self.bind[k] ~= v then
                self.bind[k] = v
            end
        end
    })
end

return basic