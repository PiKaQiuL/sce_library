---------------------------------------------------
-- 账号相关
---------------------------------------------------

local ip_funcs = require "base.ip"
require 'base.client_id'
local co = include "base.co"
local lobby = include "base.lobby"
local dialog = require 'base.confirm'
local platform = include "base.platform"
local web = include "base.web"
local argv = require 'base.argv'
require 'base.utility' 

local calc_http_server_address = base.calc_http_server_address

local io_read = io.read
local io_write = io.write
local io_serialize = io.serialize
local lua_state_name            = __lua_state_name

local user_info_file = "User/user_info"
local is_during_sdk_login_ = false
local logining = false      -- 正在登录 --
local logined = false       -- 向服务器登录成功 --
local mark_login_if_success = false

local math_random = math.random
local math_floor = math.floor
local common_get_md5 = common.get_md5

---@class common_account
local account = {}

-- account info --
local account_data = 
{
    guest_id    = '',       -- uuid
    token       = '',       -- 比如TapTap的kid + mac_key
    token_type  = 0,        -- 比如TapTap是13
    login       = 0,        -- 是否需要给用户选登录方式，一般是首次安装先登录上去，第一次选则登录方式之后就一直是true了
    login_token = '',       -- 给http用的token
    login_token_secret = '',-- 辅助login_token的私钥
    access_token       = ''
}

local function uuid()
    return "GUEST_" .. os.date("%Y-%m-%d_%H_%M_%S_") .. common.get_system_time()
end


local game_flag = true
if lobby.vm_name() == 'StateEditor' then
    game_flag = false
end
if argv.has('editor_server_debug') then
    -- 意思是编辑器里调试进游戏, game_flag=false, 但是大厅调试等同于手机进游戏, game_flag=true
    game_flag = false
end

lobby.set_is_game_flag(game_flag)
log.info('[account] lobby game_flag is:', game_flag)

local function get_user_info_file()
    if _G.IP == "e.blzzq.com" or _G.IP == nil then
        return user_info_file .. ".json"
    else
        return user_info_file .. "-" .. _G.IP .. ".json"
    end
end

local function need_check_version()
    return string.find(_G.IP, "^e.alpha") or string.find(_G.IP, "^e.beta") 
end

local function load_user_info(path)
    log.info(('[account] load user_info_file.json: %s'):format(path))
    local result, user_info_str = io_read(path)
    if result == 0 then
        log.info('[account] load user info from file:', user_info_str)
        local user_info = base.json.decode(user_info_str)
        if user_info and (not need_check_version() or user_info.version) then
            return user_info
        end
    end

end

-- 初始化账号信息
-- 如果没有文件保存就生成一个uud
local function init()
    -- defualt
    account_data.guest_id = uuid()
    account_data.token_type = 999
    account_data.token = ""
    account_data.login = 0
    account_data.version = 1

    -- saved
    local saved = load_user_info(get_user_info_file())
    if saved then
        for k, v in pairs(account_data) do
            account_data[k] = saved[k] or account_data[k]
        end
    else
        account.save()
    end
    if common.has_arg('guest_id') then
        account_data.guest_id = common.get_argv('guest_id')
    end

    log.infof('[account] inited guest_id:%s token_type:%d token:%s login:%d', 
        account_data.guest_id,
        account_data.token_type,
        account_data.token,
        account_data.login)

    lobby.set_guest_id(account_data.guest_id)

end

local function set_token(token, token_type)
    token = token or ''
    token_type = token_type or 999

    log.info(("[account] set_token %s %d"):format(token, token_type))
    account_data.token = token
    account_data.token_type = token_type
end

local function set_access_token(access_token)
    access_token = access_token or ''
    log.info(("[account] set_access_token %s"):format(access_token))
    account_data.access_token = access_token
end

local function get_access_token()
    return account_data.access_token
end

local function set_login_token(login_token, login_token_secret)
    log.info(('got login_token[%s] login_token_secret[%s]'):format(login_token, login_token_secret))
    if not login_token or login_token == '' then
        return    -- 不清空http的token!!!
    end
    account_data.login_token = login_token
    account_data.login_token_secret = login_token_secret
    if lua_state_name == 'StateEditor' then
        local SCE = ImportSCEContext()
        if SCE.GetCSharpGoods then
            local csharp_goods = SCE.GetCSharpGoods()
            if csharp_goods then
                csharp_goods:set_login_token(login_token, login_token_secret)
            end
        end
    end
end


local function get_guest_id()
    return account_data.guest_id
end

local function send_login_detail(info)
    common.stat_sender('login_detail', {detail = info, guest_id = get_guest_id()})
end

-- 是否可以token登录(有有效的token)
local function token_valid() 
    -- 有有效token且类型是11或者13， 13手机登， 11编辑器
    local token_type_valid = 11 <= account_data.token_type and account_data.token_type <= 13
    return type(account_data.token) == 'string' and string.len(account_data.token) > 0 and token_type_valid
end

-- 下次登录成功时标记成登录状态 
local function mark_login_next_success()
    mark_login_if_success = true
end

-- 第三方登录
local function sdk_login()
    --统计拉起tap客户端登录情况 
    send_login_detail('open taptap')
    log.info('sdk_login ',debug.traceback())
    is_during_sdk_login_ = true
    lobby.request_sdk_login()
end


-- 登录 有token则token登录，没有就游客登录
local function login(allow_guest)
    if logining then
        log.error("禁止重复登录")
        return false
    end

    -- 有token用token 没token用游客的情况
    -- 1.pc
    -- 2.加auto_guest调试的
    -- 3.允许游客登陆的(默认不许
    -- 4.是ios内嵌(token_cache) 且有token
    if platform.is_win() or argv.has('auto_guest') or allow_guest or (argv.has('token_cache') and token_valid()) then
        if token_valid() then
            send_login_detail('cache token');
            log.info('[account] login using token', account_data.token, account_data.token_type)
            lobby.request_token_login(account_data.token_type, account_data.token)
        else 
            send_login_detail('guest login');
            log.info('[account] login using guest id', account_data.guest_id)
            lobby.request_guest_login()
        end
    else
        send_login_detail('sdk auth');
        log.info('[account] sdk auth')
        sdk_login()
        
    end
end


local function is_during_sdk_login()
    return is_during_sdk_login_
end

local function is_logined()
    return logined
end

-- 保存
local function save(force)
    local json_str = base.json.encode(account_data)
    log.info('[account] write user_info to file:', json_str)
    io_write(get_user_info_file(), json_str)
    co.async(
        function()
            local serialize = co.wrap(io_serialize)
            serialize()
        end
    )
end

--设置登录状态
local function set_login_state(state)
    state = state or 0
    account_data.login = state
end

local function logout()
	if lobby.sdk_logout then
		lobby.sdk_logout()
	end
    log.info('[account] account.logout()')

    --登录成游客
    set_token('', 999)
    set_login_state(0)
    lobby.logout();
    logined = false
    save()
end

-- 用户名
local function get_user_name()
    return user_name
end

--登录状态
local function get_login_state()
    return account_data.login
end

local function get_token_type()
    return account_data.token_type
end

account.latest_login_info = {
    user_id = nil,  ---@type string
    login_id = nil, ---@type string
    user_name = nil, ---@type string
    login_way = nil, ---@type number
}

if lobby.vm_name() == 'StateGame' then
    lobby.register_luaState_event('同步账号信息返回', function(latest_login_info)
        account.latest_login_info = latest_login_info
        log.debugf('[account] 收到从StateApplication同步的account信息, user[%s@%s] user_name[%s] login_way[%s]',
                account.latest_login_info.user_id,
                account.latest_login_info.login_id,
                account.latest_login_info.user_name,
                account.latest_login_info.login_way
        )
    end)

    log.debugf('[account] StateGame请求同步账号信息')
    lobby.send_luastate_broadcast('同步账号信息')
else
    lobby.register_luaState_event('同步账号信息', function()
        log.debugf('[account] 收到StateGame的同步account信息请求')
        if account.latest_login_info and account.latest_login_info.user_id then
            lobby.send_luastate_broadcast('同步账号信息返回', account.latest_login_info)
        else
            log.warnf('[account] 目前还没有登录, 无法同步account信息给StateGame')
        end
    end)
end

local function check_console_wl()
    local key = tostring(account.latest_login_info.user_id)
    sce.s.score_init(sce.s.readonly_map, 45, {
        ok = function(score)
            for k,v in pairs(score) do
                log.info('[ncy]', tostring(k), tostring(v))
            end
            account.latest_login_info.is_console_wl = score[key]
            log.info(('获取控制台白名单: %s'):format(score[key]))
        end ,
        error = function(err)
            log.error(('获取控制台白名单失败: %d'):format(err))
        end,
        timeout = function()
            log.error('获取控制台白名单超时')
        end
    }, key)
end


local function on_login_result(error_code, user_id, login_id, user_name, login_way, tk, tk2,login_token, login_token_secret, error_desc)
    logining = false
    if login_way ~= 999 then -- 暂时假设非游客就是SDK
        is_during_sdk_login_ = false
    end
    log.info('登录', error_code, user_id, login_id, user_name, login_way, tk, tk2)

    --统计登录结果 结果码:用户名:登录方式:token
    common.send_user_stat('login_result', ''..error_code..':'..user_name..':'..login_way..':'..tk..':'.. tostring(tk2))

    if error_code == 0 then
        logined = true
        if common.get_argv('compatible') == '1' then
            -- 对于担心连不上的人，走websocket代理
            common.add_argv('host_network', 'tcp')
            common.add_argv('host_proxy_address', string.format('ws://host-proxy-server-%s.spark.xd.com:9999', ip_funcs.get_ip_env()))
        end

        account.latest_login_info.user_id = user_id
        account.latest_login_info.login_id = login_id
        account.latest_login_info.user_name = user_name
        account.latest_login_info.login_way = login_way
        account.latest_login_info.hash_token = login_token
        account.latest_login_info.hash_secret = login_token_secret

        log.debugf('[account] 收到登录事件, user[%s@%s] user_name[%s] login_way[%s] token:%s',
        account.latest_login_info.user_id,
        account.latest_login_info.login_id,
        account.latest_login_info.user_name,
        account.latest_login_info.login_way,
        account.latest_login_info.hash_token,
        account.latest_login_info.hash_secret,
        tk)

        set_token(tk, login_way)  -- 走entrance登录时用的
        set_login_token(login_token, login_token_secret)         -- http的token, 不会序列化, 长期有效
        if mark_login_if_success then
           set_login_state(1) 
        end
        check_console_wl()
    else 
        set_login_state(0) 
        set_token('', 999)
        set_login_token('', '')
        logined = false
        log.debug(('[account] 登录失败, user[%s] error_code[%d] error_desc[%s]'):format(account.latest_login_info.user_id, error_code, error_desc))

        if argv.has('token_cache') then
            sdk_login()
        end
    end

    mark_login_if_success = false

    save()
end

local function generate_http_token_sign(header, token, secret)
    header = header or {}
    header.noise = header.noise or tostring(math_floor(math_random()*1000000) + 1000000)
    header.time_str = header.time_str or tostring(os.time())  -- unix timestamp string
    header.content_md5 = header.content_md5 or ''

    token = token or account_data.login_token or account_data.latest_login_info.hash_token
    secret = secret or account_data.login_token_secret or account_data.latest_login_info.hash_secret
    if not token or token == '' or not secret or secret == '' then return header end

    local pre_sign = header.noise..'\n'..header.time_str..'\n'..header.content_md5..'\n'..token..'\n'..secret
    local sign = common_get_md5(pre_sign)
    header.token = token
    header.sign = sign

    return header
end

local http_request_with_token = function(http, args, on_finish)
    -- http是  sce.httplib.create()  创建出来的实例
    local header =  args.header
    if not header then
        header = {}
        args.header = header
    end

    generate_http_token_sign(header)

    return http:request(args, on_finish)  -- 添加完header后继续走http.request
end

local function on_lobby_disconnect()
    logining = false
    logined = false
end

local function bind_account(login_type, client_id, token)

    local address = calc_http_server_address('login', 9011)
    --address = '127.0.0.1:9011'
    local url = ('%s/api/v1/bind-3rd-account'):format(address)

    local async_http_request_with_token = coroutine.co_wrap(http_request_with_token)

    local http = sce.httplib.create()
    local out_stream = sce.httplib.create_stream()
    log.info('bind3rdAccount begin')
    local code, http_status = async_http_request_with_token(http, {
        url = url,
        method = 'post',
        output = out_stream,
        query = {
            client_id = client_id,
            token = token,
            login_type = tostring(login_type),
            rnd_type = tostring(argv.has('rnd') and 1 or 0),
            special_options = tostring(2),
        }
    })

    if code == 0 and http_status == 200 then
        local out_bytes = out_stream:read()
        local j = json.decode(out_bytes)
        if j.code == 0 then
            -- 绑定成功
            log.info('bind3rdAccount success')
            return true, j.code
        else
            log.warn(('bind3rdAccount failed. code: %s, msg: %s'):format(j.code, j.msg))
            common.send_user_stat('bind_account_failed', tostring(j.code) .. ':' .. tostring(j.msg))
            return false, j.code
        end
    else
        common.send_user_stat('bind_account_failed', tostring(code) .. ':http-' .. tostring(http_status))
        log.info('bind3rdAccount failed. code[%s], http_status[%s]', code, http_status)
        return false, -1
    end
end

if lobby.vm_name() ~= 'StateGame' then
    lobby.register_event("登录", on_login_result)
    lobby.register_event("断开连接",on_lobby_disconnect)

    lobby.register_event("sdk登录结果", function(code, login_way, client_id, client_id_ext, token_or_error, token_ext)
        log.info('[account] sdk_login_result', code, login_way, client_id, token_or_error)
        if code ~= 0 and not argv.has('disable_login_msg') then
            -- 游戏里不要在弹了
            if lobby.vm_name() == 'StateApplication' then
                co.async(function()
                    dialog.set_title(base.i18n.get_text('登录'))
                    dialog.message(base.i18n.get_text('登录失败'))
                    dialog.hide()
                end)
            end
        end
        if code == 0 then 
            coroutine.async(function()
                if is_logined() and account.latest_login_info.login_way == 999 then 
                    local res, code = bind_account(login_way, client_id, token_or_error) 
                    --enum Bind3rdAccountError{
                    --    SUCCESS,
                    --    USER_ID_HAS_BIND_BY_OTHER_3RD_ACCOUNT,  // 这个user_id已经被同LoginType的其他第三方账号绑定了
                    --    THE_3RD_ACCOUNT_HAS_BIND_OTHER_USER_ID,  // 这个第三方账号已经绑定了其他user_id了
                    --    CANNOT_BIND_WITH_GUEST,
                    --    AUTH_FAILED,
                    --    SQL_ERROR,
                    --}

                    --on_login_result(error_code, user_id, login_id, user_name, login_way, tk, tk2,login_token, login_token_secret)
                    if res then 
                        log.info('[account] bind_account', res, code)
                        lobby.dispatch_all_vm('登录',
                        0,
                        account.latest_login_info.user_id,
                        account.latest_login_info.login_id,
                        account.latest_login_info.user_name,
                        login_way,
                        token_or_error,
                        token_ext,
                        account.latest_login_info.hash_token,
                        account.latest_login_info.hash_secret
                        )
                    elseif code == 2 then 
                        log.info('[account] bind_account failed, login using tap token')
                        --lobby.logout();
                        lobby.request_token_login(login_way, token_or_error)
                    end
                else 
                    log.info('[account] not login as guest, login using tap token')
                    --lobby.logout();
                    lobby.request_token_login(login_way, token_or_error)
                end
            end)
        end

    end)
end

if false and lobby.vm_name() == 'StateApplication' then
    lobby.register_event("登录", coroutine.will_async(function()
        bind_account(11, nil, "kTqLGGVcIFOICvFd6OfontUp084fFOtCajUnu5s3$1/sV0JHEBBinYNqFMlIddQW6I9kkWSf1kjB1oBBwlOLZYx5AAA-yINXrV8_-IeqImXCaUb9LnQUvBQx7CaV37nU9qCtwXf-MY-W1O1KqJIN0ZR7aZUYYQhKprGqA7HWRA0mhMekobHAPgKlJhNjeBryPfZSS_vQwLCOpGUcAZhctOWQtUM0yhC-O02fS_ZmF2XyRAWLbJGnR_PBvRvKv0sPum0sRn8ppiKGDGX6pWqt2vT08wekgQqjojUa2D6Aft61tgzsXKwad1QoBp79oeTDIs9n7y94MwpiZ6ZuH0xhwBCk5wP7DxZrD_nn3N3kQmWUGhB41lInNvVfnh4pHlsdg")
    end))
end

account.init = init
account.login = login
account.set_sdk_login_param = set_sdk_login_param
account.sdk_login = sdk_login
account.guest_login = guest_login
account.is_during_sdk_login = is_during_sdk_login
account.is_logined = is_logined
account.is_guide = is_guide
account.save = save
account.get_guest_id = get_guest_id
account.save_guest_id = save_guest_id
account.get_user_name = get_user_name
account.set_user_name = set_user_name
account.logout = logout
--account.set_login_state = set_login_state
account.get_login_state = get_login_state
account.set_token = set_token
account.set_access_token = set_access_token
account.get_access_token = get_access_token
account.token_valid = token_valid
account.mark_login_next_success =  mark_login_next_success
account.generate_http_token_sign = generate_http_token_sign
account.http_request_with_token = http_request_with_token
account.get_token_type = get_token_type
account.is_console_wl = function() return account.latest_login_info.is_console_wl end
account.bind_account = bind_account

init()

return account
