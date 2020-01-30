local macro_processor = {
	Macros = {},
	Pattern = "%<([A-Za-z0-9]+)%>",
}

function macro_processor:ProcessPerCharacter(value, str)
	-- we need this for characters, if its ran too early, no changes
	if not ec_markup then return str end

	local mk = ec_markup.Parse(str)
	local new_str = ""
	for _, line in ipairs(mk.Lines) do
		for i, component in ipairs(line.Components) do
			if component.Type == "emote" then
				new_str = new_str .. value .. component:ToString()
			elseif component.Type == "text" then
				local chars = component.Content:Split("")
				for i, char in ipairs(chars) do
					if char ~= " " then
						chars[i] = value .. char
					end
				end

				new_str = new_str .. table.concat(chars)
			elseif component.Type == "stop" and i == #line.Components then
				-- nothing
			else
				new_str = new_str .. component:ToString()
			end
		end
	end

	return new_str
end

function macro_processor:ProcessMacro(macro, str)
	if macro.IsLua then
		macro.Env.MACRO_INPUT = str
		local succ, ret = pcall(macro.Value)
		return succ and ret or str
	end

	if not macro.PerCharacter then
		return macro.Value .. str
	end

	-- per character, but takes consideration for some components
	local previous_end_pos = 1
	local start_pos, _, other_macro_name = str:find(self.Pattern, 1, false)
	if not start_pos then -- no need to waste time on non-existent things
		return self:ProcessPerCharacter(macro.Value, str)
	end

	local new_str = ""
	while start_pos do
		local str_chunk = str:sub(previous_end_pos, start_pos - 1)

		if self.Macros[other_macro_name] then
			new_str = new_str .. self:ProcessPerCharacter(macro.Value, str_chunk)
		else
			new_str = new_str .. str_chunk
		end

		local other_macro_tag = ("<%s>"):format(other_macro_name)
		new_str = new_str .. other_macro_tag

		local pos_offset = other_macro_tag:len()
		previous_end_pos = start_pos + pos_offset
		start_pos, _, other_macro_name = str:find(self.Pattern, start_pos + pos_offset, false)
	end

	-- complete the new string
	local str_chunk = str:sub(previous_end_pos)
	new_str = new_str .. self:ProcessPerCharacter(macro.Value, str_chunk)

	return new_str
end

-- TODO: figure out why the fuck this acts weird when passing macro names that dont exist
function macro_processor:ProcessString(str)
	local start_pos, _, macro_name = str:find(self.Pattern, 1, false)
	while start_pos do
		local macro = self.Macros[macro_name]
		local pos_offset = ("<%s>"):format(macro_name):len()
		if macro then
			local str_chunk = self:ProcessMacro(macro, str:sub(start_pos + pos_offset))
			str = str:sub(1, start_pos - 1) .. str_chunk

			start_pos, _, macro_name = str:find(self.Pattern, start_pos, false)
		else
			start_pos, _, macro_name = str:find(self.Pattern, start_pos + pos_offset, false)
		end
	end

	return str
end

local macro_env = {
	string = true,
	math = true,
	table = true,
	select = true,
	pairs = true,
	ipairs = true,
	next = true,
	type = true,
	ScrW = true,
	ScrH = true,
	Matrix = true,
	HSVToColor = true,
	HSLToColor = true,
	ColorToHSV = true,
	ColorToHSL = true,
	Color = true,
	Vector = true,
	LerpAngle = true,
	LerpVector = true,
	Lerp = true,
	VectorRand = true,
	ColorRand = true,
	AngleRand = true,
	print = true,
	ec_markup = true, -- easychat markup
}

for global_name, _ in pairs(macro_env) do
	macro_env[global_name] = _G[global_name]
end

function macro_processor:CompileLuaMacro(macro)
	macro.Env = table.Copy(macro_env)

	local compiled, func = pcall(CompileString, macro.Value, "easychat_macro_processor", false)
	if not compiled then return false end
	if type(func) == "string" then return false end

	setfenv(func, macro.Env)
	macro.Value = func
	return true
end

function macro_processor:IsValidMacro(macro_name, macro)
	if not macro_name then return end
	if not macro then return false end
	if not macro.Value then return false end

	return true
end

function macro_processor:RegisterMacro(macro_name, macro)
	if not self:IsValidMacro(macro_name, macro) then return end

	macro.IsLua = macro.IsLua or false
	if macro.IsLua and not self:CompileLuaMacro(macro) then return end

	self.Macros[macro_name] = macro
end


-- Test macros

macro_processor:RegisterMacro("reee", {
	PerCharacter = false,
	Value = "<translate=rand(-5,5), rand(-5,5)>",
})

macro_processor:RegisterMacro("rainbow", {
	PerCharacter = true,
	Value = "<hsv=rand(0,255)>"
})

macro_processor:RegisterMacro("drop", {
	IsLua = true,
	Value = [[
		-- MACRO_INPUT: string, the input passed to the macro
		-- ^ this does not exclude other macros, tags, whatsoever, youll have to do it yourself

		local chars = MACRO_INPUT:Split("")
		for i=1, #chars do
			chars[i] = "<stop><translate=0," .. i * 10 .. ">" .. chars[i]
		end

		-- returning here "applies" your changes
		return table.concat(chars)
	]]
})

--SetClipboardText(macro_processor:ProcessString("<drop>hello world"))

return macro_processor