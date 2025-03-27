local hero_list = base.array('')
local select_target_time = nil
local show_random = false

---------------------- 方法 --------------------------
base.select_hero = {}

function base.select_hero:hero_list()
    return hero_list
end

function base.select_hero:select_hero(name)
    local unit = base.table.unit[name]
    if not unit then
        return
    end
    game.request_pick_hero(unit.UnitTypeID, false)
end

function base.select_hero:click_hero(name)
    local unit = base.table.unit[name]
    if not unit then
        return
    end
    game.request_click_hero(unit.UnitTypeID, 0)
end

function base.select_hero:click_random_hero()
    game.request_click_hero(-1, 0)
end

function base.select_hero:show_timer()
    if not select_target_time then
        return 0.0
    end
    return math.max((select_target_time - base.clock()) / 1000.0, 0.0)
end

function base.select_hero:show_hero(name, distance, offset, height)
    local unit = base.table.unit[name]
    if not unit then
        return
    end
    --game.set_preview_hero(unit.UnitTypeID, 1)
    --game.change_preview_loc(distance, offset, height)
end

function base.select_hero:show_random()
    return show_random
end

---------------------- 事件 --------------------------
function base.event.on_hero_pick_start_notify(json)
    local info = base.json.decode(json)
    -- 可选英雄列表
    hero_list:set_len(0)
    for i, obj in ipairs(info.available_hero_list) do
        hero_list[i] = base.get_unit_name(obj.hero_id)
    end
    -- 选择英雄时间
    select_target_time = info.pick_time * 1000 + base.clock()
    -- 是否显示随机英雄
    show_random = info.random_type == 1

    base.game:event_notify('游戏-选择英雄')

    -- 通知已点击或选择的英雄（断线重连）
    for _, click in ipairs(info.click_hero_notify) do
        local player = base.player(click.slot_id)
        local name = base.get_unit_name(click.hero_id) or ''

        player:event_notify('选择英雄-点击', player, name)
    end
    for _, select in ipairs(info.pick_hero_notify) do
        local player = base.player(select.slot_id)
        local name = base.get_unit_name(select.hero_id) or ''

        player:event_notify('选择英雄-选择', player, name)
    end
end

function base.event.on_select_hero_click_hero_notify(slot_id, hero_id)
    local player = base.player(slot_id)
    local name = base.get_unit_name(hero_id) or ''

    player:event_notify('选择英雄-点击', player, name)
end

function base.event.on_select_hero_pick_notify(slot_id, hero_id)
    local player = base.player(slot_id)
    local name = base.get_unit_name(hero_id) or ''
    log_file.info('选择英雄-选择', player, name);
    player:event_notify('选择英雄-选择', player, name)
end

function base.event.on_select_hero_pick_all_confirmed_notify(time)
    select_target_time = time * 1000 + base.clock()
    base.game:event_notify('游戏-选择英雄完成')
end
