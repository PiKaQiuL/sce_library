
local old_encode = require 'base.json_save'
local old_decode = require 'base.json_load'
local new_decode = common.json_decode
if not new_decode then
    log.info('old_decode')
    new_decode = old_decode
end

base.json = {
    decode = function(json_str, save_sort)
        if save_sort then
            return old_decode(json_str, save_sort)
        end
        return new_decode(json_str)
    end,
    encode = function(t, needSort) return common.json_encode and common.json_encode(t, needSort ~= false) or old_encode(t) end
}
