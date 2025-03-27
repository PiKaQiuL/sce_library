--- lua_plus ---
base.any_unit = base.game
base.any_unit_id = base.game
base.any_player = base.game
base.any_skill = base.game
base.any_eff_param = base.game
base.any_mover = base.game
base.any_item = base.game
-- pending_game_units = {}
function base.table_new() adaptive_table
    ---@ui 空表
    ---@belong 立即值
    ---@description 空表
    ---@applicable value
    return {}
end