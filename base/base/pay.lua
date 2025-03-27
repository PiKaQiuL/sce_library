
include "base.ip"
include "@common.base.player"
local lobby = include "base.lobby"
local co = include 'base.co' 
local proto = include '@common.base.pay.proto'
local platform          = require '@common.base.platform'
local argv              = require '@common.base.argv'
local account           = require '@common.base.account'
local sdk = require 'base.sdk'
local api_base = 'https://pay.spark.xd.com/v1/'

base.proto[proto.S2C.NOTIFY_PAY_URL] = function (info)
    log.info(('[支付] 打开支付链接 => [%s]'):format(info.url))
    common.open_url(info.url)
end

base.proto.on_balance_update = function(info) 
    local p = base.local_player()
    if p then
        p:event_notify('balance_update', info)
    end
end

if not pay then pay = {} end
local user_callbacks = {}
local pay_game_id = 'beta'

function resolve(e, ...)
    local cb = user_callbacks[e]
    user_callbacks[e] = nil
    if cb then
        log.info('[pay] resolve', e)
        cb(...)
    else
        --log.error('[pay] not found cb for', e)
    end
end

sdk.on_json('pay','query_restored_purchases','submit_pay', 'check_pay', function(e, val)
    log.info('[pay]', e, val)
    resolve(e, val)
    return
end)

local wait_json_event  = co.wrap(sdk.on_json)

local mt = {}
function set_cb(action, cb)
    if user_callbacks[action] then
        log.error('[pay] aciton pendding', action)
        return false
    end
    log.info('[pay] set callback for', action, cb)
    user_callbacks[action] = cb
    return true
end

function handle_http_response(url, code, status, stream, cb)
    local content = stream:read()
    log.info('[pay][http]', url, code, status, content)
    if code == 0 and content then
        cb(base.json.decode(content), code, status)
    else
        cb(nil, code, status)
    end

    return
end

function get_async(url, cb) 
    log.info('[pay] [http] get', url)
    local outstream = sce.httplib.create_stream()
    local header = account.generate_http_token_sign()
    sce.httplib.request ({ url = url, output = outstream, timeout = 4, header = header}, function(code, status) handle_http_response(url, code, status, outstream, cb) end)
end

function post_async(url, obj, cb)
    log.info('[pay] [http] post', url)
    local outstream = sce.httplib.create_stream()
    local input = sce.httplib.create_stream()
    local raw = base.json.encode(obj.data)
    local header = account.generate_http_token_sign(obj.header)
    --log.info('[pay] [htt] post', url, raw)
    input:write(raw)
    input:feed_eof()
    sce.httplib.request ({ url = url, output = outstream, input = input, content_type = 'application/json', header = header, timeout = 4}, function(code, status_code) handle_http_response(url, code, status_code, outstream, cb) end)
end


local get = co.wrap(get_async)
local post = co.wrap(post_async)

if not base.http then
    base.http = {}
end

base.http.get = get
base.http.post = post

function path_exists(t, ...)
    if not t then return false end
    for _,k in ipairs({...}) do
        if not t or type(t) ~= 'table' or not t[k] then return false end
        t = t[k]
    end

    return true 
end

function is_mainland() 
    return not tostring(_G.IP):find('intl')
end

local function store_name() 
    if argv.has('store_name') then
        return argv.get('store_name')
    end
    return argv.get('game')
end

local function get_package()
    if common.get_package then
        return common.get_package()
    end

    return ''
end

local function alipay(product) 
    if not product then cb() return end
    local user_id = account.latest_login_info.user_id
    local res = get(api_base .. 'create-alipay-wap-order?user_id='..user_id..'&game='..store_name()..'&sku_id='..product.sku_id..'&package='..get_package())
    pay.alipay(res.order)
    local _, res = wait_json_event('pay')
    return res
end

local function wxpay(product) 
    local user_id = account.latest_login_info.user_id
    local res = get(api_base .. 'create-wxpay-app-order?user_id='..user_id..'&game='..store_name()..'&sku_id='..product.sku_id..'&package='..get_package())
    pay.wxpay(res.order)


    local has_result = false
    if res.preorder then 
        -- 查询服务器订单状态
        co.async(function()
            while not has_result do
                co.sleep(1000)
                local res = post(api_base .. 'query-wxpay-app-order-status', { 
                    data = {
                        order_id = res.preorder
                    }
                })
                if res.status ~= 0 then
                    sdk.send_json_event('wx_pay', base.json.encode({
                        result = res.status == 1,
                        msg = res.msg,
                    }))
                end
            end
        end)
    end
    local _, res = wait_json_event('wx_pay')
    has_result = true
    return res
end

function mt.pay_async(product, amount, cb)
    if is_mainland() and not platform.is_ios() then
        cb(wxpay(product))
        return 
    end
    if not product then 
        cb()
        return 
    end
    if not set_cb('pay', cb) then return end
    local roleid = account.latest_login_info.user_id

    local use_tappayment = argv.has('use_tappayment')
    local order_url = api_base .. 'payment-pre-order?user_id='..roleid..'&sku_id=' .. (use_tappayment and product.goodsOpenId or product.sku_id )
    local res = get(order_url)
    if not res then
        resolve('pay', {result = false, debugMessage = 'create order failed'});
        return
    end

    local product_id 
    if platform.is_ios() then
        product_id = product.apple_sku_id
    elseif argv.has('use_tappayment') then
        product_id = base.json.encode(product)
    else
        product_id = product.sku_id
    end

    local name = use_tappayment and product.goodsName or product.sku_name
    local server_id = store_name()
    log.info('[pay] server_id', server_id)
    pay.pay(res.data.order_id, product_id, name, amount, roleid, server_id, res.data.order_id)
end
function mt.query_restored_purchases_async(cb)
    if not set_cb('query_restored_purchases', cb) then return end
    pay.query_restored_purchases()
end

pay.on_appstore_iap_init_response = function(r)
    resolve('iap_init', r)
    return
end

pay.on_appstore_iap_purchase_response = function(r, code, desc, rec, pid, tid, fg, params)
    local package = get_package()
    log.info('[pay]', r, code, desc, rec, pid, tid, fg, params, package, user_callbacks['pay'])
    if  lobby.vm_name() == 'StateApplication' then
        co.async(function()
            if not r then resolve('pay', { result = false, debugMessage = 'iap pay failed', o = nil}); return end
            local roleid = account.latest_login_info.user_id

            if not params or params == '' then
                params = store_name()
            end
            log.info('[pay] params [' .. params .. '] store name', store_name())

            local res, code, status = post(api_base .. 'verify-apple-receipt', {data = {receipt = rec, user_id = roleid, game_server_id = params , package = package}})
            if res and res.result then
                if type(res.finished_transaction) == 'table' then
                    for _, tid in ipairs(res.finished_transaction) do
                        pay.finish_transaction(tid)
                    end
                end
                resolve('pay', {result = true, debugMessage = desc .. ';'..res.msg, o = {success = r, receipt = rec, product_id = pid, transaction_id = tid, foreground = fg}})
            else
                --默认是没请求到,请求到了会有具体信息
                local msg = 'request failed'
                if res and res.msg then
                    msg = res.msg
                end
                common.send_user_stat('verify-receipt-failed', 'curl code:'..tostring(code)..',http status:'..tostring(status)..',msg:'..tostring(msg)..',user_id:'..tostring(roleid)..',receipt:'..tostring(rec))
                resolve('pay', { o = nil, result = false, debugMessage = 'verify-receipt failed'})
            end
            return
        end)
    end
    return
end

function iap_init(ids, cb)
    if not set_cb('iap_init', cb) then return end
    if pay.init(ids) then
        resolve('iap_init', true)
    end
    return
end

function fetch_tappayment_skudetails(ids) 
    if not pay.query_tappayment_products then
        return {}
    end
    pay.query_tappayment_products(base.json.encode(ids))
    local wait_json_event  = co.wrap(sdk.on_json)
    local _, products = wait_json_event('query_tappayment_products')
    return products
end


function fetch_products(cb) 
    if is_mainland() and not platform.is_ios() then
        fetch_products_mainland(function(success, products) 
            if success then
                for k, v in ipairs(products) do
                    v.sku_name = v.name
                    v.price = v.price_rmb
                    v.currency = '元'
                    v.region = 'zh_CN'
                end
            end
            cb(success, products)
        end)
        return
    end
    if not set_cb('init', cb) then cb(false, {}) return end
    local use_tappayment = argv.has('use_tappayment')
    local product_list_indicator = '&game=' .. store_name() .. '&package=' .. get_package()
    local products_url = api_base .. 'payment-items?plateform=IOS&region=HK&currency=HKD'..product_list_indicator
    if use_tappayment then 
        products_url = products_url .. '&isTappayment='..tostring(use_tappayment)
    end
    local res = get(products_url)
    if not res or not res.data then
        resolve('init', false, {})
        return
    end
    local list = res.data
    local ids = {}
    if not use_tappayment then
        for _,item in ipairs(list) do
            if platform.is_ios() then
                item.product_id = item.apple_sku_id
            else
                item.product_id = item.sku_id
            end
            ids[#ids+1] = item.apple_sku_id
        end
    end

    log.info('[pay] products', #list)
    if platform.is_ios() then
        (function()
            local winit = co.wrap(iap_init)
            local iapinited =  winit(ids)
            resolve('init', iapinited, list)
            return
        end)()
    elseif use_tappayment then
        -- 跟ios iap类似，通过从我们后端获取的商品id去sdk后端获取商品详细信息
        local tappayment_products = fetch_tappayment_skudetails(list)
        resolve('init', tappayment_products ~= nil, tappayment_products or {})
    else 
        resolve('init', true, list)
    end
    return
end

function fetch_products_mainland(cb) 
    local res = get(api_base .. 'mainland-products?game='..store_name())
    return cb(res and res.products ~= nil, res and res.products or {})
end

function get_balance(cb)
    if not set_cb('get_balance', cb) then cb() end
    local roleid = account.latest_login_info.user_id
    local res = get(api_base .. 'payment-coin?user_id='..roleid)
    if res then resolve('get_balance', res.remainCoin, res.totalCoin) return  end
    resolve('get_balance', nil)
    return
end

local function game_purchase(server_id, amount, product_id) 
    -- local server_id = __MAIN_MAP__
    local user_id = account.latest_login_info.user_id
    return get(api_base..'payment-coin2game?server_id='..server_id..'&user_id='..user_id..'&amount='..amount..'&production_id='..product_id)
end

local function check_pay(amount, cb)
    if not set_cb('check_pay', cb) then cb() end
    if not pay.check_pay(amount) then resolve('check_pay', false) end
end
local function submit_pay(amount, cb)
    if not set_cb('submit_pay', cb) then cb() end
    if not pay.submit_pay(amount) then resolve('submit_pay', false) end
end

function detect_env() 
   local env = {
       {'e.intl-beta.spark.xd.com',  'beta'},
       --{'e.intl-beta.spark.xd.com',  'beta', 'http://172.27.105.187/v1/'},
       { 'e.intl.spark.xd.com',  'default'},
       {'e.master.sce.xd.com',  'beta'},
       {'e.alpha.sce.xd.com',  'beta'},
       {'e.beta.spark.xd.com',  'beta'},
       {'e.production.spark.xd.com',  'default'},
   }
    api_base = base.calc_http_server_address("pay", 80) .. '/v1/'


   log.info('detect env for', _G.IP)
   for _, tag in ipairs(env) do
       if tag[1] == _G.IP then
           pay_game_id = tag[2]
           --api_base = tag[3]
           log.info('[pay] detect env', pay_game_id, 'api base', api_base)
           break
       end
   end
end

detect_env()

--预先初始化一下
if lobby.vm_name() == 'StateApplication' then
    lobby.register_once("登录", function(error_code)
        
        base.next(function()
            co.async(function()
                fetch_products(function() end)
            end)
        end)
    end) 
    mt.game_purchase = game_purchase
end

lobby.app_lua.pay_async = mt.pay_async

mt.fetch_products = co.wrap(fetch_products)
mt.fetch_products_mainland = co.wrap(fetch_products_mainland)
mt.pay = co.wrap(lobby.app_lua.pay_async)
mt.alipay = alipay
mt.wxpay = wxpay
mt.query_restored_purchases = co.wrap(mt.query_restored_purchases_async)
mt.get_balance = co.wrap(get_balance)

mt.check = co.wrap(check_pay)
mt.submit = co.wrap(submit_pay)

return mt

