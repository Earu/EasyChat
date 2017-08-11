local tag = "EasyChatModuleJoinLeave"

if SERVER then

    util.AddNetworkString(tag)

    gameevent.Listen("player_connect")
    gameevent.Listen("player_disconnect")

    hook.Add("player_connect", tag, function(data)
        net.Start(tag)
        net.WriteTable(data)
        net.Broadcast()
    end)

    hook.Add("player_disconnect", tag, function(data)
        net.Start(tag)
        net.WriteTable(data)
        net.Broadcast()
    end)

end

if CLIENT then

    hook.Add("ChatText", tag, function(_, _, _, mode)
        if mode == "joinleave" then
            return true
        end
    end)

    net.Receive(tag, function()
        local info = net.ReadTable()
        if not info.reason then
            chat.AddText(Color(127, 255, 127), "⮞ ", Color(200, 200, 200), info.name, Color(175, 175, 175), " (" .. info.networkid .. ") is ", Color(127, 255, 127), "joining")
        else
            chat.AddText(Color(255, 127, 127), "⮞ ", Color(200, 200, 200), info.name, Color(175, 175, 175), " (" .. info.networkid .. ") has ", Color(255, 127, 127), "left", Color(175, 175, 175), " (" .. info.reason .. ")")
        end
    end)

end

return "JoinLeave Notifications"
