
return {
    editable_prop = {
        -- ['font.bold'] = {
        --     category = '字体', text = '加粗', advance = false,
        --     type = 'select', options = {
        --         {text = '开', value = true},
        --         {text = '关', value = false},
        --     },
        --     default = false,
        -- },
        -- ['font.size'] = {
        --     category = '字体',
        --     text = '大小', advance = false,
        --     type = 'input', input_type = 'number',
        --     default = 15,
        -- },
        -- ['font.color'] = {
        --     category = '字体',
        --     text = '颜色', advance = false,
        --     type = 'color',
        --     default = '#ffffff',
        -- },
        -- ['font.align'] = {
        --     category = '字体',
        --     text = '横向对齐', advance = false,
        --     type = 'select', options = {
        --         {text = '左对齐', value = 'left'},
        --         {text = '居中对齐', value = 'center'},
        --         {text = '右对齐', value = 'right'},
        --     },
        --     default = 'center',
        -- },
        -- ['font.family'] = {
        --     category = '字体', text = '字体', advance = false,
        --     type = 'select', options = {
        --         {text = '思源黑体', value = 'Regular'},
        --         {text = '思源宋体', value = 'SourceHanSerif'},
        --         {text = '友爱圆体', value = 'NoWarRounded'},
        --     },
        --     default = 'Regular',
        -- },
        -- ['font.vertical_align'] = {
        --     text = '纵向对齐', advance = false,
        --     type = 'select', options = {
        --         {text = '上对齐', value = 'top'},
        --         {text = '居中对齐', value = 'center'},
        --         {text = '下对齐', value = 'bottom'},
        --     },
        --     default = 'center',
        -- }
        -- 以下设置了没反应。。
        -- ['font.bold_color'] = {
        --     category = '字体', advance = false,
        --     text = '加粗颜色',
        --     type = 'color',
        -- },
        -- ['font.line_height'] = {
        --     category = '字体', advance = false,
        --     text = '行高',
        --     type = 'input', input_type = 'number',
        -- },
        -- ['font.shadow.color'] = {
        --     category = '字体', advance = false,
        --     text = '投影颜色',
        --     type = 'color',
        -- },
        -- ['font.shadow.offset'] = {
        --     text = '投影偏移',
        --     type = 'vector2',
        -- },
    },
    editability = {
        prop = {
            font = {
                Type = 'Font',
                DisplayName = '字体',
            },
            text = {
                Type = 'string',
                DisplayName = '文本',
            },
        },
    }
}