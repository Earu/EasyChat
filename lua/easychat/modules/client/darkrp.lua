if gmod.GetGamemode().Name ~= "DarkRP" then return end

hook.Add("ECPostInitialize", "EasyChatModuleDarkRP", function()
	local EC_ENABLE = GetConVar("easychat_enable")
	local EC_TIMESTAMPS = GetConVar("easychat_timestamps")
	local EC_TEAMS = GetConVar("easychat_teams")
	local EC_TEAMS_COLOR = GetConVar("easychat_teams_colored")

	-- this is for the best
	function GAMEMODE:OnPlayerChat(ply, msg, is_team, is_dead, prefix, col1, col2)
		local msg_components = {}

		-- I don't trust this gamemode at all.
		local col1 = col1 or Color(255, 255, 255)
		local col2 = col2 or Color(255, 255, 255)

		table.insert(msg_components, Color(255, 255, 255)) -- we don't want previous colors to be used again

		if EC_ENABLE:GetBool() then
			if IsValid(ply) and EC_TEAMS:GetBool() then
				if EC_TEAMS_COLOR:GetBool() then
					local tcol = team.GetColor(ply:Team())
					table.insert(msg_components, tcol)
				end
				table.insert(msg_components, "[" .. team.GetName(ply:Team()) .. "] - ")
			end
		end

		if is_dead then
			table.insert(msg_components, Color(240, 80, 80))
			table.insert(msg_components, "*DEAD* ")
		end

		if prefix then
			if col1 == team.GetColor(ply:Team()) then -- Just prettier
				col1 = Color(255, 255, 255)
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

		table.insert(msg_components, Color(255, 255, 255))
		table.insert(msg_components, ": ")
		table.insert(msg_components, col2)
		table.insert(msg_components, msg)

		chat.AddText(unpack(msg_components))

		return true
	end
end)