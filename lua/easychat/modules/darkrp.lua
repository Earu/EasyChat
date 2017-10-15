local netstring = "EASY_CHAT_DARKRP"

if SERVER then
    util.AddNetworkString(netstring)

    hook.Add("PlayerSay","EasyChatDarkRP",function(ply,txt)
        local str = string.lower(txt)
        if string.match(txt,"^%/ooc") or string.match(txt,"^%/advert") then
            net.Start(netstring)
            net.WriteString(string.gsub(txt,"^.",""))
            net.Broadcast()
            return ""
        end
    end)
end

if CLIENT then
    net.Receive(netstring,function(ply)
        local mode = net.ReadString()
        if mode == "ooc" then
            chat.AddText(Color(125,125,125),"[OOC] ",ply,Color(255,255,255),":"..string.sub(txt,5,string.len(txt)))
        else
            chat.AddText(Color(244,167,66),"►---------◄ Advert By "..ply:GetName().." ►---------◄")
            chat.AddText(Color(244,167,66),"⮞⮞ ",Color(255,255,255),string.upper(string.sub(txt,8,string.len(txt))))
        end
    end)
end