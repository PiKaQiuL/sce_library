local update_record = {}
local tostring      = tostring
local io_exist_dir  = io.exist_dir
local io_create_dir = io.create_dir
local path          = require '@base.base.path'
local root_path     = path((io.get_root_dir())) / 'Update' / _G.update_subpath / 'record';
local os_date       = os.date
local get_http_env  = base.get_http_env
local io_write      = io.write
local io_write_to_file_end = io.write_to_file_end
local argv          = require 'base.argv'
local file_name
local string_sub    =  string.sub


function update_record:file_name()
    if file_name == nil then
        self.write_count = 0
        file_name = 'record-' .. os_date('%Y-%m-%d_%H-%M-%S') .. '.json'
    end
    return file_name
end

function update_record:path()
    if not io_exist_dir(tostring(root_path)) then
        if not io_create_dir(tostring(root_path)) then
            log.error(("update_record create_dir failed path[%s]"):format(tostring(root_path)))
            return nil
        end
    end
    return root_path / update_record:file_name()
end

function update_record:write(data)
    local env = get_http_env()
    if env ~= 'master' and not argv.has('inner') then
        return --
    end
    local path = tostring(self:path())
    local save_data = {}
    local name = data.info.name
    local version = data.info.version
    data.update_time = os_date('%Y-%m-%d_%H-%M-%S')
    if argv.has('editor_api_version') then
        data.editor_api_version = argv.get('editor_api_version')
    end
    if argv.has('actual_binary_api') then
        data.actual_binary_api = argv.get('actual_binary_api')
    end
    save_data[tostring(name .. '-' .. tostring(version))] = data

    local msg = base.json.encode(save_data)
    self.write_count = self.write_count + 1
    if io_write_to_file_end ~= nil then
        if not io_write_to_file_end(path, msg) then
            error(('update_record:save write pak_api_version failed. path[%s], data[%s]'):format(path, data))
        end
    else
        path = string_sub(path, 1, -6) .. '-' .. tostring(self.write_count) .. '.json'
        if not io_write(path, msg) then
            error(('update_record:save write pak_api_version failed. path[%s], data[%s]'):format(path, data))
        end
    end
end

function update_record:clear()

end

return update_record
