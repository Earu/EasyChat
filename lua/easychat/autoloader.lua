EC_MODULE_PATH = "easychat/modules/"

local modules = {}

local color_good = Color(0, 160, 220)
local color_bad = Color(255, 127, 127)
local color_default = Color(244, 167, 66)
local module_loaded_count, module_failed_count = 0, 0

local function add_module(name, file_name, callback)
	local name = isstring(name) and name or file_name
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

local function load_modules(path)
	local path = path or EC_MODULE_PATH

	local start_time = SysTime()
	for _, file_name in pairs((file.Find(path .. "*.lua", "LUA"))) do
		AddCSLuaFile(path .. file_name)
		local module = CompileFile(path .. file_name)
		local succ, module_name = xpcall(module, function(err)
			module_error(file_name, err, "SH")
		end)

		if succ then
			add_module(module_name, file_name, module)
		end
	end

	if SERVER then
		for _, file_name in pairs((file.Find(path .. "server/*.lua", "LUA"))) do
			local module = CompileFile(path .. "server/" .. file_name)
			local succ, module_name = xpcall(module, function(err)
				module_error(file_name, err, "SV")
			end)

			if succ then
				add_module(module_name, file_name, module)
			end
		end

		for _, file_name in pairs((file.Find(path .. "client/*.lua", "LUA"))) do
			AddCSLuaFile(path .. "client/" .. file_name)
		end
	end

	if CLIENT then
		for _, file_name in pairs((file.Find(path .. "client/*.lua", "LUA"))) do
			local module = CompileFile(path .. "client/" .. file_name)
			local succ, module_name = xpcall(module, function(err)
				module_error(file_name, err, "CL")
			end)

			if succ then
				add_module(module_name, file_name, module)
			end
		end
	end

	MsgC(color_default, "[EasyChat] ⮞ ", color_good, ("Loaded %d modules successfully, %d modules failed to load.\n"):format(module_loaded_count, module_failed_count))
	MsgC(color_default, "[EasyChat] ⮞ ", color_good, ("Initialized in %fs\n"):format(SysTime() - start_time))
	module_loaded_count, module_failed_count = 0, 0
end

local function get_modules()
	return modules
end

return load_modules, get_modules
