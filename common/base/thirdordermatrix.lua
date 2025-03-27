ThirdOrderMatrix = base.tsc.__TS__Class()
ThirdOrderMatrix.name = 'ThirdOrderMatrix'

local mt = ThirdOrderMatrix.prototype
mt.__index = mt
mt.type = 'ThirdOrderMatrix'
-- log_file.info("txy Martix123")


-- tom = ThirdOrderMatrix
local function create_tom(TOMArray)
    return setmetatable({TOMArray = TOMArray}, mt)
end

-- 矩阵加法
function mt:tom_addition(MartixB)
    local newArray = {
        {self.TOMArray[1][1]+MartixB.TOMArray[1][1],self.TOMArray[1][2]+MartixB.TOMArray[1][2],self.TOMArray[1][3]+MartixB.TOMArray[1][3]},
        {self.TOMArray[2][1]+MartixB.TOMArray[2][1],self.TOMArray[2][2]+MartixB.TOMArray[2][2],self.TOMArray[2][3]+MartixB.TOMArray[2][3]},
        {self.TOMArray[3][1]+MartixB.TOMArray[3][1],self.TOMArray[3][2]+MartixB.TOMArray[3][2],self.TOMArray[3][3]+MartixB.TOMArray[3][3]}
    }
    local newMartix = create_tom(newArray)
    -- log_file.info("txy Martix",newMartix.TOMArray[1][1])
    return newMartix
end
-- 矩阵减法
function mt:tom_subtraction(MartixB)
    local newArray = {
        {self.TOMArray[1][1]-MartixB.TOMArray[1][1],self.TOMArray[1][2]-MartixB.TOMArray[1][2],self.TOMArray[1][3]-MartixB.TOMArray[1][3]},
        {self.TOMArray[2][1]-MartixB.TOMArray[2][1],self.TOMArray[2][2]-MartixB.TOMArray[2][2],self.TOMArray[2][3]-MartixB.TOMArray[2][3]},
        {self.TOMArray[3][1]-MartixB.TOMArray[3][1],self.TOMArray[3][2]-MartixB.TOMArray[3][2],self.TOMArray[3][3]-MartixB.TOMArray[3][3]}
    }
    local newMartix = create_tom(newArray)
    -- log_file.info("txy Martix",newMartix.TOMArray[1][1])
    return newMartix
end

-- 与矩阵相乘
function mt:tom_multiplication_with_tom(MartixB)
    local newArray = {
        {
            self.TOMArray[1][1]*MartixB.TOMArray[1][1]+self.TOMArray[1][2]*MartixB.TOMArray[2][1]+self.TOMArray[1][3]*MartixB.TOMArray[3][1],
            self.TOMArray[1][1]*MartixB.TOMArray[1][2]+self.TOMArray[1][2]*MartixB.TOMArray[2][2]+self.TOMArray[1][3]*MartixB.TOMArray[3][2],
            self.TOMArray[1][1]*MartixB.TOMArray[1][3]+self.TOMArray[1][2]*MartixB.TOMArray[2][3]+self.TOMArray[1][3]*MartixB.TOMArray[3][3]
        },
        {
            self.TOMArray[2][1]*MartixB.TOMArray[1][1]+self.TOMArray[2][2]*MartixB.TOMArray[2][1]+self.TOMArray[2][3]*MartixB.TOMArray[3][1],
            self.TOMArray[2][1]*MartixB.TOMArray[1][2]+self.TOMArray[2][2]*MartixB.TOMArray[2][2]+self.TOMArray[2][3]*MartixB.TOMArray[3][2],
            self.TOMArray[2][1]*MartixB.TOMArray[1][3]+self.TOMArray[2][2]*MartixB.TOMArray[2][3]+self.TOMArray[2][3]*MartixB.TOMArray[3][3]
        },
        {
            self.TOMArray[3][1]*MartixB.TOMArray[1][1]+self.TOMArray[3][2]*MartixB.TOMArray[2][1]+self.TOMArray[3][3]*MartixB.TOMArray[3][1],
            self.TOMArray[3][1]*MartixB.TOMArray[1][2]+self.TOMArray[3][2]*MartixB.TOMArray[2][2]+self.TOMArray[3][3]*MartixB.TOMArray[3][2],
            self.TOMArray[3][1]*MartixB.TOMArray[1][3]+self.TOMArray[3][2]*MartixB.TOMArray[2][3]+self.TOMArray[3][3]*MartixB.TOMArray[3][3]
        },
    }
    local newMartix = create_tom(newArray)
    return newMartix
end

-- 与向量相乘
function mt:tom_multiplication_with_vector(Vector)
    local newVector = base.vector(
        self.TOMArray[1][1]*Vector.X+self.TOMArray[1][2]*Vector.Y+self.TOMArray[1][3]*Vector.Z,
        self.TOMArray[2][1]*Vector.X+self.TOMArray[2][2]*Vector.Y+self.TOMArray[2][3]*Vector.Z,
        self.TOMArray[3][1]*Vector.X+self.TOMArray[3][2]*Vector.Y+self.TOMArray[3][3]*Vector.Z
    )
    return newVector
end

-- 矩阵的行列式 determinant
function mt:tom_determinant()
    local value =
    self.TOMArray[1][1] * self.TOMArray[2][2] * self.TOMArray[3][3] +
    self.TOMArray[1][2] * self.TOMArray[2][3] * self.TOMArray[3][1] +
    self.TOMArray[1][3] * self.TOMArray[2][1] * self.TOMArray[3][2] -
    self.TOMArray[1][3] * self.TOMArray[2][2] * self.TOMArray[3][1] -
    self.TOMArray[1][2] * self.TOMArray[2][1] * self.TOMArray[3][3] -
    self.TOMArray[1][1] * self.TOMArray[2][3] * self.TOMArray[3][2]
    return value
end

base.third_order_matrix = create_tom

return {
    ThirdOrderMatrix = ThirdOrderMatrix,
}