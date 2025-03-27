
base.wx = { }

local apis = {}

-- 实现一个给 wx 调用的接口
function base.wx.api(name, func)
    apis[name] = function(json)
        local args = base.json.decode(json)
        local result = {func(table.unpack(args))}
        return base.json.encode(result)
    end
end

base.wx.on_api = setmetatable({}, {
    __index = function(self, name)
        if not apis[name] then
            log.warn(('提供给微信的接口 %s 尚未实现!'):format(name))
        else
            return apis[name]
        end
    end
})

local events = {}

-- 注册微信发送过来的事件
function base.wx.register(name, func)
    if not events[name] then events[name] = {} end
    table.insert(events[name], func)
end

base.wx.on_event = setmetatable({}, {
    __index = function(self, name)
        if events[name] then
            return function(json)
                local args = base.json.decode(json)
                for _, handler in ipairs(events[name]) do
                    handler(table.unpack(args))
                end
            end
        end
    end
})

-- 给微信发事件
function base.wx.send_event(name, ...)
    local args = {...}
    js.send_event_to_wx(name, base.json.encode(args))
end

-- 调用微信接口
function base.wx.call(name, ...)
    local args = {...}
    local result = js.call_wx_api(name, base.json.encode(args))
    local ret = base.json.decode(result)
    return table.unpack(ret)
end

local function get_user_info()
    return base.wx.call('get_user_info')
end

local function avatar(url)
    return url:sub(1, -4) .. '64'
end

-- 充值相关
local p_seq = 0
local p_cbs = {}
local function pay(args)
    amount = args.amount
    success = args.success
    failed = args.failed
    p_seq = p_seq + 1
    p_cbs[p_seq] = { success = success, failed = failed }
    log.info(('微信小游戏请求支付, 金额 [%d], 编号 [%d].'):format(amount, p_seq))
    base.wx.call('pay', p_seq, amount)
end

base.wx.register('on_pay_success', function(seq)
    log.info(('微信小游戏支付成功, 编号 [%d].'):format(seq))
    if p_cbs[seq] then p_cbs[seq].success() end
end)

base.wx.register('on_pay_failed', function(seq, error)
    log.warn(('微信小游戏支付失败, 编号 [%d], [%s]'):format(seq, error))
    if p_cbs[seq] then p_cbs[seq].failed(error) end
end)

return {
    get_user_info = get_user_info,
    avatar = avatar,
    pay = pay
}