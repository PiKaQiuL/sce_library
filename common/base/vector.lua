Vector = base.tsc.__TS__Class()
Vector.name = 'Vector'

local mt = Vector.prototype
mt.__index = mt
mt.type = 'Vector'

local function create_vector(X, Y, Z)
    return setmetatable({X = X, Y = Y, Z = Z}, mt)
end

-- 向量加法
function mt:vector_addition(VectorB)
    local VectorC = base.vector(self.X + VectorB.X,self.Y + VectorB.X,self.Z + VectorB.Z)
    return VectorC
end
-- 向量减法
function mt:vector_subtraction(VectorB)
    local VectorC = base.vector(self.X - VectorB.X,self.Y - VectorB.X,self.Z - VectorB.Z)
    return VectorC
end
-- 向量乘法(点乘)
function mt:vector_multiplication(VectorB)
    local VectorC = base.vector(self.X * VectorB.X,self.Y * VectorB.X,self.Z * VectorB.Z)
    return VectorC
end
-- 向量除法
-- function mt:vector_division()
    
-- end

-- 获取向量长度
function mt:get_vector_length()
    -- local norm = math.sqrt(math.square(self.X)+math.square(self.Y)+math.square(self.Z))
    local norm = (self.X ^ 2+ self.Y ^ 2+ self.Z ^ 2) ^ 0.5
    return norm
end

-- 获取单位向量
function mt:get_unit_vector()
    local norm = self:get_vector_length()
    return base.vector(self.X/norm,self.Y/norm,self.Z/norm)
end


base.vector = create_vector

return {
    Vector = Vector,
}