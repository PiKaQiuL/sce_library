include 'base.server'
local scenes = {}
base._scene = {}

local evt_list

local function specific_event_dispatch(event, obj, name, ...)
    if not evt_list then
        evt_list = base.trig.event.event_list
        args = base.trig.event.evt_args
    end

    local combined_args
    if evt_list and evt_list[name] and args[evt_list[name]] then
        combined_args = args[evt_list[name]](obj, name, ...)
    elseif event.custom_event then
        -- 触发器定义的自定义事件
        combined_args = args.event_custom_event(obj, name, ...)
    end
    local res, arg
    if check_event_scene(event, obj) then
        res, arg = event(combined_args)
    end
    if res ~= nil then
        return res, arg
    end
end

local function subscribe_scene_events(scene)
    if base._scene[scene] then
        for obj, events_delegate in pairs(base._scene[scene]['objs']) do
            for name, event_delegate in pairs(events_delegate) do
                local custom_event = event_delegate.custom_event
                for _, event in ipairs(event_delegate) do
                    event:_add_event(obj, name, custom_event)
                    -- if obj == base.game and name == '游戏-加载场景' and event.scene == scene then
                    --     specific_event_dispatch(event, base.game, name, scene)
                    -- end
                end
            end
        end
        for _obj, events_delegate in pairs(base._scene[scene]['funcs']) do
            local obj = (type(_obj) == 'function') and _obj()
            if obj then
                for name, event_delegate in pairs(events_delegate) do
                    local custom_event = event_delegate.custom_event
                    for _, event in ipairs(event_delegate) do
                        event:_add_event(obj, name, custom_event)
                        -- if obj == base.game and name == '游戏-加载场景' and event.scene == scene then
                        --     specific_event_dispatch(event, base.game, name, scene)
                        -- end
                    end
                end
            end
        end
    end
end

local function unsubscribe_scene_events(scene)
    if base._scene[scene] then
        for obj, events_delegate in pairs(base._scene[scene]['objs']) do
            for name, event_delegate in pairs(events_delegate) do
                for _, event in ipairs(event_delegate) do
                    event:_remove_event(obj, name)
                end
            end
        end
        for _obj, events_delegate in pairs(base._scene[scene]['funcs']) do
            local obj = (type(_obj) == 'function') and _obj()
            if obj then
                for name, event_delegate in pairs(events_delegate) do
                    for _, event in ipairs(event_delegate) do
                        event:_remove_event(obj, name)
                    end
                end
            end
        end
    end
end

local function set_scene_activated(scene)
    -- log_file.info('set_scene_activated:', scene)
    scenes[scene] = true
    subscribe_scene_events(scene)
end

local function set_scene_not_activated(scene)
    -- log_file.info('set_scene_not_activated:', scene)
    scenes[scene] = false
    unsubscribe_scene_events(scene)
end

-- local _close_scene = base.game.close_scene

-- if _close_scene then
--     base.game.close_scene = function(scene_name, ...)
--         set_scene_not_activated(scene_name)
--         local ret = _close_scene(scene_name, ...)
--         -- if ret == true then
--         --     scenes[scene_name] = false
--         -- end
--         return ret
--     end
-- end

local function is_scene_activated(scene)
    -- log_file.info('is_scene_activated:', scene)
    return scenes[scene] == true
end

local function get_activated_scenes()
    local ret = {}
    for k, v in pairs(scenes) do
        if v then
            table.insert(ret, k)
        end
    end
    return ret
end

-- local inited_scenes = base.game.get_all_scene_name()

-- if type(inited_scenes) == 'table' then
--     for i = 1, #inited_scenes do
--         set_scene_activated(inited_scenes[i])
--     end
-- end

local function get_obj_scene_events(scene, obj)
    if scene and obj then
        -- log_file.debug('get_obj_scene_events:', scene, obj)
        base._scene[scene] = base._scene[scene] or {objs = {}, funcs = {}}
        if type(obj) == 'function' then
            base._scene[scene]['funcs'][obj] = base._scene[scene]['funcs'][obj] or {}
            return base._scene[scene]['funcs'][obj]
        else
            base._scene[scene]['objs'][obj] = base._scene[scene]['objs'][obj] or {}
            return base._scene[scene]['objs'][obj]
        end
    end
end

function base.proto.__server_jump_scene(msg)
    local old_scene = msg.old_scene
    local new_scene = msg.new_scene
    base.game:event_notify('场景-请求切换', old_scene, new_scene)
end

return {
    set_scene_activated = set_scene_activated,
    set_scene_not_activated = set_scene_not_activated,
    is_scene_activated = is_scene_activated,
    get_activated_scenes = get_activated_scenes,
    get_obj_scene_events = get_obj_scene_events,
}