---------------------------------------------------
-- 检查log，删除太久远的log，如果有dump，上传log
---------------------------------------------------

local upload_log = include 'base.upload_log'
local co = include 'base.co'
local argv = require 'base.argv'

-- log 过期时间, 默认只保存 7天内的 log
local expired_time = 60 * 60 * 24 * 7
local root = 'logs'
local dump_path = 'logs/dump'

local function success(error)
    return error == 0
end

local function print_error(...)
    local args = {...}
    table.insert(args, #args, ', 错误码')
    log.error(table.unpack(args))
end

local function check_log(dir)
    local error, log_files = io.list(dir, 1)
    if not success(error) then 
        print_error('遍历日志子目录失败', dir, error) 
        return
    end

    -- 判断文件时间
    for _, file in ipairs(log_files) do
        local _, file_time = io.file_time(file)
        --log.info(file, '上次修改时间:', os.date('%Y-%m-%d %H:%M:%S', file_time))
        if file_time then
            local current = os.time()
            if current - file_time > expired_time then
                --log.info(file, '过期，需要删除')
                io.remove(file)
            end
        end
    end

    -- 获取 logs 子目录
    local error, sub_dirs = io.list(dir, 2)
    if not success(error) then 
        print_error('遍历日志根目录失败', error) 
        return
    end

    for _, sub_dir in ipairs(sub_dirs) do
        log.info('子目录', sub_dir)
        check_log(sub_dir)
    end

end

local function check_dump()

    -- 检查是否有新的 dump 文件
    local error, dumps = io.list(dump_path, 1)
    if not success(error) or #dumps == 0 then
        log.info('没有dump文件')
        return
    end

    log.info('发现', #dumps, '个dump文件')

    -- 上传 log
    co.async(function()
        local upload_log = co.wrap(upload_log)
        upload_log('crash')
        log.info('上传崩溃完毕')

        -- 删除 dump 文件
        for _, dump in ipairs(dumps) do
            log.info('删除', dump)
            io.remove(dump)
        end
    end)

end

local function start()
    check_dump()
    
    if not argv.has('editor_server_debug') then -- 编辑器调试就别每次清一遍了，里面还统计文件大小，虽然是另开线程，但总归有点浪费了
        -- 使用C++新开线程清理log
        io.clear_logs(root, expired_time)
    end
end

return {
    start = start
}