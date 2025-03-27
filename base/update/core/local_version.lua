-- 客户端地图版本

local platform             = require 'base.platform'
local path                 = require 'base.path'
local argv                 = require 'base.argv'
local util                 = require'base.util'
local account              = require 'base.account'
local version_manager      = {}

local global_client_suffix = platform.is_mobile() and '_mob' or 'client'
-- global_client_suffix = 'client'  -- 暂时强制写成client
if argv.has('packet_suffix') then
    global_client_suffix = argv.get('packet_suffix')
    log.info(('argv.get("packet_suffix"): %s'):format(global_client_suffix))
end

log.info(('~global_client_suffix: %s'):format(global_client_suffix))

local lua_state_name            = __lua_state_name
local io_read                   = io.read
local io_write                  = io.write
local io_copy                   = io.copy
local io_exist_file             = io.exist_file
local os_date                   = os.date
local math_floor                = math.floor
local tostring                  = tostring
local tonumber                  = tonumber
local pcall                     = pcall
local ipairs                    = ipairs
local pairs                     = pairs
local type                      = type
local error                     = error
local coroutine_call            = coroutine.call
local io_exist_dir              = io.exist_dir
local io_create_dir             = io.create_dir
local io_remove                 = io.remove
local io_read_cache             = io.read_cache
local io_list                   = io.list
local base_json_encode          = base.json.encode
local base_json_decode          = base.json.decode
local fmt                       = fmt
local common_get_binary_version = common.get_binary_version
local get_http_env              = base.get_http_env
local root_path                 = path(io.get_root_dir())
local version_path              = root_path / 'Update' / _G.update_subpath
local table_insert              = table.insert
local api_pak_version_manager   = require 'update.core.local_api_pak_version'
local map_pak_version_manager   = require 'update.core.local_map_pak_version'
local file_name                 = 'VERSION.JSON'
local editor_version_manager    = require "update.core.api_version_config".editor_version_manager
local root                      = nil
local json                      = require 'json'
local update_recode             = require 'update.core.update_record'
local string_find = string.find
local math_max = math.max
function version_manager:path(r)
    if r then root = r end
    return root / file_name
end

function version_manager:clear_cache()
    local cache_folder  = tostring(self:path():parent() / 'version_cache')
    if not io_exist_dir(cache_folder) then
        return
    end
    io_remove(cache_folder)
end

function version_manager:clear_patch_cache()
    local cache_folder = tostring(self:path():parent() / 'version_patch_cache')
    if not io_exist_dir(cache_folder) then
        return
    end
    log.info("更新结束清除补丁标记")
    io_remove(cache_folder)
end

function version_manager:load_cache()
    local cache_folder  = tostring(self:path():parent() / 'version_cache')
    if not io_exist_dir(cache_folder) then
        return
    end
    local err, file_list = io_list(cache_folder, 1)
    if err == 0 then
        for i, cache_file in ipairs(file_list) do
            local result, content = io_read(tostring(cache_file))
            if result == 0 then
                local json_table, error_info = common.json_decode(content)
                if not json_table then
                    log.error('解析 version_json cache_file 失败' .. tostring(error_info))
                else
                    self:update_json(json_table)
                end
            else
                log.error(('read version_json cache_file failed path[%s]'):format(tostring(cache_file)))
            end
        end
    else
        log.error(('list version_json cache_folder failed path[%s]'):format(cache_folder))
    end
    io_remove(cache_folder)
    self:save()
    api_pak_version_manager:save()
    map_pak_version_manager:save()
end

function version_manager:load_patch_cache()
    local cache_folder = tostring(self:path():parent() / 'version_patch_cache')
    if not io_exist_dir(cache_folder) then
        return
    end
    local err, file_list = io_list(cache_folder, 1)
    if err == 0 then
        log.info("补丁标记cache", json.encode(file_list))
        for _, cache_file in ipairs(file_list) do
            local package_name = util.path_last_part(cache_file)
            log.info("补丁包名", package_name)
            self:set(package_name, 0, 'nil')
        end
    else
        log.error(('list version_json patch_cache_folder failed path[%s]'):format(cache_folder))
    end
    io_remove(cache_folder)
    self:save()
end

function version_manager:remove_patch_cache(info)
    local package_name = info.name
    if api_pak_version_manager:is_multi_api(package_name) then --多API的包不需要置0
        return
    end
    local cache_file = tostring(self:path():parent() / 'version_patch_cache' / (info.name))
    if io_exist_file(cache_file) then
        io_remove(cache_file)
        log.info("删除补丁标记", cache_file)
    end
end
function version_manager:save_patch_cache(info)
    local  package_name = info.name
    if api_pak_version_manager:is_multi_api(package_name) then --多API的包不需要置0
       return
    end
    local cache_folder  = tostring(self:path():parent() / 'version_patch_cache')
    if not io_exist_dir(tostring(cache_folder)) then
        io_create_dir(tostring(cache_folder))
    end
    local cache_file = path(cache_folder) / (info.name)
    if not io_write(tostring(cache_file), '') then
        error(('wirte cache patch info failed. path[%s]'):format(tostring(cache_file)))
    end
    local save_suffix = info.suffix or 'client'
    self:set(package_name, 0, save_suffix)  -- server不可能有patch, 所以直接填考虑客户端的
end

-- 写入缓存
function version_manager:save_cache(info)
    if self.record_numer == nil then
        self.record_numer = 0
    end
    self:remove_patch_cache(info) -- 写入缓存的时候,把补丁的cache删一下
    self.record_numer = self.record_numer + 1
    local cache_folder  = self:path():parent() / 'version_cache'
    if not io_exist_dir(tostring(cache_folder)) then
        io_create_dir(tostring(cache_folder))
    end
    local cache_file = cache_folder / ('info-' .. tostring(self.record_numer) .. '.json')
    while io_exist_file(tostring(cache_file)) do
        self.record_numer = self.record_numer + 1
        cache_file = cache_folder / ('info-' .. tostring(self.record_numer) .. '.json')
    end
    local data = base_json_encode(info)
    if not io_write(tostring(cache_file), data) then
        error(('wirte cache info failed. path[%s], data[%s]'):format(tostring(cache_file), data))
    end
end

function version_manager:update_json(info)
    local package_name = info.name
    -- 更新编辑器API对应的包版本号
    local item = info;
    if lua_state_name == 'StateEditor' then     -- 只在编辑器模式下修改api_pak_version 游戏模式不用这个json
        api_pak_version_manager:load();
        local api_version_cfg, _is_ask = editor_version_manager:get();
        local editor_api_version = api_version_cfg.api_version;
        log.info("Update api_pak_version in update_task", json.encode(item));
        if item['api_version'] < 0 then                 --非多API直接保存
            api_pak_version_manager:set(item['api_version'], item['name'], item['version'])
        elseif item['same_api_version'] ~= nil then     --多API判断当前是否是用自己的这个版本的
            api_pak_version_manager:set(editor_api_version, item['name'], item['version'])
        end
    else     --游戏模式下 直接根据数据里api_version保存 其实只需要知道是不是多API的就够了 不需要知道准确的API版本
        api_pak_version_manager:set(item['api_version'], item['name'], item['version']);
    end

    -- 更新编辑器 游戏对应的包版本号
    if info.belong_map ~= nil then
        map_pak_version_manager:load();
        for _, value in ipairs(info.belong_map) do
            map_pak_version_manager:set(value, info['name'], info['version']);
        end
    end
    self:set(package_name, info.version, info.suffix or 'client')
end

-- 替换表结构
function version_manager:get_format_version(old_table)
    if old_table["#@#format_version"] == nil then
        local new_table = {}
        local version_message = {
            time = "2024_6",
            version = 1
        }
        new_table["#@#format_version"] = version_message -- 设置 version.json 的结构号
        for name, data in pairs(old_table) do
            if name:sub(1, 1) ~= '#' then
                local version = {}
                for k, v in pairs(data) do
                    if k ~= 'server' and k ~= 'count' then
                        if type(v) == "table" then
                            for _, value in ipairs(v) do
                                version[tostring(value)] = k
                            end
                        else
                            version[tostring(v)] = k
                        end
                    end
                end
                local new_data = {}
                new_data['version'] = version
                new_table[name] = new_data
            else
                new_table[name] = data -- 其他信息不做额外处理
            end
        end
        return new_table
    end
    return old_table
end

function version_manager:load(r)
    if tostring(root) == tostring(r) and self.table ~= nil then --已经load过了
        return;
    end
    root = r
    local result, content = io_read(tostring(self:path()))
    if result == 0 then
        local json_table, error_info = common.json_decode(content)
        if not json_table then
            log.warn('解析 version.json 失败，重新下载资源. ' .. tostring(error_info))
            self.table = {}
        else
            self.table = json_table
        end
        log.info(fmt("load local_version[%s] success", tostring(self:path())))
        if io_exist_file(tostring(self:path())) and get_http_env() == 'master' then
            io_copy(tostring(self:path()), tostring(root / fmt("VERSION-load-%s.JSON", os_date('%Y-%m-%d_%H-%M-%S'))))
        end
    else
        self.table = {}
    end
    -- 把version.json处理成新的结构
    self.table = self:get_format_version(self.table)
    self:load_patch_cache() -- 先读补丁的
    self:load_cache()
end

function version_manager:get_embedded_package_info()
    if self.embedded_package_info ~= nil then
        return self.embedded_package_info
    end
    if app == nil then --
        return {}
    end
    local package_info = app.get_embedded_package_info()
    if not package_info then
        log.warn('获取 embedded_package_version.json 失败')
        self.embedded_package_info = {}
    else
        self.embedded_package_info = {}
        -- 需要判断一下info的合法性，容错一下发版本引入错误的version
        for _, info in ipairs(package_info) do
            if info.json_str then
                local ret, _extract_info = pcall(base.json.decode, info.json_str)
                if ret and _extract_info then
                    self.embedded_package_info[#self.embedded_package_info+1] = _extract_info
                end
            end
        end
    end
    log.info("获取内嵌包信息", json.encode(self.embedded_package_info))
    return self.embedded_package_info
end

function version_manager:is_embedded_package(pak_name)
    local package_info = self:get_embedded_package_info()
    for _, info in ipairs(package_info) do
        if info.name == pak_name then
            return true
        end
    end
    return false
end

function version_manager:save()
    local p = tostring(self:path())
    local data = base_json_encode(self.table)
    if not io_write(p, data) then
        error(('write local_version failed. path[%s], data[%s]'):format(p, data))
    end
end



---@return any,any
function version_manager:get(map_name)
    -- 二进制地图的版本号从 c++ 拿，实际上写到 c++ 头文件里了
    if map_name == platform.binary():lower() then
        return math_floor(common_get_binary_version()), 'client'
    end
    if not self.table[map_name] then
        return 0, 'client'
    end
    local data = self.table[map_name].version
    if data == nil then
        log.error(("get version info error map_name[%s] info[%s]"):format(map_name, json.encode(self.table[map_name])))
        return 0, 'client'
    end
    local max_version = -1
    for version, suffix in pairs(data) do -- 多API包返回最大的版本号
        local v = tonumber(version) or -1
        max_version = math_max(max_version, v)
    end
    if max_version ~= -1 then
        return max_version, data[tostring(max_version)]
    end
    return 0, 'client'
end

---@return table
function version_manager:get_all_lib()
    local libs = {}
    for name, _ in pairs(self.table) do
        if type(name) == 'string' and name:sub(1, 1) ~= '#' and api_pak_version_manager:is_multi_api(name) == false then
            libs[#libs + 1] = name
        end
    end
    return libs;
end


-- 返回多API 比询问值小的最大版本号
---@return number
function version_manager:get_nearest_version(map_name, version)
    api_pak_version_manager:load()
    if not api_pak_version_manager:is_multi_api(map_name) then
        return 0
    end
    if not self.table[map_name] then
        return 0
    end
    local max_version = 0
    local data = self.table[map_name].version
    if data == nil then
        log.error(("get_nearest_version version info error map_name[%s] info[%s]"):format(map_name, json.encode(self.table[map_name])))
        return 0
    end
    for v, suffix in pairs(data) do
        local cv = tonumber(v) or 0
        if cv < version and cv > max_version then
            max_version = cv
        end
    end
    return max_version
end

--@return
function version_manager:get_multi_api_version_list(map_name)
    if not self.table[map_name] then
        return nil
    end
    local is_multiapi = api_pak_version_manager:is_multi_api(map_name);
    if not is_multiapi then
        return nil
    end
    local data = self.table[map_name].version
    local list = {}
    for v, suffix in pairs(data) do
        table_insert(list,tonumber(v))
    end
    return list
end


-- @return bool 是否存在某个版本的包
function version_manager:has(map_name, version)
    -- 二进制地图的版本号从 c++ 拿，实际上写到 c++ 头文件里了
    if map_name == platform.binary():lower() then
        return math_floor(common_get_binary_version()) == version
    end
    if not self.table[map_name] then
        return false
    end
    local data = self.table[map_name].version
    if data == nil then
        log.error(("check version info error map_name[%s] info[%s]"):format(map_name, json.encode(self.table[map_name])))
        return false
    end
    return data[tostring(version)] ~= nil
end

function version_manager:set(map_name, version, suffix)
    if map_name == platform.binary():lower() then
        return -- 不记录二进制的包版本号 这个数据 通过二进制内的API获得
    end
    local t = self.table[map_name]
    if t == nil then
        t = {}
    end
    version = math_floor(version)
    local is_multiapi = api_pak_version_manager:is_multi_api(map_name);
    if is_multiapi then
        if version == 0 then
            return -- 多API包不设置0
        end
        if t.version == nil then
            t.version = {}
        end
        t.version[tostring(version)] = suffix
    else
        local data = {}
        data[tostring(version)] = suffix
        t['version'] = data
    end
    self.table[map_name] = t -- 应该移到最后
    if is_multiapi then
        log.info(fmt("local_version:set add_version map_name[%s], version[%s], suffix[%s]", map_name, version, suffix))
    else
        log.info(fmt("local_version:set set_version map_name[%s], version[%s], suffix[%s]", map_name, version, suffix))
    end
end

-- 删除某个包的记录 只在内网和加inner参数的地方记录 
function version_manager:delete_pak_record(map_name, version, after_info)
    local env = get_http_env()
    if env ~= 'master' and not argv.has('inner') then
        return
    end
    local data = {}
    local info = {}
    info['name'] = map_name
    info['version'] = version -- -1代表删除所有版本号
    data['info'] = info
    data['is_delete'] = true
    data['after_info'] = after_info
    update_recode:write(data)
end

-- 删除某个包的引用 只提供多API包用 
function version_manager:delete_pak(map_name, version)
    local current_version = self.table[map_name]
    if current_version == nil then
        return
    end
    log.info(("local_version:delete pak name[%s] version[%s]"):format(map_name, version))
    local is_multiapi = api_pak_version_manager:is_multi_api(map_name);
    if not is_multiapi then
        log.error("非多API的包 禁止使用此函数")
    end
    version = math_floor(version)
    if not self:has(map_name, version) then
        log.info("version no exist")
        return
    end
    if util.elem_count(current_version.version) == 1 then
        self.table[map_name] = nil
    else
        current_version.version[tostring(version)] = nil
    end
    self:delete_pak_record(map_name, version, self.table[map_name])
    if self.table[map_name] ~= nil then
        log.info("remove result", json.encode(self.table[map_name]))
    else
        log.info("remove all version")
    end
end

-- 删除某个包的全部引用 非多API包用 或 多API包用于删除所有包
function version_manager:delete_pak_all_version(map_name)
    local current_version = self.table[map_name]
    log.info(("local_version:delete all pak name[%s]"):format(map_name))
    if current_version == nil then
        return
    end
    self.table[map_name] = nil
    self:delete_pak_record(map_name, -1, self.table[map_name])
end

local function starts_with(str, start)
    -- 将字符串和前缀都转换为小写
    str = str:lower()
    start = start:lower()

    -- 获取字符串的前缀部分
    return str:sub(1, #start) == start
end

local function ends_with(str, ending)
    str = str:lower()
    ending = ending:lower()
    local str_len = #str
    local ending_len = #ending
    if ending_len > str_len then
        return false
    end
    return str:sub(str_len - ending_len + 1) == ending
end

local function remove_prefix(A, B)
    -- Check if A is a prefix of B
    if B:sub(1, #A) == A then
        -- If A is a prefix, return B without A
        return B:sub(#A + 1)
    else
        -- If A is not a prefix, return B as is
        return B
    end
end

local function remove_extension(filename)
    local dotIndex = filename:match("^.+()%.%w+$")
    if dotIndex then
        return filename:sub(1, dotIndex - 1)
    else
        return filename
    end
end

-- 清理没用的多API包
function version_manager:delete_editor_useless_multi_api_package(r)
    if lua_state_name ~= 'StateEditor' then --不是编辑器不能使用这个函数 以防万一
        return
    end
    log.info("开始清理编辑器多余的API包")
    r = r or version_path
    self:load(r);
    api_pak_version_manager:load();
    local pak_list = api_pak_version_manager:get_all_need_multi_pak_version();
    for pak_name, pak_mess in pairs(pak_list) do
        local need_version = pak_mess['version']
        local pak_path = pak_mess['path']
        if starts_with(pak_path, 'Res/_m/maps/user_libs') then
            log.info("不清理第三方库", pak_path)
            goto delete_editor_useless_multi_api_package_loop_end
        end
        local list = {}
        local res, dir_list = io_list(tostring(root / pak_path), 2) -- 找目录下所有版本号
        if res == 0 then
            for i, p in pairs(dir_list) do
                local version = tonumber(string.match(p, ".*/([^/]+)$"))
                table_insert(list, version)
            end
        end
        local save_version = self:get_multi_api_version_list(pak_name) -- 把version.json里面的也放进去
        if save_version then
            for _, v in ipairs(save_version) do
                if util.indexOf(list, v) == -1 then
                    table_insert(list, v)
                end
            end
        end
        for index, need_del_version in ipairs(list) do
            if util.indexOf(need_version, need_del_version) == -1 then --需要的版本号里没有这个数 就卸载删除这个包
                local path = root / pak_path / tostring(need_del_version)
                local state = 'success'
                if io_exist_dir(tostring(path)) then
                    local result = io_remove(tostring(path))
                    if result ~= 0 then
                        state = 'failed'
                    end
                end
                log.info("delete: " .. tostring(path) .. "删除状态: " .. tostring(state))
                self:delete_pak(pak_name, need_del_version)
                self:save()
            end
        end
        ::delete_editor_useless_multi_api_package_loop_end::
    end
    self:save()
end

-- 清理游戏里没用的多API包 非多API的包要么被覆盖 要么游戏卸载时删掉
function version_manager:delete_game_useless_api_package(r)
    if lua_state_name ~= 'StateApplication' then
        return
    end
    api_pak_version_manager:load();
    if api_pak_version_manager:is_need_clear_package() == false then
        return
    end
    log.info("开始清理游戏多余的API包")
    r = r or version_path
    local generate_count = include 'uninstall.generate_count'
    generate_count:init()
    map_pak_version_manager:load();
    local stateAppPak = map_pak_version_manager:get_state_application_pak_version()
    self:load(r)
    local del_count = 0
    local multi_api_path = api_pak_version_manager:get_multi_pak_path()
    for pak_name, pak_path in pairs(multi_api_path) do
        local list = {}
        local res, dir_list = io_list(tostring(root / pak_path), 2) -- 找目录下所有版本号
        if res == 0 then
            for i, p in pairs(dir_list) do
                local version = tonumber(string.match(p, ".*/([^/]+)$"))
                table_insert(list, version)
            end
        end
        for i, version in ipairs(list) do
            if not self:has(pak_name, version) then
                log.error("本地version.json和文件目录对不上",pak_name,version) -- 这是比较严重的错误,目录里有,version里没有,(更严重的情况是,本地version里有,目录下没有)
            end
            local count = self:get_count(pak_name, version);
            if (count == nil or count <= 0) and stateAppPak[pak_name] ~= version then
                local path = root / pak_path / tostring(version)
                local state = 'success'
                if io_exist_dir(tostring(path)) then
                    local result = io_remove(tostring(path))
                    if result ~= 0 then
                        state = 'failed'
                    end
                else
                    log.info("文件不存在", tostring(path))
                end
                log.info("自动清理:delete: " .. tostring(path) .. "删除状态: " .. tostring(state))
                if state == 'success' then
                    self:delete_pak(pak_name, version)
                    self:save()
                    del_count = del_count + 1
                end
            end
        end
        self:clear_count(pak_name) -- 把计数全删了之后有用再重新算过
    end
    api_pak_version_manager:update_clear_time()
    common.stat_sender('delete_game_useless_packages', {
        guest_id = account.get_guest_id(),
        platform = common.get_platform(),
        count    = del_count
    })
    self:save()
end

-- 校验资源完整性
function version_manager:verify_resources()
    local co                       = require 'base.co'
    local confirm             = require 'base.confirm'
    local calc_http_server_address = base.calc_http_server_address

    log.info('校验资源')
    local windosw_message = function (mess)
        if __lua_state_name == 'StateEditor' then
            local message_box = require '@base.base.message_box'
            local show_message_box = co.wrap(message_box)
            show_message_box({
                content = mess,
                btn_text = '确定',
                show_send_log = false,
                show_close = false
            })
        else
            confirm.message(base.i18n.get_text(mess))
        end
    end

    if common.get_file_crc32 == nil then
        windosw_message('二进制没有校验crc的接口')
        return
    end

    local url                      = calc_http_server_address('updater', 9002) .. '/api/map/update-info'
    local libs                     = self:get_all_lib()
    local list_str                 = table.concat(libs, ';')
    local output                   = sce.httplib.create_stream()
    local editor_api_version       = 0;

    if lua_state_name == 'StateEditor' then -- 读取编辑器的API版本号 游戏不需要
        local api_version_cfg, _is_ask = editor_version_manager:get();
        editor_api_version = api_version_cfg.api_version;
    end
    local input = {
        list = list_str,
        suffix = global_client_suffix,
        is_editor = lua_state_name == 'StateEditor' and 1 or nil,
        version = 2,
        api_version = editor_api_version,
        crc_flag = 1
    }
    local code, status_code = co.call(sce.httplib.request, {
        method = 'post',
        url = url,
        input = input,
        output = output,
    })
    if code ~= 0 or status_code ~= 200 then
        throw(fmt("verify_resources update_version_info failed. code[%s], status_code[%s]", code, status_code))
        return
    end

    local content = output:read()
    local readline = (function()
        local begin = 1
        return function()
            local index = content:find('\r\n', begin)
            if index then
                local ret = content:sub(begin, index)
                begin = index + 2
                return ret
            else
                local ret = nil
                if begin ~= #content then
                    ret = content:sub(begin, #content)
                end
                begin = #content
                return ret
            end
        end
    end)()
    local line_version = readline()
    assert(line_version)
    local line_buffer_type = readline()
    assert(line_buffer_type)
    local line_pac = readline() -- 正常读 第三行
    local suc, info = pcall(json.decode, line_pac);

    local function formatPath(path)
        -- Step 1: Replace "\\" with "/"
        path = path:gsub("\\\\", "/")
    
        -- Step 2: Replace "\" with "/"
        path = path:gsub("\\", "/")
    
        -- Step 3: Remove leading "/"
        path = path:gsub("^/", "")
    
        -- Step 4: Remove trailing "/"
        path = path:gsub("/$", "")
        return path
    end

    local check_folder_package = function(file_list, crc_data, prefix)
        local has_pak = false
        for _, file in ipairs(file_list) do
            local file_path = formatPath(file)
            if ends_with(file_path, '.pak') then
                has_pak = true
            end
        end
        for _, finanl_path in ipairs(file_list) do
            local rel_path = formatPath(remove_prefix(tostring(prefix), finanl_path))
            if has_pak and not ends_with(rel_path, '.pak') then -- 存在pak的包只比较pak
                goto check_folder_package_continue
            end
            --
            if crc_data[rel_path] == nil then -- 多出来文件
                log.info(tostring(prefix))
                log.info(tostring(finanl_path))
                log.info("类型", type(finanl_path))
                log.info("移除前缀", remove_prefix(tostring(prefix), tostring(finanl_path)))
                log.error(('本地多出文件[%s]'):format(finanl_path))
                return false
            end
            local crc = common.get_file_crc32(finanl_path)
            if crc ~= crc_data[rel_path] then -- 文件crc对不上
                log.error(('文件crc对不上[%s]'):format(finanl_path))
                return false
            end
            crc_data[rel_path] = nil -- 情况
            ::check_folder_package_continue::
        end
        for path, __ in pairs(crc_data) do -- 只要进这个循环 就说明缺文件
            log.error(('缺少文件[%s]'):format(tostring(path)))
            return false
        end
        return true
    end

    if suc then
        local items = info["items"]
        local single_file_cache = {}
        for _, item in ipairs(items) do
            if item.crc == nil then
                goto verify_resources_continue
            end
            if not self:has(item.name,item.version) then --version里就没记录这个版本号 说明需要更新
                log.info(('verify_resources version no exist [%s] [%s]'):format(tostring(item.name),tostring(item.version)))
                goto verify_resources_continue
            end
            local orgin_crc_data = json.decode(item.crc)
            local crc_data = {}
            for _, data in ipairs(orgin_crc_data) do 
                crc_data[formatPath(data['Path'])] = data['CRC']
            end
            if item.packet_type == 1003 or item.packet_type == 1011 then -- 单文件包 单文件包只能校验需要的包是否存在 不能校验包里是否会有不该有的 因为不是所有的文件都已经生成了CRC
                local folder = version_path / item.path
                local file_path = tostring(folder / (item.alias or item.name))
                if single_file_cache[file_path] == nil then
                    local res, file_list = io_list(tostring(folder), 1)
                    if res == 0 then
                        for _, file_path in ipairs(file_list) do
                            local rel_path = remove_prefix(tostring(folder), file_path)
                            local crc = common.get_file_crc32(file_path)
                            local file_name = remove_extension(rel_path) --去除拓展名
                            single_file_cache[tostring(folder / file_name)] = crc
                        end
                    else
                        windosw_message(('文件校验失败 包路径不存在[%s]'):format(tostring(folder)))
                        log.error(('文件校验失败 包路径不存在[%s]'):format(tostring(folder)))
                        return
                    end
                end
                local crc = orgin_crc_data[0]['CRC']
                if single_file_cache[file_path] ~= crc then
                    windosw_message(('单文件包校验失败 package[%s] version[%s]'):format(tostring(info.name), tostring(info.version)))
                    log.error(('单文件包校验失败 package[%s] version[%s]'):format(tostring(info.name), tostring(info.version)));
                    return
                else
                    log.error("单文件包校验成功")
                end
            else
                local package_folder = version_path / item.path / (item.alias or item.name)
                if item.api_version ~= -1 then
                    local prefix = string.gsub(item['path'], "Res", "Res/_m") .. '/' .. item['name']
                    package_folder = prefix .. '/' .. tostring(item['version']) .. item['name']
                end
                local res, file_list = io_list(tostring(package_folder), 1, '*', true)
                if res == 0 then
                    if not check_folder_package(file_list, crc_data, package_folder) then
                        log.info('包数据',json.encode(item))
                        log.info('crc数据',json.encode(crc_data))
                        windosw_message(('文件校验失败 package[%s] version[%s]'):format(tostring(item.name), tostring(item.version)))
                        log.error(('文件校验失败 package[%s] version[%s]'):format(tostring(item.name), tostring(item.version)));
                        return
                    end
                else
                    windosw_message(('文件校验失败 包路径不存在[%s]'):format(tostring(package_folder)))
                    log.error(('文件校验失败 包路径不存在[%s]'):format(tostring(package_folder)))
                    return
                end
            end
            ::verify_resources_continue::
        end
    else
        log.error('校验资源 解析json失败')
    end
    windosw_message('校验资源结束,资源完整')
end

-- 设置地图引用计数
function version_manager:set_count(map_name, version, count)
    local t = self.table[map_name]
    if t == nil then
        return false
    end
    if t.count then
        t.count[tostring(version)] = count;
    else
        t.count = {}
        t.count[tostring(version)] = count;
    end
    return true
end

-- 获取地图引用计数
function version_manager:get_count(map_name, version)
    local t = self.table[map_name]
    if t == nil or t.count == nil then
        return 0
    end
    return t.count[tostring(version)]
end

-- 增加计数 计数和版本号绑定不区分是否是多API
function version_manager:add_count(map_name, version)
    local t = self.table[map_name]
    if t == nil then
        return false
    end
    if t.count then
        t.count[tostring(version)] = t.count[tostring(version)] + 1;
    else
        t.count = {}
        t.count[tostring(version)] = 1;
    end
    return true
end

-- 清除计数
function version_manager:clear_count(map_name)
    local t = self.table[map_name]
    if t == nil then
        return false
    end
    if t.count then
        t.count = nil
    end
    return true
end

function version_manager:update_game_info(game_name, info)
    local t = self.table["#game_info"]
    if t == nil then
        t = {}
        self.table["#game_info"] = t
    end
    if t[game_name] == nil then
        t[game_name] = {}
    end
    log.info(game_name, base_json_encode(info))
    t[game_name][info.name] = { version = info.version, alias = info.alias, size = info.size, original_size = info.original_size, path = info.path }
end

function version_manager:set_flag(flag)
    self.table["##resource_count_flag"] = flag
end

function version_manager:get_flag()
    return self.table["##resource_count_flag"]
end

function version_manager:data()
    if not self.table then
        self:load(version_path)
    end
    return self.table
end

local calc_http_server_address = base.calc_http_server_address
local function get_game_info(game)
    local outstream = sce.httplib.create_stream()
    local url = calc_http_server_address('game-info', 8053) .. '/game-info?game=' .. game
    if platform.is_ios() then
        url = url .. '&platform=ios'
    end
    local code, status = coroutine_call(sce.httplib.request, { url = url, output = outstream, timeout = 4 })
    local content = outstream:read()
    log.info('game info', url, game, content, code, status)
    if code == 0 and content then
        return base_json_decode(content)
    end
end


function version_manager:uninstall_prepare(game_name)
    local t = self.table
    if not t or not t['#game_info'] or not t["#game_info"][game_name] then
        return true
    end
    --这个名字是从sku拿的传进来的id，实际启动是别的游戏的话得转换，不然拿错误id删是不对得
    local info = get_game_info(game_name)
    if info.params_game then
        v = info.params_game
    end
    local game_info = t["#game_info"][game_name]
    local delete_info = {}
    delete_info["#game_name"] = game_name
    for name, info in pairs(game_info) do
        if info and info.path and t[name] then
            local current_count = self:get_count(name, info.version);
            delete_info[name] = { path = info.path, alias = info.alias, version = info.version, old_count = current_count, new_count = current_count - 1 }
        end
    end
    local p = root / "game_need_to_delete.json"
    local data = base_json_encode(delete_info)
    io_write(tostring(p), data)
    version_manager:set_flag(1) --表示算完了卸载的东西，记在game_need_to_delete.json里
    version_manager:save()
    return true
end

function version_manager:query_game_size(names)
    local t = self:data()
    local res = {}
    for i, v in pairs(names) do
        --这个名字是从sku拿的传进来的id，实际启动是别的游戏的话得转换，不然大小是0
        local info = get_game_info(v)
        if info.params_game then
            v = info.params_game
        end
        local size = 0
        if t and t['#game_info'] and t['#game_info'][v] then
            local deps = t['#game_info'][v]
            for dep, info in pairs(deps) do
                local count = self:get_count(dep, info.version);
                if (count - 1) == 0 then
                    size = size + info.original_size
                end
            end
        end
        log.info(v, size)
        res[v] = size
    end
    return res
end

function version_manager:query_all_game_size()
    local t = self:data()
    local res = {}
    if t and t['#game_info'] then
        for k, v in pairs(t['#game_info']) do
            local size = 0
            local deps = v
            for dep, info in pairs(deps) do
                local count = self:get_count(dep, info.version);
                if (count - 1) == 0 then
                    size = size + info.original_size
                end
            end
            log.info(k, size)
            local info = get_game_info(k)
            if info and info.isGame then
                info.size = size
                res[k] = info
            end
        end
    end
    return res
end

function version_manager:init_game_info()
    local t = self.table
    for _, info in pairs(t) do
        info.count = nil
    end
    t["#game_info"] = nil
end

function version_manager:do_uninstall(progress)
    local t = self.table
    local p = root / "game_need_to_delete.json"
    local result, content = io_read(tostring(p))
    if result ~= 0 then
        return true
    end
    local delete_info = base_json_decode(content)
    local game_name = delete_info["#game_name"]
    local total = 0
    local idx = 1

    for name, info in pairs(delete_info) do
        total = total + 1
    end
    for name, info in pairs(delete_info) do
        if progress then
            progress(game_name, idx, total)
        end
        if name == "#game_name" then
            --什么都不做
        elseif info.new_count == 0 then
            local remove_path_name = info.alias or name --优先用别名
            local path = root / info.path / remove_path_name
            if string_find(tostring(path), "/_m/") then -- 多API 连版本号一起删了
                path = root / info.path
            end
            local state = 'success'
            if io_exist_dir(tostring(path)) then
                local result = io_remove(tostring(path))
                if result ~= 0 then
                    state = 'failed'
                end
            end
            log.info("delete: " .. tostring(path) .. "删除状态: " .. tostring(state))
            if string_find(tostring(path), "/_m/") then
                self:delete_pak(name, info.version)
            else
                self:delete_pak_all_version(name)
            end
        else
            self:set_count(name, info.version, info.new_count)
        end
        idx = idx + 1
    end
    t["#game_info"][game_name] = nil
    --io_remove(tostring(p))
    return true
end

version_manager.global_client_suffix = global_client_suffix
return version_manager

