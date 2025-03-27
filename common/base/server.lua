local lni = require 'lni'
--local lni_writer = require 'base.lni_writer'
local profiler = include 'base.profiler'

local cmsg_pack_unpack = cmsg_pack.unpack

local MSG  = {}

local proto = {}

--[[
    key:type_id
    value:type
]]
local ui_message = {}

function proto.reload()
    reload()
end

function proto.bind(data)
    local bind = base.ui.bind[data.name]
    if not bind then
        return
    end

    local function execute()
        for i = 1, #data.key-1 do
            local key = data.key[i]
            bind = bind[key]
        end
        
        local key = data.key[#data.key]
        bind[key] = data.value
        base.game:event_notify('服务器-变量更新', data.name,data.key[1])
    end

    local result = pcall(execute)
    if not result then
        log.error(('服务器访问了不存在的界面变量, 界面名 [%s], keys %s'):format(data.name, base.json.encode(data.key)))
    end
    
end

function proto.subscribe(data)
    local bind = base.ui.bind[data.name]
    if not bind then
        return
    end
    for i = 1, #data.key-1 do
        local key = data.key[i]
        bind = bind[key]
    end
    local key = data.key[#data.key]
    bind[key] = function (...)
        base.game:server 'notify' {
            id = data.value,
            args = {...},
        }
    end
end

function proto.clock(clock)
    base.event.on_server_clock(clock)
end

local s2c_fmap = {} --所有服务端能调用的客户端函数都要在这里注册
-- 特殊的函数用register_func注册
local register_func = function(cls, key, func)
    if not s2c_fmap[cls] then
        s2c_fmap[cls] = {}
    end 
    s2c_fmap[cls][key] = func
end
-- 格式相近的函数用register_fnames注册
local register_fnames = function(cls, names, cls_mt)
    if not s2c_fmap[cls] then
        s2c_fmap[cls] = {}
    end
    if not getmetatable(s2c_fmap[cls]) and cls_mt then
        setmetatable(s2c_fmap[cls], cls_mt)
    end
    for k,v in pairs(names) do
        s2c_fmap[cls][v] = true -- 调用cls_mt里的__newindex
    end
end

-- actor相关函数的注册
register_func('actor', 'create_actor', function(sid, name, scene)
    return base.actor(name, sid, false, scene)
end)
register_func('actor', 'attach_to', function(sid, target_id, socket)
    local actor = base.actor_info().server_actor_map[sid]
    local target
    if target_id and target_id > 0 then -- target是unit
        target = target_id
    else -- target是服务端api创建的actor的服务端id,需要映射回客户端id
        target = base.actor_info().server_actor_map[target_id]
    end
    if actor and target then
        actor:attach_to(target, socket)
    end
end)

local actor_funcs = {
    'destroy',
    'detach',
    'set_owner',
    'set_asset',
    'set_shadow',
    'set_bearings',
    'set_position',
    'set_position_from',
    'set_ground_z',
    'set_rotation',
    'set_scale',
    'show',
    'play',
    'play_animation',
    'play_animation_bracket',
    'stop',
    'pause',
    'resume',
    'set_volume',
    'set_launch_site',
    'set_impact_site',
    'set_launch_position',
    'set_launch_ground_z',
    'set_grid_size',
    'set_grid_range',
    'set_grid_state',
    'set_text',
    'anim_play',
    'anim_play_bracket',
    'anim_set_paused_all',
    'set_time_scale_global',
    'anim_operation'
}

register_fnames('actor', actor_funcs, {
    __newindex = function(t, k, v)
        rawset(t, k, function(sid, ...)
            local actor = base.actor_info().server_actor_map[sid]
            if actor then
                actor[k](actor, ...)
            end
        end)
    end
})

-- 还可能有其他的class，比如unit, 也可以用s2c_rpc来实现服务端调用客户端api
register_func('unit', 'attach_to', function(unit_id, target_id, socket)
    local target
    if target_id > 0 then -- target是unit
        target = target_id
    else -- target是服务端api创建的actor的服务端id,需要映射回客户端id
        target = base.actor_info().server_actor_map[target_id]._id
    end
    if target then
        game.attach_actor_to_socket(unit_id, target, socket)
    end
end)

function proto.s2c_rpc(data)
    if not data then
        return
    end
    if not s2c_fmap[data.cls] then
        log.warn('rpc method class没有注册')
        return
    end
    local method = s2c_fmap[data.cls][data.method]
    if not method then
        log.warn('rpc method没有注册')
        return
    end
    xpcall(method, base.error, table.unpack(data.args))
end

function base.game:server(type)
    return function (args)
        MSG.type = type
        MSG.args = args
        local msg = cmsg_pack.pack(MSG)
        game.send_ui_message(msg)
    end
end

function base.event.on_ui_message(str)
    local suc, res = pcall(cmsg_pack_unpack, str)
    if not suc then
        log.warn(table.concat({'服务器发送了不能反序列化的消息', str, res}, '\r\n'))
        return
    end
    local type, args = res.type, res.args
    if not proto[type] then
        local lni_writer = require('base.lni_writer') -- 只是为了打出来好看
        log_file.warn(table.concat({'服务器发送了没有处理者的消息', type, lni_writer(args)}, '\r\n'))
        return
    end
    local timer = profiler.new()
    timer:start()
    xpcall(proto[type], base.error, args)
    timer:finish()
    if timer:get_used() > 3 then 
        log_file.info('处理服务器消息耗时过高', timer:get_used(), str, '\r\n')
    end
end

function base.event.on_ui_message_new(str, type_id, type_name)
    local suc, args = pcall(cmsg_pack_unpack, str)
    if not suc then
        log.warn(table.concat({'服务器发送了不能反序列化的消息', str, args}, '\r\n'))
        return
    end
    if not ui_message[type_id] then
        if type_name == '' then
            log.warn(table.concat({'服务器第一次给客户端发type_id，但是没有type_name', type_id}, '\r\n'))
            return
        end
        ui_message[type_id] = type_name
    end
    local type2 = ui_message[type_id]
    if not proto[type2] then
        if(type(args) == 'table') then
            local lni_writer = require('base.lni_writer') -- 只是为了打出来好看
            log_file.warn(table.concat({'服务器发送了没有处理者的消息', type2, lni_writer(args)}, '\r\n'))
        else
            log_file.warn(table.concat({'服务器发送了没有处理者的消息', type2, args, str}, '\r\n'))
        end
        return
    end
    local timer = profiler.new()
    timer:start()
    xpcall(proto[type2], base.error, args)
    timer:finish()
    if timer:get_used() > 3 then 
        log_file.info('处理服务器消息耗时过高', timer:get_used(), str, '\r\n')
    end
end

base.proto = proto


-- 处理从服务端发往客户端的事件
function base.proto.__server_event_to_client(msg)
    local obj = base.event_deserialize(msg.obj)
    local name = msg.name
    local args = base.event_deserialize(msg.args)
    log.info('客户端收到转发事件：'..name)
    if obj and name and args then
        base.event_notify(obj, name, table.unpack(args))
    else
        log.warn('事件'..name..'参数反序列化失败！')
    end
end

-- 从服务端接收地编默认单位
function base.proto.__return_default_unit(msg)
    local ok = msg.ok
    local node_mark = msg.node_mark
    local unit_id, unit
    if ok then
        unit_id = msg.unit_id
        unit = base.unit(tonumber(unit_id))
        node_mark = msg.node_mark
    end
    base.__default_unit_cache[node_mark] = {
        ok = ok,
        unit = unit
    }
    -- 唤醒等待结果的协程
    local co = base.__default_unit_co[node_mark]
    if co then
        for _, v in ipairs(co) do
            coroutine.resume(v)
        end
    end
    base.__default_unit_co[node_mark] = nil
end

-- 处理拾取物品结果
function base.proto.__unit_try_pick_item_result(msg)
    local ok = msg.ok
    local unit_id = msg.unit_id
    local item_id = msg.item_id
    local unit = base.unit(tonumber(unit_id))
    if unit and unit._try_pick_item_callback and unit._try_pick_item_callback[item_id] then
        unit._try_pick_item_callback[item_id](ok)
        unit._try_pick_item_callback[item_id] = nil
    end
end

-- 处理物品丢弃结果
function base.proto.__item_try_drop_result(msg)
    local ok = msg.ok
    local item_id = msg.item_id
    local item = base.item(tonumber(item_id))
    if item and item._try_drop_callback then
        item._try_drop_callback(ok)
        item._try_drop_callback = nil
    end
end

-- 处理服务端增加属性的接口
function base.proto.__add_attribute_and_sync_client(msg)
    if msg.struct_name and msg.struct_id then
        log_file.info('属性增加', msg.struct_name, msg.struct_id)
        base.add_attribute_key(msg.struct_name,msg.struct_id)
    end
end

-- 处理服务端设置游戏速度的接口
function base.proto._set_game_speed(msg)
    if msg.speed then
        local newSpeed = msg.speed

        -- 调用 common.set_game_speed 设置客户端的游戏速度
        common.set_game_speed(newSpeed)
        log.info("客户端游戏速度已同步为 " .. newSpeed)
    end
end

-- 设置自定义单位属性格式
function base.proto.__set_attribute_custom_format(msg)
    base.gameplay_custom_attribute_format = base.gameplay_custom_attribute_format or {}
    base.gameplay_custom_attribute_format[msg.attr] = msg.format
end

return proto
