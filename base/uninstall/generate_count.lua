local path                 = require 'base.path'
local local_version        = require 'update.core.local_version'
local global_client_suffix = local_version.global_client_suffix
local download_manager     = require 'update.download_manager'

local root_path            = path(io.get_root_dir())
local version_path         = root_path / 'Update' / _G.update_subpath
local map_path             = root_path / 'Update' / _G.update_subpath / 'Res' / 'maps'

local io_list              = io.list


local create_request  = require 'base.request'
local request         = create_request('updater')
local last_http_base  = nil

local generate_count  = {}
local tostring        =tostring
local game_count_list = {}

function generate_count:request_game_info(game_names)
    log.info('generate_count:request_game_info update info', game_name)
    local game_info_list = download_manager:update_version_info({ update_list = game_names, default_part = 1, request_game_info = true })

    log.info('update info generate_count:request_game_info', base.json.encode(game_names),
        base.json.encode(game_info_list))

    -- 增加依赖包的计数
    for _, info in pairs(game_info_list) do
        if info.packet_type ~= 1 then
            local count = 0;
            if info.belong_map then
                count = #info.belong_map
                for __, map_name in ipairs(info.belong_map) do
                    local_version:update_game_info(map_name, info) -- 更新地图依赖包
                end
            end
            local_version:set_count(info.name, info.version, count);
        end
    end

    -- 设置地图的依赖计数
    local game_name
    for _, info in pairs(game_info_list) do
        if info.packet_type == 1 then
            game_name = info.name
            local_version:add_count(info.name, info.version)
            local_version:update_game_info(game_name, info)
        end
    end
end

function generate_count:init()
    log.info("generate_count:init", version_path)
    log.info("generate_count:init", map_path)
    local_version:load(version_path)
    local res, dir_list = io_list(tostring(map_path), 2)

    if res ~= 0 then
        log.info("读取maps目录失败")
        return 1
    else
        local_version:init_game_info()
        local game_names = {}
        local prefix = tostring(map_path) .. '/'
        for i, p in pairs(dir_list) do
            --这里查update-info
            local file_name = p:sub(#prefix + 1)
            game_names[#game_names + 1] = file_name
        end
        game_names[#game_names + 1] = 'global_default' -- 特判把global_default当做游戏
        generate_count:request_game_info(game_names)
        local_version:save()
    end
end

return generate_count
