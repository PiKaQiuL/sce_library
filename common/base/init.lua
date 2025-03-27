require 'base.log'
log_file.debug("==== client base script load start ====")
-- log.debug(debug.traceback())

local path_map = {}

--local clocks = {}
local callback_count = 0
local os_clock = os.clock
local function safe_callback(name)
    return setmetatable(
        {},
        {
            __newindex = function(self, k, v)
                rawset(
                    self,
                    k,
                    function(...)
                        --local start = os_clock()
                        local suc, res = xpcall(v, base.error, ...)
                        if k ~= "on_update" and k ~= "on_post_update" then
                            --local finish = os_clock()
                            --clocks[#clocks + 1] = finish - start
                            callback_count = callback_count + 1
                        end
                        if suc then
                            return res
                        end
                    end
                )
            end
        }
    )
end

_G.base = _G.base or {}
base.test = {}
base.error = log.error

base.error_pending_kill = base.error_pending_kill or {}
local error_pending_kill = base.error_pending_kill
if base.test then
    base.test.path_map = path_map
    function base.error(err,...)
        -- log_file.info('enters base.error')
        if err == error_pending_kill then
            return
        end
        log.error(err, ...)
        if debug_bp then
            debug_bp()
        end
    end
end
base.game = base.game or {}
base.Game = base.game
base.game.lni = require "lni_loader" -- lni_loader implement by c++
_G.game_events = _G.game_events or safe_callback("game_events")
_G.ui_events = _G.ui_events or safe_callback("ui_events")
base.event = _G.game_events

function base.callback_info()
    return {
        --clocks = clocks,
        callback = callback_count
    }
end
base.tsc = require 'base.lualib_bundle'
include "base.utility"
require "base.math"
require "base.vector"
require "base.obj_check"
require "base.event"
require "base.trigger"
require "base.timer"
require "base.json"
require "base.point"
require "base.line"
require "base.collision_flags"
require "base.scene_point"
require "base.position"
include "base.game"
include "base.terrain"
include "base.screen"
include "base.settings"
include "base.shortcut"
require "base.algorithm"
require "base.deque"
require "base.event_deque"
require "base.try"
require "base.exception"
require "base.promise"
require "base.localization"
require "base.area"
require "base.单位组"
require "base.thirdordermatrix" --三阶矩阵类


local platform = require "base.platform"
if not platform.is_app() then
    include "base.table"
    require "base.eff"
    require "base.eff_param"
    require "base.cmd_result"
    require "base.unit"
    require "base.snapshot"
    require "base.response"
    require "base.actor"
    require "base.anim_handlers"
    require "base.player"
    require "base.skill"
    require "base.buff"
    require "base.team"
    require "base.group"
    require "base.force"
    require "base.hashtable"
    require "base.array"
    require "base.table"
    include "base.server"
    include "base.item"
    include "base.select_hero"
    require "base.target_filter"
    require "base.quest"
    require "base.slot"
    require "base.riseletter"
	require "base.behavior"
    require "base.circle"
    require "base.rect"
    require "base.margin"
end


require "base.ui"
include "base.template"
require "base.ad"
require "base.voice"
require "base.select_indicator"
require "base.cheat"

require "base.startup"
require "base.open_url_wrap"

log_file.debug("==== ce load start ====")

--------------old ce require
require "base.p_ui"
include "base.error_info"
include "base.wx"
---------------

if not platform.is_app() then
    require "base.pay"
    require "base.shell"
end
base.game.fff = function()
    error "22222"
end

-- require "base.disconnect"
if __lua_state_name == 'StateGame' then
    require 'base.trigger_editor_v2'
    require_folder 'base.base_lua_plus'
    require 'base.game_result'
end

log_file.debug("==== ac & ce load finish ====")
