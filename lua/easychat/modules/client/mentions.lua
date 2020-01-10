local EC_MENTION = CreateConVar("easychat_mentions", "1", FCVAR_ARCHIVE, "Highlights messages containing your name")

local function undecorate_nick(nick)
	return nick:gsub("<.->", ""):lower()
end

local function mention(ply, txt)
	if not EC_MENTION:GetBool() then return end

	-- could be run too early
	if not LocalPlayer().Nick then return end

	txt = txt:lower()
	local undec_nick = undecorate_nick(LocalPlayer():Nick())
	if not txt:match("^[%!|%.|%/]") and txt:match(undec_nick:PatternSafe()) then
		if not system.HasFocus() then
			system.FlashWindow()
		end

		EasyChat.FlashTab("Global")

		if not IsValid(ply) then return end
		if ply == LocalPlayer() then return end

		chat.AddText(ply, Color(255, 255, 255), ": ", Color(244, 167, 66), txt)
		return true -- hide chat message
	end
end

hook.Add("OnPlayerChat", "EasyChatModuleMention", mention)

return "Mentions"
