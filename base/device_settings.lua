local device_profile = require 'device_profile'
local render_quality_list = { 'ExLow', 'Low', 'Medium', 'High', 'Full' }

local function get_renderer_settings_level(platform, device_detail, renderer_name)
    local settings = device_profile[platform]
    if settings then
        for index, render_quality in ipairs(render_quality_list) do
            local match_func = settings[render_quality]
            if match_func and match_func(device_detail, renderer_name) then
                return index, render_quality
            end
        end
    end
    return -1, nil
end

-- 获取render_level对应的画面设置
local function get_renderer_settings(render_level)
    if render_level < 1 then
        render_level = 1
    end
    if render_level > #render_quality_list then
        render_level = #render_quality_list
    end
    local renderer_settings = {
        render_level = render_level,
        render_level_desc = render_quality_list[render_level],
    }
--[[
    场景画质：
    RENDER_QUALITY_LOW = 0
    RENDER_QUALITY_MEDIUM = 1
    RENDER_QUALITY_HIGHT = 2
    RENDER_QUALITY_FULL

    粒子质量：
    ParticleLevelHeight = 0,
    ParticleLevelMiddle = 1,
    ParticleLevelLow    = 2,
]]
    if render_level == 1 then            -- ExLow
        renderer_settings.scene_quality = 0
        renderer_settings.particle_lod_level = 2
        renderer_settings.dynamic_point_light = false
        renderer_settings.reoslution_level = 540
        renderer_settings.fps = 30
        renderer_settings.hdr = false
    elseif render_level == 2 then        -- Low
        renderer_settings.scene_quality = 0
        renderer_settings.particle_lod_level = 2
        renderer_settings.dynamic_point_light = false
        renderer_settings.reoslution_level = 720
        renderer_settings.fps = 60
        renderer_settings.hdr = false
    elseif render_level == 3 then        -- Mid
        renderer_settings.scene_quality = 1
        renderer_settings.particle_lod_level = 1
        renderer_settings.dynamic_point_light = false
        renderer_settings.reoslution_level = 720
        renderer_settings.fps = 60
        renderer_settings.hdr = true
    elseif render_level == 4 then         -- High
        renderer_settings.scene_quality = 2
        renderer_settings.particle_lod_level = 0
        renderer_settings.dynamic_point_light = true
        renderer_settings.reoslution_level = 720
        renderer_settings.fps = 60
        renderer_settings.hdr = true
    else                                 -- Full
        renderer_settings.scene_quality = 3
        renderer_settings.particle_lod_level = 0
        renderer_settings.dynamic_point_light = true
        renderer_settings.reoslution_level = 720
        renderer_settings.fps = 60
        renderer_settings.hdr = true
    end
    return renderer_settings
end

-- 获取设备的默认画面设置
local function get_renderer_default_settings()
    local device_detail = ''
    if common.get_detail then
        device_detail = common.get_detail()
    end
    local render_level, render_level_desc = get_renderer_settings_level(common.get_platform(), device_detail, common.get_renderer_name())
    if render_level == -1 then
        -- 未知的设备，使用mid设置
        if common.get_platform() ~= 'Windows' then
            render_level = 3
        end
        render_level_desc = nil
    end
    return get_renderer_settings(render_level)
end

local function apply_renderer_default_settings()
    local renderer_settings = get_renderer_default_settings()
    if renderer_settings.render_level_desc then
        log.info(string.format('current device renderer settings level: %s(%d)', 
            renderer_settings.render_level_desc, renderer_settings.render_level))
    else
        log.warn('can not found device profile settings')
    end

    if renderer_settings.render_level ~= -1 then
        if common.set_render_quality then
            common.set_render_quality(renderer_settings.scene_quality)
        else
            log.error('common.set_render_quality is nil')
        end
        if common.set_particle_lod_level then
            common.set_particle_lod_level(renderer_settings.particle_lod_level)
        else
            log.error('common.set_particle_lod_level is nil')
        end
        if common.set_point_light_enabled then
            common.set_point_light_enabled(renderer_settings.dynamic_point_light)
        else
            log.error('common.set_point_light_enabled is nil')
        end
        if common.set_use_cluster then
            common.set_use_cluster(renderer_settings.dynamic_point_light)
        else
            log.error('common.set_use_cluster is nil')
        end
        -- if common.set_resolution_level then
        --     common.set_resolution_level(renderer_settings.reoslution_level)
        -- else
        --     log.error('common.set_resolution_level is nil')
        -- end
        if common.set_lock_max_fps then
            common.set_lock_max_fps(renderer_settings.fps)
        else
            log.error('common.set_lock_max_fps is nil')
        end
        if common.set_postprocess_enabled then
            common.set_postprocess_enabled(renderer_settings.hdr)
        else
            log.error('common.set_postprocess_enabled is nil')
        end
    end
end

-- unit test
-- local function unit_test()
--     local str = '\n'
--     local test = {
--         -- Renderer name test   
--         { 'Android', 'Unknown', 'Mali-T6' }, -- ExLow
--         { 'Android', 'Unknown', 'Mali-T7' }, -- ExLow
--         { 'Android', 'Unknown', 'Mali-T8' }, -- ExLow
--         { 'Android', 'Unknown', 'Mali-G71' }, -- ExLow
--         { 'Android', 'Unknown', 'Mali-G52 MC2' }, -- Low
--         { 'Android', 'Unknown', 'Mali-G52' }, -- Low
--         { 'Android', 'Unknown', 'Mali-G51' }, -- Low
--         { 'Android', 'Unknown', 'Mali-G68' }, -- Mid
--         { 'Android', 'Unknown', 'Mali-G72' }, -- Mid
--         { 'Android', 'Unknown', 'Mali-G76' }, -- Mid    
--         { 'Android', 'Unknown', 'Mali-G57' }, -- High
--         { 'Android', 'Unknown', 'Mali-G77' }, -- High
--         { 'Android', 'Unknown', 'Mali-G78' }, -- High
--         { 'Android', 'Unknown', 'Adreno (TM) 512' }, -- ExLow
--         { 'Android', 'Unknown', 'Adreno (TM) 619' }, -- Low
--         { 'Android', 'Unknown', 'Adreno (TM) 630' }, -- Mid
--         { 'Android', 'Unknown', 'Adreno (TM) 642L' }, -- High
--         { 'Android', 'Unknown', 'Adreno (TM) 650' }, -- High
--         { 'Android', 'Unknown', 'Adreno (TM) 730' }, -- High
--         { 'Android', 'Unknown', 'PowerVR Rogue G66' }, -- ExLow
--         { 'Android', 'Unknown', 'PowerVR Rogue GX66' }, -- Low
--         { 'Android', 'Unknown', 'PowerVR Rogue GT78' }, -- Mid
--         { 'Android', 'Unknown', 'PowerVR Rogue GE86' }, -- ExLow
--         { 'Android', 'Unknown', 'PowerVR Rogue GM95' }, -- Mid
--         { 'Android', 'Unknown', 'NVIDIA Tegra' }, -- Low
--         { 'iOS', 'Unknown', 'A6' }, -- ExLow
--         { 'iOS', 'Unknown', 'A7' }, -- ExLow
--         { 'iOS', 'Unknown', 'A8' }, -- ExLow
--         { 'iOS', 'Unknown', 'A9' }, -- ExLow
--         { 'iOS', 'Unknown', 'A10' }, -- Low
--         { 'iOS', 'Unknown', 'A11' }, -- Mid
--         { 'iOS', 'Unknown', 'A12' }, -- Mid
--         { 'iOS', 'Unknown', 'A13' }, -- High
--         { 'iOS', 'Unknown', 'A14' }, -- High

--         -- Device detail test
--         { 'Android', 'HLK-AL00 HONOR', 'Unknown' }, -- ExLow
--         { 'Android', 'YAL-AL00 HONOR', 'Unknown' }, -- Low
--         { 'Android', 'PCT-AL10 HONOR', 'Unknown' }, -- Low
--         { 'Android', 'BMH-AN20 HONOR', 'Unknown' }, -- High       
--         { 'Android', 'TAS-AL00 HUAWEI', 'Unknown' }, -- Low
--         { 'Android', 'SEA-AL10 HUAWEI', 'Unknown' }, -- Low
--         { 'Android', 'ELE-AL00 HUAWEI', 'Unknown' }, -- Mid
--         { 'Android', 'LYA-AL00 HUAWEI', 'Unknown' }, -- Mid
--         { 'Android', 'VOG-AL10 HUAWEI', 'Unknown' }, -- High
--         { 'Android', 'PBEM00 OPPO', 'Unknown' }, -- Low
--         { 'Android', 'V2031A vivo', 'Unknown' }, -- Mid
--         { 'Android', 'V1981A vivo', 'Unknown' }, -- High   
--         { 'Android', 'GM1910 OnePlus', 'Unknown' }, -- High
--     }
--     for _, v in ipairs(test) do
--         local _1, _2 = get_renderer_settings_level(v[1], v[2], v[3])
--         str = str .. string.format('%s-%s-%s: %s(%d)\n', v[1], v[2], v[3], _2, _1)
--     end
--     return str
-- end

-- log.alert(unit_test())

--[[
Android_Adreno3xx       Adreno (TM) 300 ~ Adreno (TM) 399  ExLow
Android_Adreno4xx       Adreno (TM) 400 ~ Adreno (TM) 499  ExLow
Android_Adreno5[0-4]x   Adreno (TM) 500 ~ Adreno (TM) 549  ExLow
Android_Adreno5[5-9]x   Adreno (TM) 550 ~ Adreno (TM) 599  Low
Android_Adreno6[0-2]x   Adreno (TM) 600 ~ Adreno (TM) 629  Low
Android_Adreno63x       Adreno (TM) 630 ~ Adreno (TM) 639  Mid
Android_Adreno6[4-9]x   Adreno (TM) 640 ~ Adreno (TM) 649  High
Android_Adreno65x       Adreno (TM) 650 ~ Adreno (TM) 659  High
Android_Adreno66x       Adreno (TM) 660 ~ Adreno (TM) 669  High
Android_Adreno73x       Adreno (TM) 730 ~ Adreno (TM) 739  High
Android_Mali_T6xx       Mali-T6     ExLow
Android_Mali_T7xx       Mali-T7     ExLow
Android_Mali_T8xx       Mali-T8     ExLow
Android_Mali_G71        Mali-G71    ExLow
Android_Mali_G51        Mali-G51    Low
Android_Mali_G52        Mali-G52    Mid => 改 Low
Android_Mali_G68        Mali-G68    Mid
Android_Mali_G72        Mali-G72    Mid
Android_Mali_G76        Mali-G76    Mid
Android_Mali_G57        Mali-G57    High
Android_Mali_G77        Mali-G77    High
Android_Mali_G78        Mali-G78    High
Android_PowerVR_G6xxx   PowerVR Rogue G6[0-9]+   ExLow
Android_PowerVR_GX6xxx  PowerVR Rogue GX6[0-9]+  Low
Android_PowerVR_GT7xxx  PowerVR Rogue GT7[0-9]+  Mid
Android_PowerVR_GE8xxx  PowerVR Rogue GE8[0-9]+  ExLow
Android_PowerVR_GM9xxx  PowerVR Rogue GM9[0-9]+  Mid
Android_TegraK1         NVIDIA Tegra             Low
]]

return {
    apply_renderer_default_settings = apply_renderer_default_settings,
    get_renderer_default_settings = get_renderer_default_settings,
    get_renderer_settings = get_renderer_settings,
}
