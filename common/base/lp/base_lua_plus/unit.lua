--- lua_plus ---
function base.node_mark(node_mark:string, unit_name:string) node_mark
    return node_mark
end

function base.unit_get_attribute(unit:unit, state:单位属性) number
    ---@ui ~1~的属性~2~
    ---@arg1 base.player_get_hero(base.player_local())
    ---@arg2 单位属性.生命
    ---@description 单位的属性值
    ---@keyword 属性
    ---@applicable value
    ---@belong unit
    ---@name1 单位
    ---@name2 单位属性
    if unit_check(unit) then
        return unit:get(state)
    end
end

function base.unit_get_name(unit:unit) unit_id
    ---@ui 获取~1~的Id
    ---@arg1 e.unit
    ---@description 单位的Id
    ---@keyword 名字
    ---@applicable value
    ---@belong unit
    ---@name1 单位
    if unit_check(unit) then
        return unit:get_name()
    end
end

function base.get_unit_from_id(id:number) unit
    ---@ui 编号为~1~的单位
    ---@description 从单位编号获取单位
    ---@keyword 单位
    ---@applicable value
    ---@belong unit
    ---@name1 单位编号
    return base.unit(id)
end

function base.set_unit_location(unit:unit, position:point)
    ---@ui 客户端设置~1~单位的位置到~2~
    ---@description 设置单位位置（客户端）
    ---@keyword 单位
    ---@applicable action
    ---@belong unit
    ---@name1 单位
    ---@name2 位置
    game.set_unit_location(unit._id, position[1], position[2], position[3])
end

function base.set_unit_location_and_height(unit:unit, position:point, height:number)
    ---@ui 客户端设置~1~单位的位置到~2~，高度为~3~
    ---@description 设置单位位置和高度（客户端）
    ---@keyword 单位
    ---@applicable action
    ---@belong unit
    ---@name1 单位
    ---@name2 位置
    ---@name3 高度
    game.set_unit_location(unit._id, position[1], position[2], height)
end


 ---@keyword 单位
 function base.create_riseletter_by_link(position, text, link, color, fontsize)
    ---@ui 客户端在位置~1~创建漂浮文字，飘字内容为~2~，类型为~3~，颜色为~4~，字体大小为~5~
    ---@description 创建漂浮文字（客户端）
    ---@applicable action
    ---@name1 飘字位置
    ---@name2 飘字内容
    ---@name3 飘字类型模板名
    ---@name4 颜色
        return base.create_riseletter_by_templatename(position, text, link, color, fontsize)
end

 ---@keyword 单位
function base.create_riseletter_by_templatename(position, text, templatename, color, fontsize)
    ---@ui 客户端在位置~1~创建漂浮文字，飘字内容为~2~，类型为~3~，颜色为~4~，字体大小为~5~
    ---@description 创建漂浮文字（客户端）
    ---@applicable action
    ---@name1 飘字位置
    ---@name2 飘字内容
    ---@name3 飘字类型模板名
    ---@name4 颜色
    local riseletter_id = 0
    if not position then 
        riseletter_id = game.create_riseletter_by_templatename(-1,0,0, text, templatename, color, fontsize)
    else
        local x,y = position[1],position[2]
        riseletter_id = game.create_riseletter_by_templatename(-1,x,y, text, templatename, color, fontsize)
    end
    if riseletter_id == 0 then
        return nil
    end
    return base.riseletter:new(nil, riseletter_id)
end

 ---@keyword 单位
function base.remove_riseletter(riseletter_id)
    ---@ui 客户端删除编号为~1~的漂浮文字
    ---@belong unit
    ---@description 删除指定编号的漂浮文字（客户端）
    ---@applicable action
    ---@name1 单位
    ---@name2 飘字编号
    game.remove_riseletter(riseletter_id)
end
 ---@keyword 单位
function base.set_riseletter_position(riseletter_id, position)
    ---@ui 客户端设置编号为~1~的漂浮文字的位置到~2~
    ---@belong unit
    ---@description 设置单位漂浮文字位置（客户端）
    ---@applicable action
    ---@name1 单位
    ---@name2 飘字编号
    ---@name3 位置
    game.set_riseletter_position(riseletter_id, position[1],position[2])
end
function base.set_riseletter_world_position(riseletter_id, position)
    ---@ui 客户端设置编号为~1~的漂浮文字的位置到~2~
    ---@belong unit
    ---@description 设置单位漂浮文字世界位置（客户端）
    ---@applicable action
    ---@name1 单位
    ---@name2 飘字编号
    ---@name3 位置
    game.set_riseletter_world_position(riseletter_id, position[1],position[2],position[3])
end
function base.set_riseletter_unit(riseletter_id, unit)
    ---@ui 客户端设置编号为~1~的漂浮文字的所属单位为~2~
    ---@belong unit
    ---@description 设置漂浮文字单位（客户端）
    ---@applicable action
    ---@name1 单位
    ---@name2 飘字编号
    ---@name3 单位
    if unit_check(unit) then
        game.set_riseletter_unit(riseletter_id,unit._id)
    end
end

function base.set_unit_facing(unit:unit, angle:angle)
    ---@ui 客户端设置~1~单位的朝向为~2~
    ---@description 设置单位朝向（客户端）
    ---@keyword 单位
    ---@applicable action
    ---@belong unit
    ---@name1 单位
    ---@name2 方向
    game.set_unit_facing(unit._id, angle)
end

function base.get_unit_random_model_index(unit:unit)
    ---@ui 客户端获取~1~单位的随机模型索引
    ---@description 获取单位随机模型索引（客户端）
    ---@keyword 单位
    ---@applicable value
    ---@belong unit
    ---@name1 单位
    if unit_check(unit) then
        return unit:get_unit_random_model_index()
    end
end

function base.unit_get_tag(unit:unit) 单位标签
    ---@ui ~1~的标签
    ---@arg1 e.unit
    ---@description 单位的标签
    ---@keyword 标签
    ---@applicable value
    ---@belong unit
    ---@name1 单位
    
    if unit_check(unit) then
        return unit:get_tag()
    end
end

function base.unit_get_id(unit:unit) integer
    ---@ui ~1~的编号
    ---@description 单位的编号
    ---@keyword 编号
    ---@belong unit
    ---@applicable value
    ---@arg1 e.unit
    ---@name1 单位
    
    if unit_check(unit) then
        return unit._id
    end
end

function base.get_default_unit_v1(node_mark:node_mark) unit
    ---@ui 地编~1~
    ---@description 获取地编单位
    ---@keyword 单位
    ---@belong unit
    ---@applicable value
    ---@uitype tile_editor_item
    return base.get_default_unit(node_mark)
end

function base.get_default_item_v1(node_mark:node_mark) item
    ---@ui 地编~1~
    ---@description 获取地编物品
    ---@keyword 物品
    ---@belong item
    ---@applicable value
    ---@uitype tile_editor_item
    return base.get_default_item(node_mark)
end
function base.anim_play(unit:unit, anim:string, time:number, time_type:integer, start_offset:number, blend_time:integer, priority:integer) animation
    ---@ui 单位~1~播放动画~2~一次，时间因子为~3~，时间因子类型为~4~，动画原始偏移为~5~，混合时长为~6~s，优先级为~7~
    ---@description 模型单位播放一次动画
    ---@applicable action
    ---@belong unit
    ---@keyword 单位 动画
    ---@name1 单位
    ---@name2 动画名
    ---@name3 时间因子类型
    ---@name4 时间因子
    ---@name5 起始播放时间
    ---@name6 渐入时长
    ---@name7 优先级
    
    if unit_check(unit) then
        local params = {
            time = time,
            time_type = time_type,
            start_offset = start_offset,
            blend_time = blend_time,
            priority = priority,
        }
        return unit:anim_play(anim, params)
    else
        return nil
    end
end


function base.anim_set_paused_all(unit:unit, paused:boolean)
    ---@ui 暂停/恢复单位~1~的动画~2~
    ---@description 暂停/恢复单位模型动画（新API）
    ---@applicable action
    ---@belong unit
    ---@keyword 单位 动画 暂停 恢复
    ---@name1 单位
    ---@name2 暂停与否
    
    if unit_check(unit) then
        unit:anim_set_paused_all(paused)
    end
end

function base.set_time_scale_global(unit:unit, time_scale:number)
    ---@ui 设置单位~1~的全局相对动画播放时间倍数为~2~
    ---@description 设置单位模型动画相对播放时间倍数（只影响新API的动画）
    ---@applicable action
    ---@belong unit
    ---@keyword 单位 动画 速度 相对
    ---@name1 单位
    ---@name2 相对播放时间倍数
    if unit_check(unit) then
        unit:set_time_scale_global(time_scale)
    end
end

function base.anim_play_bracket(unit:unit, anim_birth:string, anim_stand:string, anim_death:string, force_one_shot:boolean, kill_on_finish:boolean, priority:integer, sync:boolean) animation
    ---@ui 设置单位~1~的BSD动画为birth:~2~，stand:~3~，death:~4~，强制播放一次:~5~，播完后自动销毁:~6~，优先级为~7~, 同步为~8~
    ---@description 设置模型表现的bsd动画（新API）
    ---@applicable action
    ---@belong unit
    ---@keyword 单位 动画 BSD
    ---@name1 单位
    ---@name2 birth动画
    ---@name3 stand动画
    ---@name4 death动画
    ---@name5 强制播放一次
    ---@name6 播完后自动销毁
    ---@name7 优先级
    ---@name8 同步
    if unit_check(unit) then
        local params = {
            force_one_shot = force_one_shot,
            kill_on_finish = kill_on_finish,
            priority = priority,
            sync = sync,
        }
        return unit:anim_play_bracket(anim_birth, anim_stand, anim_death, params)
    else
        return nil
    end
end

function base.unit_get_display_name(unit:unit) string
    ---@ui 获取~1~的显示名
    ---@description 单位的显示名
    ---@keyword 显示名
    ---@applicable value
    ---@belong unit
    ---@name1 单位
    ---@arg1 base.player_get_hero(base.player_local())
    if unit_check(unit) then
        return unit:get_display_name()
    end
end

function base.unit_set_display_name(unit:unit, display_name:string)
    ---@ui 设置~1~的显示名为~2~
    ---@description 设置单位的显示名
    ---@keyword 显示名
    ---@applicable action
    ---@belong unit
    ---@name1 单位
    ---@name2 显示名
    ---@arg1 base.player_get_hero(base.player_local())
    ---@arg2 '显示名'
    if unit_check(unit) then
        return unit:set_display_name(display_name)
    end
end


function base.target_filter_validate_on_unit(...)
    return base.target_filter_validate(...)
end

--- lua_plus ---
local e_cmd = base.eff.e_cmd

local function check_target_filter(target_filter)
    return and(type(target_filter) == 'table', type(target_filter.validate) == 'function')
end

function base.target_filter_validate_on_unit(...)
    return base.target_filter_validate(...)
end

function base.target_filter_validate(过滤:target_filter, 过滤单位:unit, 基准单位:unit) boolean
    ---name1 过滤
    ---name2 基准单位
    ---name3 过滤单位
    if check_target_filter(过滤) then
        local base_unit = or(基准单位, 过滤单位)
        return 过滤:validate(base_unit, 过滤单位) == e_cmd.OK
    else
        return false
    end
end

function base.unit_group_filter_group_on_unit(...)
    return base.unit_group_filter_group(...)
end

function base.unit_group_filter_group(单位组:单位组, 过滤:target_filter, 基准单位:unit) 单位组
    ---name1 过滤单位组
    ---name2 过滤
    ---name3 基准的单位
    if check_target_filter(过滤) then
        local units = {}
        if 基准单位 then
            for k, _ in pairs(单位组:get_items_map()) do
                if 过滤:validate(基准单位, k) == e_cmd.OK then
                    units[#units+1] = k
                end
            end
        else
            for k, _ in pairs(单位组:get_items_map()) do
                if 过滤:validate(k, k) == e_cmd.OK then
                    units[#units+1] = k
                end
            end
        end
        return base.单位组(units)
    else
        return base.单位组{}
    end
end