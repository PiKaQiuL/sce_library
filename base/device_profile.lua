local device_config = require 'device_config'

local function str_contain(str1, str2)
    if str2:len() > str1:len() then
        return false
    end
    for i = 1, str1:len() - str2:len() + 1 do
        local found = true
        for j = 1, str2:len() do
            if str1:byte(i + j - 1) ~= str2:byte(j) then
                found = false
                break
            end
        end
        if found then
            return true
        end
    end
    return false
end

local function MatchArray(current_name, array, contain)
    current_name = current_name or ""
    current_name = current_name:lower()
    for _, v in ipairs(array) do
        if contain then
            if str_contain(current_name, v:lower()) then
                return true
            end
        else
            if current_name == v:lower() then
                return true
            end
        end
    end
    return false
end

local function GetAndroidNumber(target_str, prefix_str)
    target_str = target_str:gsub('-', '_')
    target_str = target_str:gsub('%b()', '')

    prefix_str = prefix_str:gsub('-', '_')
    prefix_str = prefix_str:gsub('%b()', '')

    local s, e = string.find(target_str, prefix_str)
    if e ~= nil then
        return tonumber(target_str:sub(e + 1))
    end
    return nil
end

local function AndroidExLowMatch(device_detail, renderer_name)
    if MatchArray(device_detail, device_config.ExLow, true) then
        return true
    end

    if MatchArray(renderer_name, {
        'Mali-G71',
        'NVIDIA Tegra',
    }, true) then
        return true
    end

    -- Mali-T6xx ~ T8xx
    local device_type = GetAndroidNumber(renderer_name, 'Mali-T')
    if device_type ~= nil then
        if device_type == 6 or device_type == 7 or device_type == 8 then
            return true
        end
    end

    -- Adreno 3xx、Adreno 4xx、Adreno 500 ~ 549
    device_type = GetAndroidNumber(renderer_name, 'Adreno ')
    if device_type == nil then
        device_type = GetAndroidNumber(renderer_name, 'Adreno (TM) ')
    end
    if device_type ~= nil and device_type >= 300 and device_type <= 549 then
        return true
    end

    return false
end

local function AndroidLowMatch(device_detail, renderer_name)
    if MatchArray(device_detail, device_config.Low, true) then
        return true
    end

    if MatchArray(renderer_name, {
        'Mali-G31',
        'Mali-G51',
        'Mali-G52',
        'Mali-G71',
        'PowerVR Rogue',
        'Tegra K1',
        'Tegra X1',
    }, true) then
        return true
    end

    -- Adreno 550 ~ 629
    device_type = GetAndroidNumber(renderer_name, 'Adreno ')
    if device_type == nil then
        device_type = GetAndroidNumber(renderer_name, 'Adreno (TM) ')
    end
    if device_type ~= nil and device_type >= 550 and device_type <= 629 then
        return true
    end

    return false
end

local function AndroidMediumMatch(device_detail, renderer_name)
    if MatchArray(device_detail, device_config.Medium, true) then
        return true
    end

    if MatchArray(renderer_name, {
        'Mali-G72',
        'Mali-G76',
        'Mali-G68',
    }, true) then
        return true
    end

    -- Adreno 630 ~ 639
    local device_type = GetAndroidNumber(renderer_name, 'Adreno ')
    if device_type == nil then
        device_type = GetAndroidNumber(renderer_name, 'Adreno (TM) ')
    end
    if device_type ~= nil and device_type >= 630 and device_type <= 639 then
        return true
    end

    return false
end

local function AndroidHighMatch(device_detail, renderer_name)
    if MatchArray(device_detail, device_config.High, true) then
        return true
    end

    if MatchArray(renderer_name, {
        'Mali-G57',
        'Mali-G77',
        'Mali-G78',
    }, true) then
        return true
    end

    -- >= Adreno 640
    local device_type = GetAndroidNumber(renderer_name, 'Adreno ')
    if device_type == nil then
        device_type = GetAndroidNumber(renderer_name, 'Adreno (TM) ')
    end
    if device_type ~= nil and device_type >= 640 then
        return true
    end

    return false
end


local function GetiOSType(target_str)
    return target_str:match('A%d+')
end

local function iOSExLowMatch(device_detail, renderer_name)
    return MatchArray(GetiOSType(renderer_name), {
        'A1',
        'A2',
        'A3',
        'A4',
        'A5',
        'A6',
        'A7',
        'A8',
        'A9',  -- iPhone6
    }, false)
end

local function iOSLowMatch(device_detail, renderer_name)
    return MatchArray(GetiOSType(renderer_name), {
        'A10', -- iPhone7
    }, false)
end

local function iOSMediumMatch(device_detail, renderer_name)
    return MatchArray(GetiOSType(renderer_name), {
        'A11',  -- iPhone8, iPhoneX
        'A12',  -- iPhoneXS, iPhoneXS Max, iPhoneXR
    }, false)
end

local function iOSHighMatch(device_detail, renderer_name)
    return MatchArray(GetiOSType(renderer_name), {
        'A13',  -- iPhone11, iPhone11 Pro, iPhone11 Pro Max
        'A14',  -- iPhone12, iPhone12 Pro, iPhone12 Prox Max
        'A15',
        'A16',
        'A17',
        'A18',
    }, false)
end

return {
    Android = {
        ExLow = AndroidExLowMatch,
        Low = AndroidLowMatch,
        Medium = AndroidMediumMatch,
        High = AndroidHighMatch,
    },
    iOS = {
        ExLow = iOSExLowMatch,
        Low = iOSLowMatch,
        Medium = iOSMediumMatch,
        High = iOSHighMatch,
    },
    Windows = {
        Full = function()
            return true
        end,
    },
}