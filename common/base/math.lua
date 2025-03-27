base.math = {}

if cpp_rand and cpp_rand.random then
    math.random = cpp_rand.random
end
if cpp_rand and cpp_rand.randomseed then
    math.randomseed = cpp_rand.randomseed
end
cpp_rand = nil

-- 使用角度制的三角函数
local deg = math.deg(1)
local rad = math.rad(1)

-- 正弦
local sin = math.sin
function base.math.sin(r)
    return sin(r * rad)
end

-- 余弦
local cos = math.cos
function base.math.cos(r)
    return cos(r * rad)
end

-- 正切
local tan = math.tan
function base.math.tan(r)
    return tan(r * rad)
end

-- 反正弦
local asin = math.asin
function base.math.asin(v)
    return asin(v) * deg
end

-- 反余弦
local acos = math.acos
function base.math.acos(v)
    return acos(v) * deg
end

-- 反正切
local atan = math.atan
function base.math.atan(v1, v2)
    return atan(v1, v2) * deg
end

-- 向上取整
local ceil = math.ceil
function base.math.ceil(v)
    return ceil(v)
end

-- 向下取整
local floor = math.floor
function base.math.floor(v)
    return floor(v)
end

-- 浮点数比较
function base.math.float_eq(a, b)
    return math.abs(a - b) <= 1e-5
end

function base.math.float_ueq(a, b)
    return math.abs(a - b) > 1e-5
end

function base.math.float_lt(a, b)
    return a - b < -1e-5
end

function base.math.float_le(a, b)
    return a - b <= 1e-5
end

function base.math.float_gt(a, b)
    return a - b > 1e-5
end

function base.math.float_ge(a, b)
    return a - b >= -1e-5
end

-- 随机浮点数
function base.math.random_float(a, b)
    return math.random() * (b - a) + a
end

---comment
---@param n number
local function is_int(n)
    return math.floor(n) == n
end

function base.math.is_int(n)
    return is_int(n)
end

-- 随机整数
function base.math.random_int(a, b)
    if type(a) == 'number' and type(b) == 'number' then
        a = math.floor(a)
        b = math.floor(b)
        return math.random(a, b)
    end
end

-- 浮点数小数部分（编辑器用）
function base.math.float_modf(n)
    local _, b = math.modf(n)
    return b
end

--计算2个角度之间的夹角
function base.math.included_angle(r1, r2)
    local r = (r1 - r2) % 360
    if r >= 180 then
        return 360 - r, 1
    else
        return r, -1
    end
end

---插值运算
---@param from number
---@param to number
---@param t number
function base.math.lerp(from, to, t)
    if t < 0 then
        return from
    elseif t > 1 then
        return to
    end
    return from + (to - from) * t
end

function base.math.clamp(value, left, right)
    if left > right then
        left, right  = right, left
    end
    if value < left then
        return left
    end
    if value > right then
        return right
    end
    return value
end

function base.math.max(...)
    return math.max(...)
end

function base.math.min(...)
    return math.min(...)
end

function base.math.vector_add(vector1, vector2)
    return {X = vector1.X + vector2.X, Y = vector1.Y + vector2.Y, Z = vector1.Z + vector2.Z}
end

function base.math.vector_sub(vector1, vector2)
    return {X = vector1.X - vector2.X, Y = vector1.Y - vector2.Y, Z = vector1.Z - vector2.Z}
end

function base.math.vector_mul(vector, mul)
    return {X = vector.X * mul, Y = vector.Y * mul, Z = vector.Z * mul}
end

function base.math.dot_product(vector1, vector2)
    return vector1.X * vector2.X + vector1.Y * vector2.Y + vector1.Z * vector2.Z
end

function base.math.cross_product(vector1, vector2)
    return {
        X = vector1.Y * vector2.Z - vector1.Z * vector2.Y,
        Y = vector1.Z * vector2.X - vector1.X * vector2.Z,
        Z = vector1.X * vector2.Y - vector1.Y * vector2.X
    }
end

-- 平方根
function base.math.sqrt(x)
    return math.sqrt (x)
end

-- 对数
function base.math.log(...)
    return math.log(...)
end
-- 次幂
function base.math.pow(x, y)
    return x ^ y;
end

-- 平方
function base.math.square(x)
    return x * x;
end

-- 自然指数
function base.math.exp (x)
    return math.exp(x)
end

-- 绝对值
function base.math.abs(x)
    return math.abs(x)
end