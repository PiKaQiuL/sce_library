-- 自动测试相关
local upload_log = require 'base.upload_log'
local argv = require 'base.argv'

local check_test_id = function(test_id)
    if not argv.has('test_id') then
        log.warn('no test_id provided in cmdline.')
        return false
    end
    local test_id = argv.get('test_id')
    local test_map, timestr = test_id:match('([^%s]+)_([0-9]+)')
    if not (test_map and timestr and #timestr == 14) then
        log.warn('test_id not follow format [test_map]_[yyyymmddhhmmss]')
        return false
    end
    return true
end

-- 在所有capture结束之后调用，上传log到数据库
local send_autotest_log = function(exit)
    local test_id = argv.get('test_id')
    local test_map, timestr = test_id:match('([^%s]+)_([0-9]+)')
    local year, month, day = string.sub(timestr, 1, 4), string.sub(timestr, 5, 6), string.sub(timestr, 7, 8)
    local hour, min, sec = string.sub(timestr, 9, 10), string.sub(timestr, 11, 12), string.sub(timestr, 13, 14)
    local launch_time = ('%s-%s-%s %s:%s:%s'):format(year, month, day, hour, min, sec)
    local finish_cb = function(log_zip_name, log_url)
        log.info('log url in send_autotest_log is:' .. log_url)
        if test_id then
            log.info('sending autotest_log with test_id: ' .. test_id)
            common.send_autotest_log(test_id, log_url, test_map, launch_time)
        end
        if exit then
            log.info('autotest exit in 5 sec.')
            base.wait(5000, function()
                common.exit()
            end)
        end
    end
    upload_log('autotest', finish_cb)
end

local profile_desc = nil
local set_profile_desc = function(desc)
    log.info(('更新打点描述为[%s]'):format(json.encode(desc)))
    profile_desc = desc
end

if __lua_state_name == 'StateGame' and (argv.has('editor_server_debug') or argv.has('load_replay')) then
    local profile_cnt = 0 -- 记录触发profile的次数，根据这个次数来显示不同的打点描述UI
    local prompt_templ = base.ui.label {
        font = {
            size = 36,
            color = '#ff0000',
            bold = 1
        },
        color = '#00ff00',
        text = '',
        show = false,
        bind = {
            text = 'content',
            show = 'visible'
        }
    }
    local _, prompt_bind = base.ui.create(prompt_templ)

    --按Ctrl+句号号触发profile回调
    local cnt = 0
    local cmds = { 'Ctrl', '.' }
    base.game:event('按键-按下', function(trg, key)
        cnt = cnt + 1
        if key == cmds[cnt] then
            if cnt == #cmds then
                profile_cnt = profile_cnt + 1
                coroutine.async(function()
                    -- 一方游戏里场景瞬息万变，所以打三次求平均是有偏估计，所以只打一次。
                    print(string.format('打点%d', profile_cnt))
                    local desc = '打点描述'
                    if profile_desc and profile_desc[profile_cnt] then
                        desc = profile_desc[profile_cnt]
                    end
                    prompt_bind.content = string.format('打点%d,%s', profile_cnt, desc)
                    prompt_bind.visible = true
                    common.write_profile_detail(desc, false) -- replay里已经记录key事件了，所以这里profile不用写进协议
                    coroutine.sleep(1000)
                    prompt_bind.visible = false
                end)
            end
        else
            cnt = 0
        end
    end)
end



log.info("全部命令行", common.get_full_cmdline())
log.info("状态机", __lua_state_name)
log.info("是否有ai_test参数", argv.has('ai_test'))
log.info("是否有auto_test_download_and_play 参数", argv.has('auto_test_download_and_play'))
if __lua_state_name == 'StateApplication' and argv.has('auto_test_download_and_play') then
    -- 58ms 解压前 630 KB的文件 解压后 912 505 B
    local timer = 10000
    local count = 0
    local tot_data = {
        updating_tot_fps = 0,
        updating_tot_fps_cont = 0,

        updating_tot_ping = 0,
        updating_tot_ping_cont = 0,

        after_updating_tot_fps = 0,
        after_updating_tot_fps_cont = 0,

        after_updating_tot_ping = 0,
        after_updating_tot_ping_cont = 0,

        更新平均fps = 0,
        更新延时 = 0,

        正常fps = 0,
        正常延时 = 0,
    }
    local updaing_fps_list = {}
    local updating = false
    local aferupdating = false
    log.info("开始测试边玩边下载");
    local count_detal = 1000
    base.game:event('游戏-更新', function(_, update_delta)
        timer = timer + update_delta
        if timer > count_detal then
            local fps = common.get_current_fps() or 0
            local ping = common.get_current_ping()
            local jank = common.get_jank_count()
            count = count + 1
            log.info(string.format("测试边玩边下载每10输出一次自动测试数据 次数[%d] fps[%d] ping[%d] jank[%d]", count, fps, ping, jank))
            if updating then
                tot_data.updating_tot_fps = tot_data.updating_tot_fps + fps
                tot_data.updating_tot_fps_cont = tot_data.updating_tot_fps_cont + 1
                tot_data.更新平均fps = tot_data.updating_tot_fps / tot_data.updating_tot_fps_cont
                table.insert(updaing_fps_list, fps)
                if ping ~= 0 then
                    tot_data.updating_tot_ping = tot_data.updating_tot_ping + ping
                    tot_data.updating_tot_ping_cont = tot_data.updating_tot_ping_cont + 1
                    tot_data.更新延时 = tot_data.updating_tot_ping / tot_data.updating_tot_ping_cont
                end
            end

            if aferupdating then
                tot_data.after_updating_tot_fps = tot_data.after_updating_tot_fps + fps
                tot_data.after_updating_tot_fps_cont = tot_data.after_updating_tot_fps_cont + 1
                tot_data.正常fps = tot_data.after_updating_tot_fps / tot_data.after_updating_tot_fps_cont
                if ping ~= 0 then
                    tot_data.after_updating_tot_ping = tot_data.after_updating_tot_ping + ping
                    tot_data.after_updating_tot_ping_cont = tot_data.after_updating_tot_ping_cont + 1
                    tot_data.正常延时 = tot_data.after_updating_tot_ping / tot_data.after_updating_tot_ping_cont
                end
            end

            log.info("统计数据", base.json.encode(tot_data))
            timer = timer - count_detal;
            local test_update = function()
                local update = require 'update'
                local params = {}
                params["forbidden_check_binary"] = false
                local maps = {}
                table.insert(maps, "endlesscorridors")
                local DefaultProgressBind = require 'base.progress'.DefaultProgressBind
                local progress_bind       = DefaultProgressBind.new()
                params["progress_bind"]   = progress_bind
                params["reason"]          = "test_download_and_play"
                params["startup"]         = false
                params['maps']            = maps
                local ts                  = os.time() -- 获取当前时间的时间戳
                local formatted_time      = os.date("%Y-%m-%d %H:%M:%S", ts)
                log.info("开始测试更新", formatted_time);
                updating = true
                local co = require 'base.co'
                co.async(function()
                    update.try_update(params)
                    log.info("测试更新结束")
                    aferupdating = true
                    updating = false
                    table.sort(updaing_fps_list)
                    log.info("更新过程中帧率列表", base.json.encode(updaing_fps_list))
                end)
            end

            if count == 180 then --三分钟后卸载旧游戏
                local delete = require '@base.uninstall.delete'
                local progress = function(name, cur, tot)
                    log.info("卸载中 进度", name, string.format("%.2f%%", cur / tot * 100));
                end
                local update_end = function(name, res, reuslt)
                    log.info("卸载结束", name, res, reuslt);
                end
                local game_name = "endlesscorridors"
                local co = include '@base.base.co'
                co.async(function()
                    local res = delete:delete(game_name, progress, update_end);
                    log.info("卸载结果", res);
                    co.sleep(1000) -- 一秒后开始测试更新
                    common.remove_argv('no_update')
                    test_update()
                end)
            end
        end
    end)
end


local test_lz_zip = function ()
    local io_serialize = io.serialize
    local io_exist_dir = io.exist_dir
    local io_exist_file = io.exist_file
    local io_create_dir = io.create_dir
    local io_copy_to_folder = io.copy_to_folder
    local io_attribute_type = io.attribute_type
    local io_read = io.read
    local io_copy = io.copy
    local io_copy_not_decode = io.copy_not_decode
    local base_json_decode = base.json.decode
    local io_file_size = io.file_size  -- 做一下兼容...等二进制发出去后去掉or后面的
    local io_list = io.list
    local io_remove = io.remove
    local io_rename = io.rename
    local zip_file = io.test_lz4_zip_file
    local unzip_file = io.test_lz4_unzip_file
    local old_unzip = io.test_old_unzip_file
    local co                    = require 'base.co'
    local path                 = require 'base.path'
    local root_path                 = path(io.get_root_dir())
    
    local get_file_md5 = common.get_file_md5
    -- local input_path = [[C:\Users\XINDONG\Desktop\test_lz4\mob\folder]]
    -- local output_path = [[C:\Users\XINDONG\Desktop\test_lz4\mob\result.tar.lz4]]

    -- zip_file(input_path, output_path)
    local fmt = fmt
    local version_path  = root_path / 'Update' / _G.update_subpath
    local orgin_name    = 'all_pak.7z'
    local download_path = tostring(version_path / orgin_name)
    log.info("ClearLove下载路径", download_path)
    local true_md5 = 'e5c0134818099d0ec4206b489b701c3d'
    local has = false
    if io_exist_file(download_path) then
        if get_file_md5(download_path) == true_md5 then
            has = true
        else
            io_remove(download_path)
        end
    end
    if not has then
        log.info("开始下载")
        local url = 'https://sce-maps-pd.oss-cn-shanghai.aliyuncs.com/0604unziptest/jiehunxiao.7z'
        local http = sce.httplib.create()
        local code, status = co.call(http.request, http, {
            url = url,
            method = 'GET',
            output = download_path
        })
    else
        log.info("已经存在包")
    end
    if get_file_md5(download_path) ~= true_md5 then
        log.info("下载错误", get_file_md5(download_path))
        return
    end
    
    log.info("下载完成")
    local all_folder =  tostring(version_path / 'all_folder')
    old_unzip(download_path, all_folder)

    local begin  = common.utc_time();
    -- local input_path = [[C:\Users\XINDONG\Desktop\test_lz4\mob.7z]]
    -- local output_path = [[C:\Users\XINDONG\Desktop\test_lz4\foler]]

    -- old_unzip(input_path, output_path)
    local prefix = tostring(version_path / 'all_folder'/'解混淆的包')

    for i = 1, 7, 1 do
        local file7zPath = prefix .. '/' .. tostring(i) .. '_small.7z'
        local target7z   = prefix .. '/' .. tostring(i) .. 'small'
        local filelzPath = prefix .. '/' .. tostring(i) .. '_max_small.tar.lz4'
        local targetlz   = prefix .. '/' .. tostring(i) .. 'lz'
        begin            = common.utc_time();
        local rpt        = 1
        if i > 4 then
            rpt = 50
        end
        for j = 1, rpt, 1 do
            unzip_file(filelzPath, targetlz)
        end
        log.info("解压lz", i, "时间", common.utc_time() - begin)
        begin = common.utc_time();
        for j = 1, rpt, 1 do
            old_unzip(file7zPath, target7z)
        end

        log.info("解压7z", i, "时间", common.utc_time() - begin)
    end
    log.info("花费时间", common.utc_time() - begin)
end

if __lua_state_name == 'StateApplication' and argv.has('test_lz4_unzip_file') then
    log.info("测试解压效果")
    local co                    = require 'base.co'
    co.async(function ()
        test_lz_zip()
    end)
    
end
return {
    -- GPU测试
    check_test_id = check_test_id,
    send_autotest_log = send_autotest_log,
    capture = common.trigger_rdoc_capture,

    -- CPU性能测试
    set_profile_desc = set_profile_desc
}
