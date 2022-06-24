local macro_processor = {
	Macros = {},
	Pattern = "%<([A-Za-z0-9]+)%>",
	Directory = "easychat/macros",
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
				for j, char in ipairs(chars) do
					if char ~= " " then
						chars[j] = value .. char
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
		local succ, ret = pcall(macro.Run)
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
	return new_str .. self:ProcessPerCharacter(macro.Value, str_chunk)
end

-- TODO: figure out why the fuck this acts weird when passing macro names that dont exist
function macro_processor:ProcessString(str)
	local start_pos, _, macro_name = str:find(self.Pattern, 1, false)
	while start_pos do
		local macro = self.Macros[macro_name]
		local pos_offset = ("<%s>"):format(macro_name):len()
		if macro then
			macro.Name = macro_name -- for the hook

			local str_input = str:sub(start_pos + pos_offset)
			local str_chunk = self:ProcessMacro(macro, str_input)
			local ret = EasyChat.SafeHookRun("ECOnProcessMacro", macro, str_input, str_chunk)
			if isstring(ret) then str_chunk = ret end

			if not isstring(str_chunk) then
				ErrorNoHalt(("[EasyChat] > macro [%s] did not have any return value or was not a string\n"):format(macro_name))
				str_chunk = ""
			end

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
	language = true,
}

for global_name, _ in pairs(macro_env) do
	macro_env[global_name] = _G[global_name]
end

function macro_processor:CompileLuaMacro(macro)
	macro.Env = table.Copy(macro_env)

	local func = CompileString(macro.Value, "easychat_macro_processor", false)
	if isstring(func) then return false end

	setfenv(func, macro.Env)
	macro.Run = func
	return true
end

function macro_processor:IsValidMacro(macro_name, macro)
	if not macro_name then return end
	if not macro then return false end
	if not macro.Value then return false end

	return true
end

function macro_processor:RegisterMacro(macro_name, macro)
	if not self:IsValidMacro(macro_name, macro) then return false, "invalid macro" end

	macro.PerCharacter = macro.PerCharacter or false
	macro.IsLua = macro.IsLua or false
	if macro.IsLua and not self:CompileLuaMacro(macro) then return false, "could not compile macro" end

	if not file.Exists(self.Directory, "DATA") then
		file.CreateDir(self.Directory)
	end

	local to_save = util.TableToJSON({
		PerCharacter = macro.PerCharacter,
		IsLua = macro.IsLua,
		Value = macro.Value,
	}, true)
	file.Write(("%s/%s.txt"):format(self.Directory, macro_name), to_save)
	self.Macros[macro_name] = macro

	EasyChat.SafeHookRun("ECMacroRegistered", macro_name, macro)
	return true
end

function macro_processor:DeleteMacro(macro_name)
	local macro_path = ("%s/%s.txt"):format(self.Directory, macro_name)
	if file.Exists(macro_path, "DATA") then
		file.Delete(macro_path)
	end

	self.Macros[macro_name] = nil

	EasyChat.SafeHookRun("ECMacroDeleted", macro_name)
end

function macro_processor:LoadSavedMacros()
	local files = (file.Find(self.Directory .. "/*.txt", "DATA"))
	for _, f in pairs(files) do
		local path = ("%s/%s"):format(self.Directory, f)
		local macro_name = f:Replace(".txt", "")
		local json = file.Read(path, "DATA")

		local macro = util.JSONToTable(json)
		if macro.IsLua and not self:CompileLuaMacro(macro) then return end
		self.Macros[macro_name] = macro
	end
end

macro_processor:LoadSavedMacros()

return macro_processor