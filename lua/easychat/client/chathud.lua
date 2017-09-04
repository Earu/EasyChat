if EasyChat.ChatHUD and EasyChat.ChatHUD.Frame then
    EasyChat.ChatHUD.Frame:Remove()
end

--NOW THIS IS PAINFUL

local ChatHUD = EasyChat.ChatHUD or {}
EasyChat.ChatHUD = ChatHUD

ChatHUD.Arguments       = {}
ChatHUD.ShadowColor     = Color(25,50,100,255)
ChatHUD.DefaultFontSize = 17
ChatHUD.DefaultFont     = "DermaDefault"
ChatHUD.CurrentSize     = ChatHUD.DefaultFontSize
ChatHUD.CurrentFont     = ChatHUD.DefaultFont
ChatHUD.CurrentColor    = Color(255,255,255)
ChatHUD.CurrentWidth    = 550
ChatHUD.MaxArguments    = 50
ChatHUD.TimeToFade      = 16
ChatHUD.FadeTime        = 2
ChatHUD.Tags            = {}
ChatHUD.BiggestFontSize = 0

local Fonts = {}
local UpdateFont = function(fontname,size)
    ChatHUD.CurrentFont = fontname
    ChatHUD.CurrentSize = size

    if not Fonts[fontname..size] then
        if size > ChatHUD.BiggestFontSize then
            ChatHUD.BiggestFontSize = size
        end
        Fonts[fontname..size] = true
        surface.CreateFont("ECCHUD_"..fontname.."_"..size,{
            font      = fontname,
            extended  = true,
            size      = size,
            weight    = 600,
        })
        surface.CreateFont("ECCHUD_SHADOW_"..fontname.."_"..size,{
            font      = fontname,
            extended  = true,
            size      = size,
            weight    = 600,
            blursize  = 2,
        })
    end
end

local GetFontNames = function(fontname,size)
    local font   = "ECCHUD_"..fontname.."_"..size
    local shadow = "ECCHUD_SHADOW_"..fontname.."_"..size

    return font,shadow
end

UpdateFont(ChatHUD.DefaultFont,ChatHUD.DefaultFontSize)

local StoreArg = function(arg,type)
    table.insert(ChatHUD.Arguments,{ Arg = arg, Type = type, ID = #ChatHUD.Arguments})
    if #ChatHUD.Arguments <= ChatHUD.MaxArguments then
        local idtostop = 0
        for k,v in pairs(ChatHUD.Arguments) do
            if v.Arg == "STOP" then
                idtostop = k
                break
            end
        end
        for i=1,idtostop do
            table.remove(ChatHUD.Arguments,i)
        end
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

HashString = function(str,maxwidth)
	local lines    = {}
    local strlen   = string.len(str)
    local strstart = 1
    local strend   = 1

	while (strend < strlen) do
		strend = strend + 1

		if (surface.GetTextSize(string.sub(str,strstart,strend)) > maxwidth) then
			local n = string.sub(str,strend,strend)
			local I = 0

			for i = 1, 15 do
				I = i

				if (n ~= " " and n ~= "," and n ~= "." and n ~= "\n") then
					strend = strend - 1
					n = string.sub(str,strend,strend)
				else
					break
				end
			end

			if (I == 15) then
				strend = strend + 14
			end

			local finalstr = string.Trim(string.sub(str,strstart,strend))
			table.insert(lines,finalstr)
			strstart = strend + 1
		end
	end

	table.insert(lines,string.sub(str,strstart,strend))

    return table.concat(lines,"\n")
end

local inaddtext = false

ChatHUD.AppendText = function(str)
	if not inaddtext and hook.Run("ChatHudAddText",str) == false then return end
    local hashed_string = HashString(str,ChatHUD.CurrentWidth)
	ParseStoreArgs(hashed_string)
end

ChatHUD.InsertColorChange = function(r,g,b,a)
	local color = Color(r,g,b,a)
	if not inaddtext and hook.Run("ChatHudAddText",color) == false then return end
	StoreArg(color,"color")
end

ChatHUD.InsertFontChange = function(font, size)
	if hook.Run("ChatHudAddFont", font) == false then return end
	local size = size or ChatHUD.DefaultFontSize
	StoreArg({Name = font, Size = size},"font")
end

ChatHUD.AppendPlayer = function(ply)
	if not inaddtext and hook.Run("ChatHudAddText",ply) == false then return end
	local nick = ply:Nick()
	local color = team.GetColor(ply:Team())

    ChatHUD.InsertColorChange(color.r,color.g,color.b)
    ChatHUD.AppendText(nick)
end

ChatHUD.AppendMatrix = function(mat)
    if hook.Run("ChatHudAddText","") == false then return end
    StoreArg(mat,"matrix")
end

ChatHUD.AddTagStop = function(matrixcount)
   StoreArg("STOP","STOP")
end

ChatHUD.AddText = function(...)
	inaddtext = true
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

    ChatHUD.AddTagStop()
	inaddtext = false

end

--[[
    DRAWING DECLARATIONS
]]--
ChatHUD.Fade = function(arg,col)
    local col   = col or ChatHUD.CurrentColor
    local bgcol = ChatHUD.ShadowColor
    local alfv  = 0

    if arg.Faded then
        col = Color (col.r, col.g, col.b,0)
        bgcol = Color (bgcol.r, bgcol.g, bgcol.b,0)
        return col,bgcol
    end

    arg.FadeStartTime = arg.FadeStartTime or RealTime() + ChatHUD.TimeToFade
    alfv              = 1 - ((RealTime() - arg.FadeStartTime) / ChatHUD.FadeTime)
    alfv              = math.Clamp(alfv,0,1)
    arg.Faded         = alfv <= 0

    col = Color (col.r, col.g, col.b, col.a * alfv)
    bgcol = Color (bgcol.r, bgcol.g, bgcol.b, bgcol.a * alfv)

    return col,bgcol
end

ChatHUD.DrawText = function(txt,x,y,bgcol,col)
    local font,bgfont = GetFontNames(ChatHUD.CurrentFont,ChatHUD.CurrentSize)

    surface.SetTextColor(bgcol)
    surface.SetFont(bgfont)

    for i = 1,10 do
        surface.SetTextPos(x,y)
        surface.DrawText(txt)
    end

    surface.SetTextColor(col)
    surface.SetFont(font)
    surface.SetTextPos(x,y)
    surface.DrawText(txt)

    return surface.GetTextSize(txt)

end

ChatHUD.DrawStringArg = function(arg,x,y)
    local lines = string.Explode("\n",arg.Arg)
    local w = 0
    local col,bgcol = ChatHUD.Fade(arg)
    local y = y

    if not col then return x,y end

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
    if not col then return x,y end

    local w,_ = ChatHUD.DrawText(arg.Arg.Nick,x,y,bgcol,col)

    return x + w,y
end

ChatHUD.GetCurrentOffSet = function()
    local line = ""
    for k,v in ipairs(ChatHUD.Arguments) do
        if v.Type == "string" then
            line = line..v.Arg
        end
    end
    return #string.Explode("\n",line) * ChatHUD.BiggestFontSize
end


ChatHUD.Draw = function(self,w,h)
    if hook.Run("ChatHudDraw", self, w, h) == false then return end
    ChatHUD.CurrentWidth = w

    surface.DisableClipping(true)

    local x,y = 1, (- ChatHUD.GetCurrentOffSet())
    local matrixcount = 0
    for _,arg in ipairs(ChatHUD.Arguments) do
        if arg.Type == "color" then
            ChatHUD.CurrentColor = arg.Arg
        elseif arg.Type == "string" then
            x,y = ChatHUD.DrawStringArg(arg,x,y)
        elseif arg.Type == "font" then
            UpdateFont(arg.Arg.Name,arg.Arg.Size)
        elseif arg.Type == "image" then
        elseif arg.Type == "matrix" then
            cam.PushModelMatrix(arg.Arg)
            matrixcount = matrixcount + 1
        elseif arg.Type == "stop" then
            ChatHUD.CurrentColor = Color(255,255,255)
            UpdateFont(ChatHUD.DefaultFont,ChatHUD.DefaultFontSize)
            for i=1,matrixcount do
                cam.PopModelMatrix()
            end
            matrixcount = 0
        end
    end

    surface.DisableClipping(false)

end

ChatHUD.Init = function()
    ChatHUD.Frame = vgui.Create("DPanel")
    ChatHUD.Frame:SetPos(25,ScrH() - 150)
    ChatHUD.Frame:SetSize(550,320)
    ChatHUD.Frame.Paint = ChatHUD.Draw
end

if me then
   ChatHUD.Init()
end