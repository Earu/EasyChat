local EC_GREENTEXT = CreateConVar("easychat_misc_greentext", "1", FCVAR_ARCHIVE, "Makes your text green when using > at the beginning of a message")
EasyChat.RegisterConvar(EC_GREENTEXT, "4chan greentext")

local color_white = color_white
local green_color = Color(0, 255, 0)
hook.Add("OnPlayerChat", "EasyChatModuleGreenText", function(ply, msg, is_team, is_dead, is_local)
	if not EC_GREENTEXT:GetBool() then return end
	local lines = msg:Split("\n")
	local has_green_text = false
	for i, line in ipairs(lines) do
		if line:match("^>") then
			has_green_text = true
			lines[i] = { green_color, line }
		else
			lines[i] = { color_white, line }
		end
	end

	if has_green_text then
		local msg_components = {}
		if is_dead then
			EasyChat.AddDeadTag(msg_components)
		end

		if is_team then
			EasyChat.AddTeamTag(msg_components)
		end

		if is_local then
			EasyChat.AddLocalTag(msg_components)
		end

		EasyChat.AddNameTags(ply, msg_components)

		table.insert(msg_components, ply)
		table.insert(msg_components, color_white)
		table.insert(msg_components, ": ")

		for i, data in ipairs(lines) do
			table.insert(msg_components, data[1])
			table.insert(msg_components, data[2] .. (i == #lines and "" or "\n")) -- add a newline except for the last entry
		end

		chat.AddText(unpack(msg_components))

		return true
	end
end)

return "Greentext"