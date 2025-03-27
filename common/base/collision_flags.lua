CollisionFlags = base.tsc.__TS__Class()
CollisionFlags.name = 'CollisionFlags'

local mt = CollisionFlags.prototype
mt.__index = mt
mt.type = 'CollisionFlags'

local collision_flags = {
    Unwalkable = 0x2, --不可行走。 
	Unflyable = 0x4, --不可飞行。 
	Unbuildable = 0x8, --不可建造。 
	UnPeonHarvest = 0x10, --不可采集区域（
	Blighted = 0x20, --荒芜地
	Unfloatable = 0x40, --不可漂浮
	Unamphibious = 0x80, --不可两栖
	UnItemplacable = 0x100,--不可放置物品。 
	Cliff = 0x200,
	Higher = 0x400, --指存在高于地表的障碍物 
	Lower = 0x800, --指存在低于地表的障碍物（像是刷出来的沟壑） 
}

local flag_collision_map = {}

do
    for key, value in pairs(collision_flags) do
        flag_collision_map[value] = key
    end
end


function base.collision_flags(mask)
    return setmetatable({mask = mask}, mt)
end

-- 是否包含某一类型碰撞
function mt:contains(flag)
    local num = collision_flags[flag] or 0
    return self.mask and (self.mask & num) > 0
end

-- 遍历为真的碰撞
function mt:each_collision(callback)
    local mask = self.mask
    local idx = 1
    -- 碰撞从2^1开始
    while mask > 0 do
        mask = mask >> 1
        idx = idx << 1
        if (mask & 1) > 0 then
            callback(flag_collision_map[idx])
        end
    end
end