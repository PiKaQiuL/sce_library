base.terrain = {}

function base.terrain:get_texture_name(x, y)
    local name, tag = game.get_texture(x, y)
    return name
end

function base.terrain:get_texture_tag(x, y)
    local name, tag = game.get_texture(x, y)
    return tag
end

function base.terrain:get_texture_info(x, y)
    return game.get_texture(x, y)
end
