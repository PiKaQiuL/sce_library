ScreenPos = base.tsc.__TS__Class()
ScreenPos.name = 'ScreenPos'
local get_global_scale = require'@common.base.ui.auto_scale'.current_scale

local mt = ScreenPos.prototype

--结构
mt.__index = mt

--类型
mt.type = 'screen_pos'

--坐标
mt[1] = 0
mt[2] = 0

function mt:__tostring()
    return ('{screen_pos|(%s, %s)}'):format(self[1], self[2])
end

function mt:get_xy()
    return self[1], self[2]
end

function mt:get_x()
    return self[1]
end

function mt:get_y()
    return self[2]
end

function mt:get_ui_x()
    return math.floor(self[1] / get_global_scale() + 0.5)
end

function mt:get_ui_y()
    return math.floor(self[2] / get_global_scale() + 0.5)
end

function mt:get_point()
    local x, y, z = game.screen_to_world(self[1], self[2])
    return base.point(x, y, z)
end

function base.mouse_screen_pos()
    local x, y = common.get_mouse_screen_pos()
    return base.screen_pos(x, y)
end

function base.position(x, y)
    return setmetatable({x, y}, mt)
end

-- 用下面这个不容易误解
function base.screen_pos(x, y)
    return setmetatable({x, y}, mt)
end

return {
    ScreenPos = ScreenPos,
}