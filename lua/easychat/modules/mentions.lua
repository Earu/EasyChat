local discordmentions = "EASY_CHAT_DISCORD_MENTIONS"

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

    net.Receive(discordmentions,function()
        local name  = net.ReadString()
        local msg   = net.ReadString()
        local lname = string.lower(LocalPlayer():GetName())

        if not string.match(name,string.PatternSafe(lname)) then
            if string.match(msg,lname) then
                chat.AddText(Color(114,137,218,255), "[Discord] "..name,Color(244, 167, 66),": "..msg)
                if not system.HasFocus() then
                    system.FlashWindow()
                end
            end
        end
    end)

end

if SERVER then
    if discordrelay then
        util.AddNetworkString(discordmentions)

        local networkdiscordmention = function(tbl)
            local name = tbl.author.username
            local msg  = tbl.content
            net.Start(discordmentions)
            net.WriteString(name)
            net.WriteString(msg)
            net.Broadcast()
        end

        hook.Add("DiscordRelayMessage","EasyChatModuleMention",networkdiscordmention)
    end
end