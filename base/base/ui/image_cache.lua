
local co = include 'base.co'
local util = include 'base.util'
local platform = include 'base.platform'
local replace_update_url = require 'update.core.replace_update_url'

local io_download_file = io.download_file
local io_add_resource_path = io.add_resource_path
local io_exist_file = io.exist_file

local img_cache_map = {}
io_add_resource_path('imagecache')

local cache = {}

function cache.test(k, v)
    return k == 'image' and v and v:find('^http') ~= nil
end

local function avatar(url)
    -- if not platform.is_wx() then return url end
    local temp = util.split(url, '/')
    local name = ('imagefromurl' .. temp[#temp - 1] .. temp[#temp])
    name = name:sub(#name - 10)
    if url:find('^https://wx%.qlogo%.cn') ~= nil then
        return url:gsub('%d+$', '64'), name:lower()
    end
    return url, name:lower()
end

function cache.run(ui, k, v, func)
    local name
    v, name = avatar(v)
    log.info('avator name lower', name)
    if img_cache_map[v] then
        local image_name = img_cache_map[v]
        ui[k] = image_name
        func(ui.id, image_name)
    else
        local image_name = name
        co.async(function()
            local download = co.wrap(io_download_file)
            local temp_name = image_name
            local result = download(v, 'imagecache/' .. image_name, function() end, function() end)
            if result ~= 0 then
                log.warn(('下载图片失败, url [%s]'):format(v))
            else
                log.info(('下载图片完成, url [%s], 缓存 [%s].'):format(v, image_name))
                img_cache_map[v] = image_name
                ui[k] = image_name
                func(ui.id, image_name)
            end
        end)
    end
end

-- 检测本地是否已经下载过了
function cache.check_exist_local(path)
    if type(path) ~= 'string' then
        return false
    end
    if io_exist_file(path) then
        return true
    end
    return false
end

local promise_map = {}

-- 这个cache的实现, 在重启时会抛弃本地已下载的文件, TODO
-- 在请求没收到回复前再次调用会再次请求, 即被击穿, (现在改了, 不会击穿了)
function cache.get(url, func, name, use_cache)
    if type(url) ~= 'string' then
        func(1,nil)
        return
    end
    --手机上应该不能用https
    if platform.is_mobile() then
        url=string.gsub(url,"https","http");
    end
    for _, replace in ipairs(replace_update_url) do
        local new_url = replace(url)
        if new_url and new_url ~= url then
            url = new_url
            break
        end
    end
    local url_md5 = common.get_md5(url)
    local temp = util.split(url, '/')
    local last_part = temp[#temp]  --- @type string
    local ext = (last_part:match('%.%w+$') or ''):lower()
    local save_path = io.get_root_dir() .. 'imagecache/' .. url_md5 .. ext
    if use_cache == nil then
        use_cache = true
    end
    -- 本地已经有了 判一下正在下载的
    if use_cache and cache.check_exist_local(save_path) and promise_map[url_md5] == nil then
        log.info('local already exists. save_path:',save_path)
        if not img_cache_map[url_md5] then
            img_cache_map[url_md5] = save_path
        end
        if name and not img_cache_map[name] then
            img_cache_map[name] = save_path
        end
    end

    if img_cache_map[url_md5] then
        if name then
            img_cache_map[name] = save_path
        end
        func(0, img_cache_map[url_md5])
        return
    end

    coroutine.async_next(function()    -- 延迟到下一帧
        if img_cache_map[url_md5] then  -- 再试一次, 万一过了一帧后就有了呢
            if name then
                img_cache_map[name] = save_path
            end
            func(0, img_cache_map[url_md5])
        else  -- 还是没有找到...
            if promise_map[url_md5] then  -- 那看看是不是之前已经开始请求了
                local pro = promise_map[url_md5]
                local ret = pro:co_result()
                func(ret[1], ret[2])
                return  -- 本次请求不是"我"做的, 所以拿到结果后直接离开就行了
            end

            -- 由"我"来创建一次请求
            local pro = coroutine.promise()
            promise_map[url_md5] = pro

            log.info(('cache.get 请求url[%s]'):format(url))
            local code, status = co.call(sce.httplib.request, {
                url = url,
                output = save_path,
            })

            local ret = {}
            if code == 0 and status == 200 then
                -- http下载成功, 写入结果到img_url_map
                img_cache_map[url_md5] = save_path
                if name then
                    img_cache_map[name] = save_path
                end
                ret[1], ret[2] = 0, save_path
                log.debug(("cache.get 成功, url[%s]"):format(url))
            else
                log.warn(('cache.get 失败, url[%s], code[%s] status[%s], save_path[%s]'):format(url, code, status, save_path))
                ret[1], ret[2] = 1, nil
            end

            pro:try_set(ret)  -- 通知其他等待者结果
            promise_map[url_md5] = nil  -- 由"我"清掉promise
            func(ret[1], ret[2])
        end
    end)
end

function cache.get_by_name(name)
    return img_cache_map[name]
end

return cache
