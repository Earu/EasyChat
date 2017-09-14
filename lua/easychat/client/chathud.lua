if EasyChat.ChatHUD and EasyChat.ChatHUD.Frame then
    EasyChat.ChatHUD.Frame:Remove()
end

--NOW THIS IS PAINFUL

local ChatHUD = EasyChat.ChatHUD or {}
EasyChat.ChatHUD = ChatHUD

ChatHUD.Arguments       = {}
ChatHUD.ShadowColor     = Color(25,50,100,255)
ChatHUD.DefaultFontSize = 17
ChatHUD.DefaultFont     = system.IsWindows() and "Verdana" or "Tahoma"
ChatHUD.CurrentSize     = ChatHUD.DefaultFontSize
ChatHUD.CurrentFont     = ChatHUD.DefaultFont
ChatHUD.CurrentColor    = Color(255,255,255)
ChatHUD.CurrentWidth    = 550
ChatHUD.CurrentOffSet   = 0
ChatHUD.MaxArguments    = 140
ChatHUD.TimeToFade      = 16
ChatHUD.FadeTime        = 2
ChatHUD.Tags            = {}

local Fonts = {}
local UpdateFont = function(fontname,size)
    if not Fonts[fontname..size] then
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
    ChatHUD.CurrentFont = fontname
    ChatHUD.CurrentSize = size
end

local GetFontNames = function(fontname,size)
    local font   = "ECCHUD_"..fontname.."_"..size
    local shadow = "ECCHUD_SHADOW_"..fontname.."_"..size

    return font,shadow
end

UpdateFont(ChatHUD.DefaultFont,ChatHUD.DefaultFontSize)

local ClearArgs = function()
    local amount = 0
    for k,v in ipairs(ChatHUD.Arguments) do
        if v.Type == "STOP" then
            amount = k
            local nxt = ChatHUD.Arguments[k+1]
            if not nxt or not nxt.Faded then
                break
            end
        end
    end
    for _=1,amount do
        table.remove(ChatHUD.Arguments,1)
    end
end

local GetOffset = function()
    local line = ""
    for _,v in ipairs(ChatHUD.Arguments) do
        if v.Type == "string" then
            line = line..v.Arg
        end
    end
    local count = 1
    for _,_ in string.gmatch(line,"\n") do
        count = count + 1
    end
    return count * ChatHUD.DefaultFontSize
end

local StoreArg = function(arg,type)
    table.insert(ChatHUD.Arguments,{ Arg = arg, Type = type, ID = #ChatHUD.Arguments})
    if ChatHUD.Arguments[1].Faded or #ChatHUD.Arguments >= ChatHUD.MaxArguments then
        ClearArgs()
    end
    ChatHUD.CurrentOffSet = GetOffset()
end

ChatHUD.AddTag = function(name,callback)
    ChatHUD.Tags[name] = callback
end

include("easychat/client/default_tags.lua")


--[[
    STORING ARGS DECLARATIONS
]]--
local ParseStoreArgs = function(str)
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

local HashString = function(str,maxwidth)
    if not str then return "" end
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

ChatHUD.AppendText = function(str)
	if hook.Run("ChatHudAddText",str) == false then return end
    local hashed_string = HashString(str,ChatHUD.CurrentWidth)
	ParseStoreArgs(hashed_string)
end

ChatHUD.InsertColorChange = function(r,g,b,a)
	local color = Color(r,g,b,a)
	if hook.Run("ChatHudAddText",color) == false then return end
	StoreArg(color,"color")
end

ChatHUD.InsertFontChange = function(font, size)
	if hook.Run("ChatHudAddFont", font) == false then return end
	local size = size or ChatHUD.DefaultFontSize
	StoreArg({Name = font, Size = size},"font")
end

ChatHUD.AppendPlayer = function(ply)
	if hook.Run("ChatHudAddText",ply) == false then return end
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

--[[
    DRAWING DECLARATIONS
]]--
local Fade = function(arg,col)
    local col   = col or ChatHUD.CurrentColor
    local bgcol = ChatHUD.ShadowColor
    local alfv  = 0

    col.InitAlpha = col.InitAlpha or col.a
    bgcol.InitAlpha = bgcol.InitAlpha or bgcol.a

    arg.FadeStartTime = arg.FadeStartTime or RealTime() + ChatHUD.TimeToFade
    alfv              = 1 - ((RealTime() - arg.FadeStartTime) / ChatHUD.FadeTime)
    alfv              = math.Clamp(alfv,0,1)
    arg.Faded         = alfv <= 0

    col.a = col.InitAlpha * alfv
    bgcol.a = bgcol.InitAlpha * alfv
    return col,bgcol
end

local DrawString = function(txt,x,y,bgcol,col)
    local font,bgfont = GetFontNames(ChatHUD.CurrentFont,ChatHUD.CurrentSize)

    surface.SetTextColor(bgcol)
    surface.SetFont(bgfont)

    for _ = 1,10 do
        surface.SetTextPos(x,y)
        surface.DrawText(txt)
    end

    surface.SetTextColor(col)
    surface.SetFont(font)
    surface.SetTextPos(x,y)
    surface.DrawText(txt)

    return surface.GetTextSize(txt)

end

local DrawText = function(arg,x,y)
    local lines = string.Explode("\n",arg.Arg)
    local w = 0
    local col,bgcol = Fade(arg)
    local y = y
    if not col then return x,y end

    for num,line in pairs(lines) do
        if num > 1 then
            x = 1
            y = y + ChatHUD.CurrentSize
        end
        w,_ = DrawString(line,x,y,bgcol,col)
    end

    return x + w,y
end

local DrawPlayer = function(arg,x,y)
    local col,bgcol = Fade(arg)
    if not col then return x,y end

    local w,_ = DrawString(arg.Arg.Nick,x,y,bgcol,col)

    return x + w,y
end



local Draw = function(self,w,h)
    if hook.Run("ChatHudDraw",self,w,h) == false then return end
    ChatHUD.CurrentWidth = w

    surface.DisableClipping(true)
    
    local x,y = 1, -ChatHUD.CurrentOffSet
    local matrixcount = 0
    for _,arg in ipairs(ChatHUD.Arguments) do
        Fade(arg)
        if arg.Type == "color" then
            ChatHUD.CurrentColor = arg.Arg
        elseif arg.Type == "string" then
            x,y = DrawText(arg,x,y)
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
    ChatHUD.Frame.Paint = Draw
end

if me then
   ChatHUD.Init()
end