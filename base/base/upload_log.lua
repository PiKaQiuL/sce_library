local pt = require 'base.platform'
local account = require 'base.account'
local argv = require 'base.argv'
local ip_funcs = require 'base.ip'
local ip_env = ip_funcs.get_ip_env()

---------------------------------------------------
-- 上传 log 接口
---------------------------------------------------

local base_domain = 'spark.xd.com'
if base.new_base_domain then
    base_domain = base.new_base_domain
end

local function replace_extension(filename)
    if type(filename) ~= "string" then
        return filename
    end
    local zip_extension = ".zip"
    local new_extension = ".tar.7z"
    if filename:sub(- #zip_extension) == zip_extension then
        -- 替换最后四个字符
        return filename:sub(1, - #zip_extension - 1) .. new_extension
    else
        -- 如果文件名不以 ".zip" 结尾，返回原始文件名
        return filename
    end
end

local function upload_log(prefix, cb, pack_count, game_id)
    local url = ('http://log.%s/upload'):format(base_domain)

    if pt.is_web() then
        url = ('https://log.%s/upload'):format(base_domain)
    end
    log.info('beginning of upload_log')
    prefix = prefix or 'log'
    local platform = common.get_platform()
    local binary_version = 0
    if not pt.is_web() then
        binary_version = common.get_binary_version()
    end
    if not pack_count then
        pack_count = 15
    end
    log.info('upload_log, platform: ' .. platform .. ', pack_count: ' .. pack_count)
    if not account.get_guest_id() then
        account.load()
    end
    log.info('upload_log, account loaded')
    local short_prefix = prefix
    local env_str = 'game_e.master.sce.xd.com' -- 默认值
    if app and app.get_env_str then
        env_str = app.get_env_str()
    end
    -- 如果传了game_id以这个为准
    if game_id then
        local channel
        if common.has_arg('url_launch') then
            channel = 'CreativeWorkshop'
        else
            channel = 'Standalone'
        end
        env_str = string.format('game_%s_%s@%s@%s',game_id,_G.IP,game_id,channel)
        log.info('get_env_str use game_id:', env_str)
    end
    local tag = argv.get('tag')
    if tag and tag ~= 'formal' and tag ~= '' then
        env_str = env_str .. '@' .. tag
    end
    prefix = string.format('[%s]%s', env_str, prefix)
    log.info("prefix:" .. prefix)
    local user_id = lobby.get_user_id()
    if short_prefix == 'crash' then
        -- 使用dump_desc的信息覆盖当前信息，原因如下：
        -- 1.刚起来发dump，user_id是空的，所以使用上次dump时的user_id
        -- 2.上次dump之后可能玩家更新了二进制，需要使用上次dump的二进制版本才能找到正确的符号
        local io_result, dump_desc_str = io.read(io.get_root_dir() .. 'logs/dump/dump_desc.txt')
        if io_result == 0 then
            local success, dump_desc_json = pcall(base.json.decode, dump_desc_str)
            if success then
                if dump_desc_json.env_str and dump_desc_json.env_str ~= '' then
                    env_str = dump_desc_json.env_str
                end
                if dump_desc_json.binary_version and dump_desc_json.binary_version ~= '' then
                    binary_version = dump_desc_json.binary_version
                end
                if dump_desc_json.user_id and dump_desc_json.user_id ~= '' then
                    user_id = dump_desc_json.user_id
                end
            end
        end
    else
        --是日志类型的,往log-collector服务发,crash的往windwos的发
        url = string.format('http://log-collector-%s.spark.xd.com/upload',ip_env)
        if pt.is_web() then
            url = string.format('https://log-collector-%s.spark.xd.com/upload',ip_env)
        end
    end
    log.info('upload_log short_prefix:' .. short_prefix .. ' url:' .. url)
    local log_zip_name_after_prefix = '--' .. platform .. '--' .. math.tointeger(binary_version) .. '--' 
                                        .. user_id .. '--' .. account.get_guest_id() .. '--' 
                                        .. os.date('%Y_%m_%d_%H_%M_%S') .. '--' .. tostring(LOBBY_MAP) .. '.zip'
    local log_zip_name = prefix .. log_zip_name_after_prefix -- 这个是真的发上去的文件名
    if pt.is_win() then
        -- 这里是把log server的逻辑重新处理了一次，后面找个机会全改成json好了，现在这样写太蛋疼了。。。
        local count = 0
        local first, second
        for i = 1, #env_str do
            if env_str:sub(i, i) == '_' then
                count = count + 1
                if count == 1 then
                    first = i
                end
                if count == 2 then
                    second = i
                end
            end
        end
        if count == 2 then
            env_str = env_str:sub(1, first) .. env_str:sub(second + 1)
        end
    end
    env_str = env_str:gsub('@', '/')
    local log_url = ('http://log.sce.xd.com:1080/%s/%s/%s/%s%s'):format(env_str, short_prefix, os.date('%Y-%m-%d'), short_prefix, log_zip_name_after_prefix:sub(1, -5)) -- 我浏览器访问这个url可以打开  之所以要这么处理下，是因为服务器根据前缀作了区分
    log.info('log url is:' .. log_url)
    local log_dir = 'logs'
    local pack_latest_log = common.pack_latest_log('logs','logs_temp', pack_count)
    if pack_latest_log then
        log_dir = 'logs_temp'
    end

    -- if short_prefix == 'crash' or short_prefix == 'crash_now' then
    if true then -- 后来Tap海外证实了确实是 WeLinkGame.framework 里面的zip和我们的zip冲突了，准备下了那个海外云玩，因此我们就不用改了，还是用原来的zip。毕竟用.tar.7z的话大家包括外部作者得装360压缩才能解也不太好..
        io.zip_file(log_dir, log_zip_name, function() end, function()
            io.upload_file(url, log_zip_name,
                function(total, uploaded, speed)
                    --log.info(('total : %d, uploaded : %d, speed : %d'):format(total, uploaded, speed))
                end,
                function(result)
                    log.info(('result : %d'):format(result))
                    io.remove(log_zip_name)
                    if cb then
                        log.info(('log_zip_name : %s'):format(log_zip_name))
                        cb(log_zip_name, log_url)
                    end
                    if short_prefix ~= 'crash' and common.copy_to_clipboard then
                        common.copy_to_clipboard(log_url)
                    end
                end)
        end)
    else
        log_zip_name = replace_extension(log_zip_name)
        local compress_data =
        {
            input = log_dir,
            output = log_zip_name,
            use_7z = true,
            progress = function(total, uploaded, speed)
                --log.info(('total : %d, uploaded : %d, speed : %d'):format(total, uploaded, speed))
            end,
            finish = function(result)
                io.upload_file(url, log_zip_name,
                    function(total, uploaded, speed)
                        --log.info(('total : %d, uploaded : %d, speed : %d'):format(total, uploaded, speed))
                    end,
                    function(result)
                        log.info(('result : %d'):format(result))
                        io.remove(log_zip_name)
                        if cb then
                            log.info(('log_zip_name : %s'):format(log_zip_name))
                            cb(log_zip_name, log_url)
                        end
                        if short_prefix ~= 'crash' and common.copy_to_clipboard then
                            common.copy_to_clipboard(log_url)
                        end
                    end)
            end
        }
        io.zip_file(compress_data)
    end
    
end

return upload_log