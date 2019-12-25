local EC_MENTION = CreateConVar("easychat_mentions","1",FCVAR_ARCHIVE,"Highlights messages containing your name")

local Mention = function(arg,txt)
	if not EC_MENTION:GetBool() then return end
	if not LocalPlayer().Nick then return end
	local str = string.lower(txt)
	local lname = string.lower(string.gsub(LocalPlayer():Nick(),"<.->",""))
	if not string.match(str,"^[%!|%.|%/]") and string.match(str,string.PatternSafe(lname)) then
		if not system.HasFocus() then
			system.FlashWindow()
		end
		EasyChat.FlashTab("Global")
		if type(arg) == "string" then
			if string.TrimLeft(arg) == "" or string.lower(arg) == lname then return end
			chat.AddText(Color(114,137,218),"[Discord] "..arg,Color(255,255,255),": "..txt)
			return false --hide discord message
		else
			if not IsValid(arg) then return end
			if lname == string.lower(string.gsub(arg:Nick(),"<.->","")) then return end
			chat.AddText(arg,Color(255,255,255),": ",Color(244, 167, 66),txt)
			return true -- hide chat message
		end
	end
end

hook.Add("OnPlayerChat","EasyChatModuleMention",Mention)
hook.Add("OnDiscordMessage","EasyChatModuleMention",Mention)

return "Mentions"
