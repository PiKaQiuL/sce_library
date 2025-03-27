local scale = 1
local enable = true
local reference_width = 2340
local reference_height = 1080
local match_width_or_height

local function set_scale_by(width, height, ui_id)
    if not match_width_or_height then
        if width < height then
            width, height = height, width
        end
        local sx = width / reference_width
        local sy = height / reference_height
        scale = sx < sy and sx or sy
        ui.set_global_scale(scale, ui_id)
        log_file.info('set_global_scale', scale)
        return
    end
    local log_w = math.log(width / reference_width, 2)
    local log_h = math.log(height / reference_height, 2)
    --  base.game:event_notify('画面-分辨率缩放变化', scale)
    scale = 2 ^ base.math.lerp(log_w, log_h, base.math.clamp(match_width_or_height, 0, 1))
    ui.set_global_scale(scale, ui_id)
    log_file.info('set_global_scale', scale)
end

local last_w, last_h
local function try_update_scale(width, height)
    if not enable or last_w == width and last_h == height then
        return
    end
    last_w, last_h = width, height
    set_scale_by(width, height)
end

base.game:event('画面-分辨率变化', function(_, width, height)
    try_update_scale(width, height)
    log_file.info('current global_scale', scale)
end)

local function disable_auto_scale()
    enable = false
    ui.set_global_scale(1)
end

local function enable_auto_scale()
    enable = true
    set_scale_by(common.get_resolution())
end

local function set_reference_resolution(width, height)
    reference_width = width
    reference_height = height
    enable_auto_scale()
end

local function get_reference_resolution()
    return reference_width, reference_height
end

local function current_scale()
    try_update_scale(common.get_resolution()) -- 更新下。可能其他地方也监听了'画面-分辨率变化'事件
    return enable and scale or 1
end

local function set_match_width_or_height(value)
    match_width_or_height = base.math.clamp(value or 0.5, 0, 1)
    set_scale_by(common.get_resolution())
end

enable_auto_scale()

return {
    set_reference_resolution = set_reference_resolution,
    get_reference_resolution = get_reference_resolution,
    set_match_width_or_height = set_match_width_or_height,
    current_scale = current_scale,
    disable = disable_auto_scale,
    enable = enable_auto_scale,
    set_scale_by = set_scale_by,
}