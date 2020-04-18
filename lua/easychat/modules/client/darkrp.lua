if gmod.GetGamemode().Name ~= "DarkRP" then return "DarkRP Compat" end

hook.Add("ECPostInitialized", "EasyChatModuleDarkRP", function()
	local EC_ENABLE = GetConVar("easychat_enable")
	local EC_TIMESTAMPS = GetConVar("easychat_timestamps")
	local EC_TEAMS = GetConVar("easychat_teams")
	local EC_TEAMS_COLOR = GetConVar("easychat_teams_colored")

	-- this is for the best
	function GAMEMODE:OnPlayerChat(ply, msg, is_team, is_dead, prefix, col1, col2)
		local msg_components = {}

		-- I don't trust this gamemode at all.
		local col1 = col1 or color_white
		local col2 = col2 or color_white

		table.insert(msg_components, color_white) -- we don't want previous colors to be used again

		if is_dead then
			EasyChat.AddDeadTag(msg_components)
		end

		EasyChat.AddNameTags(ply, msg_components)

		if prefix then
			if col1 == team.GetColor(ply:Team()) then -- Just prettier
				col1 = color_white
			end

			table.insert(msg_components, col1)
			-- Remove the nick appened, use our own system.
			table.insert(msg_components, (prefix:gsub(ply:Nick():PatternSafe(), "")))
		end

		if IsValid(ply) then
			table.insert(msg_components, ply)
		else
			table.insert(msg_components, Color(110, 247, 177))
			table.insert(msg_components, "???") -- console or weird stuff
		end

		table.insert(msg_components, color_white)
		table.insert(msg_components, ": ")
		table.insert(msg_components, col2)
		table.insert(msg_components, msg)

		chat.AddText(unpack(msg_components))

		return true
	end
end)

return "DarkRP Compat"