return function (template, bind)
    local ui = base.ui.view {
        type = 'progress',
        name = template.name,
        id = template.id
    }

    -- 自定义精度
    local step = template.step or 0.01
    local around = function (v)
        return math.floor(v / step + 0.5) * step
    end

    base.ui.watch(ui, template, bind, 'progress_type')
    base.ui.watch(ui, template, bind, 'progress', around)
    base.ui.watch(ui, template, bind, 'progress_rotate')
    base.ui.watch(ui, template, bind, 'slider_enable')
    base.ui.watch(ui, template, bind, 'slider_image')
    base.ui.watch(ui, template, bind, 'slider_size')
    base.ui.watch(ui, template, bind, 'slider_translate')

    return ui
end
