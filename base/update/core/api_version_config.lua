--

local path                   = require '@base.base.path'
local io_read                = io.read
local io_write               = io.write
local io_exist               = io.exist_dir
local io_copy_to_folder      = io.copy_to_folder
local co                     = require 'base.co'
local root_path              = path(io.get_root_dir());
local tostring               = tostring
local table_insert           = table.insert
local argv                   = require 'base.argv'
local editor_version_manager = {}

function editor_version_manager:path()
    return root_path / 'User' / 'editor_api_version.json'
end

local lua_state_name = __lua_state_name;
local get_http_env = base.get_http_env

local default_api_version = {};
default_api_version["api_version"] = 0;
default_api_version["show_name"] = "默认版本";
function editor_version_manager:load()
    if self.table then
        return
    end
    local result, content = io_read(tostring(self:path()))
    if result == 0 then
        local json_table, error_info = common.json_decode(content);
        if not json_table then
            log.warn('解析json 失败' .. tostring(error_info))
            self.table = {}
        else
            self.table = json_table
        end
    else
        self.table = {}
    end

    -- 没有默认值的增加默认值
    if self.table['api_version'] == nil then
        self.table["api_version"] = default_api_version;
    end
    if self.table['is_always_ask'] == nil then
        self.table["is_always_ask"] = false;
    end

    if self.table['api_version'].api_version == -1 then -- 之前把默认版本号写成-1 现在改成0
        self.table['api_version'].api_version = 0
    end

    local all_api_list = self.table['all_api_list'];
    if all_api_list ~= nil then
        for _, item in ipairs(all_api_list) do -- 更新编辑器的API名字
            if item.api_version == self.table['api_version'].api_version then
                self.table['api_version'] = item;
            end
        end
    end
    if self.table['api_version'].api_version == -1 then -- 之前把默认版本号写成-1 现在改成0
        self.table['api_version'].api_version = 0
    end

    self.old_api_version = self.table['api_version'].api_version -- 记录旧的编辑器API 编辑器切换API时 生成快捷方式并复制可能不存在的二进制
end

-- 获取编辑器API版本号 和 是否每次打开时询问
function editor_version_manager:get()
    self:load();
    return self.table['api_version'], self.table['is_always_ask'];
end

function editor_version_manager:write_to_file()
    local p = tostring(self:path())
    local data = base.json.encode(self.table)
    if not io_write(p, data) then
        error(('editor_version_manager:save write editor_version failed. path[%s], data[%s]'):format(p, data))
    end
end

-- 保存编辑器API版本号 和 是否每次打开时询问
function editor_version_manager:save(version, is_always_ask)
    if version.api_version < 0 then
        return;
    end
    self:load();
    self.table['api_version'] = self:refresh_api_name(version);
    if is_always_ask ~= nil then
        self.table['is_always_ask'] = is_always_ask
    end

    if self.table['api_version'].api_version ~= self.old_api_version then -- 切换API后 创建快捷方式 并复制一套暂时的二进制
        log.info(("editor_version_manager:save change api oldversion[] new _VERSION"):format(self.old_api_version, self.table['api_version'].api_version))
        common.change_editor_api(self.old_api_version, self.table['api_version'].api_version)
    end

    self:write_to_file();
end

-- 保存编辑器API列表
function editor_version_manager:save_all_api(all_api_list)
    self:load();
    self.table['all_api_list'] = all_api_list
    for _, item in ipairs(all_api_list) do -- 更新编辑器的API名字
        if item.api_version == self.table['api_version'].api_version then
            self.table['api_version'] = item;
        end
    end
    self:write_to_file();
end

-- 
function editor_version_manager:is_exist_api(api_version)
    self:load();
    if type(self.table['all_api_list']) == "table" then
        for _, item in ipairs(self.table['all_api_list']) do
            if item.api_version == api_version.api_version then
                return true
            end
        end
    end
    return false
end


-- 更新项目API的名字
function editor_version_manager:refresh_api_name(api_version)
    self:load()
    if type(self.table['all_api_list']) == "table" then
        for _, item in ipairs(self.table['all_api_list']) do
            if item.api_version == api_version.api_version then
                api_version = item
                return api_version, true
            end
        end
    end
    return api_version, false
end

local project_api_manager = {}

function project_api_manager:load(path)
    local result, content = io_read(path .. '/project/map_settings.json')
    if result == 0 then
        local json_table, error_info = common.json_decode(content);
        if not json_table then
            log.warn('[project_api_manager:load] 解析json 失败' .. tostring(error_info))
        else
            self.table = json_table
        end
    else
        log.info('[project_api_manager:load] 打开' .. path .. '/project/map_settings.json失败，错误码：' .. tostring(result))
    end
end

-- 获取项目版本号
function project_api_manager:get(path)
    self:load(path)
    if self.table['api_version'] == nil then
        self.table['api_version'] = default_api_version;
    end
    if self.table['api_version'].api_version == -1 then -- 之前把默认版本号写成-1 现在改成0
        self.table['api_version'].api_version = 0
    end
    if self.table['api_version'].api_version == -1 then -- 之前把默认版本号写成-1 现在改成0
        self.table['api_version'].api_version = 0
    end
    return self.table['api_version']
end

-- 保存项目版本号
function project_api_manager:save(path, new_version)
    self:load(path)
    if self.table then
        self.table['api_version'] = new_version;
        local p = path .. '/project/map_settings.json';
        local data = base.json.encode(self.table)
        if not io_write(p, data) then
            error(('project_api_manager:set write project_api_version failed. path[%s], data[%s]'):format(p, data))
        end
    end
end

-- 改成在线的
local function get_all_api_version(open_window, co)
    local url = ('%s/api/map/api-version'):format(base.calc_http_server_address('updater', 9002));
    log.info("请求API列表", url);
    local output = sce.httplib.create_stream();
    local code, status = coroutine.call(sce.httplib.request, {
        url = url, output = output, method = 'post',
    })
    if code ~= 0 or status ~= 200 then
        log.error(string.format('update_all_api_version failed. code[%s] status[%s]', code, status))
        log.warn('[update_all_api_version] 解析json 失败')
        local jsonStr = '[{"api_version":-1,"show_name":"获取列表错误无法修改当前API"}]';
        local jsonObj = json.decode(jsonStr);
        open_window(co, jsonObj)
        return jsonObj;
    end
    --先这么写
    local ret_str = output:read()
    local suc, info = pcall(json.decode, ret_str);
    if not suc then
        log.warn('[update_all_api_version] 解析json 失败')
        local jsonStr = '[{"api_version":-1,"show_name":"获取列表错误无法修改当前API"}]';
        local jsonObj = json.decode(jsonStr);
        open_window(co, jsonObj)
        return jsonObj;
    else
        local show_info = {}
        for _,item  in ipairs(info) do
            if item.visible == 1 or argv.has("inner") then
                table_insert(show_info,item)
            end
        end
        -- 每次成功更新后把API列表存到 editor_api_version.json里
        editor_version_manager:save_all_api(show_info);
        open_window(co, show_info)
        return show_info;
    end
end

local argv = require '@base.base.argv'
--切换API版本 后重启编辑器
local function change_api_restart()
    -- 代码以弃用 注释掉
    -- local dir = common.get_app_dir()
    -- local launcher = dir .. argv.get('launcher')
    -- local cmdline = common.get_full_cmdline()
    -- log.info(('common.open_url("%s", "%s")'):format(launcher, cmdline))
    -- log.info('API已切换，请重启编辑器(即将弹框)')
    -- local EMessageBox
    -- if lua_state_name == 'StateEditor' then
    --     EMessageBox = ImportSCEContext():GetEMessageBox()
    --     EMessageBox:set_size(300, 160)
    --     EMessageBox:begin('API已切换，请重启编辑器;;重启编辑器')
    -- else
    --     confirm.message(base.i18n.get_text('API已切换，请重启客户端'))
    -- end
    -- common.open_url(launcher, cmdline)
    -- log.info("common.force_exit()")
    -- common.force_exit()
end


-- 读取aim_verison.json里面的东西,并修改成 (包名->数据项) 映射关系
local function get_aim_version_dict(map_path)
    local aim_version_path = map_path .. '/ref/aim_version.json'
    local ok, content = io_read(aim_version_path)
    if ok ~= 0 then
        log.info('[add_lib_path] when get_aim_version_json for ' .. map_path .. ', io.read failed')
    else
        local ok, pak_version_list = xpcall(json.decode, function(err) log.info('[get_aim_version_json] 解析' .. aim_version_path .. '失败') end, content)
        if ok then
            local name_to_pak_version = {} --改写成名字映射信息的表 之后好处理一点
            for _, item in ipairs(pak_version_list) do
                name_to_pak_version[item.name] = item
            end
            return name_to_pak_version
        end
    end
    return nil
end

return {
    editor_version_manager = editor_version_manager,
    project_api_manager = project_api_manager,
    get_all_api_version = get_all_api_version,
    change_api_restart = change_api_restart,
    get_aim_version_dict = get_aim_version_dict,
}
