--[[
    Optimization
]]--
local ipairs  = _G.ipairs

local stringExplode = string.Explode
local stringGmatch  = string.gmatch
local stringLen     = string.len
local stringSub     = string.sub
local stringGsub    = string.gsub
local stringTrim    = string.Trim

local tableInsert = table.insert
local tableRemove = table.remove
local tableConcat = table.concat

local surfaceDrawText        = surface.DrawText
local surfaceSetTextColor    = surface.SetTextColor
local surfaceSetFont         = surface.SetFont
local surfaceSetTextPos      = surface.SetTextPos
local surfaceCreateFont      = surface.CreateFont
local surfaceGetTextSize     = surface.GetTextSize
local surfaceDisableClipping = surface.DisableClipping

local EC_HUD_TTL = GetConVar("easychat_hud_ttl")

local ChatHUD             = {}
local CHUDArguments       = {}
local CHUDShadowColor     = Color(25,50,100,255)
local CHUDDefaultFontSize = 17
local CHUDDefaultFont     = system.IsWindows() and "Verdana" or "Tahoma"
local CHUDCurrentFontSize = CHUDDefaultFontSize
local CHUDCurrentFont     = CHUDDefaultFont
local CHUDCurrentColor    = Color(255,255,255)
local CHUDCurrentWidth    = 550
local CHUDCurrentOffset   = 0
local CHUDMaxArgs         = 140
local CHUDTimeToFade      = EC_HUD_TTL:GetInt()
local CHUDFadeTime        = 2
local CHUDTags            = {}
local CHUDFonts           = {}

cvars.AddChangeCallback("easychat_hud_ttl",function(_,_,new)
    CHUDTimeToFade = new
end)
--[[
    !Optimization
]]--

--this is for possible use in tags
ChatHUD.CurrentFontSize = CHUDCurrentFontSize
ChatHUD.CurrentFont     = CHUDCurrentFont
ChatHUD.CurrentColor    = CHUDCurrentColor
ChatHUD.DefaultFont     = CHUDDefaultFont
ChatHUD.DefaultFontSize = CHUDDefaultFontSize

local UpdateFont = function(fontname,size)
    if not CHUDFonts[fontname..size] then
        CHUDFonts[fontname..size] = true
        surfaceCreateFont("ECCHUD_"..fontname.."_"..size,{
            font      = fontname,
            extended  = true,
            size      = size,
            weight    = 600,
        })
        surfaceCreateFont("ECCHUD_SHADOW_"..fontname.."_"..size,{
            font      = fontname,
            extended  = true,
            size      = size,
            weight    = 600,
            blursize  = 2,
        })
    end
    CHUDCurrentFont= fontname
    CHUDCurrentFontSize = size
end

local GetFontNames = function(fontname,size)
    local font   = "ECCHUD_"..fontname.."_"..size
    local shadow = "ECCHUD_SHADOW_"..fontname.."_"..size

    return font,shadow
end

UpdateFont(CHUDDefaultFont,CHUDDefaultFontSize)

local ClearArgs = function()
    local amount = 0
    for k,v in ipairs(CHUDArguments) do
        if v.Type == "STOP" then
            amount = k
            local nxt = CHUDArguments[k+1]
            if not nxt or not nxt.Faded then
                break
            end
        end
    end
    for _ = 1,amount do
        tableRemove(CHUDArguments,1)
    end
end

local GetOffset = function()
    local line = ""
    for _,v in ipairs(CHUDArguments) do
        if v.Type == "string" then
            line = line..v.Arg
        end
    end
    local count = 1
    for _,_ in stringGmatch(line,"\n") do
        count = count + 1
    end
    return count * CHUDDefaultFontSize
end

local StoreArg = function(arg,type)
    tableInsert(CHUDArguments,{ Arg = arg, Type = type, ID = #CHUDArguments})
    if CHUDArguments[1].Faded or #CHUDArguments >= CHUDMaxArgs then
        ClearArgs()
    end
    CHUDCurrentOffset = GetOffset()
end

ChatHUD.AddTag = function(name,callback)
    CHUDTags[name] = callback
end

--[[
    STORING ARGS DECLARATIONS
]]--
local ParseStoreArgs = function(str)
    local pattern = "<(.-)=(.-)>"
    local parts = stringExplode(pattern,str,true)
    local index = 1

    for tag,content in stringGmatch(str,pattern) do
        StoreArg(parts[index],"string")
        index = index + 1
        if CHUDTags[tag] then
            local values = stringExplode(",",content)
            CHUDTags[tag](unpack(values))
            stringGsub(content,".*","")
        end
    end
    StoreArg(parts[#parts],"string")
end

local HashString = function(str,maxwidth)
    if not str then return "" end
	local lines    = {}
    local strlen   = stringLen(str)
    local strstart = 1
    local strend   = 1

	while (strend < strlen) do
		strend = strend + 1
        local width,_ = surfaceGetTextSize(stringSub(str,strstart,strend))

		if width and width > maxwidth then
			local n = stringSub(str,strend,strend)
			local I = 0

			for i = 1, 15 do
				I = i

				if (n ~= " " and n ~= "," and n ~= "." and n ~= "\n") then
					strend = strend - 1
					n = stringSub(str,strend,strend)
				else
					break
				end
			end

			if (I == 15) then
				strend = strend + 14
			end

			local finalstr = stringTrim(stringSub(str,strstart,strend))
			tableInsert(lines,finalstr)
			strstart = strend + 1
		end
	end

	tableInsert(lines,stringSub(str,strstart,strend))

    return tableConcat(lines,"\n")
end

ChatHUD.AppendText = function(str)
	if hook.Run("ChatHudAddText",str) == false then return end
    local hashed_string = HashString(str,CHUDCurrentWidth)
	ParseStoreArgs(hashed_string)
end

ChatHUD.InsertColorChange = function(r,g,b,a)
	local color = Color(r,g,b,a)
	if hook.Run("ChatHudAddText",color) == false then return end
	StoreArg(color,"color")
end

ChatHUD.InsertFontChange = function(font, size)
	if hook.Run("ChatHudAddFont", font) == false then return end
	local size = size or CHUDDefaultFontSize
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
    local col   = col or CHUDCurrentColor
    local bgcol = CHUDShadowColor
    local alfv  = 0

    col.InitAlpha = col.InitAlpha or col.a
    bgcol.InitAlpha = bgcol.InitAlpha or bgcol.a

    arg.FadeStartTime = arg.FadeStartTime or RealTime() + CHUDTimeToFade
    alfv              = 1 - ((RealTime() - arg.FadeStartTime) / CHUDFadeTime)
    alfv              = math.Clamp(alfv,0,1)
    arg.Faded         = alfv <= 0

    col.a = col.InitAlpha * alfv
    bgcol.a = bgcol.InitAlpha * alfv
    return col,bgcol
end

local DrawString = function(txt,x,y,bgcol,col)
    local font,bgfont = GetFontNames(CHUDCurrentFont,CHUDCurrentFontSize)

    surfaceSetTextColor(bgcol)
    surfaceSetFont(bgfont)

    for _ = 1,8 do
        surfaceSetTextPos(x,y)
        surfaceDrawText(txt)
    end

    surfaceSetTextColor(col)
    surfaceSetFont(font)
    surfaceSetTextPos(x,y)
    surfaceDrawText(txt)

    return surfaceGetTextSize(txt)

end

local DrawText = function(arg,x,y)
    local lines = stringExplode("\n",arg.Arg)
    local w = 0
    local col,bgcol = Fade(arg)
    local y = y
    if not col then return x,y end

    for num,line in pairs(lines) do
        if num > 1 then
            x = 1
            y = y + CHUDCurrentFontSize
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

local IsOpened = _G.EasyChat.IsOpened
local Draw = function(self,w,h)
    if hook.Run("ChatHudDraw",self,w,h) == false then return end
    if IsOpened() then return end

    CHUDCurrentWidth = w

    surfaceDisableClipping(true)

    local x,y = 1, -CHUDCurrentOffset
    local matrixcount = 0
    for _,arg in ipairs(CHUDArguments) do
        Fade(arg)
        if arg.Type == "color" then
            CHUDCurrentColor = arg.Arg
        elseif arg.Type == "string" then
            x,y = DrawText(arg,x,y)
        elseif arg.Type == "font" then
            UpdateFont(arg.Arg.Name,arg.Arg.Size)
        elseif arg.Type == "image" then
        elseif arg.Type == "matrix" then
            cam.PushModelMatrix(arg.Arg)
            matrixcount = matrixcount + 1
        elseif arg.Type == "stop" then
            CHUDCurrentColor = Color(255,255,255)
            UpdateFont(CHUDDefaultFont,CHUDDefaultFontSize)
            for i=1,matrixcount do
                cam.PopModelMatrix()
            end
            matrixcount = 0
        end
    end

    surfaceDisableClipping(false)

end

local Think = function(self)
	EasyChat.ChatHUD.DuringShouldDraw = true
	self:SetVisible(hook.Run("HUDShouldDraw","CHudChat") ~= false)
	EasyChat.ChatHUD.DuringShouldDraw = false
end

ChatHUD.Init = function()
    local frame = vgui.Create("DPanel")
    frame:SetPos(25,ScrH() - 150)
    frame:SetSize(550,320)
    frame.Paint = Draw
    frame.Think = Think
    ChatHUD.Frame = frame
end

return ChatHUD