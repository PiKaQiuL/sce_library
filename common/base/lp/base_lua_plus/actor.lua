--- lua_plus ---
function base.get_last_created_actor() actor
    ---@ui 触发器最后创建的表现
    ---@description 触发器最后创建的表现
    ---@applicable value
    ---@belong actor
    ---@keyword 表现
    return base.last_created_actor
end

function base.set_actor_creation_filter_level(level:number)
    ---@ui 设置粒子特效表现创建过滤级别为~1~，低于该等级的特效将不再创建
    ---@description 设置粒子特效表现创建过滤级别
    ---@applicable action
    ---@belong actor
    ---@keyword 表现
    ---@arg1 2
    base.actor_creation_filter_level = level
end

function base.create_actor_at(name:actor_id, point:point) actor
    ---@ui 在~2~处创建表现:~1~
    ---@description 创建表现
    ---@applicable both
    ---@belong actor
    ---@keyword 创建
    ---@name1 表现类型
    ---@name2 位置
    local actor = base.actor(name)
    base.last_created_actor = actor
    if not(actor) then
        return
    end
    actor:set_position(point[1],point[2], point[3])
    return actor
end

function base.actor_set_position(actor:actor, point:point)
    ---@ui 将~1~移动到~2~
    ---@description 移动表现
    ---@applicable action
    ---@belong actor
    ---@keyword 移动
    ---@name1 表现
    ---@name2 点
    if actor then
        actor:set_position(point[1],point[2],point[3])
    end
end

function base.actor_set_facting(actor:actor, angle:angle)
    ---@ui 设置~1~的朝向为~2~
    ---@description 设置表现朝向
    ---@applicable action
    ---@belong actor
    ---@keyword 朝向 角度
    ---@name1 表现
    ---@name2 角度值
    if actor then
        actor:set_facing(angle)
    end
end

function base.actor_attach_to_unit(actor:actor, host:unit, socket:string)
    ---@ui 将~1~附着到~2~的附着点~3~处
    ---@description 将表现附着到单位上
    ---@applicable action
    ---@belong actor
    ---@keyword 附着 单位
    ---@name1 表现
    ---@name2 宿主
    ---@name2 绑点
    if actor then
        actor:attach_to(host, socket)
    end
end

function base.actor_attach_to_actor(actor:actor, host:actor, socket:string)
    ---@ui 将~1~附着到~2~的附着点~3~处
    ---@description 将表现附着到表现上
    ---@applicable action
    ---@belong actor
    ---@keyword 附着 表现
    ---@name1 表现
    ---@name2 宿主
    ---@name3 绑点
    if actor then
        actor:attach_to(host, socket)
        actor:attach_to(host, socket)
    end
end

function base.actor_destroy(actor:actor, flag:表现摧毁方式)
    ---@ui 摧毁~1~，方式为~2~
    ---@description 摧毁表现
    ---@applicable action
    ---@belong actor
    ---@keyword 摧毁
    ---@arg1 base.get_last_created_actor()
    ---@arg2 表现摧毁方式["等待死亡动画结束"]
    ---@name1 表现
    if actor then
        actor:destroy(flag)
    end
end

function base.actor_set_asset_model(actor:actor, asset:model_id)
    ---@ui 将~1~的模型资源替换为~2~
    ---@description 替换表现的模型资源（仅对模型和粒子表现有效）
    ---@applicable action
    ---@belong actor
    ---@keyword 模型
    ---@arg1 base.get_last_created_actor()
    ---@name1 表现
    ---@name2 新模型
    if actor then
        actor:set_asset(asset)
    end
end

function base.actor_set_asset_sound(actor:actor, asset:sound_id)
    ---@ui 将表现~1~的音效资源替换为~2~
    ---@description 替换表现的音效资源（仅对音效表现有效）
    ---@applicable action
    ---@belong actor
    ---@keyword 音效
    ---@arg1 base.get_last_created_actor()
    ---@name1 表现
    ---@name2 新音效
    if actor then
        actor:set_asset(asset)
    end
end

function base.actor_set_owner(actor:actor, owner:number)
    ---@ui 将~1~的所属玩家设置为~2~号位的玩家
    ---@description 设置表现所属玩家
    ---@applicable action
    ---@belong actor
    ---@keyword 玩家
    ---@arg1 base.get_last_created_actor()
    ---@name1 表现
    ---@name2 新玩家号
    if actor then
        actor:set_owner(owner)
    end
end

function base.actor_set_shadow(actor:actor, enable:是否)
    ---@ui 将~1~设置为显示影子:~2~
    ---@description 设置表现是否显示影子（仅限模型表现）
    ---@applicable action
    ---@belong actor
    ---@keyword 影子
    ---@arg1 base.get_last_created_actor()
    ---@name1 表现
    ---@name2 是否显示影子
    if actor then
        actor:set_shadow(enable)
    end
end

function base.actor_set_scale(actor:actor, scale:number)
    ---@ui 设置~1~的缩放值为~2~
    ---@description 设置表现缩放（仅限模型和粒子表现）
    ---@applicable action
    ---@belong actor
    ---@keyword 缩放
    ---@arg1 base.get_last_created_actor()
    ---@name1 表现
    ---@name2 缩放值
    if actor then
        actor:set_scale(scale)
    end
end

function base.actor_play(actor:actor)
    ---@ui 播放~1~
    ---@description 播放表现（仅限音效和粒子表现）
    ---@applicable action
    ---@belong actor
    ---@keyword 播放
    ---@arg1 base.get_last_created_actor()
    ---@name1 表现
    if actor then
        actor:play()
    end
end

function base.actor_stop(actor:actor)
    ---@ui 停止播放~1~
    ---@description 停止播放表现（仅限音效和粒子表现）
    ---@applicable action
    ---@belong actor
    ---@keyword 停止
    ---@arg1 base.get_last_created_actor()
    ---@name1 表现
    if actor then
        actor:stop()
    end
end

function base.actor_pause(actor:actor)
    ---@ui 暂停音效表现~1~
    ---@description 暂停表现（仅限音效表现）
    ---@applicable action
    ---@belong actor
    ---@keyword 暂停
    ---@arg1 base.get_last_created_actor()
    ---@name1 表现
    if actor then
        actor:pause()
    end
end

function base.actor_resume(actor:actor)
    ---@ui 继续播放音效表现~1~
    ---@description 继续播放被暂停的表现（仅限音效表现）
    ---@applicable action
    ---@belong actor
    ---@keyword 继续
    ---@arg1 base.get_last_created_actor()
    ---@name1 表现
    if actor then
        actor:resume()
    end
end

function base.actor_set_volume(actor:actor,volume:number)
    ---@ui 设置音效表现~1~的音量为~2~
    ---@description 设置表现音量（仅限音效表现）
    ---@applicable action
    ---@belong actor
    ---@keyword 音量
    ---@arg1 base.get_last_created_actor()
    ---@name1 表现
    ---@name2 音量
    if actor then
        actor:set_volume(volume)
    end
end

function base.actor_set_grid_size(actor:actor, size_x:number, size_y:number)
    ---@ui 设置网格表现~1~的网格大小为~2~ ~3~
    ---@description 设置网格物体的网格大小（仅限网格表现）
    ---@applicable action
    ---@belong actor
    ---@keyword 网格 大小
    ---@arg1 base.get_last_created_actor()
    ---@name1 网格表现
    ---@name2 X轴大小
    ---@name3 Y轴大小（未设置同X轴）
    if actor then
        if and(size_y, size_y ~= 0) then
            actor:set_grid_size({size_x, size_y})
        else
            actor:set_grid_size({size_x, size_x})
        end
    end
end

function base.actor_set_grid_range(actor:actor, start_x:integer, start_y:integer, range_x:integer, range_y:integer)
    ---@ui 设置网格表现~1~的原点偏移（原点默认在左下角）为~2~ ~3~，网格范围为~4~ ~5~
    ---@description 设置网格物体的原点偏移和网格范围（仅限网格表现）
    ---@applicable action
    ---@belong actor
    ---@keyword 网格 偏移 范围
    ---@arg1 base.get_last_created_actor()
    ---@name1 网格表现
    ---@name2 X轴偏移
    ---@name3 Y轴偏移
    ---@name4 X轴范围
    ---@name5 Y轴范围
    if actor then
        actor:set_grid_range({start_x, start_y}, {range_x, range_y})
    end
end

function base.actor_set_grid_state(actor:actor, id_x:integer, id_y:integer, state:integer)
    ---@ui 设置网格表现~1~中坐标为~2~ ~3~的子网格状态为~4~
    ---@description 设置网格表现中子网格的状态（仅限网格表现）
    ---@applicable action
    ---@belong actor
    ---@keyword 网格 状态
    ---@arg1 base.get_last_created_actor()
    ---@arg4 1
    ---@name1 网格表现
    ---@name2 子网格X轴坐标
    ---@name3 子网格Y轴坐标
    ---@name4 状态
    if actor then
        actor:set_grid_state({id_x, id_y}, state)
    end
end

function base.actor_set_grount_height(actor:actor, height:number)
    ---@ui 设置~1~地面相对高度为~2~
    ---@description 设置表现地面相对高度
    ---@applicable action
    ---@belong actor
    ---@keyword 高度 相对
    ---@name1 表现
    ---@args2 0
    if actor then
        actor:set_ground_z(height)
    end
end

function base.actor_anim_play(actor:actor, anim:string, time:number, time_type:integer, start_offset:number, blend_time:integer, priority:integer)
    ---@ui 表现~1~播放动画~2~一次，时间因子为~3~，时间因子类型为~4~，动画原始偏移为~5~，混合时间为~6~s，优先级为~7~
    ---@description 模型表现播放一次动画
    ---@applicable action
    ---@belong actor
    ---@keyword 模型 动画
    ---@arg1 base.get_last_created_actor()
    ---@name1 模型表现
    ---@name2 动画名
    ---@name3 时间因子
    ---@name4 时间因子类型
    ---@name5 起始播放时间
    ---@name6 过渡时间
    ---@name7 优先级
    if actor then
        local params = {
            time = time,
            time_type = time_type,
            start_offset = start_offset,
            blend_time = blend_time,
            priority = priority
        }
        actor:anim_play(anim, params)
    end
end

function base.actor_anim_set_paused_all(actor:actor, paused:boolean)
    ---@ui 暂停/恢复表现~1~的所有动画~2~
    ---@description 暂停/恢复模型表现的所有动画（新API）
    ---@applicable action
    ---@belong actor
    ---@keyword 模型 动画 暂停 恢复
    ---@arg1 base.get_last_created_actor()
    ---@name1 模型表现
    ---@name2 暂停与否
    if actor then
        actor:anim_set_paused_all(paused)
    end
end

function base.actor_set_time_scale_global(actor:actor, time_scale:number)
    ---@ui 设置表现~1~的全局相对动画播放时间倍数为~2~
    ---@description 设置模型表现相对播放时间倍数（只影响新API的动画）
    ---@applicable action
    ---@belong actor
    ---@keyword 模型 动画 速度 相对
    ---@arg1 base.get_last_created_actor()
    ---@name1 模型表现
    ---@name2 相对播放时间倍数
    if actor then
        actor:set_time_scale_global(time_scale)
    end
end

function base.actor_anim_play_bracket(actor:actor, anim_birth:string, anim_stand:string, anim_death:string, force_one_shot:boolean, kill_on_finish:boolean, priority:integer)
    ---@ui 设置模型表现~1~的BSD动画为birth:~2~，stand:~3~，death:~4~，强制播放一次:~5~，播完后自动销毁:~6~，优先级为~7~
    ---@description 设置模型表现的bsd动画
    ---@applicable action
    ---@belong actor
    ---@keyword 模型 动画 BSD
    ---@arg1 base.get_last_created_actor()
    ---@name1 模型表现
    ---@name2 birth动画
    ---@name3 stand动画
    ---@name4 death动画
    ---@name5 强制播放一次
    ---@name6 结束后销毁
    ---@name7 优先级
    if actor then
        local params = {
            force_one_shot = force_one_shot,
            kill_on_finish = kill_on_finish,
            priority = priority
        }
        actor:anim_play_bracket(anim_birth, anim_stand, anim_death, params)
    end
end

function base.actor_get_parent(obj)
    local id = obj._id
    local parent_id, is_actor = game.actor_get_parent(id)
    local result
    if is_actor then
        result = base.actor_from_id(parent_id)
    else
        result = base.unit(parent_id)
    end
    return result
end

function base.actor_set_anim_mapping(obj, name_from, name_to)
    local id = obj._id
    local r = game.actor_set_anim_mapping(id, name_from, name_to)
    return r
end

function base.actor_set_anim_mapping_map(obj, name_map)
    local id = obj._id
    local r = game.actor_set_anim_mapping(id, name_map)
    return r
end