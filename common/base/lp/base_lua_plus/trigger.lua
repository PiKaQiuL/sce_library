--- lua_plus ---
function base.trigger_disable(trigger:trigger)
    ---@ui 关闭触发器~1~
    ---@description 关闭触发器
    ---@belong trigger
    ---@keyword 关闭 触发器
    ---@applicable action
    ---@name1 触发器
    if trigger_check(trigger) then
        trigger:disable()
    end
end

function base.trigger_enable(trigger:trigger)
    ---@ui 开启触发器~1~
    ---@description 开启触发器
    ---@belong trigger
    ---@keyword 开启 触发器
    ---@applicable action
    ---@name1 触发器
    if trigger_check(trigger) then
        trigger:enable()
    end
end

function base.trigger_is_enable(trigger:trigger) boolean
    ---@ui 触发器~1~是否开启
    ---@description 触发器是否开启
    ---@belong trigger
    ---@keyword 触发器 开启
    ---@applicable value
    ---@name1 触发器
    if trigger_check(trigger) then
        return trigger:is_enable()
    end
end

function base.trigger_remove(trigger:trigger)
    ---@ui 移除触发器~1~
    ---@description 移除触发器
    ---@belong trigger
    ---@keyword 移除 触发器
    ---@applicable action
    ---@name1 触发器
    if trigger_check(trigger) then
        trigger:remove()
    end
end

function base.trigger_new(func:function, t:table, disable:boolean, scene:string, sync:boolean) trigger
    local trig = base.trig:new(func, true, scene, sync)
    if type(t) == 'table' then
        for _, event in ipairs(t) do
            -- if and(type(event.obj) == 'string') then
            --     table.insert(pending_game_units, {node_mark = event.obj, event_name = event.event_name, trg = trig})
            -- else
            if event then
                trig:add_event_common(event)
            end
        end
    end
    if disable then
        trig:disable()
    end
    return trig
end

function base.trigger_add_event(trigger:trigger, trigger_event:trigger_event)
    ---@ui 为触发器~1~添加事件~2~
    ---@description 为触发器添加事件
    ---@belong trigger
    ---@keyword 添加 事件
    ---@applicable action
    ---@name1 触发器
    ---@name2 触发事件
    if trigger_check(trigger) then
        -- if and(type(event.obj) == 'string') then
        --     table.insert(pending_game_units, {node_mark = trigger_event.obj, event_name = trigger_event.event_name, trg = trigger_event})
        -- else
        if trigger_event then
            if not(trigger_event.time) then
                trigger:add_event(trigger_event.obj, trigger_event.event_name, trigger_event.custom_event)
            else
                trigger:add_event_game_time(trigger_event.time, trigger_event.periodic)
            end
        end
    end
end


--把触发事件表包装成函数
function base.trigger_event_wrapper_unit(unit:unit, event_name:单位事件) trigger_event
    ---@ui ~1~~2~时
    ---@belong unit
    ---@applicable value
    ---@description 单位事件
    ---@name1 单位
    ---@name1 单位事件

    if and(or (unit_check(unit, true), any_unit_check(unit, true), id_check(unit, true)),  event_name_check(event_name, true)) then
        return { obj = unit, event_name = event_name }
    else
        log.error"单位事件参数无效，请检测函数传入值"
    end
end

function base.trigger_event_wrapper_skill(skill:skill, event_name:技能事件) trigger_event
    ---@ui 技能~1~~2~时
    ---@belong skill
    ---@applicable value
    if and (or (skill_check(skill, true), any_skill_check(skill, true), id_check(skill, true)), event_name_check(event_name, true)) then
        return { obj = skill, event_name = event_name }
    else
        log.error"技能事件参数无效，请检测函数传入值"
    end
end

-- function base.trigger_event_wrapper_eff_param(eff_param:eff_param, event_name:效果事件) trigger_event
--     ---@ui 效果~1~~2~时
--     ---@belong effparam
--     ---@applicable value
--     return { obj = eff_param, event_name = event_name }
-- end

function base.trigger_event_wrapper_player(player:player, event_name:玩家事件) trigger_event
    ---@ui ~1~~2~时
    ---@belong player
    ---@applicable value
    if and(or (player_check(player, true), any_player_check(player, true)), event_name_check(event_name, true)) then
        return { obj = player, event_name = event_name }
    else
        log.error"玩家事件参数无效，请检测函数传入值"
    end
end

function base.trigger_event_wrapper_game(event_name:游戏事件) trigger_event
    ---@ui 游戏事件~1~时
    ---@belong gamer
    ---@applicable value
    if event_name_check(event_name, true) then
        return { obj = base.game, event_name = event_name }
    else
        log.error"游戏事件参数无效，请检测函数传入值"
    end
end

-- function base.trigger_event_wrapper_mover(mover:mover, event_name:运动事件) trigger_event
--     ---@ui 运动~1~~2~时
--     ---@belong mover
--     ---@applicable value
--     return { obj = mover, event_name = event_name }
-- end

function base.trigger_event_wrapper_timer_periodic(time:number) trigger_event
    ---@ui 游戏开始后每~1~秒执行
    ---@description 循环游戏时间事件
    ---@belong timer
    ---@applicable value
    if time_check(time) then
        return { obj = base.game, time = time, periodic = true}
    end
end

function base.trigger_event_wrapper_timer_once(time:number) trigger_event
    ---@ui 游戏开始后~1~秒执行
    ---@description 单次游戏时间事件
    ---@belong timer
    ---@applicable value
    if time_check(time) then
        return { obj = base.game, time = time, periodic = false}
    end
end

-- function base.trigger_event_wrapper_area(area:area, event_name:区域事件) trigger_event
--     ---@ui 任意单位~2~区域~1~时
--     ---@description 区域事件
--     ---@belong area
--     ---@applicable value
--     return { obj = area, event_name = event_name}
-- end

-- function base.trigger_event_wrapper_message(event_name:消息事件) trigger_event
--     ---@ui 收到类型为~1~的消息时
--     ---@description 消息事件
--     ---@belong trigger
--     ---@applicable value
--     return { obj = base.game, event_name = event_name}
-- end

function base.trigger_event_wrapper_message(event_name:消息事件) trigger_event
    ---@ui 收到类型为~1~的消息时
    ---@description 消息事件
    ---@belong trigger
    ---@applicable value
    if event_name_check(event_name) then
        return { obj = base.game, event_name = event_name}
    end
end

function base.trigger_event_wrapper_screen(event_name:画面事件) trigger_event
    ---@ui 画面~1~时
    ---@description 画面事件
    ---@belong trigger
    ---@applicable value
    if event_name_check(event_name) then
        return { obj = base.game, event_name = event_name}
    end
end

function base.trigger_event_wrapper_input(event_name:输入事件) trigger_event
    ---@ui 玩家~1~时
    ---@description 输入事件
    ---@belong trigger
    ---@applicable value
    if event_name_check(event_name) then
        return { obj = base.game, event_name = event_name}
    end
end

function base.trigger_event_wrapper_actor(event_name:表现事件) trigger_event
    ---@ui 表现事件~1~时
    ---@description 表现事件
    ---@belong trigger
    ---@applicable value
    if event_name_check(event_name) then
        return { obj = base.game, event_name = event_name}
    end
end

function base.trigger_event_wrapper_buff(buff:buff, event_name:状态事件) trigger_event
    ---@ui 状态~1~~2~时
    ---@description 状态事件
    ---@belong trigger
    ---@applicable value
    if and(buff_check(buff, true), event_name_check(event_name, true)) then
        return { obj = buff, event_name = event_name}
    end
end

function base.trigger_event_wrapper_conversation(event_name:对话事件) trigger_event
    ---@ui 对话~1~时
    ---@description 对话事件
    ---@belong trigger
    ---@applicable value
    if event_name_check(event_name) then
        return { obj = base.game, event_name = event_name}
    end
end

function base.trigger_custom_event_wrapper(event_name:自定义事件名) trigger_event
    ---@ui 自定义事件~1~时
    ---@description 自定义事件
    ---@belong trigger
    ---@applicable value
    if event_name_check(event_name) then
        return { obj = base.game, custom_event = true, event_name = event_name}
    end
end

local argv = require 'base.argv'

local thread_to_tsCo = nil

function base.trigger_call(trigger:trigger, e:trigger_event, sync: boolean)
    if trigger.sign_remove then
        return log_file.warn(string.format('触发器[%s]已经被移除！', trigger))
    end
    if not(trigger.enable_flag) then
        return log_file.warn(string.format('触发器[%s]被禁用！', trigger))
    end
    thread_to_tsCo = or(thread_to_tsCo, require("@base.base.co").thread_to_tsCo)
    if sync then
        if type(trigger.callback_sync) ~= "function" then
            return log_file.warn(string.format('触发器[%s]不能以同步方式调用！', trigger))
        end
        trigger:callback_sync(e)
        return thread_to_tsCo(coroutine.running())
    else
        if type(trigger.callback_sync) == "function" then
            local co = nil
            coroutine.will_async(function()
                co = thread_to_tsCo(coroutine.running())
                trigger:callback_sync(e)
            end)()
            return co
        else
            trigger:callback(e)
            return thread_to_tsCo(coroutine.running())
        end
    end
end