local original_common_open_url = common.open_url
local component = require '@common.base.gui.component'
local template = component {
    base.ui.panel {
        z_index = 9999,
        show = false,
        static = false,
        color = "rgba(0, 0, 0, 0.85)",
        layout = {
            grow_height = 1,
            grow_width = 1,
        },
        bind = {
            show = 'show'
        },
        swallow_event = true,
        base.ui.label {
            layout = {
                grow_width = 260 / 300,
                margin = {
                    top = 1,
                    bottom = 1
                }
            },
            text = '',
            font = {
                color = 'rgba(255, 255, 255, 0.6)',
                size = 14,
                family = 'Regular',
            },
            bind = {
                text = 'text',
                font = {
                    size = 'text_size',
                    family = 'Regular'
                }
            }
        }
    },
    method = {
    }
}

local argv = require 'base.argv'

local function show()
    local panel = template:new()
    local reference_width, reference_height = base.ui.auto_scale.get_reference_resolution()
    local design_width = 780
    local design_height = 360
    if reference_width > reference_height then
        panel.bind.grow_width = 300 / design_width
    else
        panel.bind.grow_width = 300 / design_height
    end
    local height_scale = reference_height / design_height
    panel.bind.text_size = height_scale * 14
    panel.bind.show = true
    panel.bind.text = base.i18n.get_text("无法跳转到该链接")
    base.wait(1000, function()
        panel.bind.show = false
        panel:destroy()
    end)
end

local open_url = {}

base.next(function()
    local lobby = require 'base.lobby'
    --StateGame且非editor_server_debug
    if lobby.vm_name() == 'StateGame' and not argv.has("editor_server_debug") then
        log_file.info('vm_name:', lobby.vm_name())
        sce.s.score_init(sce.s.readonly_map, 51, {
            ok = function(score)
                open_url = {}
                for k, v in pairs(score) do
                    log_file.info('url:', k)
                    open_url[k] = true
                end
            end,
            error = function(err)
                log.error(('获取url白名单失败: %d'):format(err))
            end,
            timeout = function()
                log.error('获取url白名单超时')
            end
        })
    end
end)

common.open_url = function(url, ...)
    local lobby = require 'base.lobby'
    local whitelist_prefixes = {
        "mqqopensdkapi",
        "http://qm.qq.com/cgi-bin/",
        "https://qm.qq.com/q/"
    }
    local is_whitelisted = false
    for _, prefix in ipairs(whitelist_prefixes) do
        if string.find(url, prefix, 1, true) == 1 then
            is_whitelisted = true
            break
        end
    end
    log_file.info('open url', url)
    if (lobby.vm_name() ~= 'StateGame' or open_url[url] or is_whitelisted) then
        if string.find(url, 'start-game://', 1, true) == 1 then
            base.game:send_broadcast('switch_game',url)
        else
            original_common_open_url(url, ...)
        end
        return
    end
    log.error(('无法跳转到该链接:%s'):format(url))
    show()
end