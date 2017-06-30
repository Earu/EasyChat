hook.Add("OnPlayerChat","EasyChatModuleRPTAGS",function(ply,txt)
    local txt = string.lower(txt)
    if string.match(txt,"^[%.|%/|%!]ooc") then
        chat.AddText(Color(125,125,125),"[OOC] ",ply,Color(255,255,255),":"..string.sub(txt,5,string.len(txt)))
        return true
    elseif string.match(txt,"^[%.|%/|%!]advert") then
        chat.AddText(Color(244,167,66),"►---------◄ Advert By "..ply:GetName().." ►---------◄")
        chat.AddText(Color(255,255,255),string.sub(txt,8,string.len(txt)))
        return true
    end
end)

return "RP Commands"