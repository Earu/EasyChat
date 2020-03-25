local EC_MENTION = CreateConVar("easychat_mentions", "1", FCVAR_ARCHIVE, "Highlights messages containing your name")
local EC_MENTION_FLASH = CreateConVar("easychat_mentions_flash_window", "1", "Flashes your window when you get mentioned")
local EC_MENTION_COLOR = CreateConVar("easychat_mentions_color", "244 167 66", "Color of the mentions")

EasyChat.RegisterConvar(EC_MENTION, "Color messages containing your name")
EasyChat.RegisterConvar(EC_MENTION_FLASH, "Flashes your game when you are mentioned")

local function undecorate_nick(nick)
	if ec_markup then
		return ec_markup.Parse(nick, nil, true):GetText():lower()
	else
		return nick:gsub("<.->", ""):lower()
	end
end

hook.Add("OnPlayerChat", "EasyChatModuleMention", function(ply, msg, is_team, is_dead, is_local)
	if not EC_MENTION:GetBool() then return end

	-- could be run too early
	local lp = LocalPlayer()
	if not IsValid(lp) then return end
	if ply == lp then return end

	msg = msg:lower()
	local undec_nick = undecorate_nick(lp:Nick()):PatternSafe()
	if not msg:match("^[%!%.%/]") and msg:match(undec_nick) then
		if EC_MENTION_FLASH:GetBool() then
			system.FlashWindow()
		end

		EasyChat.FlashTab("Global")

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

		if IsValid(ply) then
			EasyChat.AddNameTags(ply, msg_components)
		end

		table.insert(msg_components, ply)
		table.insert(msg_components, color_white)
		table.insert(msg_components, ": ")

		local r, g, b = EC_MENTION_COLOR:GetString():match("^(%d%d?%d?) (%d%d?%d?) (%d%d?%d?)")
		r = r and tonumber(r) or 244
		g = g and tonumber(g) or 167
		b = b and tonumber(b) or 66

		table.insert(msg_components, Color(r, g, b))
		table.insert(msg_components, msg)
		chat.AddText(unpack(msg_components))

		return true -- hide chat message
	end
end)

return "Mentions"
