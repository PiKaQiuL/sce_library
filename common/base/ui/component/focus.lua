local BaseComponent = include 'base.ui.component.base'

---提供 on_focus 和 on_focus_lose 方法供子类重写, 其根ui的on_mouse_down被用来响应focus事件, 所以继承此类时根ui不要用on_mouse_down
local FocusComponent = class('focus_component', BaseComponent)

---overrider
function FocusComponent:after_define()
    local template = self.template
    if not template.event then
        template.event = {}
    end

    local focused = false
    local on_clicked = false
    template.event.on_mouse_down = function()
        on_clicked = true
    end
    local trigger = base.game:event('鼠标-松开', function(trg, button)
        base.next(function()
            if on_clicked then
                -- 说明点在此ui上
                if not focused then
                    self:on_focus()
                end
                on_clicked = false
                focused = true
            else
                -- 说明点在了其他ui上
                if focused then
                    self:on_focus_lose()
                end
                focused = false
            end
        end)
    end)
    self:auto_remove(trigger)
end

function FocusComponent:on_focus() end
function FocusComponent:on_focus_lose() end

return FocusComponent