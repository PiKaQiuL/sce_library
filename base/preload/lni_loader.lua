
local lni = require 'lni'
local mt = {}
local marco = {}

local ignoreSubmodule = {
    ['constant'] = true,
    ['../config'] = true,
    ['mapinfo'] = true,
    ['camera'] = true,
}

local function split(str, p) local rt = {} str:gsub('[^'..p..']+', function (w) table.insert(rt, w) end) return rt end
local function trim(str) return str:gsub('^%s*(.-)%s*$', '%1') end
local function table_copy(tbl) local res = {} if tbl then for k, v in pairs(tbl) do res[k] = v end end return res end
local function complie_computed_line(line, env)
    local f, l = line:find('=', 1, true)
    if not f then
        return
    end
    local splitlv = ('%d'):format(env.max_level - 1)
    local k, v = line:sub(1, f-1), line:sub(l+1)
    v = v:gsub([[%'.-%']], function (s)
        return [[_u:get ]] .. s
    end):gsub('%[(.-)%]', function (s)
        local x, y
        local r = split(s, ',')
        if #r == 0 then
            return '[' .. s .. ']'
        elseif #r == 1 then
            x, y = s, s
        elseif #r ~= env.max_level or #r == 2 then
            x, y = r[1], r[#r]
        else
            return '({'..s..'})[_l*'..splitlv..'+1]'
        end
        return '(('..x..') + (('..y..') - ('..x..')) * _l)'
    end)
    if env.max_level <= 1 then
        return trim(k), 'local _l,_u=...;_l=0;return('..v..')'
    end
    return trim(k), 'local _l,_u=...;_l=(_l-1)/'..splitlv..';return('..v..')'
end
local function complie_computed(code, skl)
    local computed = {}
    for _, l in ipairs(split(code, '\n')) do
        local k, v = complie_computed_line(trim(l), skl)
        if k then
            computed[k] = v
        end
    end
    return computed
end
local function initialize_table(r)
    local mt = {}
    function mt:__newindex(k, v)
        if k == 'computed' then
            local computed = complie_computed(v, r)
            rawset(self, k, computed)
            return
        end
        rawset(self, k, v)
    end
    setmetatable(r, mt)
    if type(r.computed) == 'string' then
        local computed = r.computed
        r.computed = nil
        r.computed = computed
    end
end
--local custom
--local function load_custom(name, loadfile)
--    local filename = 'table/Custom.lua'
--    local buf = loadfile(filename)
--    if not buf then
--        return
--    end
--    print('load Custom.lua success')
--    local env = setmetatable({}, { __index = _ENV })
--    local err
--    local f, err = load(buf, '@'..filename, 't', env)
--    if not f then
--        error('Custom.lua syntax error:\n' .. err)
--    end
--    local suc, res = pcall(f)
--    if not suc then
--        error('Custom.lua runtime error:\n' .. err)
--    end
--    custom = res
--end
function mt:initialize_computed(result)
    for _, r in pairs(result) do
        initialize_table(r)
    end
    setmetatable(result, {
        __newindex = function(self, key, r)
            initialize_table(r)
            rawset(self, key, r)
        end
    })
    return result
end
function mt:normalize(abil)
    local spell = {}
    local max_level = abil.max_level
    if not max_level then
        max_level = 1
        for key, value in pairs(abil) do
            if type(value) == 'table' and type(value[1]) == 'number' then
                if max_level < #value then max_level = #value end
            end
        end
    end
    for key, value in pairs(abil) do
        local t = {}
        if type(value) == 'table' then
            if type(value[1]) ~= 'number' then
                for lvl = 1, max_level do
                    t[lvl] = value
                end
            elseif #value == 1 then
                for lvl = 1, max_level do
                    t[lvl] = value[1]
                end
            elseif #value == max_level then
                for lvl = 1, max_level do
                    t[lvl] = value[lvl]
                end
            elseif max_level > 1 then
                local first = value[1]
                local last = value[#value]
                local dv = (last - first) / (max_level - 1)
                for lvl = 1, max_level do
                    t[lvl] = first + dv * (lvl - 1)
                end
            end
        else
            for lvl = 1, max_level do
                t[lvl] = value
            end
        end
        spell[key] = t
    end
    spell.level = {}
    spell.max_level = {}
    for lvl = 1, max_level do
        spell.level[lvl] = lvl
        spell.max_level[lvl] = max_level
    end
    spell.computed = table_copy(abil.computed)
    return spell
end
local function load_str(str, unit, kv)
    local _, dump = complie_computed_line('='..str, kv)
    local f, err = load(dump, dump, 't', kv)
    if not f then
        return
    end
    local suc, n = pcall(f, kv.level, unit)
    if not suc then
        return
    end
    if math.type(n) == 'float' then
        n = ('%.3f'):format(n):gsub('%.?0*$', '')
    end
    return n
end
function mt:format(str, unit, kv1, kv2)
    if not unit or type(unit) ~= 'table' then
        unit = nil
    else
        function unit:get(name)
            return self[name]
        end
    end
    if marco.custom then
        return marco.custom(self, str, unit, kv1, kv2)
    end
    if kv2 then
        str = str:gsub('%&%{(.-)%}', function(str)
            return load_str(str, unit, kv2)
        end)
    end
    str = str:gsub('%{(.-)%}', function(str)
        return load_str(str, unit, kv1)
    end)
    return str
end

function mt:loader(...)
    return lni(...)
end

local function SDBMHash(str)
    local hash = 0
    for _, b in ipairs {string.byte(str, 1, #str)} do
        hash = b + (hash << 6) + (hash << 16) - hash
    end
    return hash & 0xfffffff
end

local function process_unitdata(units)
    local names = {}
    local used = {}
    for unit_name, data in pairs(units) do
        local id = data.UnitTypeID
        if id == nil then
            names[#names+1] = unit_name
        else
            used[id] = true
        end
    end

    table.sort(names)

    for _, unit_name in ipairs(names) do
        local id = SDBMHash(unit_name)
        if used[id] then
            for i = id+1, id+1000000 do
                if not used[i] then
                    id = i
                    break
                end
            end
        end
        used[id] = true
        units[unit_name].UnitTypeID = id
    end
end

function mt:packager(name, loadfile, current_lib)
    local result = {}
    local libs = {}

    local ok = {}
    current_lib = current_lib or __MAIN_MAP__

    local GLOBAL_DEFAULT = 'global_default'
    -- raw_path like 'abc' or '@lib_1', 'abc' means current_lib/abc, '@lib_1' means ref lib which named lib_1
    local function package(parent_lib, raw_path)
        local lib_name, unique_name, sub_folder_path = to_unique_name(raw_path, parent_lib, '\\/')  -- 将@xxx转换成物理路径
        if libs[GLOBAL_DEFAULT] == nil and lib_name ~= GLOBAL_DEFAULT then
            package('', '@'..GLOBAL_DEFAULT)
        end

        if libs[lib_name] == nil then
            local default = {}
            local enum = {}
            if lib_name ~= GLOBAL_DEFAULT and libs[GLOBAL_DEFAULT] then
                for k, v in pairs(libs[GLOBAL_DEFAULT].default) do
                    default[k] = v
                end
                for k, v in pairs(libs[GLOBAL_DEFAULT].enum) do
                    enum[k] = v
                end
            end

            libs[lib_name] = {default = default, enum = enum}
        end

        local default = libs[lib_name].default
        local enum = libs[lib_name].enum

        unique_name = unique_name .. '/' .. name .. '.ini'
        if ok[unique_name] then
            return
        end

        ok[unique_name] = true
        local filename = sub_folder_path .. '/' .. name..'.ini'
        local content = loadfile(lib_name, filename)
        --log.info(('try load table. libnam:%s, filename: %s, file exists: %d'):format(lib_name, filename, content and 1 or 0))
        if content then
            result, libs[lib_name].default, libs[lib_name].enum = lni(content, unique_name, { result, default, enum})
        end

        if ignoreSubmodule[name:lower()] then
            return
        end
        local config = loadfile(lib_name, sub_folder_path .. '/.iniconfig')
        if config then
            for _, dir in ipairs(split(config, '\n')) do
                dir = dir:gsub('^%s', ''):gsub('%s$', '')
                if dir ~= '' then
                    package(lib_name, sub_folder_path .. '/' .. dir)
                end
            end
        end
    end

    package(current_lib, '')
    if name == 'UnitData' then
        process_unitdata(result)
    end

    return result
end
function mt:set_marco(key, value)
    marco[key] = value
end
return mt