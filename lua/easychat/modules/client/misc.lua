local replaces = {
	[".iunno"] = [[¯\_(ツ)_/¯]],
	[".lenny"] = [[( ͡° ͜ʖ ͡° )]],
	[".fliptable"] = [[(╯°□°）╯︵ ┻━┻]],
	[".unflip "] = [[┬─┬ ノ( ゜-゜ノ)]]
}

local EC_EMOTES = CreateConVar("easychat_misc_emotes", "1", FCVAR_ARCHIVE, "Should we try to make sense of input when pressing tab")
local EC_GREENTEXT = CreateConVar("easychat_misc_greentext", "1", FCVAR_ARCHIVE, "Makes your text green when using > at the beginning of a message")
local EC_REPLACE = CreateConVar("easychat_misc_replace", "1", FCVAR_ARCHIVE, "Allows quoting replacement with s/x/y")

hook.Add("OnChatTab","EasyChatModuleMisc",function(text)
	if EC_EMOTES:GetBool() then
		local args = string.Explode(" ", text)
		local last_arg = args[#args]
		if replaces[last_arg] then
			args[#args] = replaces[last_arg]
			return table.concat(args, " ", 1, #args)
		end
	end
end)

local stored = {}
local store = function(ply, txt)
	if #stored >= 10 then
		table.remove(stored, #stored)
	end
	table.insert(stored, 1, {
		Player = ply,
		Content = txt
	})
end

hook.Add("OnPlayerChat", "EasyChatModuleMisc", function(ply, txt)
	if EC_GREENTEXT:GetBool() and string.match(txt,"^>") then
		chat.AddText(ply,Color(255,255,255),": ",Color(0,255,0),txt)
		return true
	end

	if EC_REPLACE:GetBool() and string.match(txt, "^s%/.+%/.+") then
		local args = string.Explode("/", txt)
		local toreplace
		if not args[2] or not args[3] then
			return
		end
		for k, v in pairs(stored) do
			if string.match(v.Content, string.PatternSafe(args[2])) and IsValid(v.Player) then
				toreplace = v
				break
			end
		end
		if toreplace then
			local replaced = string.Replace(toreplace.Content, args[2], args[3])
			if toreplace.Player ~= ply then
				chat.AddText(ply, Color(255, 255, 255), " thinks ", toreplace.Player, Color(255, 255, 255), " meant: " .. replaced)
			else
				chat.AddText(ply, Color(255, 255, 255), " meant: " .. replaced)
			end
			return true
		end
	else
		store(ply, txt)
	end
end)

return "Misc"
