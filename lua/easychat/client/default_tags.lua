local ChatHUD = EasyChat.ChatHUD

ChatHUD.AddTag("color",function(r,g,b)
    local r = r and tonumber(r) or 0
    local g = g and tonumber(g) or 0
    local b = b and tonumber(b) or 0

    ChatHUD.InsertColorChange(r,g,b,255)
end)

ChatHUD.AddTag("font",function(font)
    if not font then return end

    ChatHUD.InsertFontChange(font,ChatHUD.CurrenFonttSize)
end)

ChatHUD.AddTag("size",function(size)
    if not size then return end
    local size = math.Clamp(tonumber(size) * ChatHUD.DefaultFontSize,0.2,5)

    ChatHUD.InsertFontChange(ChatHUD.CurrentFont,size)
end)
