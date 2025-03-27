-- 储存每个API版本下，每个包的版本号

local path                    = require '@base.base.path'
local io_read                 = io.read
local io_write                = io.write
local argv                    = require 'base.argv'
local get_http_env            = base.get_http_env
local root_path               = path(io.get_root_dir()) / 'Update' / _G.update_subpath;

local api_pak_version_manager = {}

local tostring                = tostring
local string_lower            = string.lower

function api_pak_version_manager:path()
    return root_path / 'api_pak_version.json';
end

function api_pak_version_manager:load()
    if self.table then
        return; --已经打开了，没必要再load
    end
    self.change = false;
    self.changed_pak_list = {}
    local result, content = io_read(tostring(self:path()))
    if result == 0 then
        local json_table, error_info = common.json_decode(content);
        if not json_table then
            log.warn('api_pak_version_manager解析json 失败' .. tostring(error_info))
            self.table = {}
        else
            self.table = json_table
        end
    else
        self.table = {}
    end
end

-- 这个接口只有xdeditor用目前
function api_pak_version_manager:get(lib_name, api_version)
    local mem_version = common.get_map_pak_version(("#editor-%s:%s"):format(tostring(api_version), lib_name)) -- 读内存里的情况
    if type(mem_version) == "number" and mem_version > 0 then
        return tostring(mem_version)
    else
        mem_version = common.get_map_pak_version(("#editor-%s:%s"):format(tostring(-2), lib_name)) -- 第三方库只写入内存
        if type(mem_version) == "number" and mem_version > 0 then
            return tostring(mem_version)
        end
    end
    self:load();
    local list = nil;
    if type(api_version) == "string" then
        list = self.table[api_version];
    else
        list = self.table[tostring(api_version)];
    end
    lib_name = string_lower(lib_name);
    if list and list[lib_name] then
        return tostring(list[lib_name])
    end
    return '0';
end

-- -1代表非多API -2代表第三方包
-- 这是不是一个应该存在的包 暂时的写法
function api_pak_version_manager:pak_exist(name)
    self:load();
    for key, value in pairs(self.table) do
        -- key是 "-1" "0" 这样的一系列编号
        -- 以#号开头说明比较特殊
        if string.sub(key, 1, 1) ~= "#" then
            if value[name] ~= nil then
                return true
            end
        end
    end
    return false
end

--- 获取第三方库的包版本号
---@param lib_name string 包名
---@return string 版本号的字符串
function api_pak_version_manager:get_third_lib_version(lib_name)
    local mem_version = common.get_map_pak_version(("#editor-%s:%s"):format(tostring(-2), lib_name)) -- 第三方库只写入内存
    if type(mem_version) == "number" and mem_version > 0 then
        return tostring(mem_version)
    end
    return '0'
end

--- 设置这个包为多API包
function api_pak_version_manager:set_pak_multi(lib_name)
    if self.multi_pak_table == nil then
        self.multi_pak_table = {} -- 内存里所有的多API包的包名 先用这个来判断是不是多API
    end
    self.multi_pak_table[string_lower(lib_name)] = true
end

-- 获取这个包是不是多版本的
function api_pak_version_manager:is_multi_api(lib_name)
    lib_name = string_lower(lib_name)
    if self.multi_pak_table and self.multi_pak_table[lib_name] then
        return true
    end
    if self:get_third_lib_version(lib_name) ~= '0' then --先判断是不是第三方库
        return true
    end

    self:load();
    if not self:pak_exist(lib_name) then
        return false; -- 没有这个包直接返回假
    end

    local no_multi_api = api_pak_version_manager.table["-1"];
    if no_multi_api == nil then
        return false;
    end

    local version = no_multi_api[lib_name];
    if version then
        return false; -- 找得到说明不是多版本的
    end
    return true;
end

-- 设置api版本号下对应的 包版本号 （API版本号，包名，包版本号）
function api_pak_version_manager:set(_api_version, pak_name, pak_version)
    local api_version = tostring(_api_version);
    if _api_version ~= -1 then -- 编辑器里 只需要非-1的数据用于读路径
        common.set_map_pak_version(("#editor-%s"):format(api_version), pak_name, pak_version);
    end
    self:load();
    if api_version == "-2" then -- -2代表第三方包,只写入的到内存里 不增加修改标记(即不会只因为-2的修改,写入内存)
        return
    end
    -- 上面的代码是修改内存里存储的包版本号,下面的代码存储到json里，除非不更新和第一次启虚拟机，否则不需要读json
    if api_version ~= "-1" then --非多API转多API时 移除-1里错误的数值
        if self.table["-1"] and self.table["-1"][pak_name] then
            self.table["-1"][pak_name] = nil
        end
    end
    local newItem = self.table[api_version];
    if newItem == nil then
        newItem = {}
        self.change = true;
        log.info("api_pak_version_manager change", api_version, pak_name, pak_version)
        self.changed_pak_list[#self.changed_pak_list + 1] = pak_name
    end
    if newItem[pak_name] ~= pak_version then
        self.change = true;
        log.info("api_pak_version_manager change", api_version, pak_name, pak_version, "oldversion", newItem[pak_name])
        self.changed_pak_list[#self.changed_pak_list + 1] = pak_name
    end
    newItem[pak_name] = pak_version;
    self.table[api_version] = newItem;
end

-- 设置多API包的相对路径 不含包版本号 res/_m/... /包名
function api_pak_version_manager:set_multi_pak_path(pak_name, path)
    self:load();
    path = path:gsub('//', '/')
    local path_list = self.table['#package_path']
    if path_list == nil then
        path_list = {}
    end
    if path_list[pak_name] ~= path then
        self.change = true
        path_list[pak_name] = path
    end
    self.table['#package_path'] = path_list
end

-- 获取多API包的所有需要的包名和版本号
function api_pak_version_manager:get_all_need_multi_pak_version()
    self:load();
    local pak_list = {}
    for name, path in pairs(self.table['#package_path']) do
        local version_list = {}
        for api, mess in pairs(self.table) do
            if api ~= "-1" and string.sub(api, 1, 1) ~= "#" then
                if mess[name] then
                    table.insert(version_list, mess[name])
                end
            end
        end
        local pak_mess = {}
        pak_mess['path'] = path
        pak_mess['version'] = version_list
        pak_list[name] = pak_mess
    end
    return pak_list
end

function api_pak_version_manager:get_multi_pak_path()
    self:load();
    return self.table['#package_path']
end

local function convert_str_to_timestamp(time_str)
    local pattern = '(%d+)%-(%d+)%-(%d+) (%d+):(%d+):(%d+)'
    local year, month, day, hour, min, sec = time_str:match(pattern)
    return os.time({ year = year, month = month, day = day, hour = hour, min = min, sec = sec })
end

-- 判断是否相隔30天，需要清理用不上的包
function api_pak_version_manager:is_need_clear_package()
    self:load()
    local old_date_str = self.table['#last_clear_package_time']
    if old_date_str == nil then
        return true
    end
    local current_date = os.time()
    local old_date = convert_str_to_timestamp(old_date_str)
    local elapsed_secs = math.abs(current_date - old_date)
    local elapsed_days = elapsed_secs / (24 * 60 * 60)
    log.info(string.format("距离上次清理相差 %d 秒 %.2f 天", elapsed_secs, elapsed_days))
    if argv.has('inner') then
        return true
    end
    if elapsed_days > 30 then
        return true
    end
    return false
end

function api_pak_version_manager:update_clear_time()
    self:load()
    local time = os.time()
    self.change = true
    self.table['#last_clear_package_time'] = os.date('%Y-%m-%d %H:%M:%S', time)
    self:save();
end

function api_pak_version_manager:save()
    if not self.change then
        return
    end
    local p = tostring(self:path())
    local data = base.json.encode(self.table)
    if not io_write(p, data) then
        error(('api_pak_version_manager:save write pak_api_version failed. path[%s], data[%s]'):format(p, data))
        return
    end
    self.change = false;
end

return api_pak_version_manager
