local platform = include 'base.platform'

local enabled = true

local util = require 'base.util'

-- OperationType操作类型（1.鼠标 2.摇杆）
local OPT = {
    MOUSE = 1,
    JOYSTICK = 2
}

-- movementType指示器运动类型(1.跟随鼠标移动 2.跟随鼠标旋转 3.跟随鼠标移动且延伸 4.跟随鼠标旋转且延伸)
local MT = {
    FOLLOW = 1,
    ROTATION = 2,
}

-- ShapeType形状类型（1.圆 2.矩形）
local ST = {
    CIRCLE = 1,
    RECTANGLE = 2,
}

-- sectionIdx部位枚举（1.起点，在角色脚下 2.中端 3.终点，也就是指示器箭头部分）
local SI = {
    START = 1,
    CENTER = 2,
    END = 3,
}

-- 指示器贴地类型
local STICKING = {
    NONE = 1,
    ROOT_TO_GROUND = 2, -- 整体贴地
    VERTEX_TO_GROUND = 3, -- 顶点贴地，仅对模型发射器生效
}

local operation_type = OPT.MOUSE

local spell_id = 0
-- 当前指示器名称
local assist_name = nil
-- 指示器移动类型
local movement_type = -1
-- 施法范围（决定指示器中心最远可以放在多远）
local range_radius = 0
-- 是否跟跟随鼠标位置
local assert_follow_mouse_position
-- 普通指示器形状(施法范围指示器指的是跟着单位并且用来表示施法范围的指示器，其他都是普通指示器)
local assist_shape = 0
-- 普通指示器范围(圆表示半径，矩形表示长度)
local assist_distance = 0
-- 普通指示器宽度(只有矩形会用)
local assist_width = 0
-- 施法范围指示器半径
local assist_plane_range = 0  
-- 指示器资源范围
local assist_resource_range = 0
-- 指示器资源宽度
local assist_resource_width = 0
-- 施法范围指示器资源宽度
local assist_resource_plane_range = 0
-- 忽略鼠标移动
local pause_mouse = false
local pause_mouse_position = false

-- 可延伸指示器，延展部件各部分资源规格
local assist_grow_source_info = {}
-- 可延伸指示器初始表现大小比例：0.5 = 50%
local initial_range_rate , initial_distance_rate , initial_width_rate = 0 , 0 , 0
-- 从指定比例趋向于100%需要的时间
local assist_grow_time = 0
-- 指示器是否被激活（指示器按下后移动了指定的距离算作激活）
local assist_actived = false

-- 指示器贴地
local assist_sticking = STICKING.NONE

-- 建造技能指示器的建造层级
local spellbuild_layer = 1
-- 建造技能指示器的旋转角度
local spellbuild_spin = 1

--外部注册，接入指示器相关功能
local on_init_sections_info = {}

local spin_map = {
    {{1,0}, {0,1}},
    {{0,1}, {-1,0}},
    {{-1,0}, {0,-1}},
    {{0,-1}, {1,0}},
}

if platform.is_win() or platform.is_web_pc() then
    operation_type = OPT.MOUSE
else
    operation_type = OPT.JOYSTICK
end

local last_control_mouse_x, last_control_mouse_y = 0, 0
local control_pos_move_x, control_pos_move_y = 0, 0

local spell_can_build = true
local function get_controller_scene_pos()
    if not game.get_controled_unit_scene_name then
        return 0, 0, 0
    end
    return game.get_scene_offset(game.get_controled_unit_scene_name())
end

-- 主控附着在别的单位身上的时候 game.get_controled_unit_position获得的是相对坐标 技能指示器需要绝对坐标计算
local function get_controled_unit_global_position(unit)
    if not unit then
        unit = base.local_player():get_hero()
    end
    if unit then
        local hero_global_point = unit:get_global_point()
        return hero_global_point[1], hero_global_point[2], hero_global_point[3]
    end
    return 0, 0, 0
end

-- 摇杆或鼠标在世界中的位置
local function get_controller_pos()
    local pos_x, pos_y, pos_z = get_controled_unit_global_position()

    if operation_type == OPT.MOUSE or assert_follow_mouse_position then
        -- 就是鼠标所在的位置
        local mouse_x, mouse_y = common.get_mouse_screen_pos()
        -- 手机上若松开则获取上次的位置
        if pause_mouse_position then
            mouse_x = last_control_mouse_x
            mouse_y = last_control_mouse_y
        elseif (mouse_x == 0 and mouse_y == 0) or pause_mouse then
            mouse_x = last_control_mouse_x
            mouse_y = last_control_mouse_y
        else
            if last_control_mouse_x==mouse_x and last_control_mouse_y==mouse_y then
            else
                control_pos_move_x,control_pos_move_y= 0, 0
            end
            last_control_mouse_x, last_control_mouse_y = mouse_x, mouse_y
        end
        pos_x, pos_y = game.screen_to_world(mouse_x, mouse_y)
        if not pos_x and not pos_y then
            pos_x, pos_y = game.screen_to_xy(mouse_x, mouse_y)
        end
        -- 转成单位坐标系
        local scene_offset_x, scene_offset_y = get_controller_scene_pos()
        pos_x = pos_x - scene_offset_x + control_pos_move_x
        pos_y = pos_y - scene_offset_y + control_pos_move_y
    elseif operation_type == OPT.JOYSTICK then
        -- 单位位置加上摇杆的偏移
        local rot_x, rot_y = game.get_spell_joystick_direction()
        local percent = game.get_spell_joystick_distance_percent()
        local length = range_radius
        if length <= 0 then
            length = assist_distance
        end
        pos_x = pos_x + rot_x * length * percent
        pos_y = pos_y + rot_y * length * percent
    end
    --log_file.debug("get_controller_pos", pos_x, pos_y, pos_z, assist_actived)
    return pos_x, pos_y, pos_z, assist_actived
end

---comment
---@param link any
local function get_target_indicator_cache(link)
    if not link or #link == 0 then
        return nil
    end
    local cache = base.eff.cache(link)
    if not cache then
        local links = util.split(link, ".")
        if links then
            link = links[#links]
        end
        link = '$$.target_indicator.'..link..'.root'
        cache = base.eff.cache(link)
    end
    return cache
end

-- 将碰撞足印转换为二维数组存储
-- '■', '○'占三个字符
-- ' ', '\r', '\n'占一个字符
local function footpoint_to_map(spellbuild_footpoint)
    -- 保存spellbuild_footpoint中各字符的位置 index:位置 type:字符类型
    local list = {}
    local patterns = {'■', '○', ' ', '\r', '\n'}
    for _, pattern in pairs(patterns) do
        local index = 0
        while true do
            index = string.find(spellbuild_footpoint, pattern, index + 1)
            if index then
                table.insert(list, {index = index, type = pattern})
            else
                break
            end
        end
    end
    table.sort(list, function(a, b)
        return a.index < b.index
    end)
    -- 碰撞足印的原点在左上角 下标从0开始
    local map, size_x, size_y, last_value = {}, 0, 0, nil
    for index, value in ipairs(list) do
        if value.type ~= '\r' and value.type ~='\n' then
            if last_value and (last_value.type == '\n' or last_value.type == '\r') then
                size_y = math.max(size_y, #map[size_x] + 1)
            size_x = size_x + 1
            end
            map[size_x] = map[size_x] or {}
            if not map[size_x][0] then
                map[size_x][0] = value.type
            else
                map[size_x][#map[size_x] + 1] = value.type
            end
            last_value = value
        else
            if last_value then
                last_value = value
            end
        end
        if index == #list and last_value then
            size_y = math.max(size_y, #map[size_x] + 1)
            size_x = size_x + 1
        end
    end
    -- 场景的原点在右下角 下标从0开始
    -- 翻转XY轴
    local result = {}
    for x = 0, size_x - 1 do
        for y = 0, size_y - 1 do
            if not result[y] then
                result[y] = {}
            end
            result[y][x] = map[size_x - x -1][y]
        end
    end
    return result, size_y, size_x
end

-- 建造网格数编表
local spellbuild_grid_cache = base.eff.cache("$$spark_core.actor.GeneralBuildGrid.root") or base.eff.cache("$$default_units.actor.GeneralBuildGrid.root") or base.eff.cache("$$"..__MAIN_MAP__..".actor.GeneralBuildGrid.root")
-- 建造技能指示器网格表现
local spellbuild_grid_actor = nil
--第一层d actor
local spellbuild_grid_actor_ground = nil
-- 建造技能指示器网格表现离地面高度
local spellbuild_grid_actor_height = 5
-- 建造技能指示器网格表现的网格基准大小
local spellbuild_grid_actor_general_size = 128
-- 建造技能指示器缩放比例
local spellbuild_grid_actor_scale = (spellbuild_grid_cache and spellbuild_grid_cache.GridSize or 128) / 128
-- 建造技能指示器网格表现的网格大小
local spellbuild_grid_actor_size = spellbuild_grid_actor_general_size * spellbuild_grid_actor_scale
-- 建造技能建筑的碰撞足印
local spellbuild_footpoint_map = {}
local spellbuild_footpoint_center = {X = 0.5, Y = 0.5}
local spellbuild_footpoint_size_x = 0
local spellbuild_footpoint_size_y = 0
local spellbuild_grid_actor_size_x = 0
local spellbuild_grid_actor_size_y = 0
-- 建造技能建筑占据的高度
local spellbuild_height = 1
-- 建造技能建筑表现
local spellbuild_unit_actor = nil
-- 建造技能建筑的虚影表现
local spellbuild_unit_fresnel_actor = nil
-- 建造技能指示器上次的位置
local spellbuild_controller_last_pos_x = nil
local spellbuild_controller_last_pos_y = nil
-- 建造技能指示器上次的旋转
local spellbuild_controller_last_spin = nil
-- 能否建造
local spellbuild_can_cast = true
-- 碰撞检测块大小为32*32
local collision_block_size = 32
-- 建造块大小(技能改变目标位置所需移动的距离)
local building_block_size = 64
-- 建造技能一层的高度
local spellbuild_layer_height = 128
-- 建造技能最高和最低层级位置
local spellbuild_min_layer = 1
local spellbuild_max_layer = 1
-- 建造网格外延网格数
local spellbuild_extra_grid = 0
local spellbuild_auto_build = false
-- 检测动态碰撞
local check_dynamic_collision = false
-- 检测单位类型碰撞
local check_unit_collision = false
-- 检测物品类型碰撞
local check_item_collision = false

-- 三维表[layer][x][y]
base.collision_info = {}
local footpoint_map_size_x = 0
local footpoint_map_size_y = 0

-- 无限蓄力技能 蓄力开始的时间
local cast_channel_start_time = nil
-- 监听蓄力事件
local cast_channel_trg = nil
-- 无限蓄力技能 在蓄力中
local on_cast_channel = false

-- function base.proto.__update_collision_info(msg)
--     if msg.isRemove == nil then
--         msg.isRemove = false
--     end
--     -- point是单位中心点
--     local point = msg.point
--     local link = msg.link
--     local layer = msg.layer or 1
--     local spin = msg.spin or 1
--     local cache = base.eff.cache(link)
--     if cache and cache.UnitData and cache.UnitData.Block and cache.UnitData.Block.Footpoint then
--         -- 将碰撞足印转换为二维数组存储
--         local map, size_x, size_y = footpoint_to_map(cache.UnitData.Block.Footpoint)
--         local height = cache.UnitData.Block.Height or 1
--         -- 根据碰撞足印将动态碰撞信息更新
--         -- 碰撞足印块大小为64*64 碰撞检测块大小为32*32
--         local begin_x, begin_y = point[1], point[2]
--         for z = layer, layer + height - 1 do
--             base.collision_info[z] = base.collision_info[z] or {}
--             for i = 0, size_x-1 do
--                 for j = 0, size_y-1 do
--                     local curr_x = begin_x + i * building_block_size * spin_map[spin][1][1] + j * building_block_size * spin_map[spin][1][2]
--                     local curr_y = begin_y + i * building_block_size * spin_map[spin][2][1] + j * building_block_size * spin_map[spin][2][2]
-- 	                if map[i][j] == '■' then
--                         curr_x = math.floor(curr_x - curr_x % collision_block_size + 0.5)
--                         curr_y = math.floor(curr_y - curr_y % collision_block_size + 0.5)
--                         for x = curr_x, curr_x + building_block_size - 1, collision_block_size do
--                             for y = curr_y, curr_y + building_block_size - 1, collision_block_size do
--                                 base.collision_info[z][x] = base.collision_info[z][x] or {}
-- 	                            base.collision_info[z][x][y] = not msg.isRemove
--                             end
--                         end
--                         -- log_file.debug("update base.collision_info", z, curr_x, curr_y, not msg.isRemove)
-- 	                end
-- 	            end
-- 	        end
-- 	    end
--         footpoint_map_size_x = size_x
--         footpoint_map_size_y = size_y
--     end
-- end

local collision_flag = {
    all = -1, -- 所有碰撞地形
    unbuildable = 8, -- 不可建造
}

-- 检测区域内是否有碰撞
-- 返回true：区域内有碰撞
-- x:区域左下顶点x坐标
-- y:区域左下顶点y坐标
-- block_size:区域大小
local function check_collision_info(layer, begin_x, begin_y, block_size)
    for x = begin_x, begin_x + block_size - 1, collision_block_size do
        for y = begin_y, begin_y + block_size - 1, collision_block_size do
            -- 检测静态/建筑碰撞
            -- C++ static_collision.get_flag(x, y) 返回左下角(x, y)到右上角[x + collision_block_size, y + collision_block_size]的碰撞块上的碰撞
            -- 要获取(x, y)点的碰撞信息 应该使用static_collision.get_flag(x - collision_block_size, y - collision_block_size)
            -- 这里逻辑可能有问题 要当心
            local collision_info = static_collision.get_flag(x - collision_block_size, y - collision_block_size, true)
            for __, value in pairs(collision_flag) do
                if collision_info & value > 0 then
                    return true
                end
            end
            -- for z = layer, layer + spellbuild_height - 1 do
            --     local curr_x = math.floor(x - x % collision_block_size + 0.5)
            --     local curr_y = math.floor(y - y % collision_block_size + 0.5)
            --     -- log_file.debug("check base.collision_info", z, curr_x, curr_y, base.collision_info[z] and base.collision_info[z][curr_x] and base.collision_info[z][curr_x][curr_y])
            --     if base.collision_info[z] and base.collision_info[z][curr_x] and base.collision_info[z][curr_x][curr_y] then
	        --         return true
	        --     end
            -- end
            -- log_file.debug('检测动态碰撞', check_dynamic_collision, check_unit_collision, check_item_collision)
            -- 检测动态碰撞
            if check_dynamic_collision then
                local target = base.point(x - collision_block_size / 2, y - collision_block_size / 2, 0, game.get_current_scene())
                local max_collision_radius = 256
                local units = base.game:circle_selector(target, max_collision_radius) or {}
                for _, unit in pairs(units) do
                    if not unit:has_label("飞行;") and not unit:has_label("幽灵;") then
                        local unit_cache = base.eff.cache(unit:get_name())
                        local has_unit_collision = unit_cache.UnitData.CollisionType.Custom1
                        local has_item_collision = unit_cache.UnitData.CollisionType.Custom3 and not has_unit_collision
                        if has_unit_collision or has_item_collision then
                            local distance = base.point_distance(unit:get_point(), target)
                            
                            if check_unit_collision and has_unit_collision or check_item_collision and has_item_collision then
                                if distance <= unit_cache.UnitData.CollisionRadius then
                                    return true
                                end
                            end
                            if check_unit_collision and has_item_collision or check_item_collision and has_unit_collision then
                                if distance < collision_block_size * math.sqrt(2) then
                                    return true
                                end
                            end
                        end
                    end
                end
            end
        end
    end
    return false
end

local function get_spellbuild_controller_pos()
    local pos_x, pos_y = get_controller_pos()
    pos_x = pos_x - spellbuild_footpoint_size_x/2 * building_block_size
    pos_y = pos_y - spellbuild_footpoint_size_y/2 * building_block_size
    if spellbuild_spin == 3 or spellbuild_spin == 4 then
        pos_x = pos_x + (spellbuild_footpoint_size_x-1) * building_block_size
    end
    if spellbuild_spin == 2 or spellbuild_spin == 3 then
        pos_y = pos_y + (spellbuild_footpoint_size_y-1) * building_block_size
    end
    pos_x = pos_x - pos_x % building_block_size
    -- 对齐场景网格
    pos_x = pos_x + building_block_size / 2
    pos_y = pos_y - pos_y % building_block_size
    -- 对齐场景网格
    pos_y = pos_y + building_block_size / 2
    return pos_x, pos_y
end

local function get_spellbuild_controller_offset_pos()
    local pos_x, pos_y = get_spellbuild_controller_pos()
    local offset_x = (spellbuild_footpoint_size_x * building_block_size * spellbuild_footpoint_center.X - building_block_size / 2) * spin_map[spellbuild_spin][1][1]
                   + (spellbuild_footpoint_size_y * building_block_size * spellbuild_footpoint_center.Y - building_block_size / 2) * spin_map[spellbuild_spin][1][2]
    local offset_y = (spellbuild_footpoint_size_x * building_block_size * spellbuild_footpoint_center.X - building_block_size / 2) * spin_map[spellbuild_spin][2][1]
                   + (spellbuild_footpoint_size_y * building_block_size * spellbuild_footpoint_center.Y - building_block_size / 2) * spin_map[spellbuild_spin][2][2]
    return pos_x + offset_x, pos_y + offset_y
end

local function reset_spellbuild_grid_actor()
    if spellbuild_grid_actor then
        spellbuild_grid_actor:destroy()
        spellbuild_grid_actor = nil
    end
    if spellbuild_grid_actor_ground then
        spellbuild_grid_actor_ground:destroy()
        spellbuild_grid_actor_ground = nil
    end
    if spellbuild_unit_actor then
        spellbuild_unit_actor:destroy()
        spellbuild_unit_actor = nil
    end
    if spellbuild_unit_fresnel_actor then
        spellbuild_unit_fresnel_actor:destroy()
        spellbuild_unit_fresnel_actor = nil
    end
    spellbuild_footpoint_map = {}
    spellbuild_footpoint_center = {X = 0.5, Y = 0.5}
    spellbuild_footpoint_size_x = 0
    spellbuild_footpoint_size_y = 0
    spellbuild_grid_actor_size_x = 0
    spellbuild_grid_actor_size_y = 0
    spellbuild_height = 1
    spellbuild_controller_last_pos_x = nil
    spellbuild_controller_last_pos_y = nil
    building_block_size = 64
    pause_mouse_position = false
    check_dynamic_collision = false
    check_unit_collision = false
    check_item_collision = false
end

local utility

local function get_stop_cast_common_state()
    if not utility then
        utility = require '@defaultui.common.utility'
    end
    return utility:get_stop_cast_common_state()
end

local function is_spellbuild(skill)
    return skill and skill.cache and skill.cache.NodeType == "SpellBuild"
end

local grid_state_set_id = {
    --建造纹理外无法建造
    [0] = 0,
    --在建筑纹理上，有阻挡
    [1] = 1,
    --在建筑纹理上，可建造
    [2] = 2,
    --在建筑纹理上，允许阻挡（空白)
    [3] = 3,
    --在建造纹理外扩展区域
    [4] = 4,
}
local function update_spellbuild_grid_collision_state()
    if not spellbuild_grid_actor then
        return
    end
    spellbuild_can_cast = true
    -- 网格状态 1:不可建造 2:可建造 3：无碰撞检测 优先级: 1 > 2 > 3
    local grid_state = {}
    local function change_footpoint_state_to_grid_state(new_state, footpoint_x, footpoint_y)
        local grid_startx = math.floor(footpoint_x * building_block_size / spellbuild_grid_actor_size)
        local grid_endx = math.floor((footpoint_x + 1) * building_block_size / spellbuild_grid_actor_size) - 1
        local grid_starty = math.floor(footpoint_y * building_block_size / spellbuild_grid_actor_size)
        local grid_endy = math.floor((footpoint_y + 1) * building_block_size / spellbuild_grid_actor_size) - 1
        for i = grid_startx, grid_endx do
            for j = grid_starty, grid_endy do
                if grid_state[i] and grid_state[i][j] then
                    grid_state[i][j] = math.min(grid_state[i][j], new_state)
                end
            end
        end
    end
    for i = 0, spellbuild_grid_actor_size_x - 1 + 2*spellbuild_extra_grid do
        for j = 0, spellbuild_grid_actor_size_y - 1 + 2*spellbuild_extra_grid do
            grid_state[i] = grid_state[i] or {}
            grid_state[i][j] = grid_state_set_id[4]
        end
    end
    --for i = 0, spellbuild_grid_actor_size_x - 1 do
    --    for j = 0, spellbuild_grid_actor_size_y - 1 do
    --        grid_state[i + spellbuild_extra_grid][j + spellbuild_extra_grid] = 3
    --    end
    --end
    local pos_x, pos_y = get_spellbuild_controller_pos()
    local begin_x = pos_x - spellbuild_extra_grid*spellbuild_grid_actor_size*(spin_map[spellbuild_spin][1][1] + spin_map[spellbuild_spin][1][2])
    local begin_y = pos_y - spellbuild_extra_grid*spellbuild_grid_actor_size*(spin_map[spellbuild_spin][2][1] + spin_map[spellbuild_spin][2][2])
    for i = 0, spellbuild_footpoint_size_x-1+spellbuild_extra_grid*2 do
        for j = 0, spellbuild_footpoint_size_y-1+spellbuild_extra_grid*2 do
            local current_x = begin_x + i * building_block_size * spin_map[spellbuild_spin][1][1] + j * building_block_size * spin_map[spellbuild_spin][1][2]
            local current_y = begin_y + i * building_block_size * spin_map[spellbuild_spin][2][1] + j * building_block_size * spin_map[spellbuild_spin][2][2]
            local check_result = check_collision_info(spellbuild_layer, current_x, current_y, building_block_size)
            local chr = spellbuild_footpoint_map[i-spellbuild_extra_grid] and spellbuild_footpoint_map[i-spellbuild_extra_grid][j-spellbuild_extra_grid]
            if check_result == true or spell_can_build==false then
                if chr == '■' then
                    change_footpoint_state_to_grid_state(grid_state_set_id[1], i, j)
                    spellbuild_can_cast = false
                elseif chr == nil then
                    change_footpoint_state_to_grid_state(grid_state_set_id[0], i, j)
                else
                    change_footpoint_state_to_grid_state(grid_state_set_id[1], i, j)
                end
            else
                if chr == '■' then
                    change_footpoint_state_to_grid_state(grid_state_set_id[2], i, j)
                elseif chr == nil then
                    change_footpoint_state_to_grid_state(grid_state_set_id[4], i, j)
                else
                    change_footpoint_state_to_grid_state(grid_state_set_id[3], i, j)
                end
            end
        end
    end

    local stop_cast = get_stop_cast_common_state()
    for i = 0, spellbuild_grid_actor_size_x - 1 + 2*spellbuild_extra_grid do
        for j = 0, spellbuild_grid_actor_size_y - 1 + 2*spellbuild_extra_grid do
            if stop_cast then
                spellbuild_grid_actor:set_grid_state({i, j}, 1)
                spellbuild_grid_actor_ground:set_grid_state({i, j}, 1)
            else
                spellbuild_grid_actor:set_grid_state({i, j}, grid_state[i][j])
                spellbuild_grid_actor_ground:set_grid_state({i, j}, grid_state[i][j])
            end
        end
    end 
    base.game:event_notify('slot-技能不满足施法条件' , not spellbuild_can_cast)
end


local function init_spellbuild_grid_actor(spell_name)
    log_file.info("aaa")
    local spell_cache = base.eff.cache(spell_name)
    if not spell_cache then
        return
    end
    local unit_cache = base.eff.cache(spell_cache.Unit)
    local spell_indicator_cache = spell_cache and spell_cache.SpellIndicatorSettings and spell_cache.SpellIndicatorSettings.CursorNormal
    spell_indicator_cache = spell_indicator_cache and base.eff.cache(spell_indicator_cache)
    if not unit_cache or not spell_indicator_cache then
        return
    end
    local spellbuild_footpoint = unit_cache.UnitData.Block.Footpoint
    building_block_size = unit_cache.UnitData.Block.Size >= 32 and (unit_cache.UnitData.Block.Size - unit_cache.UnitData.Block.Size % 32) or 64
    spellbuild_layer_height = unit_cache.UnitData.Block.LayerSize or 128
    spellbuild_min_layer = unit_cache.UnitData.Block.MinLayer or 1
    spellbuild_max_layer = unit_cache.UnitData.Block.MaxLayer or 1
    spellbuild_layer = math.max(spellbuild_min_layer, math.min(spellbuild_max_layer, spellbuild_layer))
    spellbuild_extra_grid = spell_indicator_cache.BuildAssistSettings and spell_indicator_cache.BuildAssistSettings.ExtraGrid or 0
    spellbuild_auto_build = spell_indicator_cache.BuildAssistSettings and spell_indicator_cache.BuildAssistSettings.AutoBuild or false
    if not spellbuild_footpoint then
        return
    end
    spellbuild_footpoint_center = unit_cache.UnitData.Block.Center
    if not spellbuild_footpoint_center then
        spellbuild_footpoint_center = {X = 0.5, Y = 0.5}
    end
    spellbuild_footpoint_map, spellbuild_footpoint_size_x, spellbuild_footpoint_size_y = footpoint_to_map(spellbuild_footpoint)
    spellbuild_grid_actor_size_x = math.ceil(building_block_size * spellbuild_footpoint_size_x / spellbuild_grid_actor_size)
    spellbuild_grid_actor_size_y = math.ceil(building_block_size * spellbuild_footpoint_size_y / spellbuild_grid_actor_size)
    spellbuild_height = unit_cache.UnitData.Block.Height or 1
    local pos_x, pos_y = get_spellbuild_controller_pos()
    spellbuild_grid_actor_height = 5 + (spellbuild_layer-1)*spellbuild_layer_height
    spellbuild_controller_last_spin = -90*(spellbuild_spin-1)
    -- 建造类技能网格表现----------------------------------------------------------
    spellbuild_grid_actor = base.actor("$$default_units.actor.GeneralBuildGrid.root") or base.actor("$$spark_core.actor.GeneralBuildGrid.root") or base.actor("$$"..__MAIN_MAP__..".actor.GeneralBuildGrid.root")
    -- 网格表现的网格下标从0开始
    spellbuild_grid_actor:set_grid_range({0, 0}, {spellbuild_grid_actor_size_x + spellbuild_extra_grid*2, spellbuild_grid_actor_size_y + spellbuild_extra_grid*2})
    spellbuild_grid_actor:set_grid_size(spellbuild_grid_actor_general_size)
    spellbuild_grid_actor:set_scale(spellbuild_grid_actor_scale)
    spellbuild_grid_actor:set_position(
        pos_x - spellbuild_extra_grid*spellbuild_grid_actor_size*(spin_map[spellbuild_spin][1][1] + spin_map[spellbuild_spin][1][2]),
        pos_y - spellbuild_extra_grid*spellbuild_grid_actor_size*(spin_map[spellbuild_spin][2][1] + spin_map[spellbuild_spin][2][2]),
        spellbuild_grid_actor_height)
    spellbuild_grid_actor:set_ground_z(spellbuild_grid_actor_height)
    spellbuild_grid_actor:set_rotation(0, 0, spellbuild_controller_last_spin)
    -- 建造类技能网格表现【地板上的网格】
    spellbuild_grid_actor_ground = base.actor("$$default_units.actor.GeneralBuildGrid.root") or base.actor("$$spark_core.actor.GeneralBuildGrid.root") or base.actor("$$"..__MAIN_MAP__..".actor.GeneralBuildGrid.root")
    -- 网格表现的网格下标从0开始
    spellbuild_grid_actor_ground:set_grid_range({0, 0}, {spellbuild_grid_actor_size_x + spellbuild_extra_grid*2, spellbuild_grid_actor_size_y + spellbuild_extra_grid*2})
    spellbuild_grid_actor_ground:set_grid_size(spellbuild_grid_actor_general_size)
    spellbuild_grid_actor_ground:set_scale(spellbuild_grid_actor_scale)
    spellbuild_grid_actor_ground:set_position(
        pos_x - spellbuild_extra_grid*spellbuild_grid_actor_size*(spin_map[spellbuild_spin][1][1] + spin_map[spellbuild_spin][1][2]),
        pos_y - spellbuild_extra_grid*spellbuild_grid_actor_size*(spin_map[spellbuild_spin][2][1] + spin_map[spellbuild_spin][2][2]),
        spellbuild_grid_actor_height)
    spellbuild_grid_actor_ground:set_ground_z(spellbuild_grid_actor_height)
    spellbuild_grid_actor_ground:set_rotation(0, 0, spellbuild_controller_last_spin)
    ----------------------------------------------------------------------
    -- 建造类技能建筑模型表现
    spellbuild_unit_actor = base.actor("$$default_units.actor.通用模型表现.root") or base.actor("$$spark_core.actor.通用模型表现.root") or base.actor("$$"..__MAIN_MAP__..".actor.通用模型表现.root")
    if spellbuild_unit_actor then
        local offset_pos_x, offset_pos_y = get_spellbuild_controller_offset_pos()
        spellbuild_unit_actor:set_position(offset_pos_x, offset_pos_y, spellbuild_grid_actor_height)
        spellbuild_unit_actor:set_ground_z(spellbuild_grid_actor_height)
        spellbuild_unit_actor:set_rotation(0, 0, spellbuild_controller_last_spin)
        spellbuild_unit_actor:set_asset(unit_cache.ModelData)
        spellbuild_unit_actor:set_shadow(false)
    end
    -- 建造类技能建筑模型虚影表现
    spellbuild_unit_fresnel_actor = base.actor("$$default_units.actor.隐身材质表现.root") or base.actor("$$spark_core.actor.隐身材质表现.root") or base.actor("$$"..__MAIN_MAP__..".actor.隐身材质表现.root")
    if spellbuild_unit_fresnel_actor then
        spellbuild_unit_fresnel_actor:attach_to(spellbuild_unit_actor)
        spellbuild_unit_fresnel_actor:set_ground_z(spellbuild_grid_actor_height)
        spellbuild_unit_fresnel_actor:play()
        spellbuild_unit_actor._spellbuild_unit_fresnel_actor = spellbuild_unit_fresnel_actor
    end
    spellbuild_controller_last_pos_x = pos_x
    spellbuild_controller_last_pos_y = pos_y
    base.game:event_notify('技能指示器-建筑技能-开始施法', spell_name, pos_x, pos_y)
    -- 检测动态碰撞
    check_unit_collision = unit_cache.UnitData.CollisionType.Custom1
    check_item_collision = unit_cache.UnitData.CollisionType.Custom3 and not check_unit_collision
    check_dynamic_collision = spell_cache.CreateUnitFlags.DynamicCollision and (check_unit_collision or check_item_collision)
    
    spell_can_build = true

    update_spellbuild_grid_collision_state()
end

local on_update_spellbuild_grid_actor = {}
--注册build grid actor update的回调（pos_x,pos_y)，返回函数，调用清除
local function register_on_update_spellbuild_grid_actor(func)
    on_update_spellbuild_grid_actor[#on_update_spellbuild_grid_actor+1] = func
    return function()
        for k,v in ipairs(on_update_spellbuild_grid_actor) do
            if v == func then
                table.remove( on_update_spellbuild_grid_actor, k)
                break
            end
        end
    end
end

local function update_spellbuild_grid_actor(spell_name, force)
    local pos_x, pos_y = get_spellbuild_controller_pos()
    if not force and spellbuild_controller_last_pos_x == pos_x and spellbuild_controller_last_pos_y == pos_y and spellbuild_grid_actor_height == 5 + (spellbuild_layer-1)*spellbuild_layer_height and spellbuild_controller_last_spin == -90*(spellbuild_spin-1) then
        return
    else
        spellbuild_controller_last_pos_x = pos_x
        spellbuild_controller_last_pos_y = pos_y
        spellbuild_grid_actor_height = 5 + (spellbuild_layer-1)*spellbuild_layer_height
        spellbuild_controller_last_spin = -90*(spellbuild_spin-1)
    end

    if spellbuild_grid_actor then
        local x = pos_x - spellbuild_extra_grid*spellbuild_grid_actor_size*(spin_map[spellbuild_spin][1][1] + spin_map[spellbuild_spin][1][2])
        local y = pos_y - spellbuild_extra_grid*spellbuild_grid_actor_size*(spin_map[spellbuild_spin][2][1] + spin_map[spellbuild_spin][2][2])
        local z = spellbuild_grid_actor_height
        spellbuild_grid_actor:set_position( x, y, z)
    	spellbuild_grid_actor:set_ground_z( z)
        spellbuild_grid_actor:set_rotation(0, 0, spellbuild_controller_last_spin)
        if spellbuild_grid_actor_ground then
            spellbuild_grid_actor_ground:set_position( x, y, z)
            spellbuild_grid_actor_ground:set_rotation(0, 0, spellbuild_controller_last_spin)
            if spellbuild_layer == 1 then
                --没有隐藏actor的方法，先挪到天上去
                spellbuild_grid_actor_ground:set_ground_z( 10000)
            else
                spellbuild_grid_actor_ground:set_ground_z( 5)
            end
        end
    end
    if spellbuild_unit_actor then
        local offset_pos_x, offset_pos_y = get_spellbuild_controller_offset_pos()
        spellbuild_unit_actor:set_position(offset_pos_x, offset_pos_y, spellbuild_grid_actor_height)
        spellbuild_unit_actor:set_ground_z(spellbuild_grid_actor_height)
        spellbuild_unit_actor:set_rotation(0, 0, spellbuild_controller_last_spin)
        do
            local x = offset_pos_x-- - spellbuild_extra_grid*spellbuild_grid_actor_size*(spin_map[spellbuild_spin][1][1] + spin_map[spellbuild_spin][1][2])
            local y = offset_pos_y-- - spellbuild_extra_grid*spellbuild_grid_actor_size*(spin_map[spellbuild_spin][2][1] + spin_map[spellbuild_spin][2][2])
            for k,func in ipairs(on_update_spellbuild_grid_actor) do
                --func( pos_x, pos_y, spellbuild_grid_actor_height)
                func({
                    x = x,
                    y = y,
                    z = spellbuild_grid_actor_height,
                    rotation = spellbuild_controller_last_spin,
                    footpoint_map_size_x = footpoint_map_size_x,
                    footpoint_map_size_y = footpoint_map_size_y,
                    spellbuild_footpoint_size_x = spellbuild_footpoint_size_x,
                    spellbuild_footpoint_size_y = spellbuild_footpoint_size_y,
                    building_block_size = building_block_size,
                })
            end
        end
    end
    update_spellbuild_grid_collision_state()
    --[[
    do
        local x = pos_x-- - spellbuild_extra_grid*spellbuild_grid_actor_size*(spin_map[spellbuild_spin][1][1] + spin_map[spellbuild_spin][1][2])
        local y = pos_y-- - spellbuild_extra_grid*spellbuild_grid_actor_size*(spin_map[spellbuild_spin][2][1] + spin_map[spellbuild_spin][2][2])
        for k,func in ipairs(on_update_spellbuild_grid_actor) do
            --func( pos_x, pos_y, spellbuild_grid_actor_height)
            func({
                x = x,
                y = y,
                z = spellbuild_grid_actor_height,
                rotation = spellbuild_controller_last_spin,
                footpoint_map_size_x = footpoint_map_size_x,
                footpoint_map_size_y = footpoint_map_size_y,
                building_block_size = building_block_size,
            })
        end
    end]]
end

local function spellbuild_height_up()
    spellbuild_layer = spellbuild_layer + 1
    spellbuild_layer = math.min(spellbuild_layer, spellbuild_max_layer)
    update_spellbuild_grid_actor()
end

local function spellbuild_height_down()
    spellbuild_layer = spellbuild_layer - 1
    spellbuild_layer = math.max(spellbuild_layer, spellbuild_min_layer)
    update_spellbuild_grid_actor()
end

local function get_spellbuild_layer()
    return spellbuild_layer
end

local function spellbuild_spin_left()
    spellbuild_spin = (spellbuild_spin)%4 + 1
    update_spellbuild_grid_actor()
end

local function spellbuild_spin_right()
    spellbuild_spin = (spellbuild_spin + 2)%4 + 1
    update_spellbuild_grid_actor()
end

local function get_spellbuild_spin()
    return spellbuild_spin
end

-- 初始化可延伸指示器数据
local function init_sections_info(id, skill)
    local spell_name = base.skill.get_skill_name_by_hash(id)
    local spell_cache = base.eff.cache(spell_name)
    assist_name = base.table.ClientSpell[spell_name].AssistName
    local assist_data = get_target_indicator_cache(assist_name)
    movement_type = assist_data.AssistType  -- 指示器移动类型
    assert_follow_mouse_position = assist_data.FollowMouse
    assist_shape = assist_data.AssistShape  -- 指示器形状，通常指可移动部分的
    assist_sticking = assist_data.AssistSticking  -- 指示器贴地
    local assist_parts = assist_data.AssistParts
    -- 获得每个可延展部件的初始资源大小
    for partIdx , partData in ipairs(assist_parts) do
        if partData.Merge then  -- 是三段合并类指示器
            for sectionIdx , sectionData in ipairs(partData.Sections) do
                if not assist_grow_source_info[sectionIdx] then
                    assist_grow_source_info[sectionIdx] = {}
                end
                assist_grow_source_info[sectionIdx].height = sectionData.Height
                assist_grow_source_info[sectionIdx].width = sectionData.Width
                -- 初始化指示器显示状态
                -- game.set_spell_assist_section_show(partIdx , sectionIdx , partData.EnabledMove)
            end
        end

        for sectionIdx , _ in ipairs(partData.Sections) do
            game.set_spell_assist_section_stick_to_ground(partIdx , sectionIdx , assist_sticking==STICKING.VERTEX_TO_GROUND)
            game.set_spell_assist_section_show(partIdx, sectionIdx, false)
        end
    end
    local InfiniteCasting = spell_cache and spell_cache.SpellFlags and spell_cache.SpellFlags.InfiniteCasting
    local grow_time = nil
    if InfiniteCasting then
        grow_time = spell_cache and spell_cache.SpellIndicatorSettings and spell_cache.SpellIndicatorSettings.grow_time or 0
        if type(grow_time) ~= "number" then
            grow_time = grow_time and grow_time(skill)
        end
    end
    -- 从指定比例趋向于100%需要的时间
    assist_grow_time = grow_time or 0

    -- 技能范围
    range_radius = skill and skill.range or base.skill_table(spell_name, 1, "range") or 0
    if range_radius == 0 then
        initial_range_rate = 0
    else
        local initial_range = nil
        if InfiniteCasting then
            initial_range = spell_cache and spell_cache.SpellIndicatorSettings and spell_cache.SpellIndicatorSettings.initial_range or range_radius
            if type(initial_range) ~= "number" then
                initial_range = initial_range and initial_range(skill)
            end
        end
        initial_range_rate = (initial_range or range_radius)/range_radius
    end

    -- 圆形目标指示器宽度
    assist_distance = (spell_cache and spell_cache.SpellIndicatorSettings and spell_cache.SpellIndicatorSettings.CursorRadius) or 0
    if type(assist_distance) ~= 'number' then
        assist_distance = assist_distance(skill)
    end
    if assist_distance > 0 then
        local initial_distance = nil
        if InfiniteCasting then
            initial_distance = spell_cache and spell_cache.SpellIndicatorSettings and spell_cache.SpellIndicatorSettings.initial_distance or assist_distance
            if type(initial_distance) ~= "number" then
                initial_distance = initial_distance and initial_distance(skill)
            end
        end
        initial_distance_rate = (initial_distance or assist_distance)/assist_distance
    else
        initial_distance_rate = 1
    end

    -- 矩形指示器宽度
    assist_width = (spell_cache and spell_cache.SpellIndicatorSettings and spell_cache.SpellIndicatorSettings.CursorWidth) or 0
    if type(assist_width) ~= 'number' then
        assist_width = assist_width(skill)
    end
    if assist_width > 0 then
        local initial_width = nil
        if InfiniteCasting then
            initial_width = spell_cache and spell_cache.SpellIndicatorSettings and spell_cache.SpellIndicatorSettings.initial_width or assist_width
            if type(initial_width) ~= "number" then
                initial_width = initial_width and initial_width(skill)
            end
        end
        initial_width_rate = (initial_width or assist_width)/assist_width
    else
        initial_width_rate = 1
    end
    -- 建造技能指示器网格表现
    local stop_cast = get_stop_cast_common_state()
    if spell_cache.NodeType == "SpellBuild" and not stop_cast then
        init_spellbuild_grid_actor(spell_name)
    end
end

local function get_actual_assist_height(cur_assist_distance , cur_assist_width)
    local start_h , center_h , end_h = 0 , 0 , 0
    if #assist_grow_source_info > 0 then
        -- 起始端实际高度(宽度倍率和高度倍率一致)
        start_h = assist_grow_source_info[SI.START].height * cur_assist_width / assist_grow_source_info[SI.START].width
        -- 顶端实际高度(宽度倍率和高度倍率一致)
        end_h = assist_grow_source_info[SI.END].height * cur_assist_width / assist_grow_source_info[SI.END].width
        -- 中端实际高度
        center_h = cur_assist_distance - start_h - end_h
    end
    return start_h , center_h , end_h
end

local init_rot_x , init_rot_y , init_assist_distance
-- 根据配置进行缩放
local function update_assist_size(spell_hash_id, assist_parts, time, id)
    local spell_name = base.skill.get_skill_name_by_hash(spell_hash_id)
    local spell_cache = base.eff.cache(spell_name)
    local skill = base.skill.ac_skill(id)
    local unit  = skill and skill:get_owner()

    -- 指示器获得位置
    local base_pos = {}
    -- 指示器获得朝向
    local rot_x, rot_y
    -- 施法者位置
    base_pos.UNIT = {get_controled_unit_global_position(unit)}
    if (not init_rot_x) or (not init_rot_y) or (not init_assist_distance) then
        -- 这里是没有初始设定，就每帧获得指示器实际位置
        base_pos.ASSIST = {get_controller_pos()}

        if operation_type == OPT.MOUSE then
            -- 以单位为中心鼠标的方向
            local mouse_x, mouse_y = common.get_mouse_screen_pos()
            mouse_x, mouse_y = game.screen_to_world(mouse_x, mouse_y)
            if not mouse_x and not mouse_y then
                -- 地形获取失败和z=0平面求交点位置
                mouse_x, mouse_y = game.screen_to_xy(mouse_x, mouse_y)
            end
            mouse_x = mouse_x or 0
            mouse_y = mouse_y or 0
            -- 转成单位坐标系
            local scene_offset_x, scene_offset_y = get_controller_scene_pos()
            mouse_x = mouse_x - scene_offset_x
            mouse_y = mouse_y - scene_offset_y
            rot_x, rot_y = mouse_x - base_pos.UNIT[1], mouse_y - base_pos.UNIT[2]
        elseif operation_type == OPT.JOYSTICK then
            --  摇杆的方向
            rot_x, rot_y = game.get_spell_joystick_direction()
        end
    else
        -- 这里是有初始化方向和距离，通常用于智能施法或者初始化指示器
        rot_x = init_rot_x
        rot_y = init_rot_y
        base_pos.ASSIST = {
            base_pos.UNIT[1] + rot_x * init_assist_distance,
            base_pos.UNIT[2] + rot_y * init_assist_distance,
            base_pos.UNIT[3]
        }
    end
    -- 设置指示器大小
    local cur_range_radius = range_radius
    local cur_assist_distance = assist_distance
    local cur_assist_width = assist_width

    local InfiniteCasting = spell_cache and spell_cache.SpellFlags and spell_cache.SpellFlags.InfiniteCasting
    if InfiniteCasting then
        -- 根据时间计算指示器比例
        if not cast_channel_start_time then
            cur_range_radius = range_radius * initial_range_rate
            cur_assist_distance = 0
            cur_assist_width = 0
        else
            local channel_elapsed_time = time - cast_channel_start_time
            if channel_elapsed_time < assist_grow_time then
                -- 在当前时间下需要显示的范围长度大小
                cur_range_radius = range_radius * (initial_range_rate + (channel_elapsed_time / assist_grow_time)*(1 - initial_range_rate))
                -- 在当前时间下需要显示的指示器长度大小
                cur_assist_distance = assist_distance * (initial_distance_rate + (channel_elapsed_time / assist_grow_time)*(1 - initial_distance_rate))
                -- 在当前时间下需要显示的指示器宽度大小
                cur_assist_width = assist_width * (initial_width_rate + (channel_elapsed_time / assist_grow_time)*(1 - initial_width_rate))
                --print(string.format('cur_assist_width = %s , initial_width_rate = %s' , cur_assist_width , initial_width_rate))
            end
        end
    end
    
    --print(string.format('time = %s , assist_grow_time = %s', time , assist_grow_time))
    --print(string.format('cur_range_radius = %s , cur_assist_width = %s',cur_range_radius,cur_assist_width))
    -- partIdx  (part部分索引，一个part会有多个section组成)
    -- sectionIdx    (section部件索引)
    -- 范围缩放比例     长度缩放比例        宽度缩放比例
    local range_scale , height_scale , width_scale
    local cur_pos_x , cur_pos_y , cur_pos_z -- 当前部件的位置
    cur_pos_z = 0 -- 填一个默认值0

    local cur_start_height , cur_center_height , cur_end_height = get_actual_assist_height(cur_assist_distance , cur_assist_width)
    local assist_z = (assist_sticking > STICKING.NONE) and game.get_ground_z(base_pos.UNIT[1],  base_pos.UNIT[2], base_pos.UNIT[3], true) or base_pos.UNIT[3]

    local ra = math.atan(-rot_y , -rot_x)
    local cos_ra = math.cos(ra)
    local sin_ra = math.sin(ra)
    -- 修改指示器各个部件的位置、朝向、缩放比例
    for partIdx , partData in ipairs(assist_parts) do
        for sectionIdx , sectionData in ipairs(partData.Sections) do
            if partData.Merge then -- 是三段合并类指示器
                -- 起始端位置以及缩放比率计算
                if sectionIdx == SI.START then
                    cur_pos_x = base_pos.UNIT[1]
                    cur_pos_y = base_pos.UNIT[2]
                    cur_pos_z = assist_z
                    width_scale = cur_assist_width / assist_grow_source_info[SI.START].width
                    height_scale = cur_start_height / assist_grow_source_info[SI.START].height
                end
                -- 中端位置以及缩放比率计算
                if sectionIdx == SI.CENTER then
                    cur_pos_x = base_pos.UNIT[1] - cos_ra * cur_start_height
                    cur_pos_y = base_pos.UNIT[2] - sin_ra * cur_start_height
                    cur_pos_z = assist_z
                    width_scale = cur_assist_width / assist_grow_source_info[SI.CENTER].width
                    height_scale = cur_center_height / assist_grow_source_info[SI.CENTER].height
                    if height_scale <= 0 then
                        height_scale = 0
                    end
                end
                -- 顶端位置以及缩放比率计算
                if sectionIdx == SI.END then
                    cur_pos_x = base_pos.UNIT[1] - cos_ra * (cur_assist_distance - cur_end_height)
                    cur_pos_y = base_pos.UNIT[2] - sin_ra * (cur_assist_distance - cur_end_height)
                    cur_pos_z = assist_z
                    width_scale = cur_assist_width / assist_grow_source_info[SI.END].width
                    height_scale = cur_end_height / assist_grow_source_info[SI.END].height
                end
                --print(string.format('partIdx = %s , sectionIdx = %s , cur_pos_xyz = (%s , %s , %s) , height_scale = %s , width_scale = %s ' , partIdx , sectionIdx , cur_pos_x , cur_pos_y , cur_pos_z , height_scale , width_scale))
                game.set_spell_assist_section_position(partIdx , sectionIdx , cur_pos_x , cur_pos_y , cur_pos_z)
                game.set_spell_assist_section_rotation(partIdx , sectionIdx , rot_x , rot_y)
                game.set_spell_assist_section_scale(partIdx , sectionIdx , height_scale , width_scale)
            else
                if not partData.EnabledMove then
                    -- 不可动部分，合并类指示器默认为可动部分
                    height_scale = cur_range_radius / sectionData.Height
                    width_scale = height_scale
                    cur_pos_x = base_pos.UNIT[1]
                    cur_pos_y = base_pos.UNIT[2]
                    cur_pos_z = assist_z
                    --print(string.format('partIdx = %s , sectionIdx = %s , cur_pos_xyz = (%s , %s , %s) , height_scale = %s , width_scale = %s ' , partIdx , sectionIdx , cur_pos_x , cur_pos_y , cur_pos_z , height_scale , width_scale))
                else
                    --可移动部分
                    height_scale = cur_assist_distance / sectionData.Height
                    if assist_shape == ST.CIRCLE then
                        -- 圆形目标指示器
                        width_scale = height_scale
                    else
                        -- 矩形目标指示器
                        width_scale = cur_assist_width / sectionData.Width
                    end
                    -- section可以临时修改这个部件的移动方式
                    if (sectionData.Movement ~=0 and sectionData.Movement or movement_type) == MT.FOLLOW then
                        -- 移动类指示器
                        local assist_move_z = (assist_sticking > STICKING.NONE) and game.get_ground_z(base_pos.ASSIST[1], base_pos.ASSIST[2], base_pos.ASSIST[3], true) or base_pos.ASSIST[3]
                        cur_pos_x = base_pos.ASSIST[1]
                        cur_pos_y = base_pos.ASSIST[2]
                        cur_pos_z = assist_move_z
                    else
                        -- 方向类指示器
                        cur_pos_x = base_pos.UNIT[1]
                        cur_pos_y = base_pos.UNIT[2]
                        cur_pos_z = assist_z
                        game.set_spell_assist_section_rotation(partIdx , sectionIdx , rot_x , rot_y)
                    end
                end
                game.set_spell_assist_section_position(partIdx , sectionIdx , cur_pos_x , cur_pos_y , cur_pos_z)
                game.set_spell_assist_section_scale(partIdx , sectionIdx , height_scale , width_scale)
            end
            -- 设置是否显示
            -- todo 这里不清楚为什么在assist_actived = false时隐藏指示器还需要partData.EnabledMove
            -- if partData.EnabledMove and not assist_actived then
            if not assist_actived and not spellbuild_auto_build then
                game.set_spell_assist_section_show(partIdx , sectionIdx , false)
            else
                game.set_spell_assist_section_show(partIdx , sectionIdx , true)
            end
        end
    end

    if not assist_actived and not spellbuild_auto_build then--AutoBuild连续建造，在此模式下assist_actived状态为false，需要特殊处理，目前仅回响使用到这个开关
        return
    end
    -- 更新建造技能指示器网格表现
    if spell_cache.NodeType == "SpellBuild" then
        update_spellbuild_grid_actor()
    end
    -- 无限蓄力技能 在蓄力阶段时
    local skill = base.skill.ac_skill(id)
    if skill and skill:get_user_attribute("sys_state_infinite_cast") == 1 then
        local infinite_cast_mode = 'ClickAgain'
        local target_type = spell_cache.target_type
        -- target_type 0：无目标
        -- target_type 4：向量目标
        if target_type == 0 or target_type == 4 then
            local assist_data = get_target_indicator_cache(assist_name)
            infinite_cast_mode = assist_data.InfiniteCastingMode or 'ClickAgain'
        end
        if infinite_cast_mode == 'Release' then
            local offset = 90
            local angle = base.math.atan(-rot_x, rot_y) + offset
            base.game:server 'set_channel_facing' {
                unit_id = skill:get_owner()._id,
                facing = angle,
            }
        end
    end
end 

local function reset_assist_data()
    assist_name = nil
    movement_type = -1
    assist_shape = -1
    assist_grow_source_info = {}
    pause_mouse_position = false
end

--[[
    id: spell id
]]
--从defaultui库里发来的,对应施法后的情况
base.game:event('建筑技能预放置', function (_, unit, skill, success)
    if success then
        base.game:event_notify("技能-建造预放置确认", unit, skill, spellbuild_unit_actor)
    else
        base.game:event_notify("技能-建造预放置取消", unit, skill, spellbuild_unit_actor)
    end
end)

base.game:event('技能指示器-控制', function(_, control, spell_id_hash, type, shape, range, width, plane_range, id)
    reset_assist_data()
    local skill = base.skill.ac_skill(id)
    local stop_cast = get_stop_cast_common_state()
    -- 法球的技能指示器
    if skill and skill:is_attack_modifier() then
        local unit = skill:get_owner()
        local attack = unit and unit:get_attack()
        if attack then
            skill = attack
            spell_id_hash = common.string_hash(attack:get_name())
        end
    end

    --移动到取消按钮上时
    if is_spellbuild(skill) then
        if stop_cast then
            base.game:event_notify("技能-建造预放置取消", skill:get_owner(), skill, spellbuild_unit_actor)
        end
    end

    --先把spellbuild的actor交出去再调用函数销毁
    reset_spellbuild_grid_actor()

    if enabled then -- 功能开关
        if control then -- 显示/隐藏指示器
            --base.game:event_notify('技能指示器-显示信息', spell_id_hash, skill)--不污染event，换个做法
            cast_channel_trg = base.game:event('单位-施法引导', function(_, unit, name, time, total)
                if unit == skill:get_owner() and name == base.skill.get_skill_name_by_hash(spell_id_hash) then
                    on_cast_channel = true
                end
            end)
            if #on_init_sections_info>0 then
                for k,act in ipairs(on_init_sections_info) do
                    act(spell_id_hash, skill)
                end
            end
            init_sections_info(spell_id_hash, skill)
            --按下按键时
            if is_spellbuild(skill) and not stop_cast and control then
                base.game:event_notify("技能-建造预放置开始", skill:get_owner(), skill, spellbuild_unit_actor)
            end
        else
            cast_channel_start_time = nil
            on_cast_channel = false
            if cast_channel_trg then
                cast_channel_trg:remove()
                cast_channel_trg = nil
            end
            base.next(function() assist_actived = false end)
            init_rot_x , init_rot_y , init_assist_distance = nil , nil , nil
        end
    end
end)

-- 激活目标指示器
base.game:event('技能指示器-激活', function(_ , x , y , percent)
    assist_actived = true
    init_rot_x , init_rot_y , init_assist_distance = nil , nil , nil
end)

base.game:event('技能指示器-初始化显示' , function(_ , x , y , distance)
    assist_actived = true
    init_rot_x , init_rot_y , init_assist_distance = x , y , distance
end)

base.game:event('技能指示器-更新', function(_ , spell_hash_id , time, id)
    if not enabled then
        return
    end
    if not assist_name then
        return
    end
    local skill = base.skill.ac_skill(id)
    if not skill then
        assist_actived = false
    end
    local assist_data = get_target_indicator_cache(assist_name)
    if not assist_actived and not spellbuild_auto_build then
        return
    end
    if on_cast_channel and not cast_channel_start_time then
        cast_channel_start_time = time
    end
    if assist_data then -- 取指示器数编有可能为空值
        update_assist_size(spell_hash_id, assist_data.AssistParts, time, id)
    end
end)

-- log_file.debug(debug.traceback())
return {
    OPT_MOUSE = OPT.MOUSE,
    OPT_JOYSTICK = OPT.JOYSTICK,
    -- 改变操作方式 鼠标还是摇杆操作
    change_operation_type = function(type)
        operation_type = type
    end,

    -- 摇杆或鼠标在世界中的位置
    get_controller_pos = get_controller_pos,

    -- 建造技能指示器的位置
    get_spellbuild_controller_pos = get_spellbuild_controller_pos,
    get_spellbuild_controller_offset_pos = get_spellbuild_controller_offset_pos,
    -- 建造技能当前层级
    get_spellbuild_layer = get_spellbuild_layer,
    -- 建造技能当前旋转
    get_spellbuild_spin = get_spellbuild_spin,

    -- 搜敌相关
    get_focused_unit_id = game.get_spell_assist_focused_unit_id,
    set_unfocus_unit = game.set_spell_assist_unfocus_unit,

    set_enabled = function(flag)
        enabled = flag
    end,
    set_pause_mouse = function(flag)
        pause_mouse = flag
    end,
    set_mouse_position = function(x, y)
        last_control_mouse_x, last_control_mouse_y = x, y
    end,

    set_rotate = function(x, y)
        game.set_spell_assist_rotation(x, y)
    end,

    spellbuild_height_down = spellbuild_height_down,
    spellbuild_height_up = spellbuild_height_up,
    spellbuild_spin_left = spellbuild_spin_left,
    spellbuild_spin_right = spellbuild_spin_right,

    -- deprecated
    get_spell_assist_position = get_controller_pos,
    get_spell_joystick_direction = game.get_spell_joystick_direction,
    get_move_joystick_direction = game.get_move_joystick_direction,
    get_spell_joystick_distance_percent = game.get_spell_joystick_distance_percent,
    get_move_joystick_distance_percent = game.get_move_joystick_distance_percent,

    update_spellbuild_grid_actor = update_spellbuild_grid_actor,
    register_on_update_spellbuild_grid_actor = register_on_update_spellbuild_grid_actor,
    reset_assist_data = reset_assist_data,
    reset_spellbuild_grid_actor = reset_spellbuild_grid_actor,

    set_pause_mouse_position = function(bol) pause_mouse_position=bol end,
    add_mouse_screen_pos = function( x, y) control_pos_move_x=control_pos_move_x+x; control_pos_move_y=control_pos_move_y+y end,
    set_mouse_screen_pos = function( x, y) control_pos_move_x=x; control_pos_move_y=y end,
    
    --注册指示器显示
    registe_on_init_sections_info = function(act)
        on_init_sections_info[#on_init_sections_info+1] = act
        return function()
            for k,v in ipairs(on_init_sections_info) do
                if v == act then
                    table.remove( on_init_sections_info, k)
                    break
                end
            end
        end
    end,
    set_spell_can_build = function( bol) spell_can_build=bol end,
    get_spellbuild_grid_actor_ground = function() return spellbuild_grid_actor_ground end,
    get_spellbuild_unit_actor = function() return spellbuild_unit_actor end,
    --add_mouse_screen_pos = function( x, y) last_control_mouse_x=last_control_mouse_x+x; last_control_mouse_y=last_control_mouse_y+y end,
}
