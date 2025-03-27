--- lua_plus ---
function base.timer_loop(time:number, func:function<timer>) timer
    ---@ui 每~1~秒执行~2~
    ---@description 每隔一段时间循环执行动作
    ---@belong timer
    ---@keyword 循环 执行
    ---@applicable both
    return base.loop(math.floor(time * 1000), func)
end

function base.timer_loop_lazy(time:number, func:function<timer>) timer
    ---@ui 每~1~秒执行~2~
    ---@description 每隔一段时间循环执行动作
    ---@belong timer
    ---@keyword 循环 执行
    ---@applicable both
    return base.loop_lazy(math.floor(time * 1000), func)
end

function base.timer_wait(time:number, func:function<timer>) timer
    ---@ui 等待~1~秒后执行~2~
    ---@description 等待一段时间后执行动作
    ---@belong timer
    ---@keyword 等待 执行
    ---@applicable both
    return base.wait(math.floor(time * 1000), func)
end

function base.timer_timer(time:number, times:integer, func:function<timer>) timer
    ---@ui 每~1~秒执行~3~共执行~2~次
    ---@description 每隔一段时间循环执行动作(限定次数)
    ---@belong timer
    ---@keyword 循环 执行
    ---@applicable both
    return base.timer(math.floor(time * 1000), times, func)
end

function base.timer_remove(timer: timer)
    ---@ui 移除计时器~1~
    ---@description 移除计时器
    ---@belong timer
    ---@keyword 移除
    ---@applicable action
    timer:remove()
end

function base.remaining(timer: timer) number
    ---@ui ~1~的剩余时间
    ---@description 计时器剩余的秒数
    ---@belong timer
    ---@applicable both
    return get_remaining(timer)//1000
end

function base.timer_sleep(time:number)
    ---@ui 等待~1~秒
    ---@description 等待一段时间
    ---@belong timer
    ---@keyword 等待 时间
    ---@applicable action
    return coroutine.sleep(math.floor(time * 1000))
end