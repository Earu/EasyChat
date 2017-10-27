local TAG = "EasyChatModuleJoinLeave"

if SERVER then

    local EC_JOIN_LEAVE = CreateConVar("easychat_joinleave_msg","1",FCVAR_ARCHIVE,"Enables or disables join/leave messages")

    util.AddNetworkString(TAG)

    gameevent.Listen("player_connect")
    gameevent.Listen("player_disconnect")

    hook.Add("player_connect", TAG, function(data)
        if not EC_JOIN_LEAVE:GetBool() then return end
        net.Start(TAG)
        net.WriteTable(data)
        net.Broadcast()
    end)

    hook.Add("player_disconnect", TAG, function(data)
        if not EC_JOIN_LEAVE:GetBool() then return end
        net.Start(TAG)
        net.WriteTable(data)
        net.Broadcast()
    end)

end

if CLIENT then

    hook.Add("ChatText", TAG, function(_, _, _, mode)
        if mode == "joinleave" then
            return true
        end
    end)

    net.Receive(TAG, function()
        local info = net.ReadTable()
        if not info.reason then
            chat.AddText(Color(127, 255, 127), "⮞ ", Color(200, 200, 200), info.name, Color(175, 175, 175), " (" .. info.networkid .. ") is ", Color(127, 255, 127), "joining")
        else
            chat.AddText(Color(255, 127, 127), "⮞ ", Color(200, 200, 200), info.name, Color(175, 175, 175), " (" .. info.networkid .. ") has ", Color(255, 127, 127), "left", Color(175, 175, 175), " (" .. info.reason .. ")")
        end
    end)

end

return "JoinLeave Notifications"
