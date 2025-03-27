local module_selector = require '@common.base.gui.selector'
local get_by_selector = module_selector.get_by_selector
local build_selector = module_selector.build_selector
local parse_simple_selector_info = module_selector.parse_simple_selector_info
local assign_by_selector = module_selector.assign_by_selector

local function alias_get(self, bibind_prop, key)
    return get_by_selector(bibind_prop)
end

local function alias_set(self, v, bibind_prop, key)
    assign_by_selector(bibind_prop, v)
    return true
end

local function build_alias_prop(self, ctrl, prop_name)
    local alias_prop = build_selector(self, ctrl)
    alias_prop.__type = 'getset'
    alias_prop.get = alias_get
    alias_prop.set = alias_set
    return alias_prop
end

local function alias_from_selector_info(selector_info)
    selector_info.__type = 'alias'
    selector_info.build = build_alias_prop
    return selector_info
end

local alias = function(simple_selector_info_str)
    local simple_selector_info = parse_simple_selector_info(simple_selector_info_str)
    simple_selector_info.__type = 'alias'
    simple_selector_info.build = build_alias_prop
    return setmetatable(simple_selector_info, {
        __call = function(self, v)
            simple_selector_info.__default = v
            return simple_selector_info
        end
    })
end

return {
    alias_from_selector_info = alias_from_selector_info,
    alias = alias,
}