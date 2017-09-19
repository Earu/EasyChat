EC_MODULE_PATH = "easychat/modules/"

local modules = {}
local colgood = Color(0,160,220)
local colbad  = Color(255,127,127)
local coldef  = Color(244,167,66)

local IsProperReturn = function(arg)
	if type(arg) == "string" then
		return arg
	else
		return nil
	end
end

local BeautifyName = function(str)
	local str = string.gsub(str,".lua","")
	str = string.SetChar(str,1,string.upper(str[1]))
	return str
end

local AddModule = function(name,filename,callback,where)
	local properfilename = BeautifyName(filename)
	local name = IsProperReturn(name) or properfilename,
	table.insert(modules,{
		Name = name,
		File = properfilename,
		Callback = callback,
	})
	local toprint = IsProperReturn(name) or properfilename
	MsgC(coldef,"[ECModule - "..where.."] ⮞ ",colgood,toprint.." loaded\n")
end

local IssueModule = function(filename,err,where)
	MsgC(coldef,"[ECModule - "..where.."] ⮞ ",colbad,"Couldn't load "..filename.."\n "..err.."\n")
end

local LoadModules = function(path)
	local path    = path or EC_MODULE_PATH
	local pline   = "-----------------------------------------------\n"

	MsgC(coldef,"- EasyChat -\n")
	MsgC(coldef,pline)

	for _,filename in pairs((file.Find(path.."*.lua","LUA"))) do
		AddCSLuaFile(path..filename)
		local module = CompileFile(path..filename)
		local succ,err = pcall(module)
		if succ then
			AddModule(err,filename,module,"SH")
		else
			IssueModule(filename,err,"SH")
		end
	end

	if SERVER then
		for _,filename in pairs((file.Find(path.."server/*.lua","LUA"))) do
			local module = CompileFile(path.."server/"..filename)
			local succ,err = pcall(module)
			if succ then
				AddModule(err,filename,module,"SV")
			else
				IssueModule(filename,err,"SV")
			end
		end

		for _,filename in pairs((file.Find(path.."client/*.lua","LUA"))) do
			AddCSLuaFile(path.."client/"..filename)
		end
	end

	if CLIENT then
		for _,filename in pairs((file.Find(path.."client/*.lua","LUA"))) do
			local module = CompileFile(path.."client/"..filename)
			local succ,err = pcall(module)
			if succ then
				AddModule(err,filename,module,"CL")
			else
				IssueModule(filename,err,"CL")
			end
		end
	end

	MsgC(coldef,pline)

end

local GetModules = function()
    return modules
end

return LoadModules,GetModules