---
--- Generated by EmmyLua(https://github.com/EmmyLua)
--- Created by xindong.
--- DateTime: 2021/3/18 20:33
---

log.info('client_base v20240711 17:10')

require 'base.event_deque'
local try_wrap                = require 'base.try'.try_wrap
local to_exception            = require 'base.exception'.to_exception
local throw                   = require 'base.exception'.throw
local platform                = require 'base.platform'
local local_version           = require 'update.core.local_version'
local editor_version_manager  = require "update.core.api_version_config".editor_version_manager
local api_pak_version_manager = require 'update.core.local_api_pak_version'
local map_pak_version_manager = require 'update.core.local_map_pak_version'
local lua_state_name          = __lua_state_name


local co = require 'base.co'
require 'base.promise'
local sleep               = coroutine.sleep
local create_request      = require 'base.request'
local request             = create_request('updater')
local env                 = require 'update.core.env'
local argv                = require 'base.argv'
local map_path            = require 'update.core.map_path'

--local update            = require 'update.init'
local confirm             = require 'base.confirm'
local path                = require 'base.path'
local account             = require 'base.account'
local reload              = require 'reload'
local json                = require 'json'
--local update            = require 'update.init'
local DefaultProgressBind = require 'base.progress'.DefaultProgressBind
local download_manager    = require 'update.download_manager'
local lobby               = require '@base.base.lobby'
local device_settings     = require '@base.device_settings'
require 'base.ip'
require 'uninstall.delete'

local math_random = math.random
local math_floor = math.floor
local io_add_resource_path = io.add_resource_path
local io_remove = io.remove
local io_rename = io.rename
local io_unzip_file = io.unzip_file
local io_serialize = io.serialize
local io_exist_dir = io.exist_dir
local io_exist_file = io.exist_file
local next = next
local fmt = fmt
local table_insert = table.insert
local table_unpack = table.unpack
local table_remove = table.remove
local get_http_env = base.get_http_env
local tostring = tostring
local update_folder_root = path(io.get_root_dir()) / 'Update' / _G.update_subpath
local file_mutex = require 'base.file_mutex'
local game_uninstall = require 'uninstall.delete'
common.record_stage = common.record_stage or function()  end

---@class UpdateMapInfo
---@field map           string   alias
---@field packet_type   number
---@field packet_suffix string|nil
---@field packet_info   table
---@field map_show      string
---@field is_server     boolean

local last_http_base = nil

local function add_resource_path()
    local root_path = path('Update') / _G.update_subpath
    local res_path = tostring(root_path / 'Res')

    io_add_resource_path(res_path)
    --io_add_resource_path(image_cache)
    --reload.add_resource_path(res_path)

    log.info('添加资源路径', res_path)
end

local maps_that_need_reload= {'script','client_base', 'appui', 'gameui', 'engineres'}

if platform.is_ios() then
    table.insert(maps_that_need_reload, 'shadercache_ios_ui')
end

local function set_extra_maps_that_need_reload(extra_maps)
    for _, map in ipairs(extra_maps) do
        table.insert(maps_that_need_reload, map)
    end
end

local get_shader_update_map = function(shader_level)
    local update_table = {}
    local shader_cache_suffix = 
    {  
        {'_base','_low','_low_medium'},
        {'_base','_low_medium','_medium','_medium_high'},
        {'_base','_medium_high','_high'},
        {'_base','_low','_low_medium', '_medium', '_medium_high', '_high'},
    }

    -- shader_level 1:low,2:medium,3:high,4:full

    local suffixs = shader_cache_suffix[shader_level]
    log.info(("shader_cache_suffix: %s, type shader_level: %s, shader_level: %s"):format(json.encode(shader_cache_suffix), type(shader_level), shader_level))

    if platform.is_android() then
        --table.insert(update_table, 'shadercache_android')
        for i = 1, #suffixs do
            table.insert(update_table, 'shadercache_android'..suffixs[i])
            log.info('shadercache_android'..suffixs[i])
        end
    elseif platform.is_ios() then
        --table.insert(update_table, 'shadercache_ios')
        for i = 1, #suffixs do
            table.insert(update_table, 'shadercache_ios'..suffixs[i])
            log.info('shadercache_ios'..suffixs[i])
        end
    else
        if argv.has('dx11') or argv.get('renderer_type') == 'dx11' then
            if lua_state_name == 'StateEditor'  then -- 编辑器用多API的包
            -- 美术就不要下载shadercache了，用本地编译，免得他们每次更新都要删
                if not argv.has('artist') then
                    if tonumber(argv.get('editor_api_version')) >= 3 then
                        table.insert(update_table, 'shadercache_editor_dxbc')
                        log.info('shadercache_editor_dxbc')
                    else
                        table.insert(update_table, 'shadercache_windows_dxbc')
                        log.info('shadercache_windows_dxbc')--低版本编辑器用旧包
                    end
                else
                    log.info('I am an artist, skip update shadercache.')
                end
            else
                table.insert(update_table, 'shadercache_windows_game_dxbc')
                log.info('shadercache_windows_game_dxbc')
            end
        else
            if lua_state_name == 'StateEditor' then
                -- 美术就不要下载shadercache了，用本地编译，免得他们每次更新都要删
                if not argv.has('artist') then
                    if tonumber(argv.get('editor_api_version')) >= 3 then
                        table.insert(update_table, 'shadercache_editor')
                        log.info('shadercache_editor')
                    else
                        table.insert(update_table, 'shadercache_windows')
                        log.info('shadercache_windows')--低版本编辑器用旧包
                    end
                else
                    log.info('I am an artist, skip update shadercache.')
                end
            else
                table.insert(update_table, 'shadercache_windows_game')
                log.info('shadercache_windows_game')
            end
            table.insert(update_table, 'shadercache_windows_ui')
            log.info('shadercache_windows_ui')
        end
    end

    return update_table
end

local get_update_shader_map = function()
    -- shader_level 1:low,2:medium,3:high,4:full
    local shader_level
    local scene_quality = base.settings:get_option('scene_quality')
    log.info('get_update_reload_map get settings scene quality',  scene_quality)
    if scene_quality ~= nil then
        -- 这里scene_quality是+1后的
        shader_level = scene_quality
    else
        -- 根据机型获取设置shader配置
        local default_settings = device_settings.get_renderer_default_settings()
        log.info('default_settings scene_quality ',default_settings.scene_quality)
        shader_level = math.min(default_settings.scene_quality + 1, 3)
    end
    log.info('update shader cache option', shader_level)

    local shader_table = get_shader_update_map(shader_level)
    return shader_table
end

local get_update_reload_map = function(no_shader_map)
    log.info('get_update_reload_map')
    if argv.has('startup') then
        local map = argv.get('startup')
        log.info(('startup : %s'):format(map))
        table.insert(maps_that_need_reload, map)
    else
        table.insert(maps_that_need_reload, 'startup')
    end
    if not no_shader_map then
        local shader_table = get_update_shader_map()
        table.merge(maps_that_need_reload, shader_table)
    end
    return maps_that_need_reload
end


local global_promise  = nil
local stop = function()
    if global_promise then
        global_promise:try_set(nil, 'call stopped')
        global_promise = nil
    end
end


local function _get_all_reference_maps(ctx, new_list, all_map_Info)

    local function sub_count()
        ctx.count = ctx.count - 1
        if ctx.count == 0 then
            log.info(('_get_all_reference_maps ctx.count: %d, all response returned'):format(ctx.count))
            ctx.resolve()
        end
    end

    for _, v in ipairs(new_list) do
        local new_map = v.map
        if #new_map > 0 and ctx.maps_set[new_map] == nil then
            log.info(('_get_all_reference_maps call score_init: %s'):format(new_map))

            ctx.maps_set[new_map] = v
            ctx.count = ctx.count + 1

            sce.s.score_init(sce.s.readonly_map, 2, {
                ok = function(score)

                    xpcall(function()
                        local d
                        for k, v in pairs(score) do
                            if k:lower() == new_map:lower() then
                                d = v
                                break
                            end
                        end

                        if d then
                            log.info(("_get_all_reference_maps score[%s] not nil"):format(new_map))
                            local child_new_list = {}
                            for ref_name, _ in pairs(d) do
                                table.insert(child_new_list, {map = ref_name})
                            end

                            _get_all_reference_maps(ctx, child_new_list, all_map_Info)
                        else
                            log.info(('_get_all_reference_maps score[%s] is nil'):format(new_map))
                        end

                    end, log.error)

                    sub_count()
                end,
                error = function(code, reason)
                    log.error(('_get_all_reference_maps[%s] failed, code[%d] reason[%s]'):format(new_map, code, reason))
                    sub_count()
                end,
                timeout = function()
                    log.error(('_get_all_reference_maps[%s] failed, timeout'):format(new_map))
                    sub_count()
                end
            }, new_map)
        end
    end
end


local prompt_network_traffic_handler = nil

local function set_prompt_network_traffic_handler(f)
    prompt_network_traffic_handler = f
end

local need_prompt_download_size = false

local function set_need_prompt_download_size(enabled) -- 允许外部设置，说接下来要提示要更新的大小
    need_prompt_download_size = enabled
end

local update_call_back = {};
local update_finish_promise = {};

-----@return number, update_info_row[]
-----@param params get_update_download_info_param
local get_update_download_info = function(params)
    if lobby.vm_name() == 'StateGame' then
        local function get_download_info(callback)
            local update_info_seed = tostring(os.time() * 10000 + math_random(0, 9999))
            params.update_info_seed = update_info_seed
            update_call_back[update_info_seed] = callback
            base.game:send_broadcast('GameToApp-Get-Update-Download-Info', params)
        end
        local warp_get_download_info = co.wrap(get_download_info)
        return warp_get_download_info()
    else
        local update_list = download_manager:update_version_info(params)
        local total_need_download, download_dict, to_extract_bytes = download_manager:get_update_download_info(update_list)
        return total_need_download, download_dict, to_extract_bytes
    end
end

--- 删除已经下架的包
local delete_remove_package = function()
    local libs = local_version:get_all_lib()
    local list_str = table.concat(libs, ';')
    local url = ('%s/api/map/check-package-existence'):format(base.calc_http_server_address('updater', 9002))
    log.info("请求已经下架的包", url)
    local output = sce.httplib.create_stream();
    local code, status = co.call(sce.httplib.request, {
        method = 'post',
        url = url,
        json = {
            list = list_str
        },
        output = output,
        api_version = 0
    })
    if code ~= 0 or status ~= 200 then
        log.warn(("请求已经下架的包的包失败 url[%s] code[%s] status[%s]"):format(url, code, status))
        return
    end
    local ret_str = output:read()
    local suc, info = pcall(json.decode, ret_str);
    if not suc then
        log.warn('[delete_remove_package] 解析json 失败')
    else
        for package_name, item in pairs(info) do
            local name = item.alias or package_name
            local path = item.path
            local dir_path = tostring(update_folder_root / path / name)
            if api_pak_version_manager:is_multi_api(package_name) then --如果是多API的包 并且已经有路径
                local multi_path = api_pak_version_manager:get_multi_pak_path();
                if multi_path[package_name] then
                    path = multi_path[package_name];
                    dir_path = tostring(update_folder_root / path)
                end
            end
            dir_path = dir_path:gsub('//', '/')
            log.info(("准备删除已经下架的包 路径为[%s]"):format(dir_path))
            if io_exist_dir(dir_path) == false  then
                log.info("要删除的包路径不存在")
                local_version:delete_pak_all_version(package_name)
                local_version:save()
            else
                if io_remove(dir_path) == 0 then
                    log.info(("删除包成功 name[%s]"):format(package_name));
                    local_version:delete_pak_all_version(package_name)
                    local_version:save()
                else
                    log.info(("删除包失败 name[%s]"):format(package_name));
                end
            end
        end
        local_version:save()
    end
end


local function handle_update_progress_call_back(params)
    local seed = params['seed'];
    local progress_bind = update_call_back[seed];
    if progress_bind then
        if params.params then
            progress_bind[params.func_name](progress_bind, table.unpack(params.params))
        else
            progress_bind[params.func_name](progress_bind)
        end
    end
end


local function send_update_progress(seed, func_name, ...)
    local params = {};
    local argv = { ... };
    params['seed'] = seed;
    params['func_name'] = func_name;
    if #argv > 1 then
        log.info(base.json.encode(argv));
        table_remove(argv, 1);
        params['params'] = argv;
    end
    params['randomSeed'] = math_random(0, 99999999);
    base.game:send_broadcast('StateApplication-CallBack', params)
end

local function receive_update_finish(params)
    if update_finish_promise[params.seed] then
        co.async(function()
            local ret, err = update_finish_promise[params.seed]:try_set(params.status, nil);
        end)
    end
end

local function send_update_finish(seed, status)
    if seed == '' then
        return
    end
    local params = {}
    params['seed'] = seed
    params['status'] = status
    base.game:send_broadcast('StateApplication-Update-Finish', params)
end



local updating = false; --是否正在更新
local update_list = {};
local update_task
local loop_timer
local function start_check_wifi_state()
    if not platform.is_mobile() then
        return
    end
    local is_wifi = common.is_wifi()
    loop_timer = base.loop(500, function()
        if is_wifi and not common.is_wifi() and update_task then
            -- 从wifi变成了流量 暂停下载
            update_task:cancel()
        end
    end)
end

local function end_check_wifi_state()
    if loop_timer then
        loop_timer:remove()
        loop_timer = nil
    end
end

local function do_try_update(params)
    if lobby.vm_name() == 'StateGame' then                                          --统一在StateApp里更新
        local update_state_game_seed = tostring(os.time() * 10000 + math_random(0, 9999)); --游戏更新的随机数种子
        params.update_state_game_seed = update_state_game_seed;
        update_call_back[update_state_game_seed] = params.progress_bind;
        local name_list = {}
        for name, func in pairs(params.progress_bind) do --只保留名字
            name_list[name] = name;
        end
        params.progress_bind = name_list
        base.game:send_broadcast('StateGame-Update', params);
        -- 开始等待直到任务完成
        update_finish_promise[update_state_game_seed] = coroutine.promise()
        local pro = update_finish_promise[update_state_game_seed]
        local ret, err = pro:co_get(1000 * 60 * 60 * 5);
        if err then
            throw('update failed.')
            return
        end
        if ret then
            if ret == 'cancelled' then
                throw('cancelled')
                return
            end
            if ret ~= 'success' then
                throw('update failed.')
            end
            return
        end
        return;
    elseif lobby.vm_name() == 'StateApplication' then
        if params.update_state_game_seed then -- 游戏更新
            log.info("重定向更新")
            local new_progress_bind = DefaultProgressBind.new()
            for name, value in pairs(params.progress_bind) do
                local old_func = new_progress_bind[name]
                new_progress_bind[name] = function(...)
                    log.info("准备发送命令", params.update_state_game_seed, name, base.json.encode({ ... }))
                    send_update_progress(params.update_state_game_seed, name, ...)
                    if name ~= 'show' then -- 不显示
                        old_func(...)
                    end
                end
            end
            params.progress_bind = new_progress_bind;
        end
    end

    log.info('do_try_update updating:',updating)
    if updating then                              --当前已经在更新
        if not params.update_state_game_seed then --是app自己的更新
            params.update_state_app_seed = tostring(os.time() * 10000 + math_random(0, 9999));
        end
        table_insert(update_list, params)
        if params.update_state_game_seed then --如果是游戏转过来的更新 直接return就可以了 不需要在等函数返回 已经有另一处在等了
            return
        end
        -- 开始等待直到任务完成
        update_finish_promise[params.update_state_app_seed] = coroutine.promise()
        local pro = update_finish_promise[params.update_state_app_seed]
        local ret, err = pro:co_get(1000 * 60 * 60 * 5);
        if err then
            throw('update failed.')
            return
        end
        if ret then
            if ret ~= 'success' then
                throw('update failed.')
            end
            return
        end
        return;
    end
    updating = true;


    local mtx = file_mutex.create(local_version:path(update_folder_root))
    -- 先不生成文件，后面加个进程号防止卡死再打开
    --mtx:lock()

    game_uninstall:check() -- 检测之还有没卸载完的
    local_version:load(update_folder_root)
    if argv.has('no_update') then
        log.info('因为设置了-no_update, 所以不需要更新')
        mtx:unlock()
        updating = false
        return
    end

    local is_wifi = common.is_wifi()
    common.send_user_stat('is_wifi', tostring(is_wifi))

    start_check_wifi_state()
    local allow_update_binary = true
    if argv.has('binary_no_update') then
        log.info('ignore binary update')
        allow_update_binary = false
    elseif argv.has('url_launch') and platform.is_android() then
        log.info('android + url_launch so ignore binary update')        
        allow_update_binary = false
    end

    local binary = platform.binary():lower()
    local has_binary = false
    local final_update_list = params.maps
    local first_time_update_list = { "script", "appui", "gameui", "startup", "client_base" }
    if lobby.vm_name() == "StateEditor" then
        table_insert(first_time_update_list, "XDEditor")
        table_insert(first_time_update_list, "XDEditor_Startup")
        table_insert(first_time_update_list, "editorlauncher")
    else
        if common.get_platform() == 'Windows' then -- 只在window更新这个
            if argv.has('special_launcher') and argv.has('game') then
                table_insert(first_time_update_list, argv.get('game') .. '_winlauncher')
            else
                table_insert(first_time_update_list, "winlauncher")
            end
        end
    end

    -- 
    local final_to_download_list = {}
    local final_to_download_size = 0
    local final_to_extract_bytes = 0
    local need_reload = false
    if params.need_check_shader then
        local shader_table = get_update_shader_map()
        for i, v in ipairs(shader_table) do
            table.insert(final_update_list,v)
        end
    end

    -- 编辑器调试，大厅内更新（估计还有编辑器打开项目更新），forbidden_check_binary会是true
    -- 这时候强制不更新 二进制和其他需要重启虚拟机的包
    if not params.forbidden_check_binary then
        local maps_that_need_reload = get_update_reload_map(params.no_shader_map)
        local binary_download_list = {table_unpack(maps_that_need_reload)}
        if allow_update_binary then
            log.info(("will check binary[%s] version, local_version[%s]"):format(binary, local_version:get(binary)))
            table_insert(first_time_update_list, 1, binary)
        else
            log.info(("don't need update binary[%s] version, local_version[%s]"):format(binary, local_version:get(binary)))
        end

        for k, v in pairs(binary_download_list) do
            table_insert(final_update_list, v)
        end

        local first_list_flag = {} --标记一下第一次更新的包
        local need_reload_package = {}
        for k, v in pairs(first_time_update_list) do
            first_list_flag[v] = 1
            need_reload_package[v:lower()] = 1
        end

        local download_list_length = #final_update_list
        for k, v in pairs(final_update_list) do
            if first_list_flag[v] == 1 then
                final_update_list[k] = nil  --如果第一次更过了，第二次就忽略
            end
        end

        table.unique(final_update_list, 1, download_list_length)
        for i = #first_time_update_list, 1, -1 do --第一个是二进制 保证final_update_list的第一个也是二进制
            table_insert(final_update_list, 1, first_time_update_list[i])
        end

        final_to_download_size, final_to_download_list, final_to_extract_bytes = get_update_download_info {
            update_list = final_update_list,
            default_part = params.default_part or 1,
            suffix = nil,
            update_info_start = function()
                common.record_stage('start','UpdateInfoFirstStart')
            end,
            update_info_end = function()
                common.record_stage('start','UpdateInfoFirstEnd')
            end,
        }

        local binary_version_number = 0 -- 直接从具体地址下包的情景下用了
        for _, v in ipairs(final_to_download_list) do
            if need_reload_package[v.name:lower()] == 1 then
                need_reload = true
            end
            if v.name:lower() == binary then
                has_binary = true
                binary_version_number = v.version
                log.info(("binary need update. local_version[%s] online_version[%s]"):format(local_version:get(binary), v.version))
            end
            if need_reload and has_binary then
                break
            end
        end

        if argv.has('as_if_low_binary') then
            has_binary = true
            log.info('as if my binary version is low.')
        end

        -- 其实下面这段应该改成后台配，知道要二进制更新了去查下客户端积分，否则每次改这个信息还得发版
        -- 如果是手机端，在下载之前提示更新
        if has_binary then
            if platform.is_android() or platform.is_ios() then
                local platform_name = platform.is_android() and 'android' or 'ios'
                common.send_user_stat('binary_update', platform_name)
                mtx:unlock()
                local url = ("https://client-updater-url-%s.spark.xd.com/get_url?platform=%s&binary_name=%s&from=%s&game_name=%s&binary_version_number=%s&url_launch=%s")
                :format(
                    base.get_http_env(),
                    platform_name,
                    binary,
                    argv.get('from'),
                    argv.get('game'),
                    tostring(binary_version_number),
                    argv.has('url_launch') and '1' or ''
                )
                log.info(("请求二进制更新信息的url [%s]"):format(url))
                local output = sce.httplib.create_stream()
                local code, status_code = co.call(sce.httplib.request, {
                    method = 'get',
                    url = url,
                    output = output,
                })
                if code == 0 and status_code == 200 then
                    local content = output:read()
                    local suc, info = pcall(json.decode, content);
                    if suc then
                        local url = info['url']
                        local msg = info['msg']
                        confirm.message(base.i18n.get_text(msg))
                        if url ~= '' then -- 空字符串的话说明不用弹网页，弹个框就行了
                            common.open_url(url) -- 对战平台地址
                        end
                    else
                        throw(fmt("json decode binary update info failed url[%s]", url))
                    end
                else
                    throw(fmt("get binary update info failed. code[%s], status_code[%s]", code, status_code))
                end
                updating = false
                common.exit()
                return
            end
        end
        if has_binary then
            local index_to_keep = nil
            for i, v in ipairs(final_to_download_list) do
                if v.name:lower() == binary then
                    index_to_keep = i
                    break
                end
            end
            if index_to_keep then
                local binary_info = final_to_download_list[index_to_keep]
                final_to_download_size = binary_info.size
                final_to_extract_bytes = binary_info.original_size
                final_to_download_list = { binary_info }
                log.info("只更新二进制")
            end
        end
    else
        final_to_download_size, final_to_download_list, final_to_extract_bytes = get_update_download_info {
            update_list = final_update_list,
            default_part = params.default_part or 1,
            suffix = nil,
            is_first_to_update = 1,
            update_info_start = function()
                common.record_stage('start','UpdateInfoFirstStart')
            end,
            update_info_end = function()
                common.record_stage('start','UpdateInfoFirstEnd')
            end,
        }
    end

    -- 移动端，非wifi(或者外部另行指定)，要发生实质更新的话，给他弹个提示
    -- 再往前的话可能会发生先弹框，在更新二进制，很奇怪；再往后的话第一趟更新已经更掉了，所以只能放这儿（为此把forbidden_check_binary的判断给拆成两个了）

    -- 其实理想情况应该弄两个接口，一个查总尺寸，一个真更（但不要重复查服务器数据）
    if #final_to_download_list > 0 then
        log.info(fmt("first_to_download_list count: %s, size: %s", #final_to_download_list, final_to_download_size))
        if need_prompt_download_size or platform.is_mobile() and not is_wifi then
            log.info('need give a prompt if havent')
            local prompt_flag = common.get_value('prompt_update_need_network_traffic')
            if need_prompt_download_size or not prompt_flag or prompt_flag == '' then -- 整个进程的生命周期里，这个提示只提示一次（注意游戏没值是空字符串，编辑器目前必定空值），除非外部设置了
                log.info('prompt network traffic')                
                if prompt_network_traffic_handler then
                    local total_to_update_size = final_to_download_size
                    prompt_network_traffic_handler(total_to_update_size, is_wifi)
                    common.set_value('prompt_update_need_network_traffic', total_to_update_size) -- 进handler了才set_value（否则用户都没看到，不算
                    need_prompt_download_size = false
                end
            else
                log.info('have network traffic but been prompt before:', prompt_flag)
            end
        end
    end
    -- 
    log.info("更新原因:", params.forbidden_check_binary and 'normal' or 'binary')
    update_task = download_manager:do_update({
        update_list = final_update_list,
        progress_bind = params.progress_bind,
        default_part = params.default_part or 1,  -- 1: client, 2: server, 3: editor(即client+server)
        startup = params.startup,
        suffix = nil,
        game = params.game,
        reason = params.forbidden_check_binary and 'normal' or 'binary',
        to_download_list = final_to_download_list,
        to_extract_bytes = final_to_extract_bytes,
        total_download_size = final_to_download_size,
        status_callback = function(status)
            log.info(("status_callback status:%s"):format(status))
        end
    })

    -- 更新结束
    update_task.finish_promise:co_get()  -- 不关心返回值
    end_check_wifi_state()
    send_update_finish(params.update_state_game_seed or params.update_state_app_seed or '', update_task.status);  -- 发送更新结束的消息
    if update_task.status ~= 'success' then
        if update_task.status == 'cancelled' then
            throw('cancelled')
        else
            throw('update failed.')
        end
    end
    common.record_stage('start','UpdateFirstEnd')

    -- 如果是windows, 下载完之后再重启一下客户端强制更新
    if allow_update_binary and has_binary and platform.is_win() then
        common.send_user_stat('binary_update', 'win')
        local dir = common.get_app_dir()
        local launcher = dir .. argv.get('launcher')
        local cmdline = common.get_full_cmdline()
        log.info(('common.open_url("%s", "%s")'):format(launcher, cmdline))
        log.info('客户端已更新，请重启编辑器(即将弹框)')
        if __lua_state_name == 'StateEditor' then
            local message_box = require '@base.base.message_box'
            local show_message_box = co.wrap(message_box)
            show_message_box({
                content = '客户端已更新，请重启编辑器',
                btn_text = '重启编辑器',
                show_send_log = false,
                show_close = false
            })
            log.info('客户端已更新，不弹窗直接重启编辑器')
        else
            confirm.message(base.i18n.get_text('客户端已更新，请重启客户端'))
        end
        common.open_url(launcher, cmdline)
        log.info("common.force_exit()")
        mtx:unlock()
        updating = false
        common.force_exit()
        return
    end

    if need_reload and not platform.is_wx() and not platform.is_qq() then  -- 说明script/appui之类的东西有更新, 要reload
        mtx:unlock()
        log.info("更新到第一轮更新的包,重启虚拟机")
        updating = false
        reload.run({stop = stop}, _G.update_subpath)
        return
    else
        log.info('不需要更新启动页')
        base.game:send_broadcast('启动页更新完毕')
    end

    -- 到这里就算更新完成了 后面清理API包的过程中 如果来了更新请求就会卡住
    updating = false
    common.record_stage('start','UpdateSecondEnd')

    if common.reload_font_map then
        common.reload_font_map() --更新完成后重载一下font map
    end

    if #update_list > 0 then
        mtx:unlock()
        local p = table.remove(update_list, 1);
        local result, error_msg = xpcall(do_try_update, function(e)
            log.error("update.try_update更新失败, err:", tostring(e))
        end, p)
    else
        if not common.has_arg('compatible') then
            delete_remove_package();-- 删除下架的包
        end
        if lobby.vm_name() == 'StateApplication' then
            local_version:delete_game_useless_api_package()
            mtx:unlock()
        else
            mtx:unlock()
        end
    end

end

-- 套一层来捕获异常，报错直接判定为失败，更新状态改成false
local function try_update(params)
    try {
        function()
            do_try_update(params)
        end,
        catch = function(e)
            log.error(e)
            updating = false
            end_check_wifi_state()
            error(e)
        end
    }
end

--- 直接下载 不走update-info的接口 需要在外面把下载数据拼好
local function download_manager_update(params)
    if lobby.vm_name() == 'StateGame' then
        local update_state_game_seed = tostring(os.time() * 10000 + math_random(0, 9999))
        params.update_state_game_seed = update_state_game_seed
        update_call_back[update_state_game_seed] = params.progress_bind
        local name_list = {}
        for name, func in pairs(params.progress_bind) do --只保留名字
            name_list[name] = name;
        end
        params.progress_bind = name_list
        -- 开始等待直到任务完成
        update_finish_promise[update_state_game_seed] = coroutine.promise()
        base.game:send_broadcast('GameToApp-Download-Manager-Update', params)
        local pro = update_finish_promise[update_state_game_seed]
        local ret, err = pro:co_get(1000 * 60 * 60 * 5);
        if err then
            throw('update failed.')
            return
        end
        if ret then
            if ret == 'cancelled' then
                throw('cancelled')
                return
            end
            if ret ~= 'success' then
                throw('update failed.')
            end
        end
    elseif lobby.vm_name() == 'StateApplication' then
        if params.update_state_game_seed then -- 游戏更新
            log.info("重定向更新")
            local new_progress_bind = DefaultProgressBind.new()
            for name, value in pairs(params.progress_bind) do
                local old_func = new_progress_bind[name]
                new_progress_bind[name] = function(...)
                    log.info("准备发送命令", params.update_state_game_seed, name, base.json.encode({ ... }))
                    send_update_progress(params.update_state_game_seed, name, ...)
                    if name ~= 'show' then -- 不显示
                        old_func(...)
                    end
                end
            end
            params.progress_bind = new_progress_bind;
        end
        -- 判断是否已下载
        local_version:load(update_folder_root)
        local need_update_list = {}
        for i, download_item in ipairs(params.to_download_list) do
            local version, suffix = local_version:get(download_item.name)
            if version == download_item.version then
                log.info('exist file skip download :',download_item.name)
            else
                table.insert(need_update_list, download_item)
            end
        end
        if #need_update_list > 0 then
            params.to_download_list = need_update_list
            local task = download_manager:do_update(params)
            task.finish_promise:co_get()
            if task.status ~= 'success' then
                throw('update failed.')
            end
            send_update_finish(params.update_state_game_seed or '', task.status)  -- 发送更新结束的消息
        else
            send_update_finish(params.update_state_game_seed or '', 'success')
        end
    end
end

local function save()
    if platform.is_web() then
        co.async(function()
            log.info('序列化更新资源')
            local serialize = co.wrap(io_serialize)
            serialize()
            log.info('序列化更新资源完毕')
        end)
    else
        log.info('非web不需要序列化')
    end
end



base.game:event('广播', function(...) --接收广播
    local _, type, params = table.unpack({ ... });
    if type == 'StateGame-Update' then
        if lobby.vm_name() == 'StateApplication' then --统一在StateApp里更新
            co.async(function()
                try {
                    function()
                        try_update(params)
                    end,
                    catch = function(e)
                        -- 捕获异常直接判失败
                        log.error(e)
                        updating = false
                        send_update_finish(params.update_state_game_seed,'failed')
                    end
                }
            end)
        end
    elseif type == 'GameToApp-Download-Manager-Update' then
        if lobby.vm_name() == 'StateApplication' then --统一在StateApp里更新
            co.async(function()
                try {
                    function()
                        download_manager_update(params)
                    end,
                    catch = function(e)
                        -- 捕获异常直接判失败
                        log.error(e)
                        send_update_finish(params.update_state_game_seed,'failed')
                    end
                }
            end)
        end
    elseif type == 'StateApplication-CallBack' then
        if lobby.vm_name() == 'StateGame' then --调用StateGame里的函数
            handle_update_progress_call_back(params);
        end
    elseif type == 'StateApplication-Update-Finish' then
        receive_update_finish(params);
    elseif type == 'GameToApp-Get-Update-Download-Info' then
        if lobby.vm_name() == 'StateApplication' then
            co.async(function()
                try {
                    function()
                        local total_need_download, download_dict, to_extract_bytes = get_update_download_info(params)
                        base.game:send_broadcast('AppToGame-Get-Update-Download-Info',{
                            update_info_seed = params.update_info_seed,
                            total_need_download = total_need_download,
                            download_dict = download_dict,
                            to_extract_bytes = to_extract_bytes
                        })
                    end,
                    catch = function(e)
                        base.game:send_broadcast('AppToGame-Get-Update-Download-Info',{
                            update_info_seed = params.update_info_seed,
                            total_need_download = 0,
                            download_dict = nil,
                            to_extract_bytes = 0
                        })
                    end
                }
            end)
        end
    elseif type == 'AppToGame-Get-Update-Download-Info' then
        if lobby.vm_name() == 'StateGame' then
            if update_call_back[params.update_info_seed] then
                update_call_back[params.update_info_seed](params.total_need_download,params.download_dict,params.to_extract_bytes)
                update_call_back[params.update_info_seed] = nil
            end
        end
    end
end)
return {
    stop = stop,
    save = save,
    try_update = try_update,
    set_extra_maps_that_need_reload = set_extra_maps_that_need_reload,
    get_update_download_info = get_update_download_info,
    add_resource_path = add_resource_path,
    set_prompt_network_traffic_handler = set_prompt_network_traffic_handler,
    set_need_prompt_download_size = set_need_prompt_download_size,
    get_shader_update_map = get_shader_update_map,
    get_update_shader_map = get_update_shader_map,
    download_manager_update = download_manager_update,
}
