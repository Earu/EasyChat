local replaces = {
    [".iunno"]     = [[¯\_(ツ)_/¯]],
    [".lenny"]     = [[( ͡° ͜ʖ ͡° )]],
    [".fliptable"] = [[(╯°□°）╯︵ ┻━┻]],
    [".unflip "]   = [[┬─┬ ノ( ゜-゜ノ)]],
}

hook.Add("OnChatTab","EasyChatModuleMisc",function(text)
    local args = string.Explode(" ",text)
    if replaces[args[#args]] then
        args[#args] = replaces[args[#args]]
    end
    return table.concat(args," ",1,#args)
end)

local stored = {}
local store = function(ply,txt)
	if #stored >= 10 then
		table.remove(stored,#stored)
	end
	table.insert(stored,1,{
		Player = ply,
		Content = txt,
	})
end

hook.Add("OnPlayerChat","EasyChatModuleMisc",function(ply,txt)
    if string.match(txt,"^>") then
		chat.AddText(ply,Color(255,255,255),": ",Color(0,255,0),txt)
		return true
	end

    if string.match(txt,"^s%/.+%/.+") then
		local args = string.Explode("/",txt)
		local toreplace
		if not args[2] or not args[3] then return end
		for k,v in pairs(stored) do
			if string.match(v.Content,string.PatternSafe(args[2])) and IsValid(v.Player) then
				toreplace = v
				break
			end
		end
		if toreplace then
			local replaced = string.Replace(toreplace.Content,args[2],args[3])
			if toreplace.Player ~= ply then
				chat.AddText(ply,Color(255,255,255)," thinks ",toreplace.Player,Color(255,255,255)," meant: "..replaced)
			else
				chat.AddText(ply,Color(255,255,255)," meant: "..replaced)
			end
			return true
		end
	else
		store(ply,txt)
	end
end)

return "Misc"
