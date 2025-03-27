local platform = require '@common.base.platform'
local argv = require '@common.base.argv'
local component = require '@common.base.gui.component'
local bind = component.bind

base.cheat = {}

local reload_start = {}
local reload_finish = {}
local reload_include = {}
local reloading = false
--
--local function safe_include(filename, env)
--	return xpcall(require, base.error, filename, env)
--end
--
--local function _include(filename, env, is_reload)
--	if is_reload == true then
--		log_file.info(('reload: @%s/%s'):format(env:get_env_name(), filename))
--	end
--	if reload_include[filename] == nil then
--		local reload_info = {filename=filename, env=env}
--		reload_include[#reload_include+1] = reload_info
--	end
--	reload_include[filename] = true
--	local ok, res = safe_include(filename, env)
--	if not ok then
--		return nil
--	end
--	return res
--end
--
--local function reload_trigger()
--	log_file.debug('---- Reloading trigger start ----')
--	for trg in base.each_trigger() do
--		local info = debug.getinfo(trg.callback, 'S')
--		local filename = info.source:sub(2)
--		if reload_include[base.test.path_map[filename]] ~= nil then
--			log_file.debug(('Reload trigger in %s at %s'):format(base.test.path_map[filename], filename))
--			trg:remove()
--		end
--	end
--	log_file.debug('---- Reloading trigger end   ----')
--end
--
--local function reload_require()
--	log_file.debug('---- Reloading require start ----')
--	local list = reload_include
--	reload_include = {}
--
--	for _, reload_info in ipairs(list) do
--		local _, unique_name, _ = to_unique_name(reload_info.filename, reload_info.env:get_env_name())
--		package.loaded[unique_name] = nil
--	end
--
--	for _, reload_info in ipairs(list) do
--		print(('reload @%s/%s'):format(reload_info.env:get_env_name(), reload_info.filename))
--		_include(reload_info.filename, reload_info.env, true)
--	end
--	log_file.debug('---- Reloading require end   ----')
--end
--
--function base.cheat.is_reloading()
--	return reloading
--end
--
--function base.cheat.reload(player, cmd)
--	log_file.debug('---- Reloading start ----')
--	reloading = true
--	for _, func in ipairs(reload_start) do
--		xpcall(func, base.error)
--	end
--	reload_start = {}
--	reload_finish = {}
--	reload_trigger()
--	reload_require()
--	for _, func in ipairs(reload_finish) do
--		xpcall(func, base.error)
--	end
--	reloading = false
--	log_file.debug('---- Reloading end   ----')
--end
--
--function base.cheat.on_reload(on_start, on_finish)
--	reload_start[#reload_start+1] = on_start
--	reload_finish[#reload_finish+1] = on_finish
--end
--
--local function create_include_function(self_env)
--	if argv.has('debug') then
--		rawset(self_env, 'include', function(file_name, env)
--			env = env or self_env
--			return _include(file_name, env)
--		end)
--	else
--		rawset(self_env, 'include', function(file_name, env)
--			env = env or self_env
--			return require(file_name, env)
--		end)
--	end
--end
--
----[[
-- 外面每个lib里面的main.lua中都应该自己调用下面这一行:
-- ```
-- require('@common.base.cheat').create_include_function(_G)
-- ```
-- 如果不调用, 则无法使用include
--]]
--return {create_include_function = create_include_function}

local gm = {}
base.game:event('玩家-输入作弊码', function(_, player, command)
    if player ~= base.local_player() then
        return
    end
    local cmd = base.split(command, ' ')
    if #cmd == 0 then
        return
    end
    local name = string.lower(cmd[1])
    if gm[name] then
        gm[name](cmd)
        return
    end
end)

local showmovejoystick = platform.is_mobile()
gm.showmovejoystick = function(cmd)
    local show = cmd[2]
    if type(show) ~= 'boolean' then
        show = not showmovejoystick
    end
    showmovejoystick = show
    local lib_control = require "@lib_control.main".lib_control
    local gui_move_joystick = base.gui_get_part(lib_control.get_lib_control_main_page(), '移动摇杆')
    if gui_move_joystick then
        gui_move_joystick['@move_joystick']['@virtual_joystick.show'] = show
    end
end
gm.smj = gm.showmovejoystick

local debug_unit_template = component {
    base.ui.panel {
        layout = {
            direction = 'col',
            col_content = 'start',
            col_self = 'start',
            row_self = 'start',
            height = 900,
        },
        enable_scroll = true,
        array = bind.array,
        base.ui.label {
            font = {
                align = 'left',
            },
            bind = {
                text = 'text'
            }
        }
    },
    method = {
        set = function(self, props)
            self.array = #props
            for index, value in ipairs(props) do
                self.bind.text[index] = value
            end
        end
    }
}

local debug_unit_panel
base.proto.__gm_debug_unit = function(msg)
    if not debug_unit_panel then
        debug_unit_panel = debug_unit_template:new()
    end
    if msg.props == nil then
        debug_unit_panel:set({})
    else
        debug_unit_panel:set(json.decode(msg.props))
    end
end

local debug_player_panel
base.proto.__gm_debug_player = function(msg)
    if not debug_player_panel then
        local player_attribute_amount = 0
        for _, __ in pairs(base.table.constant['玩家属性']) do
            player_attribute_amount = player_attribute_amount + 1
        end
        local debug_player_template = component {
            base.ui.panel {
                layout = {
                    direction = 'row',
                    row_content = 'center',
                    col_self = 'start',
                    row_self = 'center',
                },
                array = bind.array,
                base.ui.panel {
                    layout = {
                        direction = 'col',
                        col_content = 'start',
                        col_self = 'start',
                        row_self = 'end',
                    },
                    array = player_attribute_amount,
                    base.ui.label {
                        font = {
                            align = 'left',
                        },
                        bind = {
                            text = 'text'
                        }
                    }
                }
            },
            method = {
                set = function(self, all_trace_player_props)
                    self.array = #all_trace_player_props
                    for index1, props in ipairs(all_trace_player_props) do
                        for index2, prop in ipairs(props) do
                            self.bind.text[index1][index2] = prop
                        end
                    end
                end,
            }
        }
        debug_player_panel = debug_player_template:new()
    end
    if msg.all_trace_player_props == nil then
        debug_player_panel:set({})
    else
        debug_player_panel:set(json.decode(msg.all_trace_player_props))
    end
   
end

local debug_game_template = component {
    base.ui.panel {
        layout = {
            direction = 'col',
            col_content = 'end',
            col_self = 'end',
            row_self = 'start',
        },
        array = bind.array,
        base.ui.label {
            font = {
                align = 'left',
            },
            bind = {
                text = 'text'
            }
        }
    },
    method = {
        set = function(self, props)
            self.array = #props
            for index, value in ipairs(props) do
                self.bind.text[index] = value
            end
        end
    }
}

local debug_game_panel
base.proto.__gm_debug_game = function(msg)
    if not debug_game_panel then
        debug_game_panel = debug_game_template:new()
    end
    if msg.props == nil then
        debug_game_panel:set({})
    else
        debug_game_panel:set(json.decode(msg.props))
    end
end

local eff_tree = {}
local RangeDraw = {} --判断同一施法实例是否绘制过了
local alive_time = 1 --非持续性节点存活时间(s)
local all_keep_alive = false
local Color = {
    Red = '#f00a0a',
    Green = '#11f00a',
    Blue = '#0519f2',
    Aquamarine = '#03f8fc',
    Yellow = '#f7eb05'
}

local function eff_destroy(root_id, id, force)
    if eff_tree[root_id] and eff_tree[root_id][id] then
        local eff = eff_tree[root_id][id]
        eff.alive = false
        if (eff.keep_alive or all_keep_alive) and not force then
            eff.keep_alive = all_keep_alive
            return
        end
        if eff.actor then
            eff.actor:destroy()
        end
        if eff.line_actor then
            for key, value in pairs(eff.line_actor) do
                if value then
                    value:destroy()
                end
            end
        end
    end
end

local function eff_destroy_all()
    for key1, params in pairs(eff_tree) do
        for key2, eff in pairs(params) do
            eff_destroy(eff.root_id, eff.id, true)
        end
    end
end

base.proto.__gm_debug_eff_destory_all = function (msg)
    eff_destroy_all()
    eff_tree = {}
    RangeDraw = {}
    all_keep_alive = false
end

base.proto.__gm_debug_eff_destory = function (msg)
    local props = msg.props
    eff_destroy(props.root_id, props.id, false)
end

base.proto.__gm_debug_eff_info = function (msg)
    local props = msg.props
    if not eff_tree[props.root_id] then
        eff_tree[props.root_id] = {}
    end
    eff_tree[props.root_id][props.id] = {}
    local eff_data = eff_tree[props.root_id][props.id]
    for index, value in pairs(props) do
        eff_data[index] = value
    end
    base.cheat.VRP(eff_data)
end

--是单位则更新单位所处地点
local function get_unit_point (eff_data)
    if eff_data.target_type == 'unit' then
        local x, y, z, scene_hash = game.get_unit_location(eff_data.unit_id)
        eff_data.point = base.scene_point_by_hash(x, y, z, scene_hash)
    else
        -- 将服务器传下来的point转换为客户端scene_point
        local p = eff_data.point
        eff_data.point = base.scene_point_by_hash(p[1], p[2], p[3], p.scene_hash)
    end
end

local function draw_circle_area(eff_data,actor, color)
    if eff_data.search_method == 'Circle' and actor then
        local high_point =base.point(eff_data.point[1], eff_data.point[2], eff_data.point[3]+5, game.get_current_scene())
        base.game.debug_draw_circle(actor, high_point, 0, 0, 0, eff_data.radius, color, false)
    end
end

local function draw_arc_area(eff_data,actor)
    if eff_data.search_method == 'Arc' and actor then
        local high_point =base.point(eff_data.point[1], eff_data.point[2], eff_data.point[3]+5, game.get_current_scene())
        base.game.debug_draw_sector(actor, high_point, 0, 0, eff_data.angle - eff_data.Arc/2, eff_data.radius, eff_data.Arc, Color.Red, false)
    end
end

local function draw_line_area(eff_data,actor)
    if eff_data.search_method == 'Line' and actor then
        local p = eff_data.point
        local w = eff_data.Width
        local h = eff_data.Height
        local angle = eff_data.angle
        local dis1 = w/2
        local dis2 = h

        angle = angle - 90
        local a = p:polar_to({angle, dis1})
        local b = p:polar_to({angle + 180, dis1})
        angle = angle + 90
        local c = b:polar_to({angle,dis2})
        local d = a:polar_to({angle,dis2})
        a[3] = a[3] + 5
        b[3] = b[3] + 5
        c[3] = c[3] + 5
        d[3] = d[3] + 5
        base.game.debug_draw_line(actor, a, d, Color.Red)
        base.game.debug_draw_line(actor, b, c, Color.Red)
        base.game.debug_draw_line(actor, c, d, Color.Red)
        base.game.debug_draw_line(actor, a, b, Color.Red)
    end
end

local function get_eff_method(eff_data)
    if eff_data.Arc then
        eff_data.search_method = 'Arc'
    elseif eff_data.Width then
        eff_data.search_method = 'Line'
    elseif eff_data.radius then
        eff_data.search_method = 'Circle'
    end
end


local function draw_line(point, parent_point, actor, color)
    local parent_high_point = base.point(parent_point[1], parent_point[2], (parent_point[3] or 0) + math.random() + 5, game.get_current_scene())
    local this_high_point = base.point(point[1], point[2], point[3]+math.random() + 5, game.get_current_scene())
    base.game.debug_draw_line(actor, this_high_point, parent_high_point, color)
end

function base.cheat.VRP(eff_data)
    local actor = base.game.create_debug_draw_actor()
    eff_data.actor = actor
    local line_actor = base.game.create_debug_draw_actor()
    eff_data.line_actor = {}
    eff_data.alive = true
    get_eff_method(eff_data)
    --如果父节点还没初始化完就等待一帧
    if eff_data.is_search_data then
        if not eff_tree[eff_data.root_id][eff_data.parent_id] or not eff_tree[eff_data.root_id][eff_data.parent_id].alive  then
            base.next(function ()
                if eff_tree[eff_data.root_id][eff_data.parent_id] and eff_tree[eff_data.root_id][eff_data.parent_id].alive then
                    get_unit_point(eff_data)
                    draw_circle_area(eff_data, line_actor, '#8332a8')
                    table.insert(eff_tree[eff_data.root_id][eff_data.parent_id].line_actor, line_actor) 
                end
            end)
            return
        end
        get_unit_point(eff_data)
        draw_circle_area(eff_data, line_actor, '#8332a8')
        table.insert(eff_tree[eff_data.root_id][eff_data.parent_id].line_actor, line_actor)
        return
    end
    if not eff_data.persist then
        base.timer_wait(
            alive_time,
            function ()
                eff_destroy(eff_data.root_id, eff_data.id, false)
            end
        )
    end
    eff_data.keep_alive = all_keep_alive

    get_unit_point(eff_data)
    local high_point = base.point(eff_data.point[1], eff_data.point[2], eff_data.point[3] +5, game.get_current_scene())
    local high_point_text = base.point(eff_data.point[1], eff_data.point[2], eff_data.point[3]+math.random()*100 + 5, game.get_current_scene())

    base.game.debug_draw_circle(actor, high_point, 0, 0, 0, 10, Color.Red, true)

    --文本处理和输出
    local root = string.reverse(eff_data.link)
    root = string.sub(root, string.find(root, '.', 1, true) , -1)
    root = string.reverse(root) .. 'root'
    local cache = base.eff.cache(eff_data.link)
    local root_cache = base.eff.cache(root)
    local root_name = root_cache.Name

    base.game.debug_draw_text(actor, high_point_text, base.i18n.get_text(root_name).. ' ( ' .. base.i18n.get_text(cache.Name) .. ' ) ', Color.Green)

    --如果是根节点绘制施法范围
    if eff_data.parent_id == nil and root_cache and root_cache.Range and eff_data.source and not RangeDraw[eff_data.root_id] then
        local source_point = nil
        if eff_data.source_type == 'unit' then
            local x, y, z, scene_hash = game.get_unit_location(eff_data.source)
            source_point = base.scene_point_by_hash(x, y, z, scene_hash)
        else
            source_point = eff_data.source
        end
        local high_point =base.point(source_point[1], source_point[2], source_point[3]+5, game.get_current_scene())
        base.game.debug_draw_circle(actor, high_point, 0, 0, 0, root_cache.Range, Color.Aquamarine, false)
        RangeDraw[eff_data.root_id] = true
    end

    local line_color = Color.Red
    if cache.NodeType == 'EffectUnitApplyMover' or cache.NodeType == 'EffectLaunchMissile' or cache.NodeType == 'EffectTeleport' then
        line_color = Color.Blue
    end
    --画与父节点的连接线
    if eff_data.launch_point then
        draw_line(eff_data.point, eff_data.launch_point, line_actor, line_color)
        table.insert(eff_data.line_actor, line_actor)
    elseif not eff_data.parent_id and eff_data.source then
        local parent_point = nil
        if eff_data.source_type == 'unit' then
            local x, y, z, scene_hash = game.get_unit_location(eff_data.source)
            parent_point = base.scene_point_by_hash(x, y, z, scene_hash)
        else
            parent_point = eff_data.source
        end
        draw_line(eff_data.point, parent_point, line_actor, line_color)
        table.insert(eff_data.line_actor, line_actor)
    else
        if eff_data.parent_id and eff_tree[eff_data.root_id][eff_data.parent_id] and eff_tree[eff_data.root_id][eff_data.parent_id].alive then
        get_unit_point(eff_data)
        get_unit_point(eff_tree[eff_data.root_id][eff_data.parent_id])
        draw_line(eff_data.point, eff_tree[eff_data.root_id][eff_data.parent_id].point, line_actor, line_color)
        table.insert(eff_data.line_actor, line_actor)
        table.insert(eff_tree[eff_data.root_id][eff_data.parent_id].line_actor, line_actor)
        else
            base.next(function ()
                if eff_data.parent_id and eff_tree[eff_data.root_id][eff_data.parent_id] and eff_tree[eff_data.root_id][eff_data.parent_id].alive then
                    get_unit_point(eff_data)
                    get_unit_point(eff_tree[eff_data.root_id][eff_data.parent_id])
                    draw_line(eff_data.point, eff_tree[eff_data.root_id][eff_data.parent_id].point, line_actor, line_color)
                    table.insert(eff_data.line_actor, line_actor)
                    table.insert(eff_tree[eff_data.root_id][eff_data.parent_id].line_actor, line_actor)
                end
            end)
        end
    end
    if eff_data.search_method then
        if eff_data.search_method == 'Circle' then
            draw_circle_area(eff_data, actor, Color.Red)
        elseif eff_data.search_method == 'Arc' then
            draw_arc_area(eff_data, actor)
        elseif eff_data.search_method == 'Line' then
            draw_line_area(eff_data, actor)
        end
    end
end

base.proto.__gm_debug_eff_keep = function (msg)
    all_keep_alive = msg.all_keep_alive
    if not all_keep_alive then
        for key1, params in pairs(eff_tree) do
            for key2, eff in pairs(params) do
                if eff.keep_alive then
                    eff_destroy(eff.root_id, eff.id, true)
                end
            end
        end
    end
end

-- 将data中的目标与来源通过红线连接，并在来源头上标注技能信息
function base.cheat.VAO_cast(source_id, target_id, info)
    local source = base.unit(source_id)
    local target = base.unit(target_id)
    if not source or not target then
        return
    end
    local line_color = Color.Red

    local actor = base.game.create_debug_draw_actor()
    if not actor then
        log_file.warn('create_debug_draw_actor failed')
        return
    end

    local s_point = source:get_point()
    local t_point = target:get_point()
    base.game.debug_draw_line(actor, s_point, t_point, line_color)

    local x,y,z = game.get_socket_position(target_id, 'socket_blood_bar')
    if not z or z <= s_point[3] then
        s_point[3] = s_point[3] + 100
    else
        s_point[3] = z
    end
    base.game.debug_draw_text(actor, s_point, info, Color.Yellow, true)

    base.wait(500, function ()
        actor:destroy()
    end)
end

local approach_map = {}


function base.cheat.VAO_approach(source_id, target_id, info)
    local source = base.unit(source_id)
    local target = target_id
    local _type = 'point'
    if type(target_id) == 'number' then
        target = base.unit(target_id)
        _type = 'unit'
    end
    if not source or not target then
        return
    end
    local line_color = Color.Yellow

    local actor = base.game.create_debug_draw_actor()
    
    if not actor then
        log_file.warn('create_debug_draw_actor failed')
        return
    end

    local s_point = source:get_point()
    local t_point = target
    local data = {}
    data.actor = actor
    s_point[3] = s_point[3] + 50
    if _type == 'unit' then
        t_point = target:get_point()
        t_point[3] = t_point[3] + 50

        base.game.debug_draw_line(actor, s_point, t_point, Color.Yellow)
        data.timer = base.loop(100, function ()
            base.game.clear_debug_draws(actor)

            s_point = source:get_point()
            t_point = target:get_point()
            s_point[3] = s_point[3]
            t_point[3] = t_point[3]
            base.game.debug_draw_line(actor, s_point, t_point, Color.Yellow)
        end)
    else
        t_point[3] = t_point[3]
        base.game.debug_draw_line(actor, s_point, t_point, line_color)
    end
    approach_map[source_id] = data
end

function base.cheat.VAO_approach_destory(source_id)
    if approach_map[source_id] then
        local actor = approach_map[source_id].actor
        local timer = approach_map[source_id].timer
        if actor then
            actor:destroy()
        end
        if timer then
            timer:remove()
        end
        approach_map[source_id] = nil
    end
end


base.proto.__gm_debug_ai_order = function (msg)
    if msg.type == 'cast' then
        base.cheat.VAO_cast(msg.source_id, msg.target_id, msg.info)
    elseif msg.type == 'approach' then
        if msg.info == 'start' then
            base.cheat.VAO_approach(msg.source_id, msg.target_id or msg.target, msg.info)
        else
            base.cheat.VAO_approach_destory(msg.source_id)
        end
    end
end