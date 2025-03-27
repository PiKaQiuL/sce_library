local reduce = require "base.mprofiler_reduce"
local lmprof_print = require "base.mprofiler_ascii_print"

local function hprint(msg, bl)
  local size = string.len(msg)
  local header = "%s %s %s"
  --print('111111',(78 - size)/2)
  local highlight = string.rep('=', math.ceil( (78 - size)/2) )
  local s = string.format(header, highlight, msg, highlight)
  if size%2 ~= 0 then
    s = s .. '='
  end
  return s .. '\n'
end

local function lprint(bl)
  return string.rep("=", 80) .. '\n'
end

---@param prof_type string
---@param prof_filename string
---@param tolog boolean true:打印到log
---@return string|nil
local function mprofiler_text(call_table, prof_type, size)

  if not (prof_type == "flat" or prof_type == "call" or prof_type == "all") then
    prof_type = "all"
  end
  --local call_table = require(prof_filename)
  -- local ok, call_table = pcall(dofile, prof_filename)
  -- if not ok then
  --   print(call_table)
  --   os.exit(1)
  -- end

  size = size or 10

  local func_table = reduce(call_table)


  -- tsize is the max number and tlimit the number of functions to be shown
  local tsize = 0
  local tf = 0
  for k,v in pairs(func_table) do
    tsize = tsize + 1
    if v.mem_perc > 1 then
      tf = tf + 1
    end
  end
  local tlimit = size or (tf > 10 and tf) or (tsize < 10 and tsize) or 10

  -- print header
  local msg = "Showing %d of %d functions that allocated memory"
  msg = string.format(msg, tlimit, tsize)
  local result = '\n' ..
    hprint(msg)
    lprint()

  if prof_type == "all" then
    result = result .. lmprof_print.flat_print(func_table, size) .. '\n' .. lprint() .. lprint() .. '\n' .. lmprof_print.call_graph_print(func_table, size)
  else
    if prof_type == "flat" then
      result = result .. lmprof_print.flat_print(func_table, tlimit) .. lprint()
    elseif prof_type == "call" then
      result = result .. lmprof_print.call_graph_print(func_table, tlimit)
    end
  end

  return result
end

return mprofiler_text
