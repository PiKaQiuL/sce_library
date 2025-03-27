---
--- Generated by EmmyLua(https://github.com/EmmyLua)
--- Created by meiqi.
--- DateTime: 2023/11/15 11:37
---
local message_id = 1

local callback = {}

local function show_message_box(data, cb)
	if __lua_state_name == 'StateEditor' then
		local SCE = ImportSCEContext()
		local content = data.content
		local title = data.title or '提示'
		local btn_text = data.btn_text or '我知道了'
		local show_send_log = data.show_send_log
		if show_send_log == nil then
			show_send_log = true
		end
		local show_close = data.show_close
		if show_close == nil then
			show_close = true
		end
		-- 支持更多的设置项
		if SCE.Common.show_message_box_extra then
			if cb then
				callback[message_id] = cb
				SCE.Common.show_message_box_extra(content, title, btn_text, show_send_log, show_close, message_id)
				message_id = message_id + 1
			else
				SCE.Common.show_message_box_extra(content, title, btn_text, show_send_log, show_close)
			end
		-- 只支持文本内容
		elseif SCE.Common.show_message_box then
			if cb then
				callback[message_id] = cb
				SCE.Common.show_message_box(content, message_id)
				message_id = message_id + 1
			else
				SCE.Common.show_message_box(content)
			end
		else
			local EMessageBox = SCE:GetEMessageBox()
			if EMessageBox then
				EMessageBox:set_font_family("Regular")
				EMessageBox:begin(content..';;'..title)
				if cb then
					cb()
				end
			end
		end
	end
end

_G.message_box = {}
_G.message_box.show = show_message_box
_G.message_box.close_call_back = function(message_id)
	log.info('[message_box] close_call_back',message_id)
	if callback[message_id] then
		callback[message_id]()
		callback[message_id] = nil
	end
end

return show_message_box