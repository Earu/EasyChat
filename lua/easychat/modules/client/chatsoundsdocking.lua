if hook.GetTable().ChatsoundsUpdated and hook.GetTable().ChatsoundsUpdated.EasyChatModuleChatsoundsDocking then
    chatgui = EasyChat.GUI.ChatBox
end

hook.Add("ChatsoundsUpdated","EasyChatModuleChatsoundsDocking",function()
    chatgui = EasyChat.GUI.ChatBox
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