local round_corner = base.ui.component('appui_basic_round_corner')

function round_corner:define()
    self.props = {
        radius = {
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

                self.bind.border = { top, bottom, left, right }
                self.bind.mask_image = self:get_mask_image(math.max(top, bottom, left, right))
            end
        },
        color = {
            setter = function(value)
                self.bind.color = value
            end
        },
        image = {
            setter = function(value)
                self.bind.image = value
            end
        },
        show = {
            setter = function(value)
                self.bind.show = value
            end
        },
        opacity = {
            setter = function(value)
                self.bind.opacity = value
            end
        }
    }

    self.template = base.ui.panel {
        layout = { padding = self.bind.padding },
        show = self.bind.show,
        color = self.bind.color,
        image = self.bind.image,
        border = self.bind.border,
        opacity = self.bind.opacity,
        mask_image = self.bind.mask_image,

        table.unpack(self.children)
    }
end

function round_corner:get_mask_image(radius)
    radius = radius and radius or 0
    local mask_radius = { 1, 2, 4, 8, 16 }
    for i = 1, #mask_radius do
        if radius <= mask_radius[i] then
            return ('image/basic/radius_%d.png'):format(mask_radius[i])
        end
    end
    return 'image/basic/radius_16.png'
end

return round_corner