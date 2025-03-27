
base.proto.__shell = function (info)
    local func, err = load(info.code)
    if func then
        local result, ret = pcall(func)
        base.game:server '__shell' { ret = ret, session = info.session }
    end
end