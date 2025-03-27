
-- local debug = require 'base.debugger'
-- debug(false)
if __MAIN_MAP__ then
    local endStr = string.sub(__MAIN_MAP__, -3)
    if endStr == '_eq' then
        _G.__GAME_ID__ = string.sub(__MAIN_MAP__, 1, -4)
    else
        _G.__GAME_ID__ = __MAIN_MAP__
    end
end

log_file.info("load @common.main begin..")
require 'base'
require 'json'
include 'base.console'
require 'update'  -- 预先加载update, 因为之后io.write/read会被阉割
require 'uninstall.generate_count'

cmsg_pack.set_max_pack_byte_count(102400)

local platform = require 'base.platform'

if platform.is_web() then
    js.call('onGameLoaded()')
end

local argv = require 'base.argv'
if(argv.get('test') and #argv.get('test') > 0) then
    include ('test.' .. argv.get('test'))
end

local util = require '@base.base.util' -- 从startup迁移到这里
if common.has_arg("unit_test") then
    local s = argv.get("unit_test")
    log_file.info("unit_test:", s)
    local li = util.split(s, ';')

    local unit_test = require("@common.base.example.main")
    log_file.info('local unit_test:', unit_test)
    unit_test(li)
    return
end

require 'isolation'