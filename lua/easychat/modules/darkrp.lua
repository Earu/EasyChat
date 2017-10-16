local netstring = "EASY_CHAT_DARKRP"

if SERVER then
    util.AddNetworkString(netstring)

    local ProperNick = function(ply)
        return string.gsub(ply:Nick(),"<.->","")
    end

    local FindPlyByName = function(name)
        for _,ply in ipairs(player.GetAll()) do
            if string.match(ProperNick(ply),name) do
                return ply
            end
        end
        return nil
    end

    hook.Add("PlayerSay","EasyChatDarkRP",function(ply,txt)
        local str = string.lower(txt)
        if string.match(txt,"^%/") or string.match(txt,"^%/") then
            local parts = string.Explode(" ",txt)
            local cmd = string.gsub(parts[1],"^.","")

            net.Start(netstring)
            net.WriteEntity(ply)
            net.WriteString(cmd)

            if cmd == "pm" then --secure pm and group
                local target = FindPlyByName(parts[2])
                if target then
                    net.WriteString(table.concat(parts," ",3,#parts))
                    net.Send(target)
                end
            elseif cmd == "group" then
                local plys = team.GetPlayers(ply:Team())
                net.WriteString(table.concat(parts," ",2,#parts))
                net.Send(plys)
            else
                net.WriteString(table.concat(parts," ",2,#parts))
                net.Broadcast()
            end

            return ""
        end
    end)
end

if CLIENT then

    local modes = {
        ooc = function(ply,txt)
            chat.AddText(Color(125,125,125),"[OOC] ",ply,Color(255,255,255),": "..txt)
        end,
        ["/"] = modes.ooc, --alias in darkrp
        a = mode.ooc, --another ooc alias
        advert = function(ply,txt)
            chat.AddText(Color(244,167,66),"►---------◄ Advert By "..ply:GetName().." ►---------◄")
            chat.AddText(Color(244,167,66),"⮞⮞ ",Color(255,255,255),txt)
        end,
        y = function(ply,txt)
            chat.AddText(Color(240,125,125),"[Yell] ",ply,Color(255,255,255),": " .. txt)
        end,
        w = function(ply,txt)
            chat.AddText(Color(75,75,240),"[Whisper] ",ply,Color(255,255,255),": " .. txt)
        end,
        me = function(ply,txt)
            chat.AddText(Color(255,255,255),"**" .. ply .. " " .. txt .. "**")
        end,
        broadcast = function(ply,txt)
            chat.AddText(Color(150,20,20),"[Broadcast] ",ply,Color(255,255,255),": " .. txt)
        end,
        pm = function(ply,txt)
            chat.AddText(Color(220,220,60),"[PM] ",ply,Color(255,255,255),": " .. txt)
        end,
        group = function(ply,txt)
            chat.AddText(Color(220,60,220),"[Group] ",ply,Color(255,255,255),": " .. txt)
        end,
    }

    net.Receive(netstring,function()
        local ply = net.ReadEntity()
        local mode = net.ReadString()
        local txt = net.ReadString()

        if modes[mode] then
            modes[mode](ply,txt)
        end
    end)

end