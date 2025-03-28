---
--- Generated by EmmyLua(https://github.com/EmmyLua)
--- Created by xindong.
--- DateTime: 2021/7/15 22:11
---

local argv              = require '@base.base.argv'
local util              = require '@base.base.util'
local fmt = fmt

local table_concat = table.concat

-- 获取环境下的 ip
local function get_env_ip()
    local str = __CE_ENV
    if str then
        for r in str:gmatch('/(.-)/') do
            local vec = util.split(r, '.')
            if #vec > 0 then
                local idx = vec[#vec]:find('_')
                if idx then
                    -- 比如__CE_ENV == "Update/e.master.sce.xd.com_test/xxxx", 转换完毕后, 应当是:e.master.sce.xd.com
                    vec[#vec] = vec[#vec]:sub(1, idx - 1)
                end
            end

            local ip = table.concat(vec, ".")
            log.info('IP', ip)
            return ip
        end
    else
        return 'e.master.sce.xd.com'
    end
end

if not _G.IP then  -- 为了防止include后reload时重置IP, 判一下
    _G.IP = get_env_ip()

    if argv.has('server') then
        _G.IP = argv.get('server')
    end
end

_G.update_subpath = _G.IP
if argv.has('tag') then
    local tag = argv.get('tag')
    if tag ~= 'formal' and tag ~= '' then
        _G.update_subpath = _G.update_subpath .. '_' .. tag
    end
end

local function get_qrcode_domain()
    if _G.IP:find(".intl", 1, true) then
        return 'www.tap.io'
    end

    if _G.IP:find("-intl", 1, true) then
        return 'www.tap.io'
    end

    if argv.has('rnd') then
        return 'oauth.api.xdrnd.cn'
    end
    return 'www.taptap.com'
end

local get_oauth2_device_code_url = function()
    local domain = get_qrcode_domain()
    local ret = ("https://%s/oauth2/v1/device/code"):format(domain)
    log.info(("get_oauth2_device_code_url ret: %s"):format(ret))
    return ret
end

local get_oauth2_token_url = function()
    local domain = get_qrcode_domain()
    local ret = ("https://%s/oauth2/v1/token"):format(domain)
    log.info(("get_oauth2_token_url ret: %s"):format(ret))
    return ret
end

local ip_envs = {
    MASTER = 'master',
    ALPHA = 'alpha',
    BETA = 'beta',
    PD = 'pd',
    FJREVIEW = 'fj-review',
    INTL = 'intl',
    INTLBETA = 'intl-beta'
}

local current_ip_env
local current_env_display_name_short

local function get_ip_env()
    if current_ip_env then
        return current_ip_env
    end

    if _G.IP == 'e.master.sce.xd.com' or _G.IP == 'editor-master.spark.xd.com' then
        current_ip_env = ip_envs.MASTER
    elseif _G.IP == 'e.alpha.sce.xd.com' or _G.IP == 'editor-alpha.spark.xd.com' then
        current_ip_env = ip_envs.ALPHA
    elseif _G.IP == 'e.beta.spark.xd.com' or _G.IP == 'editor-beta.spark.xd.com' then
        current_ip_env = ip_envs.BETA
    elseif _G.IP == 'e.production.spark.xd.com' or _G.IP == 'editor-pd.spark.xd.com' then
        current_ip_env = ip_envs.PD
    elseif _G.IP == 'e.fj-review.spark.xd.com' or _G.IP == 'editor-fj-review.spark.xd.com' then
        current_ip_env = ip_envs.FJREVIEW
    elseif _G.IP == 'e.intl.spark.xd.com' or _G.IP == 'editor-intl.spark.xd.com' then
        current_ip_env = ip_envs.INTL
    elseif _G.IP == 'e.intl-beta.spark.xd.com' or _G.IP == 'editor-intl-beta.spark.xd.com' then
        current_ip_env = ip_envs.INTLBETA
    end

    if not current_ip_env then
        current_ip_env = ip_envs.MASTER
    end

    return current_ip_env
end

local function get_env_display_name_short()
    if current_env_display_name_short then
        return current_env_display_name_short
    end

    local env = get_ip_env()
    if env == ip_envs.MASTER then
        current_env_display_name_short = '内网'
    elseif env == ip_envs.ALPHA then
        current_env_display_name_short = '外网'
    elseif env == ip_envs.BETA then
        current_env_display_name_short = '准线上'
    elseif env == ip_envs.PD then
        current_env_display_name_short = '线上'
    elseif env == ip_envs.FJREVIEW then
        current_env_display_name_short = '提审'
    end

    if not current_env_display_name_short then
        current_env_display_name_short = ''
    end

    return current_env_display_name_short
end

return {
    get_qrcode_domain = get_qrcode_domain,
    get_oauth2_device_code_url = get_oauth2_device_code_url,
    get_oauth2_token_url = get_oauth2_token_url,
    ip_envs = ip_envs,
    get_ip_env = get_ip_env,
    get_env_display_name_short = get_env_display_name_short,
}
