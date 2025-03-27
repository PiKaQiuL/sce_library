---
--- Generated by EmmyLua(https://github.com/EmmyLua)
--- Created by xindong.
--- DateTime: 2021/7/28 18:04
---

-- isolation: 隔离
-- 隔离一些不安全的函数

local path = require 'base.path'
local argv = require 'base.argv'
local util = require 'base.util'

log_file.info(("load isolation.lua, __lua_state_name[%s]"):format(__lua_state_name))

local main_map = __MAIN_MAP__
local debug_traceback = debug.traceback
local app_dir = path(io.get_root_dir())
local root_path = app_dir / 'User/maps' / main_map
io.get_user_data_path = function()
    return tostring(root_path)
end

if __lua_state_name == 'StateGame' then
    local is_editor_debug = argv.has("editor_server_debug") or argv.has("editor_lobby_debug")

    local function full(p)
        if p:find('..', 1, true) ~= nil then
            if not is_editor_debug then
                error (('StateGame中路径[%s]不能使用".."'):format(p))
            end
        end

        local pp = path(p)
        if pp:is_absolute() then
            if is_editor_debug then
                return pp.str
            else
                error (('StateGame中必须使用相对路径, traceback: %s'):format(debug_traceback()))
            end
        end

        return (root_path / pp).str
    end

    local write = io.write
    io.write = function(p, ...)
        local full_p = full(p)
        local ret = write(full_p, ...)
        if ret ~= 0 then
            log.error(('io.write failed, full path[%s], error_code[%s]'):format(full_p, ret))
        end
        return ret
    end

    local read = io.read
    io.read = function(p, ...)
        local full_p = full(p)
        local ret, content = read(full_p, ...)
        if ret ~= 0 then
            log_file.warn(('io.read failed, full path[%s], error_code[%s]'):format(full_p, ret))
        end
        return ret, content
    end

    local copy = io.copy
    io.copy = function(p1, p2, ...)
        local full_p1 = full(p1)
        local full_p2 = full(p2)
        local ret = copy(full_p1, full_p2, ...)
        if ret ~= true then
            log.error(('io.copy failed, from path[%s], to path[%s] error_code[%s]'):format(full_p1, full_p2, ret))
        end
        return ret
    end

    local rename = io.rename
    io.rename = function(old_p, new_p, ...)
        local full_p1 = full(old_p)
        local full_p2 = full(new_p)
        local ret = rename(full_p1, full_p2, ...)
        if ret ~= true then
            log.error(('io.rename failed, from path[%s], to path[%s] error_code[%s]'):format(full_p1, full_p2, ret))
        end
        return ret
    end

    local remove = io.remove
    io.remove = function(p, ...)
        local full_p = full(p)
        local ret = remove(full_p, ...)
        if ret ~= 0 then
            log.error(('io.remove failed, full path[%s], error_code[%s]'):format(full_p, ret))
        end
        return ret
    end

    local copy_to_folder = io.copy_to_folder
    io.copy_to_folder = function(src_p, dest_p, ...)
        local full_p1 = full(src_p)
        local full_p2 = full(dest_p)
        local ret = copy_to_folder(full_p1, full_p2, ...)
        if ret ~= true then
            log.error(('io.copy_to_folder failed, from path[%s], to path[%s] error_code[%s]'):format(full_p1, full_p2, ret))
        end
        return ret
    end

    local create_dir = io.create_dir
    io.create_dir = function(p, ...)
        local full_p = full(p)
        local ret = create_dir(full_p, ...)
        if ret ~= true then
            log.error(('io.create_dir failed, full path[%s], error_code[%s]'):format(full_p, ret))
        end
        return ret
    end

    local exist_dir = io.exist_dir
    io.exist_dir = function(p, ...)
        return exist_dir(full(p), ...)
    end

    local exist_file = io.exist_file
    io.exist_file = function(p, ...)
        return exist_file(full(p), ...)
    end

    local walk_dir = io.walk_dir
    io.walk_dir = function(p, ...)
        return walk_dir(full(p), ...)
    end

    local list = io.list
    io.list = function(p, ...)
        return list(full(p), ...)
    end

    local attribute_type = io.attribute_type
    io.attribute_type = function(p, ...)
        return attribute_type(full(p), ...)
    end

    local file_time = io.file_time
    io.file_time = function(p, ...)
        return file_time(full(p), ...)
    end

    local dofile = _G.dofile
    _G.dofile = function(p, ...)
        return dofile(full(p), ...)
    end

    local loadfile = _G.loadfile
    _G.loadfile = function(p, mode, ...)
        mode = 't'  -- forbidden binary, only support text
        return loadfile(full(p), mode, ...)
    end

    local load = _G.load
    _G.load = function(chunk, mode, ...)
        mode = 't'  -- forbidden binary, only support text
        return load(chunk, mode, ...)
    end

    io.walk_resource_dir = nil
    io.walk_absolute_dir = nil
    io.popen = nil
    io.check_resource_dir = nil
    io.check_resource_file = nil

    io.deserialize = nil
    io.serialize = nil
    io.is_serializing = nil
    io.read_cache = nil

    io.read_pak_entries = nil
    io.extract_pak = nil
    io.extract_pak_file = nil

    io.copy_cache_file = nil
    io.download_file = nil
    if not argv.has('auto_test') then
        io.upload_file = nil
    end
    -- io.unzip_file = nil
    -- io.zip_file = nil

    io.add_resource_path = nil
    io.remove_resource_path = nil

    io.select_file = nil
    io.select_files = nil
    io.select_folder = nil
    io.select_folder_new = nil
    io.open_path_in_explorer = nil
    io.show_file_in_explorer = nil

    io.add_watch = nil
    io.remove_watch = nil

    io.empty_method = nil

    io.get_package_path = nil

    io.create_dir('.')

    os.execute = nil
    os.exit = nil
    os.remove = nil
    os.rename = nil
    os.setlocale = nil
    os.tmpname = nil

    debug.getregistry = nil
    debug.getupvalue = nil
    debug.setlocal = nil
    debug.getlocal = nil
    debug.upvaluejoin = nil
    debug.sethook = nil
    debug.setupvalue = nil
    debug.setuservalue = nil
    debug.upvalueid = nil
    debug.gethook = nil

    cmsg_pack.set_max_pack_byte_count = nil

    -- c++里面用的是real_package, 这里包装一下
    local raw_package = _G.package
    _G.package = setmetatable({}, {
        __newindex = function(self, key, value)
            if key == 'path' then
                assert(type(value) == 'string')
                local li = util.split(value, ';')
                for _, sub in ipairs(li) do
                    if sub:find('[.][.]') or sub:find('^[\\w\\d]+:') or sub:find('^/') then
                        error(('set package.path with an invalid string: %s'):format(sub))
                    end
                end
            end
            raw_package[key] = value
        end,
        __index = function(self, key)
            return raw_package[key]
        end
    })

    _G.package.loadlib = nil


    log_file.info('执行绝地天通完成')
end