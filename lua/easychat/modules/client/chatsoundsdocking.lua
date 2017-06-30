if hook.GetTable().ChatsoundsUpdated and hook.GetTable().ChatsoundsUpdated.EasyChatModuleChatsoundsDocking then
    chatgui = EasyChat.ChatBox
end

hook.Add("ChatsoundsUpdated","EasyChatModuleChatsoundsDocking",function()
    chatgui = EasyChat.ChatBox
end)

cvars.AddChangeCallback("easychat_enable",function(name,old,new)
        if chatsounds then
            if GetConVar(name):GetBool() then
                chatgui = EasyChat.ChatBox
            else
                chatgui = nil
            end
        end
end)

EasyChat.AddMode("Chatsound",function(text)
        LocalPlayer():ConCommand("saysound "..text)
end)

return "Chatsounds"