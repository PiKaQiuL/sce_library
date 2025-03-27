
local lobby=require '@base.base.lobby'
local argv = require 'base.argv'
local co = include 'base.co' 

lobby.app_lua.play_custom_ad = function(cb) 
    local component = require '@common.base.gui.component'
    local template = component {
        base.ui.panel {
            layout = {
                grow_width = 1,
                grow_height = 1,
            },
            swallow_event = true,
            color = 'rgba(0, 0, 0, 0.7)',
            base.ui.panel {
                layout = {
                    grow_width = 0.8,
                    grow_height = 0.8,
                    direction = 'col',
                },
                round_corner_radius = 8,
                static = false,
                color = '#2A2D3C',
                base.ui.panel{
                    layout = {
                        grow_width = 1,
                        height = 24 * 1.5,
                    },
                    base.ui.label {
                        z_index = 99999,
                        layout = {
                            width = 24 * 1.5,
                            height = 24 * 1.5,
                            margin = 4,
                            row_self = 'start',
                            col_self = 'start',
                        },
                        bind = {
                            text = 'remain_secs'
                        },
                    },
                    base.ui.label {
                        text = '跳过',
                        layout = { 
                            row_self = 'end',
                            width = 24 * 1.5,
                            height = 24 * 1.5,
                            margin = 5 
                        },
                        show = false,
                        --image = 'image/close.png',
                        bind = {
                            show = 'show_skip',
                            event = {
                                on_click = 'click_close',
                            },
                        },
                    },

                },
                base.ui.webview {
                    layout = {
                        grow_width = 1,
                        grow_height = 1,
                    },
                    bind = {
                        url = 'url',
                        html = 'html',
                        event = {
                            on_web_message = 'on_web_message',
                        }
                    }
                },

                base.ui.panel {
                    layout = {
                        grow_width = 1,
                        height = 24 * 1.5,
                    },
                    base.ui.label {
                        layout = { 
                            row_self = 'end',
                            margin = 5 
                        },
                        text = '游戏详情>>',
                        bind = {
                            event = {
                                on_click = 'on_open_detail'
                            }
                        }
                    }
                }

            }
        }
    }

    local ui = template:new()

    local jump_link = {
        promotion2 = 'https://www.taptap.cn/craft/29',
        endlesscorridors = 'https://www.taptap.cn/craft/25',
        demo_s18a = 'https://www.taptap.cn/craft/37',
    }

    local filtered = {}
    for k, v in pairs(jump_link) do
        log_file.info(k, v)
        if k ~= argv.get('game') then
            log_file.info('add', k, v)
            filtered[#filtered + 1] = {
                name = k,
                link = v
            }
        end
    end
    local t = os.time()
    local h = #filtered
    local idx = (t%h) + 1
    log_file.info(t, h, idx)
    local ad_source = filtered[idx]
    ui.bind.html = '<video autoplay width="100%" height="100%"  webkit-playsinline playsinline controlsList="noplaybackrate nodownload nofullscreen noremoteplayback" disablePictureInPicture="true" muted style="object-fit:fill"> <source src="https://custom-ad.spark.xd.com/MP4/'..ad_source.name .. '.mp4" type="video/mp4"/>'
    --ui.bind.html = '<button type="button">click</button> <script> document.querySelector("button").addEventListener("click",()=>{ window.scelua.send_string("hello scelua")})</script>'
    local closed = false 
    local time_secs = 60

    ui.bind.on_open_detail = function() 
        common.open_url(ad_source.link)
    end
    ui.bind.click_close = function() 
        closed = true
        ui:destroy()
        cb({result = true, msg = 'skip', is_custom=true})
    end
    ui.bind.remain_secs = time_secs
    co.async(function()
        while time_secs > 0 do
            co.sleep(1000)
            time_secs = time_secs - 1
            ui.bind.remain_secs = time_secs

            if time_secs <= 30 then
                ui.bind.show_skip = true
            end
        end
        if not closed then
            ui:destroy()
            cb({result=true, msg='finish', is_custom=true})
        end
    end)
end

return lobby