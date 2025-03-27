local t = {
    'label',
    'panel',
    'button',
}

local metadatas = {}
for i, v in ipairs(t) do
    local metadata = require ('@common.base.gui.metadatas.'..v)
    metadatas[v] = metadata
end

return metadatas