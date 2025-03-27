local math = math
local table = table
local setmetatable = setmetatable
local type = type

Point = base.tsc.__TS__Class()
Point.name = 'Point'

---@class Point
local mt = Point.prototype

--结构
mt.__index = mt

--类型
mt.type = 'point'

--坐标
mt[1] = 0.0
mt[2] = 0.0
mt[3] = 0.0

--创建一个点
--	base.point(x, y, z)
---comment
---@param x number
---@param y number
---@param z number
---@param scene string?
---@return Point
local function create_point(x, y, z, scene)
	return setmetatable({x, y, z, scene = scene}, mt)
end

---comment
---@param table table
---@return Point?
local function table_to_point(table)
	local x = table[1]
	local y = table[2]
	if x and type(x) =="number"  and y and type(y) == "number" then
		return setmetatable(table, mt)
	end
end

function mt:__tostring()
	return ('{point|(%f, %f, %f)|%s}'):format(self[1], self[2], self[3], self.scene or '')
end

--获取坐标
--	@2个坐标值
function mt:get_xy()
	return self[1], self[2]
end

function mt:get_x()
	return self[1]
end

function mt:get_y()
	return self[2]
end

function mt:get_height()
	return self[3]
end

---comment
---@param scene string
function mt:set_scene(scene)
	self.scene = scene
end

mt.__call = mt.get_xy

--复制点
function mt:copy()
	return create_point(self[1], self[2], self[3], self.scene)
end

function mt:copy_to_scene_point(scene)
	return base.scene_point(self[1], self[2], self[3], scene)
end

--返回点
function mt:get_point()
	return self
end

function mt:get_scene_point()
	return self
end

function mt:get_scene()
	return self.scene
end

-- 返回位置
function mt:get_position()
	local x, y = game.world_to_screen(self[1], self[2], self[3])
	return base.position(x, y)
end

function mt:__add(data)
	if self.scene and data.scene and self.scene ~= data.scene then
		log_file.debug('场景不同点不能相加')
		return self
	end
	return create_point(self[1] + data[1], self[2] + data[2], self[3] + data[3], self.scene or data.scene)
end

--按照极坐标系移动(point - {angle, distance})
--	@新点
local cos = base.math.cos
local sin = base.math.sin
function mt:__sub(data)
	local x, y = self[1], self[2]
	local angle, distance = data[1], data[2]
	if self.scene and data.scene and self.scene ~= data.scene then
		log_file.debug('场景不同点不能相减')
		return self
	end
	return create_point(x + distance * cos(angle), y + distance * sin(angle))
end

--求距离(point * point)
function mt:__mul(dest)
	return self:distance(dest)
end

--求方向(mt / point)
local atan = base.math.atan
function mt:__div(dest)
	return self:angle(dest)
end

function mt:__unm()
	return create_point(-self[1], -self[2], -self[3], self.scene)
end

function mt:add(data)
	if self.scene and data.scene and self.scene ~= data.scene then
		log_file.debug('场景不同点不能相加')
		return self
	end
	return create_point(self[1] + data[1], self[2] + data[2], self[3] + data[3], self.scene or data.scene)
end

function mt:polar_to_ex(angle, distance)
    if self.error_mark then
        log_file.info(('点[%s]不能进行坐标系移动'):format(self))
        return create_point(0, 0, 0), true
    else
        local x, y = self[1], self[2]
        return create_point(x + distance * cos(angle), y + distance * sin(angle), self[3], self.scene)
    end
end

--按照极坐标系移动(point:polar_to{angle, distance} )
--	@新点
function mt:polar_to(data)
	local x, y = self[1], self[2]
	local angle, distance = data[1], data[2]
	return create_point(x + distance * cos(angle), y + distance * sin(angle))
end

--求方向(向量self和向量dest的夹角)
function mt:angle(dest)
	local x1, y1 = self[1], self[2]
	local x2, y2 = dest[1], dest[2]
	return atan(y2 - y1, x2 - x1)
end

--与目标的距离
local sqrt = math.sqrt
function mt:distance(dest)
	local x1, y1 = self[1], self[2]
	local x2, y2 = dest[1], dest[2]
	local x0 = x1 - x2
	local y0 = y1 - y2
	return sqrt(x0 * x0 + y0 * y0)
end

-- 将self映射到坐标系(point, facing)后, self在该坐标系里的位置
function mt:to_coordinate(point, facing)
	local offset = self + (-point)
	if facing ~= 0 then
		local sin_a = sin(facing)
		local cos_a = cos(facing)
		offset[1], offset[2] = cos_a * offset[1] + sin_a * offset[2], -sin_a * offset[1] + cos_a * offset[2]
	end

	return offset
end

function mt:set_height(value)
    if value then
        self[3] = value
    end
end

function mt:is_block()
	return game.check_collision(self[1], self[2])
end

function mt.has_restriction(_,_)
    return false
end

---comment
function mt.has_label(_,_)
    return false
end

---comment
function mt.get_attackable_radius(_)
    return 0
end

function mt:get_unit()
    return nil
end

function mt:get_team_id()
    return nil
end

base.point = create_point
base.table_to_point = table_to_point

function base.get_scene_point(scene, area_name, present)
    ---@ui 场景~1~的点~2~
    ---@description 获取地编点
    ---@belong 点
    ---@instant true
    ---@applicable value
    ---@uitype tile_editor_item
    if present[scene] and present[scene]['point'][area_name] then
        if not(present[scene]['point'][area_name]:get_scene()) then
            present[scene]['point'][area_name] = present[scene]['point'][area_name]:copy_to_scene_point(scene)
        end
    end
    return present[scene] and present[scene]['point'][area_name]
end

return {
	Point = Point,
}