if EasyChat.ChatHUD and EasyChat.ChatHUD.Frame then
    EasyChat.ChatHUD.Frame:Remove()
end

local ChatHUD = EasyChat.ChatHUD or {}
EasyChat.ChatHUD = ChatHUD

ChatHUD.Arguments       = {}
ChatHUD.DefaultFontSize = 17
ChatHUD.DefaultFont     = "DermaDefault"
ChatHUD.CurrentSize     = ChatHUD.DefaultFontSize
ChatHUD.CurrentFont     = ChatHUD.DefaultFont
ChatHUD.CurrentColor    = Color(255,255,255)
ChatHUD.CurrentWidth    = 550
ChatHUD.MaxHistory      = 100
ChatHUD.TimeToFade      = 16  -- seconds
ChatHUD.FadeTime        = 300 -- frames
ChatHUD.Tags = {}

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

ChatHUD.AddTag = function(name,callback)
    ChatHUD.Tags[name] = callback
end

include("easychat/client/default_tags.lua")


--[[
    STORING ARGS DECLARATIONS
]]--
ParseStoreArgs = function(str)
    local pattern = "<(.-)=(.-)>"
    local parts = string.Explode(pattern,str,true)
    local index = 1
    for tag,content in string.gmatch(str,pattern) do
        StoreArg(parts[index],"string")
        index = index + 1
        if ChatHUD.Tags[tag] then
            local values = string.Explode(",",content)
            ChatHUD.Tags[tag](unpack(values))
            string.gsub(content,".*","")
        end
    end
    StoreArg(parts[#parts],"string")
end

HashString = function(str,max_width)
	local lines = {}
    local str_len = string.len(str)
    local str_start = 1
    local str_end = 1

	while (str_end < str_len) do
		str_end = str_end + 1

		if (surface.GetTextSize(string.sub(str,str_start,str_end)) > max_width) then
			local n = string.sub(str,str_end,str_end)
			local I = 0

			for i = 1, 15 do
				I = i

				if (n ~= " " and n ~= "," and n ~= "." and n ~= "\n") then
					str_end = str_end - 1
					n = string.sub(str,str_end,str_end)
				else
					break
				end
			end

			if (I == 15) then
				str_end = str_end + 14
			end

			local final_str = string.Trim(string.sub(str,str_start,str_end))
			table.insert(lines,final_str)
			str_start = str_end + 1
		end
	end

	table.insert(lines,string.sub(str,str_start,str_end))

    return table.concat(lines,"\n")
end

local in_addtext = false

ChatHUD.AppendText = function(str)
	if not in_addtext and hook.Run("ChatHudAddText",str) == false then return end
    local hashed_string = HashString(str,ChatHUD.CurrentWidth)
	ParseStoreArgs(hashed_string)
end

ChatHUD.InsertColorChange = function(r,g,b,a)
	local color = Color(r,g,b,a)
	if not in_addtext and hook.Run("ChatHudAddText",color) == false then return end
	StoreArg(color,"color")
end

ChatHUD.InsertFontChange = function(font, size)
	if hook.Run("ChatHudAddFont", font) == false then return end
	local size = size or ChatHUD.DefaultFontSize
	StoreArg({Name = font, Size = size},"font")
end

ChatHUD.AppendPlayer = function(ply)
	if not in_addtext and hook.Run("ChatHudAddText",ply) == false then return end
	local nick = ply:Nick()
	local color = team.GetColor(ply:Team())
	StoreArg({Nick = nick, Color = color},"player")
end

ChatHUD.PushMatrix = function(mat)
    if hook.Run("ChatHudAddText","") == false then return end
    StoreArg(mat,"push_matrix")
end

ChatHUD.PopMatrix = function()
    if hook.Run("ChatHudAddText","") == false then return end
    StoreArg("pop_matrix","pop_matrix")
end


ChatHUD.AddTagStop = function(matrixcount)
    ChatHUD.InsertColorChange(255,255,255,255)
    ChatHUD.InsertFontChange(ChatHUD.DefaultFont,ChatHUD.DefaultFontSize)
    for i=1,matrixcount do
        ChatHUD.PopMatrix()
    end
end

ChatHUD.AddText = function(...)
	in_addtext = true
	if hook.Run("ChatHudAddText",...) == false then return end
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
    --ChatHUD.AddTagStop()
	in_addtext = false
end

--[[
    DRAWING DECLARATIONS
]]--
ChatHUD.Fade = function(arg,col)
    local col = col or ChatHUD.CurrentColor
    local bgcol = Color(25,50,100,255)

    arg.TimeToFade = arg.TimeToFade or (RealTime() + ChatHUD.TimeToFade)

    if arg.TimeToFade and arg.TimeToFade <= RealTime() then
        local t = ChatHUD.FadeTime

        arg.__a = arg.__a and math.Clamp(arg.__a - (1/t),0,t) or col.a/t
        arg.__bga = arg.__bga and math.Clamp(arg.__bga - (1/t),0,t) or bgcol.a/t

        col = Color(col.r,col.g,col.b,arg.__a)
        bgcol = Color(bgcol.r,bgcol.g,bgcol.b,arg.__bga)

    end

    return col,bgcol

end

ChatHUD.DrawText = function(txt,x,y,bgcol,col)
    surface.SetTextColor(bgcol)
    surface.SetFont("ChatHUDShadowFont")
    for i = 1,10 do
        surface.SetTextPos(x,y)
        surface.DrawText(txt)
    end
    surface.SetTextColor(col)
    surface.SetFont("ChatHUDFont")
    surface.SetTextPos(x,y)
    surface.DrawText(txt)
    return surface.GetTextSize(txt)
end

ChatHUD.DrawStringArg = function(arg,x,y)
    local lines = string.Explode("\n",arg.Arg)
    local w = 0
    local col,bgcol = ChatHUD.Fade(arg)
    local y = y
    for num,line in pairs(lines) do
        if num > 1 then
            x = 1
            y = y + ChatHUD.CurrentSize
        end
        w,_ = ChatHUD.DrawText(line,x,y,bgcol,col)
    end
    return x + w,y
end

ChatHUD.DrawPlayerArg = function(arg,x,y)
    local col,bgcol = ChatHUD.Fade(arg)
    local w,_ = ChatHUD.DrawText(arg.Arg.Nick,x,y,bgcol,col)

    return x + w,y
end

ChatHUD.Draw = function(self,w,h)
    if hook.Run("ChatHudDraw", self, w, h) == false then return end
    ChatHUD.CurrentWidth = w
    local x,y = 1,0
    surface.DisableClipping(true)
    for _,arg in ipairs(ChatHUD.Arguments) do
        if arg.Type == "color" then
            ChatHUD.CurrentColor = arg.Arg
        elseif arg.Type == "string" then
            x,y = ChatHUD.DrawStringArg(arg,x,y)
        elseif arg.Type == "player" then
            ChatHUD.CurrentColor = arg.Arg.Color
            x,y = ChatHUD.DrawPlayerArg(arg,x,y)
        elseif arg.Type == "font" then
            UpdateFont(arg.Arg.Name,arg.Arg.Size)
        elseif arg.Type == "image" then
        elseif arg.Type == "matrix" then
            cam.PushModelMatrix(arg.Arg)
        end
    end
    surface.DisableClipping(false)
end

ChatHUD.Init = function()
    ChatHUD.Frame = vgui.Create("DPanel")
    ChatHUD.Frame:SetPos(25,ScrH() - 400)
    ChatHUD.Frame:SetSize(550,320)
    ChatHUD.Frame.Paint = ChatHUD.Draw
end

if me then
   ChatHUD.Init()
end