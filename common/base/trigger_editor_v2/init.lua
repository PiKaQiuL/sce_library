base.tsc.CLASSES = {
    Actor = require 'base.actor'.Actor,
    Buff = require 'base.buff'.Buff,
    Coroutine = require 'base.co'.Coroutine,
    Item = require 'base.item'.Item,
    Player = require 'base.player'.Player,
    Point = require 'base.point'.Point,
    ScreenPos = require 'base.position'.ScreenPos,
    Camera = require 'base.camera'.Camera,
    Skill = require 'base.skill'.Skill,
    Team = require 'base.team'.Team,
    Timer = require 'base.timer'.Timer,
    Trigger = require 'base.trigger'.Trigger,
    Unit = require 'base.unit'.Unit,
    Target = require 'base.utility'.Target,
    Quest = require 'base.quest'.Quest,
    QuestCondition = require 'base.quest'.QuestCondition,
    Array = require 'base.trigger_editor_v2.array'.Array,
}

function base.ArrayIterator(array)
    local image = {}
    for i = 1, #array, 1 do
        image[#image+1] = array[i]
    end
    return function(self, index)
        index = index + 1
        local item = image[index + 1]
        if item ~= nil then
            return index, item
        end
    end, array, -1
end

local function __TS__Class2(name)
    local c = {prototype = {}}
    c.prototype.__index = c.prototype
    c.prototype.constructor = c
    c.name = name
    function c.prototype.____constructor(self)
    end
    base.tsc.CLASSES[name] = c
    return c
end

base.tsc.__TS__Class2 = __TS__Class2

local ts_string = base.tsc.__TS__Keyword("string")
local ts_boolean = base.tsc.__TS__Keyword("boolean")
local ts_number = base.tsc.__TS__Keyword("number")

local ts_cast = {
    [ts_string] = function (obj)
        --[[ local o_type = type(obj)
    
        if o_type == 'userdata' or o_type == 'table' then
            if obj.__tostring then
                return tostring(obj)
            end
            return json.encode(obj)
        end ]]
        return tostring(obj)
    end,
    [ts_boolean] = function (obj)
        if obj then
            return true
        end
        return false
    end,
    [ts_number] = function (obj)
        return tonumber(obj)
    end
}

---comment
---@param obj any
---@return any
base.force_as = function(classTbl, obj)
    if ts_cast[classTbl]  then
        return ts_cast[classTbl](obj)
    end
    local obj_type = type(obj)
    -- 临时允许数编节点之间强转
    if type(obj) == 'table' and (obj.NodeType or obj.__component_node) then return obj end
    if type(obj) == 'table' and obj.NodeType then return obj end
    local result = base.tsc.__TS__ForceAs(obj, classTbl)
    if (not result)
    and (not classTbl.typeName) and classTbl.kind == "TypeReference"
    and (obj_type == 'number' or obj_type == 'string' or (obj_type == 'table' and (not obj.typeName)))
    then
        return obj
    end
    return result
end

base.instance_of = function(classTbl, obj)
    return base.tsc.__TS__InstanceOf(obj, classTbl)
end