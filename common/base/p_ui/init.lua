base_ = base

base_.p_ui = setmetatable({}, {__index = base.ui})

base_.p_ui.class = {}


local base = {}

function base:emit(event, ...)
    local event_callback = self._prop[event]
    if event_callback then
        event_callback(...)
    end
    if self._handlers[event] then
        self._handlers[event](...)
    end
end

function base:init_events(bind)
    self._handlers = {}
    for _, event in pairs(self.event()) do
        bind.watch[event] = function(_, cb)
            self._handlers[event] = cb
        end
    end
end

function base:merge(from, to)
    if not from or not to then return end
    for k, v in pairs(from) do
        to[k] = v
    end
end

function base:new_bind()
    return nil
end

function base_.p_ui.register(type, control, base_class)
    base_.p_ui[type] = function(prop)
        prop.class = type
        return prop
    end

    local derived = setmetatable(control, {__index = base_class or base})
    base_.p_ui.class[type] = derived

    local index = 1
    base_.p_ui['create_'..type] = function(prop, bind)
        local inst = setmetatable(derived.data(), {__index = derived})
        inst._prop = prop
        local template = inst:define()
        local new_bind = inst:new_bind()
        local _ui, _impl = base_.ui.create(template, '__cui__'..index, new_bind or bind)
        inst._ui = _ui
        inst._impl = _impl
        inst._parent = bind
        inst:init()
        local watchers = inst:watch()
        bind:load(prop)
        for key, watcher in pairs(watchers) do
            bind.watch[key] = function(t, ...)
                watcher(...)
            end
        end
        inst:init_events(bind)
        index = index + 1
        return _ui
    end
end