
local upload_log = include 'base.upload_log'
local update_env = include 'update.core.env'
local util       = include 'base.util'
local wx         = include 'base.wx'
local platform   = include 'base.platform'
local confirm    = include 'base.confirm'
local argv       = include 'base.argv'
local scelobby   = include 'base.lobby'
local co = include '@base.base.co'
include 'base.ip'

-----------------------------------------
local backdoor


-- log.info('emm', scelobby.vm_name())

if scelobby.vm_name() == 'StateApplication' or scelobby.vm_name() == 'StateEditor' then
    -- 左上角的那个（按五下会出来控制台）
    local backdoor_ui = base.ui.button {
        z_index = 9999,
        color = 'rgba(255, 0, 0, 0)',
        show = true,
        layout = {
            col_self = 'end',
            row_self = 'start',
            grow_width = 0.1,
            grow_height = 0.1
        },
        bind = {
            show = 'show'
        },
        static = true
    }
    -- log.info('blabla')
    local _
    _, backdoor = base.ui.create(backdoor_ui, 'backdoor')
    local cmd_panel
    local count = 0
    local cnt_begin_time = os.clock()

    if scelobby.vm_name() == 'StateApplication' or scelobby.vm_name() == 'StateEditor' then
        base.game:event('鼠标-松开', function()
            local mouse_x, mouse_y = common.get_mouse_screen_pos()
            local x, y, w, h = _:rect()        
            -- log.info(':::::::', x, y, w, h, mouse_x, mouse_y)
            if x < mouse_x and x + w > mouse_x and y < mouse_y and y + h > mouse_y then
                local cnt_end_time = os.clock()
                local time_span = cnt_end_time - cnt_begin_time
                log.info('cmd click time_span ', time_span)
                if time_span > 0.5 then
                    count = 0 -- 两次点击时间大于2秒则重置计数，避免误点
                end
                cnt_begin_time  = cnt_end_time
                count = count + 1
                if count == 10 then 
                    local account = include 'base.account'
                    if not account.is_console_wl() then 
                        log.info('not on console whitelist')
                    else
                        cmd_panel_control.show = true 
                        backdoor.show = false
                    end
                end
            end
        end)
    end
end
-------------------------------------------

local console_ui = base.ui.input {
    z_index = 9999,
    draw_level = 9999,
    show = false,
    layout = {
        grow_width = 1,
        height = 100,
        col_self = 'end',
        margin = { left = 300 }
    },
    text = '',
    color = 'rgba(0, 0, 255, 0.5)',
    font = {
        color = 'rgba(255, 255, 255, 1)',
        -- size = 40
    },
    bind = {
        text = 'text',
        show = 'show',
        event = {
            on_input = 'input'
        }
    }
}

local cui, console = base.ui.create(console_ui, 'console')
local code = ''

console.input = function(text)
    code = text
end

-----------------------------------------------

local cmd_panel_ui = base.ui.panel {
    z_index = 10000,
    draw_level = 9999,
    layout = { grow_width = 0.1, grow_height = 1, row_self = 'start' },
    transition = { position = { time = 200 } },
    base.ui.label {
        draw_level = 9999,
        text = '←',
        static = false,
        layout = { row_self = 'end', grow_width = 1, ratio = {1, 1}, translate = { 1, 0 } },
        color = 'rgba(0, 0, 0, 0.7)',
        font = { color = '#FFFFFF' },
        bind = { event = { on_click = 'toggle' }, text = 'toggle_text' }
    },
    show = false,
    bind = { show = 'show', layout = { translate = 'translate' } }
}

local cmd_pannel_inner_ui = base.ui.panel {
    draw_level = 9999,
    layout = { grow_width = 1, grow_height = 1, direction = 'col' },
    color = 'rgba(0, 0, 0, 0.5)',
    static = false,
    enable_scroll = true,
}

local container, temp = base.ui.create(cmd_panel_ui, '__cmd_panel')
cmd_panel_control = temp

local cmd_panel = base.ui.create(cmd_pannel_inner_ui, '__cmd_pannel_inner')
container:add_child(cmd_panel)

local toggle_panel = false
cmd_panel_control.toggle = function()
    toggle_panel = not toggle_panel
    if toggle_panel then
        cmd_panel_control.translate = {-0.1, 0}
        -- cmd_panel_control.toggle_text = '→'
    else
        cmd_panel_control.translate = {0, 0}
        -- cmd_panel_control.toggle_text = '←'
    end
end

if scelobby.vm_name() == 'StateApplication' then
    if argv.has('editor_server_debug') and argv.has('inner') then -- 调试启动，且内部用户，才打开后台
        cmd_panel_control.show = true 
        backdoor.show = false
        cmd_panel_control.toggle()
    end
end

base.game:event('游戏-更新', function(current_trigger, update_delta)
    cmd_panel_control.toggle_text = 'fps:' .. common.get_current_fps() .. '\nping:' .. common.get_current_ping() .. '\ndraw call:' .. common.get_current_draw_call()
end)

local function add_button(text, command)
    local btn = base.ui.label {
        draw_level = 9999,
        layout = { grow_width = 1, margin = {bottom = 5}, ratio = {1, 1} },
        color = 'rgba(0, 0, 0, 0.7)',
        static = false,
        text = text,
        font = { color = '#FFFFFF', family = 'Update' },
        bind = {
            color = 'btn_color',
            event = { on_click = 'on_click' } }
    }
    local ui, bind = base.ui.create(btn, '___cmd__' .. text)
    bind.on_click = function() 
        command()
        bind.btn_color = 'rgba(0.5, 0.5, 0.5, 0.7)'
    end
    cmd_panel:add_child(ui)
end

-----------------------------------------------

local cmd = setmetatable({}, {
    __newindex = function(t, key, value)
        -- print(key, value)
        if key ~= '__index' then
            if type(value) == 'function' then
                add_button(key, value)
            end
        end
        rawset(t, key, value)
    end
})

cmd.__index = function(self, key)
    if cmd[key] then return cmd[key] end
    return function()
        local func, err = load(key)
        if func then
            xpcall(func, base.error)
        else
            log.alert(err)
        end
    end
end

cmd.卸载 = function()
    co.async(function()
        log.info(155533)
    end)
end

-- cmd.测试报错 = function()
--     log.info('应该会报错')
--     local a
--     log.info('hehe', a.b)
--     log.info('应该永远也跑不到这里')
-- end
cmd['UninstallGame'] = function()
    local delete = require '@base.uninstall.delete'
    local progress = function(name, cur, tot)
        log.info("卸载中 进度", name, string.format("%.2f%%", cur / tot * 100));
    end
    local update_end = function(name, res, reuslt)
        log.info("卸载结束", name, res, reuslt);
    end
    local target = common.get_argv("uninstall_game_name");
    local game_name = target or "promotion2"
    co.async(function()
        local res = delete:delete(game_name, progress, update_end);
        log.info("卸载结果", res);
    end)
end

cmd['资源校验'] = function()
    co.async(function()
        local local_version = require 'update.core.local_version'
        local_version:verify_resources()
    end)
end

cmd['关控制台'] = function()    
    cmd_panel_control.show = false
    backdoor.show = true
end

cmd['开录像'] = function()
    -- F7是录像开关，开了录像之后下一个游戏局才开始，关录像后本局游戏立刻停止录像   
    -- F7已经失效了，因为每次都起新的GamePlayOnline,然后saveReplay_又是false了
    --ui.vk_key_click(7)
    log.info('手动开录像')
    common.add_argv('save_replay','')
end

if _G.IP == 'e.master.sce.xd.com' then -- 内网环境自动打开录像，不过想关可以手动关闭
    log.info('自动开录像')
    common.add_argv('save_replay','')
else
    log.info('没有自动开录像')
end

if platform.is_wx() then
    cmd['查看已用空间'] = function()
        local used_space = base.wx.call('fs_getUsedSpace')
        confirm.message(('已用空间 %.2f M'):format(used_space / 1024 / 1024))
    end
end

for i = 0, 3 do
    cmd['skin_type='..i] = function()
        common.set_skin_type(i)
    end
end

function cmd.map(map_name)
    lobby.set_test_map(map_name)
end

local show = console.show
function cmd.toggle_console()
    show = not show
    console.show = show
    if console.show then
        base.ui.gui.set_focus(cui.id, console.show) 
    end
end

cmd.发log = function()
    upload_log('log', nil, 18)
end

base.game:broadcast('upload_userlog', function()
    if scelobby.vm_name() == 'StateApplication' then -- 通常是游戏的LuaState发过来的，StateGame自己就别进了(StateGame不让调上传接口)
        upload_log('userlog', nil, 18)
    end
end)

base.game:broadcast('upload_applog', function(game_id)
    if scelobby.vm_name() == 'StateApplication' then
        upload_log('app_log', function()
            base.game:send_broadcast('upload_applog_finish')
        end, 18, game_id)
    end
end)

base.game:broadcast('upload_replaylog', function()
    if scelobby.vm_name() == 'StateApplication' then
        upload_log('replay_log', nil, 18)
    end
end)

base.game:broadcast('set_render_quality', function(index)
    -- PIE设置游戏画质
    if scelobby.vm_name() == 'StateGame' then
        common.set_render_quality(index)
    end
end)

-- 测试用，msgpack一个循环引用的table
function cmd.msgpack_nest()
    local a = {hehe = 1, haha = '2'}
    local b = {x = a, emm = '.'}
    local c = {t = b, ka = '444'}
    a.y = c
    
    local ret = cmsg_pack.pack(a)
    log.info('msgpack_nest', ret)    
end

function cmd.auto_region()
    -- 恢复自动选区
    common.ForceRegionSelect('')
end

-- 这里暂时是和Startup里维护了两份，是因为这里暂时只是测试用，然后嫌现在Script发起来不方便，大区正经的配置还是配Startup里..
local regions = {
    'singapore',
    'usa',
    'uk',
    'hk',
    'germany',
    'korea',
    'japan',
    'thailand',
    'indonesia',
    'india',
}

for _, r in ipairs(regions) do
    cmd[r] = function()
        common.ForceRegionSelect(r)
    end
end

for i = 1, 12 do
    local btn = 'F' .. i
    cmd[btn] = function()
        ui.vk_key_click(i)
    end
end

function cmd.open_render_mask()
    common.set_render_mask(true)
end

function cmd.close_render_mask()
    common.set_render_mask(false)
end

function cmd.exit()
    scelobby.send_luastate_broadcast('退出', {})
end

function cmd.engine_exit()
    common.exit()
end

function cmd.fps30()
    common.set_max_fps(30)
end

function cmd.fps60()
    common.set_max_fps(60)
end

function cmd.fps144()
    common.set_max_fps(144)
end

function cmd.bake_shadow()
    common.baking_shadowmap_once()
end

function cmd.radius()
    common.toggle_show_unit_radius()
end


function cmd.select()
    common.toggle_show_select()
end

function cmd.boundingbox()
    common.toggle_show_boundingbox()
end

function cmd.toggle_ui()
    common.toggle_game_ui()
end

function cmd.toggle_vsync()
    common.toggle_vsync()
end

function cmd.toggle_instance()
    common.toggle_instance()
end

function cmd.toggle_terrain()
    common.toggle_terrain()
end

function cmd.toggle_particle()
    common.toggle_particle()
end

function cmd.toggle_bg()
    common.toggle_bg()
end

function cmd.toggle_shadow()
    common.toggle_shadow()
end

function cmd.toggle_animated_model()
    common.toggle_animated_model()
end

function cmd.toggle_animation()
    common.toggle_animation()
end

function cmd.toggle_postprocess()
    common.toggle_postprocess()
end

function cmd.toggle_cluster()
    common.toggle_cluster()
end

function cmd.open_cluster()
    common.set_use_cluster(true)
end

function cmd.close_cluster()
    common.set_use_cluster(false)
end

function cmd.open_merge_light()
    common.set_merge_directional_light_and_point_light(true)
end

function cmd.close_merge_light()
    common.set_merge_directional_light_and_point_light(false)
end

function cmd.open_merge_mesh()
    common.set_enable_compute_merge_mesh(true)
end

function cmd.close_merge_mesh()
    common.set_enable_compute_merge_mesh(false)
end

function cmd.render_low()
    common.set_render_quality(0)
end

function cmd.render_medium()
    common.set_render_quality(1)
end

function cmd.render_high()
    common.set_render_quality(2)
end

function cmd.render_full()
    common.set_render_quality(3)
end

function cmd.get_ren_quali()
    log.info('render quality:', common.get_render_quality())
end

function cmd.set_sound_volume(volume)
	common.set_sound_volume(volume)
end

function cmd.set_background_texture(index)
	common.set_background_texture(index)
end

function cmd.set_background_texture_uv(us,vs,ue,ve)
	common.set_background_texture_uv(us,vs,ue,ve)
end

function cmd.set_need_clear_resource_cache(toggle)
	common.set_need_clear_resource_cache(toggle)
end

function cmd.set_logic_view(width,height)
	common.set_logic_view(width,height)
end

function cmd.lock_scene_view()
    common.lock_scene_view()
end

function cmd.unlock_scene_view()
    common.unlock_scene_view()
end

function cmd.disconnect_game_test()
    common.disconnect_test(true, false)
end

function cmd.disconnect_entrance_test()
    common.disconnect_test(false, true)
end

function cmd.disconnect_game_and_entrance_test()
    common.disconnect_test(true, true)
end

function cmd.hide_nav()
    common.show_nav(0)
end

function cmd.show_nav_mesh()
    common.show_nav(1)
end

function cmd.show_nav_voxels()
    common.show_nav(2)
end


function cmd.hide_debug()
    common.show_debug_view(0)
end

function cmd.show_2u_debug()
    common.show_debug_view(1)
end

function cmd.show_lod_debug()
    common.show_debug_view(2)
end

function cmd.lua(code)
    local func, err = load(code)
    if func then
        xpcall(func, base.error)
    else
        log.alert(err)
    end
end

-- 点这个现在会转屏，待修 TODO
function cmd.reload()
    reload()
end

cmd['清缓存'] = function()
    log.info('准备清除缓存 ...')
    base.game:send_broadcast('删除缓存重新更新')
end

if platform.is_win() then

    function cmd.reload()
        reload()
    end

    function cmd.map(map_name)
        lobby.set_test_map(map_name)
    end

    local show = console.show
    function cmd.toggle_console()
        show = not show
        console.show = show
        if console.show then
            base.ui.gui.set_focus(cui.id, console.show)
        end
    end
    
end

-----------------------------------------------

command = setmetatable({}, cmd)

base.game:event('按键-按下', function(_, key)
    if key == 'L' and base.game:key_state('Ctrl') then
        upload_log()
    end
    if key == 'Enter' then
        local tokens = util.split(code, ' ')
        local cmd = tokens[1]
        table.remove(tokens, 1)
        local args = tokens
        for i, arg in ipairs(args) do
            local result
            result, args[i] = xpcall(load('return ' .. arg), base.error)
        end
        xpcall(command[cmd], base.error, table.unpack(args))
        console.show = false
        code = ''
        console.text = ''
    elseif key == 'F10' then
        if argv.has('inner') then
            cmd.toggle_console()
        end
    elseif key == 'F11' and platform.is_win() then
        --cmd.reload()
    end
end)

return {
    show = function()
        cmd_panel_control.show = true
        backdoor.show = true
    end,
    hide = function()
        do return end
        console.show = false
        backdoor.show = false
    end,
    add_button = function(name, callback)
        cmd[name] = callback
        command = setmetatable({}, cmd)
    end
}