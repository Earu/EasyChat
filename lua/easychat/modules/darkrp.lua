local netstring = "EASY_CHAT_DARKRP"

if SERVER then
    util.AddNetworkString(netstring)

    hook.Add("PlayerSay","EasyChatDarkRP",function(ply,txt)
        local str = string.lower(txt)
        if string.match(txt,"^%/") or string.match(txt,"^%/") then
            local parts = string.Explode(" ",txt)
            local cmd = string.gsub(parts[1],"^.","")

            net.Start(netstring)
            net.WriteEntity(ply)
            net.WriteString(cmd)
            net.WriteString(table.concat(parts," ",2,#parts))
            net.Broadcast()

            return ""
        end
    end)
end

if CLIENT then

    local modes = {
        ooc = function(ply,txt)
            chat.AddText(Color(125,125,125),"[OOC] ",ply,Color(255,255,255),":"..txt)
        end,
        ["/"] = modes.ooc, --alias in darkrp
        advert = function(ply,txt)
            chat.AddText(Color(244,167,66),"►---------◄ Advert By "..ply:GetName().." ►---------◄")
            chat.AddText(Color(244,167,66),"⮞⮞ ",Color(255,255,255),txt)
        end,
        y = function(ply,txt)
            chat.AddText(Color(240,125,125),"[Yell] ",ply,Color(255,255,255),":"..txt)
        end,
        w = function(ply,txt)
            chat.AddText(Color(75,75,240),"[Whisper] ",ply,Color(255,255,255),":"..txt)
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