--[[

用法:

local update = include 'base.update'

-- 更新
update.start {
    -- 更新哪些模型
    maps = { 'model_1', 'model_2' },
    -- 更新完毕的回调
    on_finish = function (success, msg)
        if success then
            log_file.info('更新成功')
        else
            log_file.warn('更新失败, 错误信息' .. msg)
        end
    end
}

-- 删除
update.remove { 'model_1', 'model_2' }

]]

local co = include 'base.co'

local seq = 0
local function start(args)
    seq = seq + 1
    local session = seq
    args.seq = seq
    if args.on_finish then
        base.game:broadcast('update_map_finish', function(seq, success, error_msg)
            if seq == session then
                args.on_finish(success, error_msg)
            end
        end)
    end
    base.game:send_broadcast('update_map', args)
end

local function start_async(args)
    local exec = co.wrap(function(args, callback)
        args.on_finish = function(...)
            callback(...)
        end
        start(args)
    end)
    return exec(args)
end

local function remove(maps)
    base.game:send_broadcast('remove_map', maps)
end

return {
    start = start,
    start_async = start_async,
    remove = remove
}