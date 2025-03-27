
local watch = base.ui.watch
local view = base.ui.view
local ip_funcs = require '@base.base.ip'
local ip_env = ip_funcs.get_ip_env()

local video_id_map = { [''] = '' }
local path_replace = { keys = '[?&=]', ['?'] = '%3F', ['&'] = '%26', ['='] = '%3D' }

local function set_video_id(ui, video_id)
    ui.video_id = video_id

    video_id = video_id or ''
    if video_id_map[video_id] then
        base.ui.gui.set_video_url(ui.id, video_id_map[video_id])
        return
    end

    local get_video = string.format('https://app-box-server-%s.spark.xd.com/api/v1/get_video?uuid=%s',ip_env,video_id)
    local outstream = sce.httplib.create_stream()
    sce.httplib.request({ url = get_video, output = outstream }, function(code, status)
        local content = outstream:read()
        if code ~= 0 or not content then
            log.error('get video info error', get_video, content, code, status)
            return
        end
        local data = base.json.decode(content)
        if not data or data.result ~= 0 then
            log.error('get video info error', get_video, content)
            return
        end
        local player_url = data.data and data.data.player_url or ''
        video_id_map[video_id] = string.format('https://store-%s.spark.xd.com/app_box_video/?video_url=%s',ip_env,player_url:gsub(path_replace.keys, path_replace))
        log_file.info('video:', video_id, video_id_map[video_id])
        if ui.video_id == video_id then
            base.ui.gui.set_video_url(ui.id, video_id_map[video_id])
        end
    end)
end

return function (template, bind)
    local ui = view {
        type = 'video',
        name = template.name,
        id = template.id
    }

    if template._in_editor then
        ui.type = 'panel' -- 编辑器中不显示
    end

    if template.video_id then
        set_video_id(ui, template.video_id)
    end
    watch(ui, template, bind, 'video_id', function(video_id)
        set_video_id(ui, video_id)
        return video_id
    end)
    watch(ui, template, bind, 'src')

    return ui
end
