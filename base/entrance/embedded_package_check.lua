local co = require 'base.co'
local json = require 'json'
local argv = require 'base.argv'
local local_version = require 'update.core.local_version'
local path = require 'base.path'
local platform              = require 'base.platform'
local store_value               = require 'base.store_value'
local ProgressBind = nil
local installed_count = 0
local to_install_count = 0
local now_extract_count = 0
local total_extract_count = 0
local update_progress_dirty = false
local update_handler = nil
local tostring = tostring
local string_gsub = string.gsub

local function display_current_progress()
    if ProgressBind and update_progress_dirty then
        ProgressBind:set_extract_status({
            installed_count = installed_count,
            to_install_count = to_install_count,
            now_extract_count = now_extract_count,
            total_extract_count = total_extract_count,
        })
        update_progress_dirty = false
    end
end

local function unzip_progress(total, current, _)
    now_extract_count = current
    total_extract_count = total
    update_progress_dirty = true
end

local function get_version_info(version_json_path)
    local code, buff = io.read(version_json_path)
    if code ~= 0 then
        return nil
    end
    return json.decode(buff)
end

local function send_extract_embedded_pacakge_error(error_msg)
    log.error(error_msg)
    common.send_http_user_stat(_G.update_subpath, 'extract_embedded_package_error', error_msg)
end

local function get_parent_path(path)
    for i = #path, 1, -1 do
        if path:sub(i, i) == '/' then
            return path:sub(1, i)
        end
    end
    return ''
end

local function async_extract_embedded_package(src_package_path, dst_package_path, cache_package_path, packet_type)
    if not io.exist_file(src_package_path) then
        send_extract_embedded_pacakge_error(string.format('embedded pacakge[%s] not exists', src_package_path))
        return false
    end
    if not io.copy(src_package_path, cache_package_path) then
        send_extract_embedded_pacakge_error(string.format('copy embedded pacakge[%s=>%s] failed', src_package_path, cache_package_path))
        return false
    end
    -- 删除目标路径下
    if io.exist_dir(dst_package_path) or io.exist_file(dst_package_path) then
        local code = io.remove(dst_package_path)
        if code ~= 0 then
            log.error(string.format('remove package file[%s] failed, error code:%s', dst_package_path, code))
        end
    end
    if packet_type == 1003 then
        -- 单文件包，解压到dst_package_path上一级路径
        dst_package_path = get_parent_path(dst_package_path)
        log.info('single file package => move to parent path:', dst_package_path)
    end
    -- 创建package路径
    if not io.create_dir(dst_package_path) then
        if not io.exist_dir(dst_package_path) then
            send_extract_embedded_pacakge_error(string.format('create package dir[%s] failed', dst_package_path))
        end
    end
    local result = true
    local code = co.call(io.unzip_file, cache_package_path, dst_package_path, unzip_progress)
    if code ~= 0 then
        result = false
        send_extract_embedded_pacakge_error(string.format('extract embedded package[%s=>%s] failed, error code: %d', cache_package_path, dst_package_path, code))
    end
    code = io.remove(cache_package_path)
    if code ~= 0 then
        result = false
        log.error(string.format('remove embedded cache package[%s] failed, error code: %d', cache_package_path, code))
    end
    return result
end

local function check_package(finish_callback, inProgressBind)
    -- 兼容一下旧的包，避免脚本和二进制更新顺序导致坏了
    if not app.get_embedded_package_info then
        log.error('app.get_embedded_package_info nil')
        finish_callback()
        return
    end

    local package_info = app.get_embedded_package_info()
    if not package_info then
        log.warn('embedded package info is nil')
        finish_callback() 
        return
    end
    -- 添加规则 一次启动只检查一遍内嵌包 
    if store_value.get_store_bool('has_check_embedded_package') then
        log.info("has check embedded package")
        finish_callback()
        return
    end
    store_value.set_store_value('has_check_embedded_package', true)
    log.info("check embedded package")

    ProgressBind = inProgressBind

    -- 初始化进度条，显示初始进度为0
    if ProgressBind then
        installed_count = 0
        to_install_count = #package_info
        now_extract_count = 0
        total_extract_count = 0
        update_progress_dirty = true
        ProgressBind:reset()
        ProgressBind:show(true)
        display_current_progress()

        -- 每帧有修改了在更新进度
        update_handler = base.game:event('游戏-更新', function()
            display_current_progress()
        end)
    end

    -- Android: /pak/Res/embedded_packages
    -- iOS: Container/${uuid}/Res/embedded_packages
    -- 这里很坑，api故意把GetProgramDir返回的'/'去掉了
    local embedded_packages_dir = io.get_app_dir() .. '/Res/embedded_packages/'
    -- PC 平台的内嵌包,不是放在Res目录下的
    if platform.is_win() then
        embedded_packages_dir = io.get_app_dir() .. '/embedded_packages/'
    end

    -- Android: /data/data/${appid}/Update/e.master.sce.xd.com/
    -- iOS: Container/${uuid}/Update/e.master.sce.xd.com/
    local update_dir = io.get_root_dir() .. 'Update/' .. _G.update_subpath .. '/'

    -- 内嵌包的cache目录，因为android /apk目录不能直接解压，要先拷贝到非/apk目录才能解压
    local embedded_pacakges_cache_dir = update_dir .. 'embedded_cache/'
    if not io.exist_dir(embedded_pacakges_cache_dir) then
        if not io.create_dir(embedded_pacakges_cache_dir) then
            send_extract_embedded_pacakge_error(string.format('create embedded package dir[%s] failed', embedded_pacakges_cache_dir))
        end
    end

    local_version:load(path(update_dir))

    co.async(function()
        local valid_package_count = 0
        local replace_package_count = 0
        local replace_embedded_package_count = 0
        for i = 1, #package_info do
            -- 每个pakcage的进度初始值
            installed_count = i
            now_extract_count = 0
            total_extract_count = 1
            update_progress_dirty = true

            -- 需要判断一下info的合法性，容错一下发版本引入错误的version
            local info = package_info[i] or {}
            local extract_info = {}
            if info.json_str then
                local ret, _extract_info = pcall(base.json.decode, info.json_str)
                if ret then
                    extract_info = _extract_info or {}
                end
            end
            info.json_str = nil
            if info.name and info.extension and info.path and info.version and info.suffix then
                local dst_package_name = info.alias or info.name
                local src_package_path = embedded_packages_dir .. info.name .. info.extension
                local dst_package_path = update_dir .. info.path .. '/' .. dst_package_name

                if info.api_version ~= -1 then
                    -- 多版本的API包 把输出的路径 改掉成 _multi_api/ 旧路径 /包名/版本号/
                    local prefix = string_gsub(info.path, "Res", "Res/_m") .. '/' .. info.name
                    local newPath = update_dir .. prefix .. '/' .. tostring(info.version) .. '/' .. info.name
                    dst_package_path = string_gsub(newPath, '//', '/')
                end

                local cache_package_path = embedded_pacakges_cache_dir .. info.name .. info.extension
                -- 没有version认为版本为0
                local version_id, suffix = local_version:get(info.name)
                -- 检测：
                -- 1.内嵌包的版本>Update包的版本，更新VERSION.JSON
                -- 2.内嵌包的版本==Update包的版本，但是suffix不一致，更新VERSION.JSON
                log.info("内嵌包信息", json.encode(info))
                local is_multi_api = info.api_version ~= -1
                local check_need_extract = function()
                    if is_multi_api then
                        if local_version:has(info.name, info.version) then
                            return false
                        end
                    else
                        if version_id >= info.version then
                            return false
                        end
                    end
                    return true
                end
                if check_need_extract() then
                    log.info('extract embedded package', src_package_path, dst_package_path, cache_package_path)
                    -- 如果是nessary包，lua不负责解压，解压部分由C++做了（C++要保证一定解压成功，实际上这种包如果解压失败了，后面的流程全都是有问题的）
                    if not info.nessary then
                        if async_extract_embedded_package(src_package_path, dst_package_path, cache_package_path, extract_info.packet_type) then
                            replace_package_count = replace_package_count + 1
                            local_version:set(info.name, info.version, info.suffix)
                        end
                    elseif info.pre_extract then
                        log.info('skip extract nessary embedded package', info.name, info.version, info.suffix)
                        replace_embedded_package_count = replace_embedded_package_count + 1
                        log.info("设置内嵌包版本号", info.name, info.version, info.suffix)
                        local_version:set(info.name, info.version, info.suffix)
                    else
                        -- 这种说明nessary的包在C++时解压失败 ,非多API包 本来就可能不解压
                        if info.api_version == nil or info.api_version == -1 or version_id == 0 then
                            local tag = argv.get('tag')
                            if tag ~= 'formal' and tag ~= '' then -- 测试环境只警告一下
                                log.warn('nessary embedded package pre extract failed', info.name, info.version, info.suffix)
                            else
                                log.error('nessary embedded package pre extract failed', info.name, info.version, info.suffix)
                            end
                        end
                    end
                end
                valid_package_count = valid_package_count + 1
            end
        end
    
        -- 统计一下内嵌包的解压情况
        log.info(string.format('embedded package stats: total pk count(%d), valid pk count(%d), replace pk count(%d), replace embedded pk count(%d)', #package_info, valid_package_count, replace_package_count, replace_embedded_package_count))
    
        -- 如果有非法的内嵌包，一定要发统计
        local invalid_package_count = #package_info - valid_package_count
        if invalid_package_count > 0 then
            send_extract_embedded_pacakge_error('invalid embedded package count: ' .. invalid_package_count)
        end

        -- 这里记得移除update事件，避免后面造成不必要的开销
        if update_handler then
            update_handler:remove()
            update_handler = nil
        end

        local_version:save()

        -- 最后一定要把进度条隐藏，否则进大厅进度条还在显示
        if ProgressBind then
            ProgressBind:show(false)
        end

        finish_callback()
    end)
end

return check_package
