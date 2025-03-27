local function deep_copy(t)
    if type(t) == 'table' then
        local new = {}
        for k, v in pairs(t) do
            new[k] = deep_copy(v)
        end
        return new
    else
        return t
    end
end

local function eq(a, b)
    local tp1, tp2 = type(a), type(b)
    if tp1 ~= tp2 then
        return false
    end
    if tp1 == 'table' then
        local mark = {}
        for k in pairs(a) do
            if not eq(a[k], b[k]) then
                return false
            end
            mark[k] = true
        end
        for k in pairs(b) do
            if not mark[k] then
                return false
            end
        end
        return true
    end
    return a == b
end

local function update_model(self, k, v)
    if not self.model then
        self.model = {}
    end
    -- if k ~= 'scale' then
    --     if eq(self.model[k], v) then
    --         return
    --     end
    -- end
    self.model[k] = v
    base.ui.gui.set_model(self.id, {[k] = v})
end

local function update_camera_info(self, k, v)
    if not self.camera_info then
        self.camera_info = {}
    end
    self.camera_info[k] = v
    base.ui.gui.set_camera_info(self.id, {[k] = v})
end

local function update_particle(self, k, v)
    if not self.particle then
        self.particle = {}
    end
    self.particle[k] = v
    base.ui.gui.set_particle(self.id, {[k] = v})
end

local function update_buff(self, k, v)
    if not self.buff then
        self.buff = {}
    end
    local copy_v = deep_copy(v)
    self.buff[k] = copy_v
    base.ui.gui.set_buff(self.id, {[k] = copy_v})
end

local function update_light(self, k, v)
    if not self.light then
        self.light = {}
    end
    self.light[k] = v
    base.ui.gui.set_light(self.id, {[k] = v})
end

local tp = (__lua_state_name == 'StateGame' or __lua_state_name == 'StateApplication') and 'scene' or 'panel'

return function (template, bind)
    local ui = base.ui.view {
        type = tp,
        name = template.name,
        id = template.id
    }

    ui.independent = template.independent

    ui.camera_info = deep_copy(template.camera_info)
    function bind.watch:camera_info(k, v)
        update_camera_info(ui, k, v)
    end

    ui.model = deep_copy(template.model)
    function bind.watch:model(k, v)
        update_model(ui, k, v)
    end

    ui.particle = deep_copy(template.particle)
    function bind.watch:particle(k, v)
        update_particle(ui, k, v)
    end
    ui.buff = deep_copy(template.buff)
    function bind.watch:buff(k, v)
        update_buff(ui, k, v)
    end

    ui.light = deep_copy(template.light)
    function bind.watch:light(k, v)
        update_light(ui, k, v)
    end

    base.ui.watch(ui, template, bind, 'part_cloth')
    base.ui.watch(ui, template, bind, 'save')

    return ui
end