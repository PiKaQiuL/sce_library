Array = base.tsc.__TS__Class()
Array.name = 'Array'
function Array.prototype.____constructor(self, T, ...)
    for _, item in ipairs(table.pack(...)) do
        self[#self+1] = item
    end
end

return {
    Array = Array,
}