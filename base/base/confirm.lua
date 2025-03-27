local co = include 'base.co'
local design_width = 780
local design_height = 360

local confirm_ui = base.ui.panel {
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
    base.ui.panel {
        layout = {
            -- 宽度固定比例，高度自适应
            grow_width = 300 / design_width,
        },
        bind = {
            layout = {
                grow_width = 'grow_width'
            }
        },
        swallow_event = true,
        base.ui.panel {
            layout = {
                grow_width = 1,
                grow_height = 1
            },
            color = '#2a2d3c',
            round_corner_radius = 8 * base.ui.auto_scale.current_scale()
        },
        base.ui.panel{
            layout = {
                grow_width = 1,
                direction = 'col',
            },
            -- 标题
            base.ui.panel{
                layout = {
                    grow_width = 1,
                    height = 50,
                },
                bind = {
                    layout = {
                        height = 'title_height'
                    }
                },
                base.ui.label{
                    layout = {
                        grow_width = 1,
                        grow_height = 1,
                    },
                    text = base.i18n.get_text('提示'),
                    font = {
                        color = 'rgba(255, 255, 255, 0.8)',
                        bold = 1,
                        size = 16,
                        family = 'Update',
                    },
                    bind = {
                        text = 'title_text',
                        font = {
                            size = 'title_size',
                            family = 'family'
                        }
                    },
                },
            },
            -- 文本
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
                    family = 'Update',
                },
                bind = {
                    text = 'text',
                    font = {
                        size = 'text_size',
                        family = 'family'
                    }
                }
            },
            --按钮
            base.ui.panel{
                layout = {
                    height = 80,
                    grow_width = 1,
                    direction = 'row',
                },
                bind = {
                    layout = {
                        height = 'button_height'
                    }
                },
                --带确定按钮的弹窗
                base.ui.panel{
                    show = false,
                    layout = {
                        grow_height = 1,
                        grow_width = 260/300,
                    },
                    bind = {
                        show = 'confirm_show',
                    },
                    base.ui.panel{
                        layout = {
                            grow_height = 1,
                            grow_width = 122/260,
                            row_self = 'start'
                        },
                        base.ui.button{
                            layout = {
                                grow_width = 1,
                                grow_height = 0.5,
                            },
                            color = '#FFFFFF',
                            round_corner_radius = 8 * base.ui.auto_scale.current_scale(),
                            bind = {
                                event = {
                                    on_click = 'on_cancel'
                                }
                            },
                            base.ui.panel {
                                layout = {
                                    grow_width = 1,
                                    grow_height = 1,
                                    margin = 2
                                },
                                color = '#2A2D3C',
                                round_corner_radius = 8 * base.ui.auto_scale.current_scale(),
                            },
                            base.ui.label {
                                layout = {
                                    grow_height = 1,
                                    grow_width = 1,
                                    margin = {
                                        top = 5
                                    }
                                },
                                text = base.i18n.get_text('取消'),
                                font = {
                                    color = 'rgba(255, 255, 255, 0.8)',
                                    bold = 1,
                                    family = 'Update',
                                },
                                bind = {
                                    text = 'cancel_text',
                                    font = {
                                        size = 'cancel_size',
                                        family = 'family'
                                    }
                                }
                            },
                        },
                    },
                    base.ui.panel{
                        layout = {
                            grow_height = 1,
                            grow_width = 122/260,
                            row_self = 'end'
                        },
                        base.ui.button{
                            layout = {
                                grow_width = 1,
                                grow_height = 0.5,
                            },
                            color = '#F64C4C',
                            round_corner_radius = 8 * base.ui.auto_scale.current_scale(),
                            bind = {
                                color = 'confirm_color',
                                event = {
                                    on_click = 'on_ok'
                                },
                            },
                            base.ui.label {
                                layout = {
                                    grow_height = 1,
                                    grow_width = 1,
                                    margin = {
                                        top = 5
                                    }
                                },
                                text = base.i18n.get_text('确定'),
                                font = {
                                    color = '#FFFFFF',
                                    bold = 1,
                                    family = 'Update',
                                },
                                bind = {
                                    text = 'ok_text',
                                    font = {
                                        size = 'confirm_size',
                                        family = 'family'
                                    }
                                }
                            },
                        },
                    },
                },

                --消息弹窗
                base.ui.panel{
                    show = false,
                    layout = {
                        grow_height = 1,
                        grow_width = 1,
                        direction = 'row',
                    },
                    bind = {
                        show = 'message_show',
                    },
                    base.ui.button{
                        layout = {
                            grow_width = 260 / 300,
                            grow_height = 40 / 80,
                        },
                        image = 'image/知道了.png',
                        bind = {
                            event = {
                                on_click = 'message_confirm_click'
                            },
                        },
                         base.ui.label {
                             layout = {
                                 grow_height = 1,
                                 grow_width = 1,
                                 margin = {
                                     top = 5
                                 }
                             },
                             text = base.i18n.get_text('知道了'),
                             font = {
                                 size = 14,
                                 color = '#FFFFFF',
                                 bold = 1,
                                 family = 'Update',
                                 shadow = {
                                     color = 'rgba(0, 0, 0, 0.4)',
                                     offset = {0,1}
                                 }
                             },
                             bind = {
                                 text = 'message_text',
                                 font = {
                                     size = 'message_confirm_size',
                                     family = 'family'
                                 }
                             }
                         },
                    },

                },
            },
        },
    }
}

local ui, bind = base.ui.create(confirm_ui, 'confirm')

local title_set_size = nil
local text_set_size = nil
local confim_set_size = nil
local cancel_set_size = nil


local function resize()
    local reference_width, reference_height = base.ui.auto_scale.get_reference_resolution()
    if reference_width > reference_height then
        bind.grow_width = 300 / design_width
    else
        bind.grow_width = 300 / design_height
    end
    local height_scale = reference_height / design_height
    bind.title_height = height_scale * 50
    bind.button_height = height_scale * 80
    bind.title_size = height_scale * 16
    bind.text_size = height_scale * 14
    bind.cancel_size = height_scale * 14
    bind.confirm_size = height_scale * 14
    bind.message_confirm_size = height_scale * 14
end

base.game:event('画面-分辨率变化', function(_, width, height)
    resize()
end)

base.game:event('画面-分辨率缩放变化', function(_, scale)
    resize()
end)

-- 确认
local function confirm(text,confirm_text)
    local show_confirm = function(callback)
        bind.show = true
        bind.confirm_show = true
        bind.message_show = false

        bind.text = text
        bind.on_ok = function()
            bind.show = false
            callback(true)
        end
        bind.on_cancel = function()
            bind.show = false
            callback(false)
        end
        bind.ok_text = confirm_text or base.i18n.get_text('确定')
        bind.cancel_text = base.i18n.get_text('取消')

        --特殊处理一下
        if confirm_text == base.i18n.get_text('退出') then
            bind.confirm_color = '#F64C4C'
        else
            bind.confirm_color = '#948EFF'
        end
        resize()
    end

    local co_show_confirm = co.wrap(show_confirm)
    return co_show_confirm()
end

-- 提示
local function message(text)
    local show_message = function(callback)
        bind.show = true
        bind.confirm_show = false
        bind.message_show = true
        bind.message_button_show = true
        bind.text = text
        bind.message_text = base.i18n.get_text('知道了')
        bind.message_confirm_click = function()
            bind.show = false
            callback(true)
        end
        resize()
    end

    local co_show_message = co.wrap(show_message)
    return co_show_message()
end

local function show(text)
    --bind.family = 'Regular'  -- 尝试从更新字体换成常规字体(如果没找到会继续用原字体)
    resize()
    bind.show = true
    bind.confirm_show = false
    bind.message_show = true
    bind.text = text
    bind.message_button_show = false
end

local function hide()
    bind.show = false
end

local function set_title(text)
    --bind.family = 'Regular'
    bind.title_text = text
end

local function set_font_family(family)
    bind.family = family
end

local function set_message_button_text(text)
    bind.message_text = text
end

local function is_show()
    return bind.show
end

local function set_title_style(style)
    if style.size then 
        bind.title_size = style.size 
        title_set_size = style.size 
    end
    if style.color then bind.title_color = style.color end    
end

local function set_text_style(style)
    if style.size then 
        bind.text_size = style.size 
        text_set_size = style.size 
    end
    if style.color then bind.text_color = style.color end   
end    

local function set_button_style(style)
    if style.size then 
        bind.cancel_size = style.size 
        bind.confirm_size = style.size

        cancel_set_size = style.size 
        confim_set_size = style.size 
    end
    if style.color then 
        bind.cancel_color = style.color 
        bind.confirm_color = style.color
    end   
end    


return {
    confirm = confirm,
    message = message,
    show = show,
    hide = hide,
    set_title = set_title,
    set_font_family = set_font_family,
    set_message_button_text = set_message_button_text,
    is_show = is_show,
    set_title_style = set_title_style,
    set_text_style = set_text_style,
    set_button_style = set_button_style,
    get_ui = function () return ui end,
}