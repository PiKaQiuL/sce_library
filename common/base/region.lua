local base = base

Region = Region or base.tsc.__TS__Class()
Region.name = 'Region'


local mt = Region.prototype
mt.type = 'region'


return {
    Region = Region
}