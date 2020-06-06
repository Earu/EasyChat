local EC_LEGACY_ENTRY = GetConVar("easychat_legacy_entry")
local can_use_cef = EasyChat.CanUseCEFFeatures()
local use_new_text_entry = (EC_LEGACY_ENTRY and not EC_LEGACY_ENTRY:GetBool()) or not EC_LEGACY_ENTRY

if not can_use_cef or not use_new_text_entry then
	local function utf8_reverse(str)
		local ret = ""
		for _, code in utf8.codes(str) do
			ret = utf8.char(code) .. ret
		end
		return ret
	end

	local function utf8_caret_pos(str, pos)
		if pos == 0 then return pos end

		local i = 0
		for cur, code in utf8.codes(str) do
			i = i + 1
			if i >= pos then
				return cur + utf8.char(code):len()
			end
		end
	end

	EasyChat.RegisterCTRLShortcut(KEY_BACKSPACE, function(_, fullStr, pos)
		local str = fullStr:sub(1, math.max(0, utf8_caret_pos(fullStr, pos) - 1))
		local strEnd = fullStr:sub(utf8_caret_pos(fullStr, pos) or fullStr:len()) -- what easychat gives us is incorrect

		local chunk = utf8_reverse(str)
		local offset = 0
		local in_spaces = false
		for cur_pos, code in utf8.codes(chunk) do
			local char = utf8.char(code)
			if char:match("%p") then
				if cur_pos == 1 then
					offset = offset + 1
				end
				break
			elseif char:match("%s") then
				if cur_pos == 1 then
					in_spaces = true
				end
				if not in_spaces then
					break
				end
				offset = offset + 1
			else
				if in_spaces then break end
				offset = offset + char:len()
			end
		end
		local keep = utf8.offset(chunk, offset)
		chunk = keep and chunk:sub(keep) or "" -- last word
		chunk = utf8_reverse(chunk)

		return chunk .. strEnd, utf8.len(chunk)
	end)

	EasyChat.RegisterCTRLShortcut(KEY_DELETE, function(_, fullStr, pos)
		local str = fullStr:sub(1, math.max(0, utf8_caret_pos(fullStr, pos) - 1))
		local strEnd = fullStr:sub(utf8_caret_pos(fullStr, pos) or fullStr:len()) -- what easychat gives us is incorrect

		local chunk = strEnd
		local offset = 0
		local in_spaces = false
		for cur_pos, code in utf8.codes(chunk) do
			local char = utf8.char(code)
			if char:match("%p") then
				if cur_pos == 1 then
					offset = offset + 1
				end
				break
			elseif char:match("%s") then
				if cur_pos == 1 then
					in_spaces = true
				end
				if not in_spaces then
					break
				end
				offset = offset + 1
			else
				if in_spaces then break end
				offset = offset + 1
			end
		end
		local keep = utf8.offset(chunk, offset)
		chunk = keep and chunk:sub(keep) or "" -- last word

		return str .. chunk, pos
	end)
end
