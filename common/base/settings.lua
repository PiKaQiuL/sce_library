base.settings = {}

local registered_func = {}
local cur_setting_game

function base.settings:get_option(key)
    if (type(key) == 'string') then
        return common.get_option(key)
    end
end

function base.settings:save_global_option(key, para)
    if type(para) == 'string' then
        common.save_string_option(key, para, true)
    elseif type(para) == 'number' then
        common.save_float_option(key, para, true)
    elseif type(para) == 'boolean' then
        common.save_boolean_option(key, para, true)
    end
end

function base.settings:save_option(key, para)
    if type(para) == 'string' then
        common.save_string_option(key, para)
    elseif type(para) == 'number' then
        common.save_float_option(key, para)
    elseif type(para) == 'boolean' then
        common.save_boolean_option(key, para)
    end
end

function base.settings:set_option(key, para)
    if type(para) == 'string' then
        common.set_string_option(key, para)
    elseif type(para) == 'number' then
        common.set_float_option(key, para)
    elseif type(para) == 'boolean' then
        common.set_boolean_option(key, para)
    end
end

function base.settings:set_default_option(key, para)
    if type(para) == 'string' then
        common.set_default_string_option(key, para)
    elseif type(para) == 'number' then
        common.set_default_float_option(key, para)
    elseif type(para) == 'boolean' then
        common.set_default_boolean_option(key, para)
    end
end

function base.settings:register_option(name, func)
    common.register_option(name)
    registered_func[name] = func
end

function base.settings:set_current_game(current_game)
    if common.set_current_game then
        common.set_current_game(current_game)
    end
    cur_setting_game = current_game
end

function base.settings:get_current_game()
    return cur_setting_game
end

function base.event.on_settings_changed(pressed, val)
    if registered_func[pressed] then
        registered_func[pressed](val)
    end
end

if common.get_value('save_replay') == 'true' and __lua_state_name == 'StateGame' then
    base.game:event('卸载地图', function()
        log_file.info('save_replay--->false')
        common.set_value('save_replay', 'false')
    end)
end