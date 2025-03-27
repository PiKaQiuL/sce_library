-- 储存每个地图名依赖的包的版本号

local path                    = require '@base.base.path'
local io_read                 = io.read
local io_write                = io.write

local root_path               = path(io.get_root_dir()) / 'Update' / _G.update_subpath;
local map_pak_version_manager = {}
local util = require 'base.util'

-- StateApp 需要的非多API包只有这四个 appui gameui global_default script
local state_application_need_map           = { 'gameui', 'appui', 'global_default', 'script' }

function map_pak_version_manager:path()
    return root_path / 'map_pak_version.json';
end

function map_pak_version_manager:load()
    if self.table then
        return;
    end
    log.info("map_pak_version_manager:load");
    self.change = false;
    local result, content = io_read(tostring(self:path()))
    if result == 0 then
        local json_table, error_info = common.json_decode(content);
        if not json_table then
            log.warn('map_pak_version_manager解析json 失败' .. tostring(error_info))
            self.table = {}
        else
            self.table = json_table
        end
    else
        self.table = {}
    end
    self.changed_pak_list = {}
    if self.table['#StateApplication'] ~= nil then --清除之前多添加的包
        local data = self.table['#StateApplication']
        for key, value in pairs(data) do
            if not self:is_state_application_need_pak(key) then
                log.info("清理之前的错误修改", key)
                data[key] = nil
                self.change = true
            end
        end
    end
end

function map_pak_version_manager:is_state_application_need_pak(map_name)
    return util.indexOf(state_application_need_map, map_name) ~= -1
end

-- 获取stateApp需要的包
function map_pak_version_manager:get_state_application_pak_version()
    self:load();
    local pak_list = {}
    for name, version in pairs(self.table['#StateApplication']) do
        pak_list[name] = version
    end
    return pak_list
end

-- 设置地图版本号下对应的 包版本号 （地图名，包名，包版本号）
function map_pak_version_manager:set(map_name, pak_name, pak_version)
    common.set_map_pak_version(map_name, pak_name, pak_version);
    -- 上面的代码是修改内存里存储的包版本号,下面的代码存储到json里，除了#StateApp，都不应该读取到json里的数据
    self:load();
    local have_change = false; --这次修改了数据
    local newItem = self.table[map_name];
    if newItem == nil then
        newItem = {}
        log.info("map_pak_version_manager:change", map_name, pak_name, pak_version);
        self.change = true;
        have_change = true;
        self.changed_pak_list[#self.changed_pak_list + 1] = pak_name
    end
    if newItem[pak_name] ~= pak_version then
        self.change = true;
        have_change = true;
        self.changed_pak_list[#self.changed_pak_list + 1] = pak_name
        log.info("map_pak_version_manager:change", map_name, pak_name, pak_version, 'oldversion', newItem[pak_name]);
    end
    newItem[pak_name] = pak_version;
    self.table[map_name] = newItem;
    return have_change
end

function map_pak_version_manager:save()
    if not self.change then
        return;
    end
    log.info("map_pak_version_manager:save begin");
    local p = tostring(self:path())
    local data = base.json.encode(self.table)
    if not io_write(p, data) then
        error(('map_pak_version_manager:save write pak_api_version failed. path[%s], data[%s]'):format(p, data))
        return;
    end
    self.change = false;
end

return map_pak_version_manager
