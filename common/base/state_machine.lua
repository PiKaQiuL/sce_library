if not (ImportSCEContext and __lua_state_name == 'StateGame') then return end
local SCE = ImportSCEContext()

local CustomStateMachine = class('CustomStateMachine', SCE.StateMachine)

function CustomStateMachine:ctor(name, priority, layer)
    self.states = {}
    self.name = name
    self.priority = priority
    self.layer = layer
end

function CustomStateMachine:add_state(name, id)
    if not self.states[id] then
        local state = base.state_machine_state(name, id)
        self.states[id] = state -- 这里存state是为了防止lua gc
        self.super.add_state(self, state)
    end
end

function base.state_machine(name, priority, layer)
    return CustomStateMachine.new(name, priority or 0, layer or 0)
end

local State = class('CustomState', SCE.SMState)

function State:ctor(name, id)
    self.id = id
    self.name = name
end

function base.state_machine_state(name, id)
    return State.new(name, id)
end