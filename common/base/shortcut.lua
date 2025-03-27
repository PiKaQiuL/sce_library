if __lua_state_name ~= 'StateGame' then
    return
end

_G.shortcut_events = _G.shortcut_events or {}

base.shortcut = {}

local registered_func = {}

function base.shortcut:register(name, func)
    shortcut.register_shortcut(name, nil)
    registered_func[name] = func
end

function shortcut_events.on_shortcut_pressed(pressed)
    if registered_func[pressed] then
        registered_func[pressed]()
    end
end

function base.shortcut:has_registered(name)
    return shortcut.has_register_shortcut(name)
end
function base.shortcut:unregister(name)
    shortcut.unregister_shortcut(name)
    registered_func[name] = nil
end
function base.shortcut:get_shortcut_pressed(name, repeatable)
    return shortcut.get_shortcut_pressed(name, repeatable)
end
function base.shortcut:lock(name)
    shortcut.lock(name)
end
function base.shortcut:unlock(name)
    shortcut.unlock(name)
end
function base.shortcut:lock_all()
    shortcut.lock_all()
end
function base.shortcut:unlock_all()
    shortcut.unlock_all()
end

-- 快捷键映射
base.shortcut.TEST = 5000