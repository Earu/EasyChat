EC_MODULE_PATH = "easychat/modules/"

local modules = {}

local color_good = Color(0, 160, 220)
local color_bad = Color(255, 127, 127)
local color_default = Color(244, 167, 66)

local function is_string_return(arg)
	return type(arg) == "string" and arg or nil
end

local function prettify_name(str)
	return str:gsub(".lua", ""):SetChar(1, str[1]:upper())
end

local function add_module(name, file_name, callback, where)
	local pretty_file_name = prettify_name(file_name)
	local name = is_string_return(name) or pretty_file_name
	table.insert(modules, {
		Name = name,
		File = pretty_file_name,
		Callback = callback
	})

	local to_print = is_string_return(name) or pretty_file_name
	MsgC(color_default, "[ECModule - " .. where .. "] ⮞ ", color_good, to_print .. " loaded\n")
end

local function module_error(file_name, err, where)
	MsgC(color_default, "[ECModule - " .. where .. "] ⮞ ", color_bad, "Couldn't load " .. file_name .. "\n " .. err .. "\n")
end

local function load_modules(path)
	local path = path or EC_MODULE_PATH
	local log_separator = "-----------------------------------------------\n"

	MsgC(color_default, "- EasyChat -\n")
	MsgC(color_default, log_separator)

	for _, file_name in pairs((file.Find(path .. "*.lua", "LUA"))) do
		AddCSLuaFile(path .. file_name)
		local module = CompileFile(path .. file_name)
		local succ, err = pcall(module)
		if succ then
			add_module(err, file_name, module, "SH")
		else
			module_error(file_name, err, "SH")
		end
	end

	if SERVER then
		for _, file_name in pairs((file.Find(path .. "server/*.lua", "LUA"))) do
			local module = CompileFile(path .. "server/" .. file_name)
			local succ, err = pcall(module)
			if succ then
				add_module(err, file_name, module, "SV")
			else
				module_error(file_name, err, "SV")
			end
		end

		for _, file_name in pairs((file.Find(path .. "client/*.lua", "LUA"))) do
			AddCSLuaFile(path .. "client/" .. file_name)
		end
	end

	if CLIENT then
		for _, file_name in pairs((file.Find(path .. "client/*.lua", "LUA"))) do
			local module = CompileFile(path .. "client/" .. file_name)
			local succ, err = pcall(module)
			if succ then
				add_module(err, file_name, module, "CL")
			else
				module_error(file_name, err, "CL")
			end
		end
	end

	MsgC(color_default, log_separator)
end

local get_modules = function()
	return modules
end

return load_modules, get_modules
