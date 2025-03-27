local round_corner = require 'baseui.components.basic.round_corner'

local loading_icon = base.ui.component('appui_basic_loading_icon')

function loading_icon:define()
    self.props = {
        show = {
            default = true,
            setter = function(value)
                self.bind.show = value
            end,
        },
        size = {
            default = 'large',
            setter = function(value)
                if value == 'equipment' then
                    self.bind.normal_show = false
                    self.bind.sp_show = true
                    self.bind.image = 'image/loading_white_mini.png'
                elseif value == 'black' then
                    self.bind.normal_show = true
                    self.bind.sp_show = false
                    self.bind.image = 'image/loading_black_mini.png'
                else
                    self.bind.normal_show = true
                    self.bind.sp_show = false
                    if value == 'mini' then
                        self.bind.image = 'image/loading_mini.png'
                    else
                        self.bind.image = 'image/loading.png'
                    end
                end
            end,
        },
        text = {
            default = '加载中',
            setter = function(value)
                self.bind.text = value
            end,
        }
    }
    self.template = round_corner {
        layout = { width = 64, height = 64 },
        radius = 4,
        show = self.bind.show,
        base.ui.sprites {
            layout = { grow_width = 1, grow_height = 1 },
            image = self.bind.image,
            frame_count = 90,
            row_frame_count = 16,
            start_frame = 1,
            end_frame = 90,
            interval = 33,
            sprite_size = { 64, 64 },
            loop = true,
            playing = true,
            show = self.bind.normal_show,
        },
        base.ui.panel {
            show = self.bind.sp_show,
            image = 'image/toast.png',
            layout = { 
                direction = 'row',
            },
            base.ui.sprites {
                layout = { 
                    width = 14, 
                    height = 14,
                    margin = {right = 6},
                },
                image = self.bind.image,
                frame_count = 90,
                row_frame_count = 16,
                start_frame = 1,
                end_frame = 90,
                interval = 33,
                sprite_size = { 64, 64 },
                loop = true,
                playing = true
            },
            base.ui.label {
                text = self.bind.text,
                font = {
                    size = 12,
                    color = '#ffffff',
                },
            },
        },
    }
end

return loading_icon