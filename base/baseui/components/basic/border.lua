local border = base.ui.component('appui_basic_border')

function border:define()
    self.props = {
        border_width = {
            default = 0,
            setter = function(value)
                self.bind.padding = value
                self.props.border_radius = self.props.border_radius
                self:check_no_border()
            end
        },
        border_color = {
            setter = function(value)
                self.bind.outer_color = value
                self:check_no_border()
            end
        },
        border_radius = {
            default = 0,
            setter = function(value)
                local top, bottom, left, right = 0, 0, 0, 0
                if type(value) == 'table' then
                    top = value.top or top
                    bottom = value.bottom or bottom
                    left = value.left or left
                    right = value.right or right
                elseif type(value) == 'number' then
                    top = value
                    bottom = value
                    left = value
                    right = value
                end

                local width = self.props.border_width
                self.bind.inner_border = { top - width, bottom - width, left - width, right - width }
                self.bind.outer_border = { top, bottom, left, right }
                self.bind.inner_mask_image = self:get_mask_image(math.max(top, bottom, left, right) - width)
                self.bind.outer_mask_image = self:get_mask_image(math.max(top, bottom, left, right))
                self:check_no_border()
            end
        },
        color = {
            setter = function(value)
                self.bind.inner_color = value
            end
        },
        image = {
            setter = function(value)
                self.bind.inner_image = value
            end
        },
        show = {
            setter = function(value)
                self.bind.show = value
            end
        },
        static = {
            setter = function(value)
                self.bind.static = value
            end
        },
    }

    self.template = base.ui.panel {
        layout = { padding = self.bind.padding },
        show = self.bind.show,
        static = self.bind.static,
        color = self.bind.outer_color,
        border = self.bind.outer_border,
        mask_image = self.bind.outer_mask_image,

        base.ui.panel {
            static = self.bind.static,
            layout = { grow_width = 1, grow_height = 1 },
            color = self.bind.inner_color,
            image = self.bind.inner_image,
            border = self.bind.inner_border,
            mask_image = self.bind.inner_mask_image,
        },
        self.children[1],
    }
end

function border:get_mask_image(radius)
    radius = radius and radius or 0
    local mask_radius = { 1, 2, 4, 8, 16 }
    for i = 1, #mask_radius do
        if radius <= mask_radius[i] then
            return ('image/basic/radius_%d.png'):format(mask_radius[i])
        end
    end
    return 'image/basic/radius_16.png'
end

function border:check_no_border()
    -- 边缘是透明的，需要隐藏
    if self.props.border_width <= 0 then
        self.bind.outer_mask_image = nil
        self.bind.outer_color = 'rgba(0,0,0,0)'
    end
end

return border
