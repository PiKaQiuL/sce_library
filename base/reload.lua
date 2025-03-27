
local co        = include 'base.co'

local resource_path = {}
local function add_resource_path(path)
    resource_path[path] = true
end

local function run(update, update_subpath)

    co.async(function()
        log.info('------------------------ 准备刷新启动页 ----------------------')

        -- 停止更新
        update.stop()
        --lobby.disconnect()
        -- 标记成app_reload行为
        common.add_argv('app_reload','')
        --local script_path = 'Update/' .. update_subpath .. '/Res'
        --log.info('设置脚本启动路径', script_path)
        --app.set_script_path(script_path)
    
        log.info('重新启动 ...')
        app.reload()
    
        log.info('------------------------ 启动页刷新完成 ----------------------')
    end)

end

local reload =  {
    add_resource_path = add_resource_path,
    run = run
}

return reload
