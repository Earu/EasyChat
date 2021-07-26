EC_MODULE_PATH = "easychat/modules/"

local ignore_list = {}
local MODULE_IGNORE_LIST_PATH = "easychat/module_ignore_list.txt"
if file.Exists(MODULE_IGNORE_LIST_PATH, "DATA") then
	local file_contents = file.Read(MODULE_IGNORE_LIST_PATH, "DATA")
	local lines = ("\r?\n"):Explode(file_contents, true)
	for _, line in pairs(lines) do
		line = line:Trim()
		if #line > 0 then
			ignore_list[line] = true
		end
	end
end

local modules = {}

local color_good = Color(0, 160, 220)
local color_bad = Color(255, 127, 127)
local color_default = Color(244, 167, 66)
local module_loaded_count, module_failed_count, module_ignored_count = 0, 0, 0

local function add_module(name, file_name, callback)
	name = isstring(name) and name or file_name
	table.insert(modules, {
		Name = name,
		File = file_name,
		Callback = callback
	})

	module_loaded_count = module_loaded_count + 1
end

local function module_error(file_name, err, where)
	ErrorNoHalt(err .. "\n")
	MsgC(color_default, "[EasyChat | " .. where .. "] ⮞ ", color_bad, "Couldn't load " .. file_name .. "\n")
	module_failed_count = module_failed_count + 1
end

local function module_ignore(file_name, where)
	MsgC(color_default, "[EasyChat | " .. where .. "] ⮞ ", color_default, "Ignored " .. file_name .. "\n")
	module_ignored_count = module_ignored_count + 1
end

local function load_modules(path)
	path = path or EC_MODULE_PATH

	local start_time = SysTime()
	local shared_files = (file.Find(path .. "*.lua", "LUA"))
	for _, file_name in pairs(shared_files) do
		local file_path = path .. file_name
		if not ignore_list[file_path] then
			AddCSLuaFile(file_path)
			local module = CompileFile(file_path)
			local succ, module_name = xpcall(module, function(err)
				module_error(file_name, err, "SH")
			end)

			if succ then
				add_module(module_name, file_name, module)
			end
		else
			module_ignore(file_name, "SH")
		end
	end

	if SERVER then
		local server_files = (file.Find(path .. "server/*.lua", "LUA"))
		for _, file_name in pairs(server_files) do
			local file_path = path .. "server/" .. file_name
			if not ignore_list[file_path] then
				local module = CompileFile(file_path)
				local succ, module_name = xpcall(module, function(err)
					module_error(file_name, err, "SV")
				end)

				if succ then
					add_module(module_name, file_name, module)
				end
			else
				module_ignore(file_name, "SV")
			end
		end

		local client_files = (file.Find(path .. "client/*.lua", "LUA"))
		for _, file_name in pairs(client_files) do
			local file_path = path .. "client/" .. file_name
			if not ignore_list[file_path] then
				AddCSLuaFile(file_path)
			else
				module_ignore(file_name, "CL")
			end
		end
	end

	if CLIENT then
		local client_files = (file.Find(path .. "client/*.lua", "LUA"))
		for _, file_name in pairs(client_files) do
			local module = CompileFile(path .. "client/" .. file_name)
			local succ, module_name = xpcall(module, function(err)
				module_error(file_name, err, "CL")
			end)

			if succ then
				add_module(module_name, file_name, module)
			end
		end
	end

	MsgC(color_default, "[EasyChat] ⮞ ", color_good, ("Loaded %d modules successfully, %d ignored, %d failed to load.\n"):format(module_loaded_count, module_ignored_count, module_failed_count))
	MsgC(color_default, "[EasyChat] ⮞ ", color_good, ("Initialized in %fs\n"):format(SysTime() - start_time))
	module_loaded_count, module_failed_count, module_ignored_count = 0, 0, 0
end

local function get_modules()
	return modules
end

return load_modules, get_modules
