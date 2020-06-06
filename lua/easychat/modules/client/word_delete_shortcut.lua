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

EasyChat.RegisterCTRLShortcut(KEY_BACKSPACE, function(_, full_str, pos)
	local str = full_str:sub(1, math.max(0, utf8_caret_pos(full_str, pos) - 1))
	local str_end = full_str:sub(utf8_caret_pos(full_str, pos) or full_str:len()) -- what easychat gives us is incorrect

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

	return chunk .. str_end, utf8.len(chunk)
end)

EasyChat.RegisterCTRLShortcut(KEY_DELETE, function(_, full_str, pos)
	local str = full_str:sub(1, math.max(0, utf8_caret_pos(full_str, pos) - 1))
	local str_end = full_str:sub(utf8_caret_pos(full_str, pos) or full_str:len()) -- what easychat gives us is incorrect

	local chunk = str_end
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

return "Keyboard Shortcuts"