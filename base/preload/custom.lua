local function format(n, formater)
	if type(n) == 'number' then
		if formater then
			return ('%' .. formater):format(n)
		else
			return math.tointeger(n) or ('%.1f'):format(n)
		end
	end
	return n
end
local function around_number(n)
	return tonumber(('%.4f'):format(n))
end
local function replace_count(count, unit, base, attr, fmt, coe)
	if count == 0 then
		if coe then
			return nil
		end
		return format(base, fmt)
	end
	if count > #attr then
		return nil
	end
	local key = attr[count]
	if coe then
		return attr[key]
	end
	if unit then
		return format(unit:get(key) * attr[key], fmt)
	else
		return ('%s*%s'):format(key, attr[key])
	end
end
local function replace_indef(count, unit, base, attr, fmt, coe)
	if coe then
		return nil
	end
	if count > #attr then
		return nil
	end
	if unit then
		local value = 0
		for i = count, #attr do
			if i == 0 then
				value = value + base
			else
				local key = attr[i]
				value = value + unit:get(key) * attr[key]
			end
		end
		return format(value, fmt)
	else
		local strs = {}
		for i = count, #attr do
			if i == 0 then
				if #attr == 0 or base ~= 0 then
					strs[#strs+1] = format(base, fmt)
				end
			else
				local key = attr[i]
				if attr[key] >= 0 then
					if #strs > 0 then
						strs[#strs+1] = '+'
					end
					strs[#strs+1] = ('%s*%s'):format(key, around_number(attr[key]))
				else
					strs[#strs+1] = ('-%s*%s'):format(key, around_number(-attr[key]))
				end
			end
		end
		return table.concat(strs)
	end
end
local function replace_key(key, unit, attr, fmt, coe)
	if not attr[key] then
		return nil
	end
	if coe then
		return attr[key]
	end
	if unit then
		return format(unit:get(key) * attr[key], fmt)
	else
		return ('%s*%s'):format(key, attr[key])
	end
end
local fmter = {}
function fmter:__call(formater)
	local count = 0
	local unit = self.unit
	local data = self.data
	local attr = data.attr
	local base = data.base
	return formater:gsub('%{(.-)%}', function(str)
		local fmt
		local coe
		local pos = str:find ':'
		local key = str
		if pos then
			fmt = str:sub(pos+1)
			key = str:sub(1,pos-1)
		end
		if key:sub(-1) == '*' then
			key = key:sub(1, -2)
			coe = true
		end
		local result
		if key == '' then
			result = replace_count(count, unit, base, attr, fmt, coe)
			if result then
				count = count + 1
			end
		elseif key == '...' then
			result = replace_indef(count, unit, base, attr, fmt, coe)
			if result then
				count = #attr + 1
			end
		else
			result = replace_key(key, unit, attr, fmt, coe)
		end
		return result or ('{%s}'):format(str)
	end)
end
function fmter:__index(key)
	local data = self.data
	if key:sub(-1) == '*' then
		return data.attr[key:sub(1, -2)] or 0
	elseif key == 'unit' then
		return nil
	else
		if not data.attr[key] then
			return 0
		end
		local unit = self.unit
		if unit then
			return unit:get(key) * data.attr[key]
		else
			return self(('{%s}'):format(key))
		end
	end
end
local function unpack_computed(str, unit, level, env)
	local func = assert(load(str, '=(load)', 't', env))
	local attr = {}
	local dummy = {}
	function dummy:get(key)
		if not attr[key] then
			attr[key] = true
			table.insert(attr, key)
		end
		return 0
	end
	local base = func(level, dummy)
	for i = 1, #attr do
		function dummy:get(key)
			if key == attr[i] then
				return 1
			else
				return 0 
			end
		end
		attr[attr[i]] = around_number(func(level, dummy) - base)
	end
	local data = {
		level = level,
		func = func,
		attr = attr,
		base = base,
	}
	return setmetatable({ unit = unit, data = data }, fmter)
end
local function default(self)
    local unit = self.unit
    local data = self.data
    if unit then
        return data.func(data.level, unit)
    else
        return self '{...}'
    end
end
local function dostring(self, str, keyval, sep, unit)
	local computed = keyval.computed
	local level = keyval.level
	local env = setmetatable({}, { __index = function(_, key)
		if computed and computed[key] then
			return unpack_computed(computed[key], unit, level, keyval)
		end
		if keyval[key] then
			local value = keyval[key]
			if type(value) == 'string' then
				value = dostring(self, value, keyval, sep, unit)
			end
			return value
		end
		return _G[key]
	end })
	return str:gsub('%' .. sep .. '(.-)%' .. sep, function(str)
		local pos = str:find ':[%.%d]*%a$'
		local fmt
		if pos then
			fmt = str:sub(pos+1)
			str = str:sub(1, pos-1)
		end
		local value = assert(load('return (' .. str .. ')', '=(load)', 't', env))()
		if type(value) == 'table' then
			value = default(value)
		end
		return format(value, fmt)
	end)
end
return function (self, str, unit, kv1, kv2)
	str = dostring(self, str, kv1, '$', unit)
	if kv2 then
		str = dostring(self, str, kv2, '&', unit)
	end
	return str
end
