Camera = base.tsc.__TS__Class()
Camera.name = 'Camera'

local default = {
    CameraMode = '默认',
    scene_border = {},
    Position = {},
    Rotation = {},
    cache = {},
}

local attr_key = {
    focus_unit_moving_time = 0.3,
    min_focus_moving_speed = 2000,
    max_focus_moving_speed = 4000,
    focus_scroll_border = 15,
    scroll_move_speed = 750,
    filed_of_view = 45,
    near_clip = 1,
    far_clip = 100000,
    YBias = 0,
    XBias = 0,
    ZBias = 0,
    SpringArm = false,
    Orthographic = false,
    Distance = 0,
}


local mt = Camera.prototype
mt.__index = mt

local camera_ = setmetatable({},mt)

mt.__newindex = function (self, k, v)
    --不是特殊key直接赋值
    if attr_key[k] == nil then
        rawset(self,k,v)
        return
    end
    --特殊key存进data里
    if v == nil then
        log_file.info('设置属性 v == nil', k, debug.traceback())
        return
    end
    self.data[k] = v
    --如果是当前相机直接设置
    if self == camera_ then
        log_file.info('set', k, v)
        game.set_camera_attribute({[k] = v})
    end
end

mt.__index = function( self, k)
    --有default的key
    if attr_key[k] then
        --优先取data，然后取默认
        return rawget(self, 'data')[k] or attr_key[k] or default[k]
    end
    --普通key
    return rawget( self, k) or default[k] or mt[k]
end

mt.type = 'camera'
mt._name = nil

function mt.____constructor(self,link)
    local obj = self
    rawset( self, 'data', {})
    obj.cache = base.eff.cache(link)
    for k, v in pairs(obj.cache) do
        obj[k] = v
    end
    obj.Position = obj.cache.init_position
    obj.Rotation = obj.cache.default_rotation
    obj.Distance = obj.cache.max_distance
    return obj
end

function base.get_camera_link()
    return game.get_camera_link()
end

local function default_camera_init()
    local default_link = game.get_camera_link()
    camera_:____constructor(default_link)
end

if base.eff.cache_init_finished() then
    default_camera_init()
else
    base.game:event('Src-PostCacheInit', function()
        default_camera_init()
    end)
end


function mt:__tostring()
    return 'GameCamera'
end

function mt:get_name()
    return self._name
end

-- 旋转镜头
function mt:rotate_camera(point, speed, time)
    if self == camera_ then
        game.camera_rotate_around_point(point[1], point[2], point[3], speed, time)
    end
end
    

-- 震动镜头
function mt:shake_camera(type, frequency, amplitude, time)
    if self == camera_ then
        game.shake_camera(type, frequency, amplitude, time)
    end
end

-- 移动镜头
function mt:set_camera(position, rotation, focus_distance, time)
    if self == camera_ then
        game.set_camera({position = position, rotation = rotation, focus_distance = focus_distance, time = time * 1000})
    else
        if self ~= camera_ then
            self.Position = position
            self.Rotation = rotation
            self.Distance = focus_distance
        end
    end
    
end

-- 设置镜头属性
function mt:set_camera_attribute_number(k, v, time)
    game.set_camera_attribute({[k] = v, time = time})
end

-- 切换镜头
function mt:switch_camera(link, time)
    game.switch_camera(link, time)
end

-- 获取位置
function mt:get_position()
    local current_camera = game.get_camera()
    local position = {}
    if self == camera_ then
        position = current_camera.position
    else
        if self ~= camera_ then
            position = self.Position
        end
    end
    local x, y, z = position[1], position[2], position[3]
	return base.point(x or 0.0, y or 0.0, z or 0.0)
end

-- 获取旋转
function mt:get_rotation()
    local current_camera = game.get_camera()
	local rotation = {}
    if self == camera_ then
        rotation = current_camera.rotation
    else
        if self ~= camera_ then
            rotation = self.Rotation
        end
    end
    local roll, pitch, yaw = rotation[1], rotation[2], rotation[3]
	return { yaw = yaw, pitch = pitch, roll = roll }
end

-- 获取焦点距离
function mt:get_distance()
    local current_camera = game.get_camera()
	local distance = 1000
    if self == camera_ then
        distance = current_camera.focus_distance
    else
        if self ~= camera_ then
            distance = self.Distance
        end
    end
	return distance
end


--设置为活动镜头
function mt:set_as_active()
    for k, v in pairs(self.cache) do
        game.set_camera_attribute({[k] = v})
    end
    camera_ = self
    game.set_camera({position = self.Position, rotation = self.Rotation, focus_distance = self.Distance, time = 0})
end

function base.camera()
    return camera_
end

base.proto.set_camera = function(msg)
    if msg ~= nil then
        camera_:switch_camera(msg.camera_id_name, msg.time)
    end
end

return {
    Camera = Camera,
}
