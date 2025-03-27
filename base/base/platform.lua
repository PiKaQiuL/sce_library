
local web = require 'base.web'
local argv = require 'base.argv'

local binary_map = {
    ['Windows'] = 'Win',
    ['Android'] = {
        ['sce'] = 'Android',
    },
    ['iOS'] = {
        ['sce'] = 'ios_app',
        ['enterprise'] = 'ios',
        ['appstore'] = 'ios-appstore',
    },
}

local function is_win()
    return not common.has_arg('android') and not common.has_arg('ios') and common.get_platform() == 'Windows'
end

local function is_web()
    return common.get_platform() == 'Web'
end

local function is_web_ios()
    if is_web() then
        local is_ios = js.call([[
            isIOS() + ''
        ]])
        return is_ios == 'true'
    end
    return false
end

local function is_web_pc() 
    if is_web() then
        local is_mobile = js.call([[
            isMobile() + ''
        ]])
        return is_mobile ~= 'true'
    end
    return false
end

local function is_web_mobile() 
    if is_web() then
        return not is_web_pc()
    end
    return false
end

local function is_web_android()
    if is_web() then
        return is_web_mobile() and (not is_web_ios())
    end
    return false
end

local function is_wx()
    return common.get_platform() == 'Wx' and not argv.has('qq')
end

local function is_wx_devtool()
    if not is_wx() then return false end
    local system_info = base.wx.call('get_system_info')
    return system_info.brand == 'devtools'
end

local function is_wx_ios()
    if not is_wx() then return false end
    if is_wx_devtool() then return false end
    local system_info = base.wx.call('get_system_info')
    return system_info.system:find('iOS', 1, true) ~= nil
end

local function is_wx_android()
    if not is_wx() then return false end
    if is_wx_devtool() or is_wx_ios() then return false end
    return true
end

local function is_qq()
    return common.get_platform() == 'Wx' and argv.has('qq')
end

local function is_qq_devtool()
    if not is_qq() then return false end
    local system_info = base.wx.call('get_system_info')
    return system_info.brand == 'devtools'
end

local function is_qq_ios()
    if not is_qq() then return false end
    if is_qq_devtool() then return false end
    local system_info = base.wx.call('get_system_info')
    return system_info.system:find('iOS', 1, true) ~= nil
end

local function is_qq_android()
    if not is_qq() then return false end
    if is_qq_devtool() or is_qq_ios() then return false end
    return true
end

local function is_android()
    return common.has_arg('android') or common.get_platform() == 'Android'
end

local function is_ios()
    return common.has_arg('ios') or common.get_platform() == 'iOS'
end

local function is_appstore()
    return common.get_argv('from') == 'appstore'
end

local function is_mobile()
    if common.get_debug_game_mobile then
        return is_ios() or is_android() or common.get_debug_game_mobile()
    else
        return is_ios() or is_android()
    end
end

local function is_mobile_game()
    return is_mobile() or common.has_arg('mobile')
end

local function is_haoyou()
    return common.get_argv('from') == 'haoyou'
end

local function is_taptap()
    return common.get_argv('from') == 'taptap'
end

local function is_offical()
    if is_web() then
        return not web.is_sdk()
    end

    if is_ios() then
        return false
    end

    if is_win() then
        return not common.has_arg('SDK')
    end

    local from = common.get_argv('from')
    if is_android() then
        return from == 'ce' or from == '' or from == nil
    end

    return false
end

-- GetPlatform返回
-- String GetPlatform()
-- {
--     #if defined(__ANDROID__)
--         return "Android";
--     #elif defined(IOS)
--         return "iOS";
--     #elif defined(TVOS)
--         return "tvOS";
--     #elif defined(__APPLE__)
--         return "macOS";
--     #elif defined(_WIN32)
--         return "Windows";
--     #elif defined(RPI)
--         return "Raspberry Pi";
--     #elif defined(__EMSCRIPTEN__)
--     #if defined(EMSCRIPTEN_WX)
--         return "Wx";
--     #else
--         return "Web";
--     #endif
--     #elif defined(__linux__)
--         return "Linux";
--     #else
--         return "(?)";
--     #endif
-- }

local function binary()
    if common.get_binary then        
        return common.get_binary()
    else
        -- 转移到c++里了，下面的代码是兼容考虑；之后如果不满意C++里的逻辑，lua里要再改也是可以的。。
        if binary_map[common.get_platform()] then
            local plat = common.get_platform()
            if is_mobile() then
                local channel = ''
                if common.has_arg('from') then
                    channel = common.get_argv('from')
                end
                local binary = binary_map[plat][channel]
                if not binary then
                    if common.has_arg('game') then
                        binary = common.get_argv('game') .. '_' .. common.get_platform() -- 对于from里没有且有带了game参数的，统一使用这种拼装方式
                    else                    
                        binary = binary_map[plat]['sce'] -- 默认                    
                    end
                end
                return binary
            end
            return binary_map[plat]
        end
        return nil
    end
end

-- 判断是否为正式服环境
local function is_formal()

    if is_web() then
        local formal_url = 'blzzq.com'
        local url = js.call([[
            window.location.href
        ]])
        if url:find(formal_url, 1, true) then
            return true
        end
    end

    if is_win() then
        local entrance = common.get_argv('entrance')
        if entrance ~= '' then
            return true
        end
    end

    if is_android() or is_ios() then
        return true
    end

    return false
end

local function is_app()
    return __MAP_NAME == 'Script'
end

local cpp_create_shortcut = common.create_shortcut

local function create_shortcut()
    local game = common.get_argv('game')
    sce.s.score_init(sce.s.readonly_map, 40, {
        ok = function(score)
            log.info(common.json_encode(score))
            score = score and score[game]
            if score then
                local craft_id = score['craft_id']
                if not craft_id then
                    log.error('[shortcut] craft id not found :'.. tostring(game))
                    return
                end
                cpp_create_shortcut(craft_id)
            end
        end ,
        error = function(err)
            log.error(('[shortcut] quert craft id failed: %d'):format(err))
        end,
        timeout = function()
            log.error('[shortcut] query craft id timeout')
        end
    },game)
end

local apis = {
    is_win = is_win,

    is_web = is_web,
    is_web_pc = is_web_pc,
    is_web_mobile = is_web_mobile,

    is_web_ios = is_web_ios,
    is_web_android = is_web_android,

    is_wx = is_wx,
    is_wx_ios = is_wx_ios,
    is_wx_android = is_wx_android,
    is_wx_devtool = is_wx_devtool,

    is_qq = is_qq,
    is_qq_ios = is_qq_ios,
    is_qq_android = is_qq_android,
    is_qq_devtool = is_qq_devtool,

    is_android = is_android,
    is_ios = is_ios,

    is_appstore = is_appstore,

    is_mobile = is_mobile,
    is_mobile_game = is_mobile_game,

    is_formal = is_formal,
    is_offical = is_offical,

    is_haoyou = is_haoyou,
    is_taptap = is_taptap,

    binary = binary,

    is_app = is_app,
    create_shortcut = create_shortcut,
}

local function cache(func)
    local c
    return function(...)
        if c ~= nil then return c end
        c = func(...)
        return c
    end
end

for key, api in pairs(apis) do
    apis[key] = cache(api)
end

apis.override_binary_map = function(binary_map_name)
    apis.binary = function()
        return binary_map_name
    end
end

return apis
