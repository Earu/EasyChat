local Modules = {}

EasyChat.LoadModules = function()
	local path = "easychat/modules/"
	local pline = "-----------------------------------------------"

	print(pline)

	local propername = function(arg)
		if type(arg) == "string" then
			return arg
		else
			return nil
		end
	end

	for _,file_name in pairs((file.Find(path.."*.lua","LUA"))) do
		AddCSLuaFile(path..file_name)
		local module = CompileFile(path..file_name)
		local succ,err = pcall(module)
		if succ then
			table.insert(Modules,{
				Name = propername(err) and propername(err) or "",
				File = file_name,
				Callback = module,
			})
			print("[ECModule] ⮞ "..(propername(err) and propername(err) or file_name).." mounted")
		else
			print("[ECModule] ⮞ Couldn't mount "..file_name.."\n "..err)
		end
	end

	if SERVER then
		for _,file_name in pairs((file.Find(path.."server/*.lua","LUA"))) do
			local module = CompileFile(path.."server/"..file_name)
			local succ,err = pcall(module)
			if succ then
				table.insert(Modules,{
					Name = propername(err) and propername(err) or "",
					File = file_name,
					Callback = module,
				})
				print("[ECModule] ⮞ "..(propername(err) and propername(err) or file_name).." mounted")
			else
				print("[ECModule] ⮞ Couldn't mount "..file_name.."\n "..err)
			end
		end

		for _,file_name in pairs((file.Find(path.."client/*.lua","LUA"))) do
			AddCSLuaFile(path.."client/"..file_name)
		end
	end

	if CLIENT then
		for _,file_name in pairs((file.Find(path.."client/*.lua","LUA"))) do
			local module = CompileFile(path.."client/"..file_name)
			local succ,err = pcall(module)
			if succ then
				table.insert(Modules,{
					Name = propername(err) and propername(err) or "",
					File = file_name,
					Callback = module,
				})
				print("[ECModule] ⮞ "..(propername(err) and propername(err) or file_name).." mounted")
			else
				print("[ECModule] ⮞ Couldn't mount "..file_name.."\n "..err)
			end
		end
	end

	print(pline)

end

EasyChat.GetModules = function()
    return Modules
end
