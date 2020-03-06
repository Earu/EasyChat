local EC_GREENTEXT = CreateConVar("easychat_misc_greentext", "1", FCVAR_ARCHIVE, "Makes your text green when using > at the beginning of a message")

hook.Add("OnPlayerChat", "EasyChatModuleGreenText", function(ply, msg, is_team, is_dead, is_local)
	if EC_GREENTEXT:GetBool() and string.match(msg,"^>") then
		local msg_components = {}

		EasyChat.AddNameTags(msg_components)

		if is_team then
			EasyChat.AddTeamTag(msg_components)
		end

		if is_dead then
			EasyChat.AddDeadTag(msg_components)
		end

		if is_local then
			EasyChat.AddLocalTag(msg_components)
		end

		table.insert(msg_components, ply)
		table.insert(msg_components, color_white)
		table.insert(msg_components, ": ")
		table.insert(msg_components, Color(0,255,0))
		table.insert(msg_components, msg)
		chat.AddText(unpack(msg_components))

		return true
	end
end)

return "Greentext"