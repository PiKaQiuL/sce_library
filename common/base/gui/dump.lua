
local DUMP = {}

local function dump(var, space, step, filter)
    step = step or 0
    space = space or 0
    local nl = (step == -1 and '' or '\n')
    if step == -1 then
        step = 0
    end
    local prefix_1 = string.rep(' ', space)
    local prefix_2 = string.rep(' ', space + step)
    if type(var) == 'table' then
        if next(var) == nil then
            return '{}'
        end
        local d = var[DUMP]
        if d then
            local dt = type(d)
            if dt == 'string' then
                return d
            else
                return d(var, space, step, filter)
            end
        end
        local out = '{'..nl
        local sorted_keys = {}
        for key, value in pairs(var) do
            table.insert(sorted_keys, key)
        end
        table.sort(sorted_keys)
        for _, key in ipairs(sorted_keys) do
            local value = var[key]
            if filter then
                key, value = filter(key, value)
                if key == nil or value == nil then
                    goto CONTINUE
                end
            end
            local k
            if type(key) == 'number' then
                k = '['..key..']'
            elseif type(key) == 'string' then
                local l, r = string.find(key, '[%w_]+')
                k = (l == 1 and r == #key) and key or "['"..key.."']"
            else
                goto CONTINUE
            end
            local v
            if type(value) == 'string' then
                if string.byte(value, 1) == 64 and string.byte(value, -1) == 64 then -- i18n key @<key>@
                    v = 'get_text(\''..string.sub(value, 2, -2)..'\')'
                else
                    v = '\''..value..'\''
                end
            else
                v = dump(value, space + step, step)
            end
            out = out..prefix_2..k.." = "..v..','..nl
        ::CONTINUE::
        end
        return out..prefix_1..'}'
    end
    if type(var) == 'function' then-- 这种有可能是依赖库里的控件初始化的时候引入的事件，给个空字符串跳过吧
        return '\'\''
    end
    return tostring(var)
end

return {
    DUMP = DUMP,
    dump = dump,
}