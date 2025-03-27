local path = require 'base.path'
local lobby = require 'base.lobby'
local util = require 'base.util'
local tostring = tostring
local local_version = require 'update.core.local_version'
local api_pak_version_manager = require 'update.core.local_api_pak_version'
local root_path = io.get_root_dir()
local version_path = path(root_path) / 'Update' / _G.update_subpath
local base_json_encode = base.json.encode
local base_json_decode = base.json.decode
local io_list = io.list
local io_write = io.write
local io_read = io.read
local string_gsub = string.gsub
local string_find = string.find
local io_exist_dir = io.exist_dir
local io_exist_file = io.exist_file
local io_remove = io.remove
local generate_count = require 'uninstall.generate_count'
local generate = require 'uninstall.generate'
local co = require '@base.base.co'
local file_name = 'VERSION.JSON'
local is_uninstalling = false

local game_uninstall = {}

local uninstall_callback = {}
local request_id = 0

local function default_tag()
    local tag = common.get_argv('tag')
    if not tag or tag == '' then
        tag = 'formal'
    end
    return tag
end

function game_uninstall:update_path(tag)
    if not tag then
        tag = default_tag()
    end
    local update_path = _G.IP
    if tag == 'test' then
        update_path = update_path..'_test'
    end
    return root_path .. '/Update/' .. update_path
end

function game_uninstall:check()
    local_version:load(version_path)
    if local_version:get_flag() == 1 then
        local_version:do_uninstall()
        local_version:set_flag(nil)
        local_version:save()
    end
end

--兼容老接口
function game_uninstall:delete(game_name, progress, result)
    log.info("game_uninstall:delete begin uninstall gamename",game_name);
    generate_count:init() -- 卸载前 重新更新计数
    log.info("game_uninstall:delete generate_count finish");
    local_version:load(version_path)
    local_version:uninstall_prepare(game_name)
    local res = local_version:do_uninstall(progress)
    local_version:set_flag(nil)
    local_version:save()
    log.info("game_uninstall:delete end uninstall result",res and 'success' or 'failed');
    if result then
        result(game_name, res, res and 'success' or 'failed')
    end
    if res then
        return true
    else
        return false
    end
end

--- 检测是否有上一次没卸载完的
function game_uninstall:check_uninstall_undone()
    if lobby.vm_name() == 'StateGame' then
        base.game:send_broadcast('GameToApp-Check-Uninstall', { request_id = request_id })
    else
        local game_need_to_delete_path = self:update_path('formal') .. '/app_need_to_delete.json'
        if io_exist_file(game_need_to_delete_path) then
            self:do_uninstall('formal')
        end
        game_need_to_delete_path = self:update_path('test') .. '/app_need_to_delete.json'
        if io_exist_file(game_need_to_delete_path) then
            self:do_uninstall('test')
        end
    end
end

--- [转发Application处理]执行卸载
--- 只提供给app_box用
function game_uninstall:uninstall(map_list, result)
    log.info('[uninstall] do_uninstall',json.encode(map_list))
    if lobby.vm_name() == 'StateGame' then
        request_id = request_id + 1
        uninstall_callback[request_id] = result
        base.game:send_broadcast('GameToApp-Uninstall', { request_id = request_id, map_list = map_list })
    elseif lobby.vm_name() == 'StateApplication' then
        if is_uninstalling then
            log.info('[uninstall] 卸载失败 当前正在卸载中')
            --直接拦截 卸载失败
            if result then
                result('failed')
            end
            return
        end
        co.async(function()
            for i, v in ipairs(map_list) do
                if self:map_is_exist(v.tag, v.game_id) then
                    self:init_local_game_update_info(v.tag)
                    generate:calculate_count(v.tag)
                    self:uninstall_prepare(v.tag, v.game_id)
                    self:do_uninstall(v.tag)
                end
            end
            if result then
                result('success')
            end
        end)
    end
end

function game_uninstall:is_uninstalling()
    return is_uninstalling
end

function game_uninstall:set_is_uninstalling(value)
    is_uninstalling = value
    if lobby.vm_name() == 'StateApplication' then
        base.game:send_broadcast('AppToGame-Uninstall-State', { state = is_uninstalling })
    end
end

---计算要删除的资源
function game_uninstall:uninstall_prepare(tag, game_id)
    local game_info = generate:get_game_info(tag, game_id)
    if game_info then
        local delete_info = {}
        delete_info["#game_name"] = game_id
        for i, v in pairs(game_info) do
            local count = generate:get_count(tag, v.name, v.version)
            -- global_default不删
            if count == 1 and v.name ~= 'global_default' then
                local item = generate:get_item(tag, v.name, v.version)
                delete_info[v.name] = { path = item.path, alias = item.alias, packet_type = item.packet_type, version = item.version }
            end
        end
        -- 加入游戏自身包
        delete_info[game_id] = { path = 'Res/maps' }
        local p = self:update_path(tag) .. '/app_need_to_delete.json'
        local data = base_json_encode(delete_info)
        io_write(tostring(p), data)
    end
end

function game_uninstall:do_uninstall(tag)
    local game_need_to_delete_path = self:update_path(tag) .. '/app_need_to_delete.json'
    local result, content = io_read(tostring(game_need_to_delete_path))
    if result ~= 0 then
        return
    end
    self:set_is_uninstalling(true)
    local delete_info = base_json_decode(content)
    local game_name = delete_info['#game_name']
    log.info('[uninstall] 开始卸载',game_name)
    local version_json = self:load_version_json(tag)
    for name, info in pairs(delete_info) do
        if name == "#game_name" then
            --什么都不做
        else
            local remove_path_name = info.alias or name --优先用别名
            local path = self:update_path(tag) .. '/' .. info.path .. '/'
            path = string_gsub(path, '//', '/')
            if not string_find(path, "/_m/") then --多API的包不要加文件名 要连版本号一起删掉
                path = path .. remove_path_name
            end
            local state = 'success'
            if io_exist_dir(path) then
                --需要释放pak，地图自身和依赖库
                --进过装备局、游戏局再退出来不会释放pak，C++那边是等开下一局的时候才会释放
                if name == game_name then
                    if app.release_pak then
                        app.release_pak(name)
                    end
                elseif info.packet_type == 2 or info.packet_type == 4 then
                    if app.release_pak then
                        app.release_pak(name..'-'..info.version)
                    end
                end
                local result = io_remove(path)
                if result ~= 0 then
                    state = 'failed'
                end
            else
                log.info("文件不存在", path)
            end
            log.info("卸载游戏delete: " .. path .. "删除状态: " .. state)
            if string_find(path, "/_m/") then
                log.info("卸载游戏删除游戏多API包", name, base_json_encode(info), path, io_exist_dir(path))
                local current_version = version_json[name]
                if type(current_version) == 'table' then
                    current_version.version[tostring(info.version)] = nil
                    if util.elem_count(current_version.version) == 0 then
                        version_json[name] = nil
                    end
                end
            else
                version_json[name] = nil
            end
            if tag == default_tag() then
                -- 如果卸载的是当前环境游戏，要同步删除update那边读到的缓存
                if string_find(tostring(path), "/_m/") then
                    local_version:delete_pak(name, info.version) -- 多API包专用接口
                else
                    local_version:delete_pak_all_version(name)   -- 非多API包 用这个接口
                end
            end
        end
    end
    local version_json_path = self:update_path(tag)..'/'..file_name
    local data = base_json_encode(version_json)
    if not io_write(version_json_path, data) then
        error(('[uninstall] write local_version failed. path[%s], data[%s]'):format(version_json_path, data))
    end
    io_remove(game_need_to_delete_path)
    generate:remove_game_info(tag, game_name)
    log.info('[uninstall] 卸载完成',game_name)
    self:set_is_uninstalling(false)
end

function game_uninstall:load_version_json(tag)
    local path = self:update_path(tag)..'/'..file_name
    local result, content = io_read(path)
    if result == 0 then
        local version_json, error_info = common.json_decode(content)
        if version_json then
            return local_version:get_format_version(version_json)
        end
    end
end

--- [转发Application处理]获取所有可卸载的地图
--- 这个转发处理是因为计算游戏大小需要请求一遍所有游戏的update-info，可以省一次请求
--- 包括 formal 环境和 test 环境
--- 过滤掉了大厅地图，以及独立装备局（_eq结尾），如果有独立装备局会跟随游戏局一起卸载
---@return { tag = tag, game_id = game_id, size = size}
function game_uninstall:get_all_local_game_list(callback)
    if lobby.vm_name() == 'StateGame' then
        request_id = request_id + 1
        uninstall_callback[request_id] = callback
        base.game:send_broadcast('GameToApp-Uninstall-Game-List',{request_id = request_id})
    elseif lobby.vm_name() == 'StateApplication' then
        co.async(function()
            local formal = self:get_local_game_list('formal')
            local test = self:get_local_game_list('test')
            for i, v in ipairs(test) do
                table.insert(formal, v)
            end
            if callback then
                callback(formal)
            end
        end)
    end
end

function game_uninstall:init_local_game_update_info(tag)
    local need_request_update_info = self:get_maps_dir_game(tag)
    generate:request_update_info(need_request_update_info, tag)
end

function game_uninstall:get_maps_dir_game(tag)
    local maps = {}
    local maps_path = self:update_path(tag) .. '/Res/maps'
    local err, dirs = io_list(maps_path, 2)
    if err == 0 then
        for i, v in ipairs(dirs) do
            local map_name = string.match(v, '/[^/]+$')
            map_name = string.sub(map_name, 2)
            -- 这时候还不能过滤
            table.insert(maps, map_name)
        end
    end
    return maps
end

function game_uninstall:map_is_exist(tag, game_id)
    local maps_path = self:update_path(tag) .. '/Res/maps/'..game_id
    return io_exist_dir(maps_path)
end

--- 取本地所有可卸载游戏列表(计算大小)
function game_uninstall:get_local_game_list(tag)
    local need_request_update_info = self:get_maps_dir_game(tag)
    generate:request_update_info(need_request_update_info, tag)
    local result_list = {}
    for i, game_id in ipairs(need_request_update_info) do
        -- 过滤掉大厅(app_开头) 独立装备局(_eq结尾)
        if string.sub(game_id,1, 4) ~= 'app_' and string.sub(game_id,#game_id - 2) ~= '_eq' then
            local size = generate:calculate_map_size(tag, game_id)
            table.insert(result_list,{ tag = tag, game_id = game_id, size = size})
        end
    end
    return result_list
end

--- 取本地所有可卸载游戏列表(不计算大小)
function game_uninstall:get_local_game_list_no_size(tag)
    local need_request_update_info = self:get_maps_dir_game(tag)
    local result_list = {}
    for i, game_id in ipairs(need_request_update_info) do
        -- 过滤掉大厅(app_开头) 独立装备局(_eq结尾)
        if string.sub(game_id,1, 4) ~= 'app_' and string.sub(game_id,#game_id - 2) ~= '_eq' then
            table.insert(result_list,{ tag = tag, game_id = game_id})
        end
    end
    return result_list
end

function game_uninstall:get_all_local_game_list_no_size()
    local formal = self:get_local_game_list_no_size('formal')
    local test = self:get_local_game_list_no_size('test')
    for i, v in ipairs(test) do
        table.insert(formal, v)
    end
    return formal
end

base.game:event('广播', function(...)
    local _, type, params = table.unpack({ ... })
    if type == 'GameToApp-Uninstall' then
        if lobby.vm_name() == 'StateApplication' then
            log.info('[uninstall] receive GameToApp-Uninstall ',json.encode(params))
            game_uninstall:uninstall(params.map_list,function(result)
                base.game:send_broadcast('AppToGame-Uninstall',{request_id = params.request_id, result = result})
            end)
        end
    elseif type == 'AppToGame-Uninstall' then
        if lobby.vm_name() == 'StateGame' then
            if uninstall_callback[params.request_id] then
                uninstall_callback[params.request_id](params.result)
            end
        end
    elseif type == 'GameToApp-Uninstall-Game-List' then
        if lobby.vm_name() == 'StateApplication' then
            game_uninstall:get_all_local_game_list(function(result)
                base.game:send_broadcast('AppToGame-Uninstall-Game-List',{request_id = params.request_id, result = result})
            end)
        end
    elseif type == 'AppToGame-Uninstall-Game-List' then
        if lobby.vm_name() == 'StateGame' then
            if uninstall_callback[params.request_id] then
                uninstall_callback[params.request_id](params.result)
            end
        end
    elseif type == 'GameToApp-Check-Uninstall' then
        if lobby.vm_name() == 'StateApplication' then
            game_uninstall:check_uninstall_undone()
        end
    elseif type == 'AppToGame-Uninstall-State' then
        if lobby.vm_name() == 'StateGame' then
            game_uninstall:set_is_uninstalling(params.state)
        end
    end
end)

return game_uninstall
