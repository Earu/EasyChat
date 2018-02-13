if hook.GetTable().ChatsoundsUpdated and hook.GetTable().ChatsoundsUpdated.EasyChatModuleChatsoundsDocking then
	chatgui = EasyChat.GUI.ChatBox
end

hook.Add("ChatsoundsUpdated","EasyChatModuleChatsoundsDocking",function()
	chatgui = EasyChat.GUI.ChatBox
end)

hook.Add("ECOpened", "chatsounds_autocomplete", function()
	if hook.GetTable().StartChat then
		local func = hook.GetTable().StartChat.chatsounds_autocomplete
		if func then func() end
	end
end)

cvars.AddChangeCallback("easychat_enable",function(name,old,new)
	if chatsounds then
		if GetConVar(name):GetBool() then
			chatgui = EasyChat.GUI.ChatBox
		else
			chatgui = nil
		end
	end
end)

EasyChat.AddMode("Chatsound",function(text)
	LocalPlayer():ConCommand("saysound "..text)
end)

return "Chatsounds"
