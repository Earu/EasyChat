if EasyChat.ChatHUD and EasyChat.ChatHUD.Frame then
    EasyChat.ChatHUD.Frame:Remove()
end

local ChatHUD = EasyChat.ChatHUD or {}
EasyChat.ChatHUD = ChatHUD

ChatHUD.Arguments = {}
ChatHUD.DefaultFontSize = 17
ChatHUD.DefaultFont = "DermaDefault"
ChatHUD.CurrentSize = ChatHUD.DefaultFontSize
ChatHUD.CurrentFont = ChatHUD.DefaultFont
ChatHUD.CurrentColor = Color(255,255,255)
ChatHUD.CurrentWidth = 527
ChatHUD.MaxHistory = 100
ChatHUD.FadeTime = 16
ChatHUD.FadingTime = 2

surface.CreateFont("ChatHUDFont",{
    font      = ChatHUD.CurrentFont,
    extended  = true,
    size      = ChatHUD.CurrentSize,
    weight    = 600,
})
surface.CreateFont("ChatHUDShadowFont",{
    font      = ChatHUD.CurrentFont,
    extended  = true,
    size      = ChatHUD.CurrentSize,
    weight    = 600,
    blursize  = 2,
})

local UpdateFont = function(fontname,size)
    if fontname == ChatHUD.CurrentFont and ChatHUD.CurrentSize == size then return end
    ChatHUD.CurrentSize = size
    ChatHUD.CurrentFont = fontname
    surface.CreateFont("ChatHUDFont",{
        font      = fontname,
        extended  = true,
        size      = size,
        weight    = 600,
    })
    surface.CreateFont("ChatHUDShadowFont",{
        font      = fontname,
        extended  = true,
        size      = size,
        weight    = 600,
        blursize  = 2,
    })
end

UpdateFont("DermaDefault",ChatHUD.DefaultFontSize)

local StoreArg = function(arg,type)
    table.insert(ChatHUD.Arguments,{ Arg = arg, Type = type, ID = #ChatHUD.Arguments})
    if #ChatHUD.Arguments >= ChatHUD.MaxHistory then
        table.remove(ChatHUD.Arguments,1)
    end
end

local HashString = function(str, max_width)
    local max_width = max_width - 5
    local tbl = string.ToTable(str)
    local lines = {}
    local chars = {}
    local i = 1

    local width = 0
    local width_before_last_space = 0
    local width_of_trailing_space = 0
    local last_space_index = -1
    local prev_char

    while i <= #tbl do
        local c = tbl[i]

        surface.SetFont("ChatHUDFont")
        local char_width,_ = surface.GetTextSize(c)
        local new_width = width + char_width

        if c == "\n" then
            table.insert(lines, table.concat(chars))
            chars = {}

            width = 0
            width_before_last_space = 0
            width_of_trailing_space = 0

            prev_char = nil
            last_space_index = -1
            i = i + 1
        elseif char ~= " " and width > max_width then
            if #chars == 0 then
                i = i + 1
            elseif last_space_index ~= -1 then
                for i = #chars, 1, -1 do
                    if chars[i] == " " then
                        break
                    end
                    table.remove(chars, i)
                end

                width = width_before_last_space
                i = last_space_index
                i = i + 1
            end

            table.insert(lines, table.concat(chars))
            chars = {}

            prev_char = nil
            width = char_width
            width_before_last_space = 0
            width_of_trailing_space = 0
            last_space_index = -1
        else
            if prev_char ~= " " and c == " " then
                width_before_last_space = width
            end

            width = new_width
            prev_char = c

            table.insert(chars, c)

            if c == " " then
                last_space_index = i
            elseif c ~= "\n" then
                width_of_trailing_space = 0
            end

            i = i + 1
        end
    end

    if #chars ~= 0 then
        table.insert(lines, table.concat(chars))
    end

    return table.concat(lines,"\n")
end

local in_addtext = false

ChatHUD.AppendText = function(str)
	if not in_addtext and hook.Run("ChatHudAddText", str) == false then return end
	StoreArg(HashString(str, ChatHUD.CurrentWidth), "string")
end

ChatHUD.InsertColorChange = function(r,g,b,a)
	local color = Color(r,g,b,a)
	if not in_addtext and hook.Run("ChatHudAddText", color) == false then return end
	StoreArg(color, "color")
end

ChatHUD.InsertFontChange = function(font, size)
	if hook.Run("ChatHudAddFont", font) == false then return end
	local size = size or ChatHUD.DefaultFontSize
	StoreArg({Name = font, Size = size}, "font")
end

ChatHUD.AppendPlayer = function(ply)
	if not in_addtext and hook.Run("ChatHudAddText", ply) == false then return end
	local nick = ply:Nick()
	local color = team.GetColor(ply:Team())
	StoreArg({Nick = nick, Color = color}, "player")
end

ChatHUD.AddText = function(...)
	in_addtext = true
	if hook.Run("ChatHudAddText", ...) == false then return end
    local args = {...}
    for _,v in pairs(args) do
        if type(v) == "table" then
            ChatHUD.InsertColorChange(v.r,v.g,v.b,v.a or 255)
        elseif type(v) == "string" then
            ChatHUD.AppendText(v)
        elseif v:IsPlayer() then
            ChatHUD.AppendPlayer(v)
        else
            ChatHUD.AppendText(tostring(v))
        end
    end
    ChatHUD.InsertColorChange(255,255,255,255)
	in_addtext = false
end

local FadeHandle = function(arg,col)
    local col = col or ChatHUD.CurrentColor
    local bgcol = Color(25,50,100,255)
    arg.fade = arg.fade or (RealTime() + ChatHUD.FadeTime)
    if arg.fade and arg.fade <= RealTime() then
        arg.fading = arg.fading and arg.fading or (RealTime() + ChatHUD.FadingTime)
        local a = Lerp(RealTime()/arg.fading,col.a,0)
        local bga = Lerp(RealTime()/arg.fading,bgcol.a,0)
        col = Color(col.r,col.g,col.b,a)
        bgcol = Color(bgcol.r,bgcol.g,bgcol.b,bga)
    end
    return col,bgcol
end

local DrawTextHandle = function(txt,x,y,bgcol,col)
    surface.SetTextColor(bgcol)
    surface.SetFont("ChatHUDShadowFont")
    for i=1,10 do
        surface.SetTextPos(x,y)
        surface.DrawText(txt)
    end
    surface.SetTextColor(col)
    surface.SetFont("ChatHUDFont")
    surface.SetTextPos(x,y)
    surface.DrawText(txt)
    return surface.GetTextSize(txt)
end

local StringHandle = function(arg,x,y)
    local lines = string.Explode("\n",arg.Arg)
    local w = 0
    local col,bgcol = FadeHandle(arg)
    local y = y
    for num,line in pairs(lines) do
        if num > 1 then
            x = 1
            y = y + ChatHUD.CurrentSize
        end
        w,_ = DrawTextHandle(line,x,y,bgcol,col)
    end
    return x + w,y
end

local PlayerHandle = function(arg,x,y)
    local col,bgcol = FadeHandle(arg)
    local w,_ = DrawTextHandle(arg.Arg.Nick,x,y,bgcol,col)

    return x + w,y
end

ChatHUD.Draw = function(self,w,h)
	if hook.Run("ChatHudDraw", self, w, h) == false then return end
    ChatHUD.CurrentWidth = w
    local x,y = 1,0
    for _,arg in ipairs(ChatHUD.Arguments) do
        if arg.Type == "color" then
            ChatHUD.CurrentColor = arg.Arg
        elseif arg.Type == "string" then
            x,y = StringHandle(arg,x,y)
        elseif arg.Type == "player" then
            ChatHUD.CurrentColor = arg.Arg.Color
            x,y = PlayerHandle(arg,x,y)
        elseif arg.Type == "font" then
            UpdateFont(arg.Arg.Name,arg.Arg.Size)
        elseif arg.Type == "image" then
        end
    end
end

ChatHUD.Init = function()
    ChatHUD.Frame = vgui.Create("DPanel")
    ChatHUD.Frame:SetPos(25,ScrH() - 370)
    ChatHUD.Frame:SetSize(527,315)
    ChatHUD.Frame.Paint = ChatHUD.Draw
end

if me then
   ChatHUD.Init()
end
