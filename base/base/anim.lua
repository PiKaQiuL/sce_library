
local map = {}
local cxx_anim = anim

local function set_anim(id, config, fn)
    if cxx_anim == nil then
        return
    end
    local k = cxx_anim.set(id, config)
    map[k] = fn
end

local function update(data)
    for k, v in pairs(data) do
        -- print('update '..k..' '..v)
        map[k](v)
    end
end

if cxx_anim then
    cxx_anim.register_on_update(update)
end

anim = {
    set = set_anim
}

return anim