ScenePoint = ScenePoint or base.tsc.__TS__Class()
ScenePoint.name = 'ScenePoint'

local point_core = require 'base.point'.Point.prototype

---@class ScenePoint:Point
---@field error_mark boolean?
---@field scene string
local mt = ScenePoint.prototype

-- 注意在这里，ScenePoint并不是Point的子类，而是Target的子类，但ScenePoint可视为Implement了Point
base.tsc.__TS__ClassExtends(ScenePoint, Target)

mt[1] = 0
mt[2] = 0
mt[3] = 0
mt.type = 'point'
mt = setmetatable(mt, point_core)
local MAX_DISTANCE = 99999999
local ERROR_ANGLE = 0

---comment
---@param x number
---@param y number
---@param z number?
---@param scene string
---@param error_mark boolean?
---@return ScenePoint
local function create_scene_point(x, y, z, scene, error_mark)
    local scene_hash = scene and base.get_scene_hash_by_name(scene)
    return setmetatable({x, y, z, scene = scene and string.lower(scene), scene_hash = scene_hash, error_mark = error_mark}, mt)
end

---comment
---@param x number
---@param y number
---@param z number?
---@param scene_hash integer
---@param error_mark boolean?
---@return ScenePoint
local function create_scene_point_by_hash(x, y, z, scene_hash, error_mark)
    local scene_name = scene_hash and base.get_scene_name_by_hash(scene_hash)
    return setmetatable({ x, y, z, scene = scene_name and string.lower(scene_name), scene_hash = scene_hash, error_mark = error_mark}, mt)
end

base.scene_point = create_scene_point
base.scene_point_by_hash = create_scene_point_by_hash

function mt:__tostring()
    if self.error_mark then
        return '{point|(错误)}'
    else
        return ('{point|(%f, %f, %f, %s)}'):format(self[1], self[2], self[3], self.scene)
    end
end

--获取坐标
--	@2个坐标值
function mt:get_xy()
    if self.error_mark then
        log_file.info(('点[%s]不能获得xy值'):format(self))
        return nil, nil, true
    else
        return self[1], self[2]
    end
end

function mt:get_x()
    if self.error_mark then
        log_file.info(('点[%s]不能获得x值'):format(self))
        return nil, true
    else
        return self[1]
    end
end

function mt:get_y()
    if self.error_mark then
        log_file.info(('点[%s]不能获得y值'):format(self))
        return nil, true
    else
        return self[2]
    end
end

-- 获取z
function mt:get_z()
    if self.error_mark then
        log_file.info(('点[%s]不能获得z坐标'):format(self))
        return MAX_DISTANCE, true
    else
        return self[3]
    end
end

function mt:get_height()
    return self:get_z() or 0
end


function mt:get_scene()
    if self.error_mark then
        log_file.info(('点[%s]不能获得场景'):format(self))
        return nil, true
    else
        if self.scene then
            if not self.scene_hash then
                self.scene_hash = base.get_scene_hash_by_name(self.scene)
            end
            return self.scene
        end

        if self.scene_hash then
            self.scene = base.get_scene_name_by_hash(self.scene_hash)
            return self.scene
        end
        return nil
    end
end

function mt:get_scene_name()
    return self:get_scene()
end

function mt:get_scene_point()
    return self
end

--复制点
function mt:copy()
    if self.error_mark then
        log_file.info(('点[%s]不能进行复制'):format(self))
        return create_scene_point(0, 0, 0, '', true)
    else
        return create_scene_point(self[1], self[2], self[3], self.scene)
    end
end

function mt:copy_to_scene_point(scene)
    return base.scene_point(self[1], self[2], self[3], scene)
end

--返回点
function mt:get_point()
    return self
end

-- 转换为矢量
function mt:to_vector(height)
    if self.error_mark then
        log_file.info(('点[%s]不能转换为矢量'):format(self))
        return nil, true
    else
        return {self[1], self[2], height}
    end
end


--按照极坐标系移动(point:polar_to({angle, distance}))
--	@新点
local cos = base.math.cos
local sin = base.math.sin
function mt:__add(data)
    if self.error_mark or data.error_mark or (self.scene and data.scene and data.scene ~= self.scene) then
        log_file.info(('场景不同的的点[%s], [%s]不能相加'):format(self, data))
        return create_scene_point(0, 0, 0, '', true), true
    else
        return create_scene_point(self[1] + data[1], self[2] + data[2], self[3] + data[3], self.scene or data.scene)
    end
end

--按照极坐标系移动(point:polar_to({angle, distance}))
--	@新点
function mt:__sub(data)
    if self.error_mark or data.error_mark or (self.scene and data.scene and data.scene ~= self.scene) then
        log_file.info(('场景不同的的点[%s], [%s]不能相减'):format(self, data))
        return create_scene_point(0, 0, 0, '', true), true
    else
        local x, y = self[1], self[2]
        local angle, distance = data[1], data[2]
        return create_scene_point(x + distance * cos(angle), y + distance * sin(angle), nil, self.scene or data.scene)
    end
end

--求距离(point * point)
function mt:__mul(dest)
    if self.error_mark or dest.error_mark or dest.scene ~= self.scene then
        log_file.info(('场景不同的的点[%s], [%s]不能相乘'):format(self, dest))
        return MAX_DISTANCE, true
    else
        return self:distance(dest)
    end
end

--求方向(mt / point)
local atan = base.math.atan
function mt:__div(dest)
    return self:angle(dest)
end

function mt:__unm()
    if self.error_mark then
        log_file.info(('点[%s]不能取反'):format(self))
        return create_scene_point(0, 0, 0, '', true), true
    else
        return create_scene_point(-self[1], -self[2], -self[3], self.scene, self.error_mark)
    end
end

function mt:add(data)
    if self.error_mark or data.error_mark or (self.scene and data.scene and data.scene ~= self.scene) then
        log_file.info(('场景不同的的点[%s], [%s]不能add'):format(self, data))
        return create_scene_point(0, 0, 0, '', true), true
    else
        return create_scene_point(self[1] + data[1], self[2] + data[2], self[3] + data[3], self.scene or data.scene)
    end
end

--按照极坐标系移动(point:polar_to{angle, distance} )
--	@新点
function mt:polar_to(data)
    if self.error_mark then
        log_file.info(('点[%s]不能进行坐标系移动'):format(self))
        return create_scene_point(0, 0, 0, '', true), true
    else
        local x, y = self[1], self[2]
        local angle, distance = data[1], data[2]
        return create_scene_point(x + distance * cos(angle), y + distance * sin(angle), nil, self.scene)
    end
end

function mt:polar_to_ex(angle, distance)
    if self.error_mark then
        log_file.info(('点[%s]不能进行坐标系移动'):format(self))
        return create_scene_point(0, 0, 0, '', true), true
    else
        local x, y = self[1], self[2]
        return create_scene_point(x + distance * cos(angle), y + distance * sin(angle), nil, self.scene)
    end
end

--求方向(向量self和向量dest的夹角)
function mt:angle(dest)
    if self.error_mark or dest.error_mark or (self.scene and dest.scene and dest.scene ~= self.scene) then
        log_file.info(('场景不同的的点[%s], [%s]不能求夹角'):format(self, dest))
        return ERROR_ANGLE, true
    else
        local x1, y1 = self[1], self[2]
        local x2, y2 = dest[1], dest[2]
        return atan(y2 - y1, x2 - x1)
    end
end

--与目标的距离
local sqrt = math.sqrt
function mt:distance(dest)
    if self.error_mark or dest.error_mark or (dest.scene and self.scene and dest.scene ~= self.scene) then
        log_file.info(('场景不同的的点[%s], [%s]不能求距离'):format(self, dest))
        return MAX_DISTANCE, true
    else
        local x1, y1 = self[1], self[2]
        local x2, y2 = dest[1], dest[2]
        local x0 = x1 - x2
        local y0 = y1 - y2
        return sqrt(x0 * x0 + y0 * y0)
    end
end

-- 将self映射到坐标系(point, facing)后, self在该坐标系里的位置
function mt:to_coordinate(point, facing)
    if self.error_mark then
        log_file.info(('点[%s]不能映射到坐标系'):format(self))
        return nil, true
    else
        local offset = self + (-point)
        if facing ~= 0 then
            local sin_a = sin(facing)
            local cos_a = cos(facing)
            offset[1], offset[2] = cos_a * offset[1] + sin_a * offset[2], -sin_a * offset[1] + cos_a * offset[2]
        end
        return offset
    end
end

function mt:get_unit()
    if self.error_mark then
        log_file.info(('点[%s]不能获取单位'):format(self))
        return nil, true
    end
    return nil
end

function mt:get_owner()
    if self.error_mark then
        log_file.info(('点[%s]不能获取所有者'):format(self))
        return nil, true
    end
    return nil
end

function mt:get_facing()
    if self.error_mark then
        log_file.info(('点[%s]不能获取朝向'):format(self))
        return nil, true
    end
    return nil
end

function mt:get_team_id()
    if self.error_mark then
        log_file.info(('点[%s]不能获取队伍Id'):format(self))
        return nil, true
    end
    return nil
end

---comment
---@param dest table
---@return number?, boolean?
function mt:angle_to(dest)
    if self.error_mark or dest.error_mark or (self.scene and dest.scene and dest.scene ~= self.scene) then
        log_file.info(('场景不同的的点[%s], [%s]不能求角度'):format(self, dest))
        return ERROR_ANGLE, true
    else
        local x1, y1 = self[1], self[2]
        local x2, y2 = dest[1], dest[2]
        if(x1==y1 and x2==y2)then
            return nil
        end
        return atan(y2 - y1, x2 - x1)
    end
end

function mt:get_snapshot()
    if self.error_mark then
        log_file.info(('点[%s]不能生成快照'):format(self))
        return nil, true
    else
        local snapshot=base.snapshot:new()
        snapshot.origin_type='point'
        snapshot.point=self:get_point()
        return snapshot
    end
end

--TODO: 需要特别指定一个中立玩家：
function mt:create_effect(model)
    if self.error_mark then
        log_file.info(('点[%s]不能生成效果节点'):format(self))
        return true
    else
        base.player(0):effect{
            model = model,
            target = {self , self[3] or 0},
            time = 0.7,
            speed = 1,
        }
    end
end

---comment
---@param dest Player
---@return boolean?, boolean?
function mt:is_visible_to(dest)
    if self.error_mark then
        log_file.info(('点[%s]不能判断可见与否'):format(self))
        return nil, true
    end
    return self:is_visible(dest)
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

function mt:get_collision_flags(bol)
    local scene = self:get_scene()
    if not scene then
        log.warn("当前获取的点没有场景属性，无法获取碰撞标记集合")
        return nil
    end
    local mask = static_collision.get_flag(self:get_x(), self:get_y(), bol)
    if type(mask) ~= "number" then
        log.warn("获取碰撞标记集合出错",self)
    end
    return base.collision_flags(mask)
end


return {
    ScenePoint = ScenePoint
}