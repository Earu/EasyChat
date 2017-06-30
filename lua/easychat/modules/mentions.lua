if CLIENT then

    EasyChat.GetMention = function(ply,txt)
        local txt = string.lower(txt)
        local lname = string.lower(LocalPlayer():GetName())
        if string.match(txt,string.PatternSafe(lname)) and IsValid(ply) and ply ~= LocalPlayer() then --Mentions
            chat.AddText(team.GetColor(ply:Team()),ply:GetName(),Color(244, 167, 66),": "..txt)
            if not system.HasFocus() then
                system.FlashWindow()
            end
            return true
        end
    end

    hook.Add("OnPlayerChat","EasyChatModuleMention",EasyChat.GetMention)

end

return "Mentions"
