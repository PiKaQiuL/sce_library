
local argv = require 'base.argv'
local sdk_map = {
    ['4399'] = 2,
    ['7k7k'] = 3,
    ['qqzone'] = 8
}

local function get_sdk_type(sdk)
    return sdk_map[sdk]
end

local function get_url()
    return js.call('window.location.href')
end

local function get_sdk()
    if argv.has('sdk') then
        return argv.get('sdk')
    end
    local url = get_url()
    log.info(url)
    if url:find('qqopenapp') then
        return 'qqzone'
    end
    for agency in url:gmatch('//(.-)%.') do
        if agency ~= 'www' then
            return agency
        end
    end
end

local function get_token()
    local url = get_url()
    for token in url:gmatch('%?(.+)') do
        return token
    end
end

local function is_sdk()
    return get_sdk_type(get_sdk()) ~= nil
end

return {
    get_url = get_url,
    get_sdk = get_sdk,
    get_sdk_type = get_sdk_type,
    get_token = get_token,
    is_sdk = is_sdk
}