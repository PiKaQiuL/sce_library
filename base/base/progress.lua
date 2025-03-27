local appui = require 'baseui.appui'

local progress = base.ui.panel {
    name = 'loading_progress',
    static = true,
    layout = { grow_width = 1, grow_height = 1 },
    z_index = 15,
    show = false,
    bind = { show = 'show' },
    appui.ui.loading_icon {
        static = true,
        bind = { show = 'loading_icon_show' },
    },
    base.ui.panel {
        static = true,
        layout = { grow_width = 1, direction = 'col', col_self = 'end' },
        draw_level = 15,
        base.ui.label {
            static = true,
            layout = { grow_width = 1, margin = 10 },
            draw_level = 15,
            font = { align = 'start', family = 'Update', },
            bind = {
                text = 'status',
                font = {
                    size = 'font_size',
                    color = 'font_color',
                }
            }
        },
        base.ui.panel {
            layout = { grow_width = 1 },
            appui.ui.slider {
                static = true,
                draw_level = 15,
                show_handle_bar = false,
                range = { 0, 1 },
                bind = { value = 'progress' },
            },
            base.ui.panel {
                layout = { grow_width = 1, grow_height = 1 },
            }
        }
    }
}

local ui, bind = base.ui.create(progress, '__loading_progress')

local function set_theme()
    local theme = appui.theme.get_current_theme()
    bind.font_size = theme.font_size_regular
    bind.font_color = theme.font_color_secondary
end

set_theme()
appui.theme.on_theme_change(function()
    set_theme()
end)


---@class ProgressBind
local ProgressBind = class 'ProgressBind'
function ProgressBind:ctor()
    self.bind = bind
end

function ProgressBind:display()
    -- to be override
end

function ProgressBind:set_status(params)
    -- to be override
end

function ProgressBind:reset()
    -- to be override
end

function ProgressBind:show(show, reason)
    -- to be override
end

---@class DefaultProgressBind: ProgressBind
local DefaultProgressBind = class('DefaultProgressBind', ProgressBind)
function DefaultProgressBind:ctor()
    ProgressBind.ctor(self)

    self:reset()
end

function ProgressBind:show(show, reason)
    if show then
        log.info('progress_show show, reason:'..reason)
        self.bind.status = '正在更新'
        self.bind.progress = 0
    else
        log.info('progress_show hide, reason:'..reason)
    end
    self.bind.show = show
end

function DefaultProgressBind:reset()
    self._now_downloaded = 0
    self._total_size = 0
    self._now_speed = 0
    self._installed_count = 0
    self._to_install_count = 0
    self._installed_size = 0
    self._to_install_size = 0
    self._progress_bytes = 0
    self._total_bytes = 0
end

function DefaultProgressBind:set_status(params)
    self._now_downloaded = params.now_downloaded or self._now_downloaded
    self._total_size = params.total_size or self._total_size
    self._now_speed = params.now_speed or self._now_speed
    self._installed_count = params.installed_count or self._installed_count
    self._to_install_count = params.to_install_count or self._to_install_count
    self._installed_size = params.installed_size or self._installed_size
    self._to_install_size = params.to_install_size or self._to_install_size
    self._progress_bytes = params.progress_bytes or self._progress_bytes
    self._total_bytes = params.total_bytes or self._total_bytes
    self:display()
end

function DefaultProgressBind:display()
    if self._total_size == 0 and self._to_install_count == 0 then
        self.bind.status = '准备下载'
        self.bind.progress = 0
        return
    end

    if self._now_downloaded >= self._total_size then
        self.bind.status = ('               安装进度: %.2f MB / %.2f MB'):format(
            1.0*self._installed_size / 1024 / 1024,
            1.0*self._to_install_size / 1024 / 1024
        )
    else
        self.bind.status = ('更新中: %.2f MB / %.2f MB, 下载速度: %.2f KB/s, 安装进度: %.2f MB / %.2f MB'):format(
            1.0 * self._now_downloaded / 1024 / 1024,
            1.0*self._total_size / 1024 / 1024,
            1.0*self._now_speed / 1024,
            1.0*self._installed_size / 1024 / 1024,
            1.0*self._to_install_size / 1024 / 1024
        )
    end

    if self._to_install_count ~= 0 and self._total_bytes ~= 0 then
        self.bind.progress = self._progress_bytes / self._total_bytes
    else
        self.bind.progress = 0
    end
end

return {
    ProgressBind = ProgressBind,
    DefaultProgressBind = DefaultProgressBind,
}