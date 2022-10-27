local chathud = EasyChat.ChatHUD
local compile_expression = CLIENT and EasyChat.Expressions.Compile or function() return false end
local pcall = _G.pcall

local surface_SetDrawColor = CLIENT and surface.SetDrawColor
local surface_SetMaterial = CLIENT and surface.SetMaterial
local surface_DrawTexturedRect = CLIENT and surface.DrawTexturedRect
local surface_DrawRect = CLIENT and surface.DrawRect
local surface_DrawLine = CLIENT and surface.DrawLine
local surface_SetAlphaMultiplier = CLIENT and surface.SetAlphaMultiplier
local surface_GetAlphaMultiplier = CLIENT and surface.GetAlphaMultiplier

local draw_NoTexture = CLIENT and draw.NoTexture

local cam_PushModelMatrix = CLIENT and cam.PushModelMatrix
local cam_PopModelMatrix = CLIENT and cam.PopModelMatrix

local math_sin = math.sin
local math_abs = math.abs
local math_max = math.max
local math_min = math.min
local math_clamp = math.Clamp
local math_EaseInOut = math.EaseInOut

local MAX_TEXT_OFFSET = 400
local SMOOTHING_SPEED = 1000
local EC_HUD_SMOOTH = GetConVar("easychat_hud_smooth")
--[[-----------------------------------------------------------------------------
	Color Component

	Color modulation with hexadecimal values.
]]-------------------------------------------------------------------------------
local color_hex_part = {
	Usage = "<c=hexadecimal>",
	Examples = {
		"<c=f00>red text!",
		"<c=00ff00>green text!"
	}
}

function color_hex_part:HexToRGB(hex)
	hex = hex:Replace("#","")

	local function n(input) return tonumber(input) or 255 end

	if #hex == 3 then
		return
			n("0x" .. hex:sub(1, 1)) * 17,
			n("0x" .. hex:sub(2, 2)) * 17,
			n("0x" .. hex:sub(3, 3)) * 17
	else
		return
			n("0x" .. hex:sub(1, 2)),
			n("0x" .. hex:sub(3, 4)),
			n("0x" .. hex:sub(5, 6))
	end
end

function color_hex_part:Ctor(str)
	self:ComputeSize()
	local r, g, b = self:HexToRGB(str)
	self.Color = Color(r, g, b)

	return self
end

function color_hex_part:Draw(ctx)
	ctx:UpdateColor(self.Color)
end

chathud:RegisterPart("c", color_hex_part)

--[[-----------------------------------------------------------------------------
	HSV Component

	Color modulation with HSV values.
]]-------------------------------------------------------------------------------
local hsv_part = {
	OkInNicks = false,
	RunExpression = function() return 360, 1, 1 end,
	Usage = "<hsv=expression> or <hsv=hue,saturation,value>",
	Examples = {
		"<hsv=t()*300>Rainbow text"
	}
}

function hsv_part:Ctor(expr)
	local succ, ret = compile_expression(expr)
	if succ then
		self.RunExpression = ret
	end

	return self
end

function hsv_part:ComputeHSV()
	local succ, h, s, v = pcall(self.RunExpression)

	h = succ and ((tonumber(h) or 360) % 360) or 360
	s = succ and math.Clamp(tonumber(s) or 1, 0, 1) or 1
	v = succ and math.Clamp(tonumber(v) or 1, 0, 1) or 1

	self.Color = HSVToColor(h, s, v)
end

function hsv_part:Draw(ctx)
	self:ComputeHSV()
	ctx:UpdateColor(self.Color)
end

chathud:RegisterPart("hsv", hsv_part)

--[[-----------------------------------------------------------------------------
	BHSV Component

	Color modulation with HSV values on text background.
]]-------------------------------------------------------------------------------
local bhsv_part = {
	OkInNicks = false,
	RunExpression = function() return 360, 1, 1 end,
	Usage = "<bhsv=expression> or <bhsv=hue,saturation,value>",
	Examples = {
		"<bhsv=t()*300>Rainbow background"
	}
}

function bhsv_part:Ctor(expr)
	local succ, ret = compile_expression(expr)
	if succ then
		self.RunExpression = ret
	end

	return self
end

function bhsv_part:ComputeHSV()
	local succ, h, s, v = pcall(self.RunExpression)

	h = succ and ((tonumber(h) or 360) % 360) or 360
	s = succ and math.Clamp(tonumber(s) or 1, 0, 1) or 1
	v = succ and math.Clamp(tonumber(v) or 1, 0, 1) or 1

	self.Color = HSVToColor(h, s, v)
end

function bhsv_part:PreTextDraw(ctx, x, y, w, h)
	self:ComputeHSV()
	self.Color.a = ctx.Alpha

	surface_SetDrawColor(self.Color)
	surface_DrawRect(x, y, w, h)
	surface_SetDrawColor(ctx.Color)
end

function bhsv_part:Draw(ctx)
	ctx:PushPreTextDraw(self)
end

chathud:RegisterPart("bhsv", bhsv_part)

--[[-----------------------------------------------------------------------------
	Flash Component

	Color modulation between 0,0,0 and the input
]]-------------------------------------------------------------------------------
local flash_part = {
	TargetColor = Color(255, 0, 0),
	Color = Color(255, 0, 0),
	Usage = "<flash> or <flash=r,g,b>",
	Examples = {
		"<flash=255,0,0>Red flashing text",
		"<flash=0,255,255>Cyan flashing text",
	}
}

function flash_part:Ctor(str)
	local flash_components = str:Split(",")
	self.TargetColor = Color(
		tonumber(flash_components[1]) or self.TargetColor.r,
		tonumber(flash_components[2]) or self.TargetColor.g,
		tonumber(flash_components[3]) or self.TargetColor.b
	)

	self.Color = Color(self.TargetColor.r, self.TargetColor.g, self.TargetColor.b)

	return self
end

function flash_part:ComputeColor()
	local coef = math_sin(CurTime() * 3)
	self.Color.r = (self.TargetColor.r / 2) + (coef * (self.TargetColor.r / 2))
	self.Color.g = (self.TargetColor.g / 2) + (coef * (self.TargetColor.g / 2))
	self.Color.b = (self.TargetColor.b / 2) + (coef * (self.TargetColor.b / 2))
end

function flash_part:Draw(ctx)
	self:ComputeColor()
	ctx:UpdateColor(self.Color)
end

chathud:RegisterPart("flash", flash_part, "%<(flash)%>")

--[[-----------------------------------------------------------------------------
	Alpha Component

	Alpha modulation.
]]-------------------------------------------------------------------------------
local alpha_part = {
	Alpha = 255,
	Usage = "<flash> or <flash=alpha>",
	OkInNicks = false,
	Examples = {
		"<flash=155>Going half transparent",
		"<flash>Going fully transparent",
	}
}

function alpha_part:Ctor(expr)
	local succ, ret = compile_expression(expr)
	if succ then
		self.RunExpression = ret
	end

	return self
end

function alpha_part:ComputeAlpha()
	local succ, alpha = pcall(self.RunExpression)
	self.Alpha = succ and tonumber(alpha) or 255
end

function alpha_part:PreTextDraw()
	self:ComputeAlpha()
	self.PreviousAlpha = surface_GetAlphaMultiplier()

	surface_SetAlphaMultiplier(self.Alpha / 255)
end

function alpha_part:PostTextDraw()
	surface_SetAlphaMultiplier(self.PreviousAlpha)
end

function alpha_part:Draw(ctx)
	ctx:PushPostTextDraw(self)
	ctx:PushPreTextDraw(self)
end

chathud:RegisterPart("a", alpha_part)

--[[-----------------------------------------------------------------------------
	Horizontal Scan Component

	Horizontal scanning thingy.
]]-------------------------------------------------------------------------------
local hscan_part = {
	Speed = 1,
	ScanColor = Color(9, 155, 234),
	Usage = "<hscan> or <hscan=speed,r,g,b>",
	Examples = {
		"<hscan>normal horizonal scan",
		"<hscan=3,0,255,0>fast green scan"
	}
}

function hscan_part:Ctor(str)
	local hscan_components = str:Split(",")
	self.Speed = math.Clamp(tonumber(hscan_components[1]) or 1, 1, 5)
	self.ScanColor = Color(
		tonumber(hscan_components[2]) or self.ScanColor.r,
		tonumber(hscan_components[3]) or self.ScanColor.g,
		tonumber(hscan_components[4]) or self.ScanColor.b
	)

	return self
end

function hscan_part:PostTextDraw(ctx, x, y, w, h)
	self.ScanColor.a = ctx.Alpha

	local half_width = w / 2
	surface_SetDrawColor(self.ScanColor)
	surface_DrawRect(x + half_width + (math_sin(RealTime() * self.Speed) * half_width), y, 10, h)
	surface_SetDrawColor(ctx.Color)
end

function hscan_part:Draw(ctx)
	ctx:PushPostTextDraw(self)
end

chathud:RegisterPart("hscan", hscan_part, "%<(hscan)%>")

--[[-----------------------------------------------------------------------------
	Vertical Scan Component

	Vertical scanning thingy.
]]-------------------------------------------------------------------------------
local vscan_part = {
	Speed = 1,
	ScanColor = Color(234, 9, 61),
	Usage = "<vscan> or <vscan=speed,r,g,b>",
	Examples = {
		"<vscan>normal vertical scan",
		"<vscan=3,0,255,0>fast green scan"
	}
}

function vscan_part:Ctor(str)
	local hscan_components = str:Split(",")
	self.Speed = math.Clamp(tonumber(hscan_components[1]) or 1, 1, 5)
	self.ScanColor = Color(
		tonumber(hscan_components[2]) or self.ScanColor.r,
		tonumber(hscan_components[3]) or self.ScanColor.g,
		tonumber(hscan_components[4]) or self.ScanColor.b
	)

	return self
end

function vscan_part:PostTextDraw(ctx, x, y, w, h)
	self.ScanColor.a = ctx.Alpha

	local half_height = h / 2
	surface_SetDrawColor(self.ScanColor)
	surface_DrawRect(x, y + half_height + (math_sin(RealTime() * self.Speed) * half_height), w, 3)
	surface_SetDrawColor(ctx.Color)
end

function vscan_part:Draw(ctx)
	ctx:PushPostTextDraw(self)
end

chathud:RegisterPart("vscan", vscan_part, "%<(vscan)%>")

--[[-----------------------------------------------------------------------------
	Scale Component

	Scales text components up and down.
]]-------------------------------------------------------------------------------
local scale_part = {
	OkInNicks = false,
	RunExpression = function() return 1 end,
	Enabled = false,
	Usage = "<scale=size> or <scale=expression>",
	Examples = {
		"<scale=3>Big text",
		"<scale=sin(t()*3)>Size changing text"
	}
}

function scale_part:Ctor(expr)
	local succ, ret = compile_expression(expr)
	if succ then
		self.RunExpression = ret
	end

	return self
end

function scale_part:ComputeScale()
	local succ, ret = pcall(self.RunExpression)
	local n = math.Clamp(succ and tonumber(ret) or 1, -3, 3)
	self.Scale = Vector(n, n, n)
end

function scale_part:PreTextDraw(ctx, x, y, w, h)
	self:ComputeScale()

	local tr = Vector(x, y + h / 2)
	local m = Matrix()
	m:Translate(tr)
	m:Scale(self.Scale)
	m:Translate(-tr)
	cam_PushModelMatrix(m, true)
end

function scale_part:PostTextDraw(ctx, x, y, w, h)
	cam_PopModelMatrix()
end

function scale_part:Draw(ctx)
	ctx:PushPreTextDraw(self)
	ctx:PushPostTextDraw(self)
end

chathud:RegisterPart("scale", scale_part)

--[[-----------------------------------------------------------------------------
	Rotate Component

	Rotates text components.
]]-------------------------------------------------------------------------------
local rotate_part = {
	OkInNicks = false,
	RunExpression = function() return 1 end,
	Usage = "<rotate=angle> or <rotate=expression>",
	Examples = {
		"<rotate=90>:) :D",
		"<rotate=t()*300>zoom zoom I rotate"
	}
}

function rotate_part:Ctor(expr)
	local succ, ret = compile_expression(expr)
	if succ then
		self.RunExpression = ret
	end

	return self
end

function rotate_part:ComputeAngle()
	local succ, ret = pcall(self.RunExpression)
	local n = succ and tonumber(ret) or 0
	self.Angle = Angle(0, n, 0)
end

function rotate_part:PreTextDraw(ctx, x, y, w, h)
	self:ComputeAngle()

	local tr = Vector(x + w / 2, y + h / 2)
	local m = Matrix()
	m:Translate(tr)
	m:SetAngles(self.Angle)
	m:Translate(-tr)
	cam_PushModelMatrix(m, true)
end

function rotate_part:PostTextDraw(ctx, x, y, w, h)
	cam_PopModelMatrix()
end

function rotate_part:Draw(ctx)
	ctx:PushPreTextDraw(self)
	ctx:PushPostTextDraw(self)
end

chathud:RegisterPart("rotate", rotate_part)

--[[-----------------------------------------------------------------------------
	ZRotate Component

	Rotates on yaw and roll axis text components.
]]-------------------------------------------------------------------------------
local z_rotate_part = {
	OkInNicks = false,
	RunExpression = function() return 1 end,
	Usage = "<zrotate=angle> or <zrotate=expression>",
	Examples = {
		"<zrotate=90>:) :D",
		"<zrotate=t()*300>zoom zoom I rotate"
	}
}

function z_rotate_part:Ctor(expr)
	local succ, ret = compile_expression(expr)
	if succ then
		self.RunExpression = ret
	end

	return self
end

function z_rotate_part:ComputeAngle()
	local succ, roll = pcall(self.RunExpression)
	self.Angle = Angle(0, 0, succ and tonumber(roll) or 0)
end

function z_rotate_part:PreTextDraw(ctx, x, y, w, h)
	self:ComputeAngle()

	local tr = Vector(x + w / 2, y + h / 2)
	local m = Matrix()
	m:Translate(tr)
	m:SetAngles(self.Angle)
	m:Translate(-tr)
	cam_PushModelMatrix(m, true)
end

function z_rotate_part:PostTextDraw(ctx, x, y, w, h)
	cam_PopModelMatrix()
end

function z_rotate_part:Draw(ctx)
	ctx:PushPreTextDraw(self)
	ctx:PushPostTextDraw(self)
end

chathud:RegisterPart("zrotate", z_rotate_part)

--[[-----------------------------------------------------------------------------
	Texture Component

	Shows a texture in the chat.
]]-------------------------------------------------------------------------------
local texture_allowed_shaders = {
	UnlitGeneric = true,
	VertexLitGeneric = true,
	Wireframe = true,
	Refract_DX90 = true,
	Water_DX90 = true,
	Sky_DX9 = true,
	gmodscreenspace = true,
	Modulate_DX9 = true,
	Cable = true
}

local texture_part = {
	RealPos = { X = 0, Y = 0 },
	Usage = "<texture=path, size?>",
	Examples = {
	--	"<texture=,16>"
	}
}

function texture_part:Ctor(str)
	local texture_components = str:Split(",")

	local path = texture_components[1]:Trim()
	local mat = Material(path, path:EndsWith(".png") and "nocull noclamp" or nil)
	if not mat then
		self.Invalid = true
		self.TextureSize = math.Clamp(tonumber(texture_components[2]) or (CLIENT and draw.GetFontHeight(self.HUD.DefaultFont) or 16), 16, 64)
		return self
	end

	local shader = mat:GetShader()
	if not texture_allowed_shaders[shader] then self.Invalid = true end
	if shader == "VertexLitGeneric" or shader == "Cable" then
		local tex_path = mat:GetString("$basetexture")
		if tex_path then
			local params = {
				["$basetexture"] = tex_path,
				["$vertexcolor"] = 1,
				["$vertexalpha"] = 1,
			}

			self.Material = CreateMaterial("ECFixMat_" .. tex_path, "UnlitGeneric", params)
		end
	else
		self.Material = mat
	end

	if not self.Material then self.Invalid = true end
	self.TextureSize = math.Clamp(tonumber(texture_components[2]) or (CLIENT and draw.GetFontHeight(self.HUD.DefaultFont) or 16), 16, 64)

	return self
end

function texture_part:LineBreak()
	local new_line = self.HUD:NewLine()
	new_line:PushComponent(self)
end

function texture_part:ComputeSize()
	if self.Invalid then
		self.Size = { W = 0, H = 0 }
	else
		self.Size = { W = self.TextureSize, H = self.TextureSize }
	end
end

function texture_part:ComputePos()
	if not EC_HUD_SMOOTH:GetBool() then
		self.RealPos.Y = self.Pos.Y
		return
	end

	if self.RealPos.Y ~= self.Pos.Y then
		if self.RealPos.Y > self.Pos.Y then
			local factor = math_EaseInOut((self.RealPos.Y - self.Pos.Y) / 100, 0.02, 0.02) * SMOOTHING_SPEED * RealFrameTime()
			self.RealPos.Y = math_max(self.RealPos.Y - math_max(math_abs(factor), 0.15), self.Pos.Y)
		else
			local factor = math_EaseInOut((self.Pos.Y - self.RealPos.Y) / 100, 0.02, 0.02) * SMOOTHING_SPEED * RealFrameTime()
			self.RealPos.Y = math_min(self.RealPos.Y + math_max(math_abs(factor), 0.15), self.Pos.Y)
		end
	end
end

function texture_part:GetDrawPos(ctx)
	local offsex_x, offset_y =
		math_clamp(ctx.TextOffset.X, -MAX_TEXT_OFFSET, MAX_TEXT_OFFSET),
		math_clamp(ctx.TextOffset.Y, -MAX_TEXT_OFFSET, MAX_TEXT_OFFSET)
	return self.Pos.X + offsex_x, self.RealPos.Y + offset_y
end

function texture_part:Draw(ctx)
	if self.Invalid then return end

	self:ComputePos()

	local x, y = self:GetDrawPos(ctx)

	ctx:CallPreTextDrawFunctions(x, y, self.Size.W, self.Size.H)

	surface_SetMaterial(self.Material)
	surface_DrawTexturedRect(x, y, self.Size.W, self.Size.H)
	draw_NoTexture()

	ctx:CallPostTextDrawFunctions(x, y, self.Size.W, self.Size.H)
end

chathud:RegisterPart("texture", texture_part)

--[[-----------------------------------------------------------------------------
	Translate Component

	Translates text from its original position to another.
]]-------------------------------------------------------------------------------
local translate_part = {
	OkInNicks = false,
	RunExpression = function() return 0, 0 end,
	Offset = { X = 0, Y = 0 },
	Usage = "<translate=x,y> or <translate=expression>",
	Examples = {
		"<translate=100,0>To the right",
		"<translate=rand()*10,rand()*10>Im angry!"
	}
}

function translate_part:Ctor(expr)
	local succ, ret = compile_expression(expr)
	if succ then
		self.RunExpression = ret
	end

	return self
end

function translate_part:ComputeOffset()
	local succ, x, y = pcall(self.RunExpression)
	self.Offset = { X = succ and tonumber(x) or 0, Y = succ and tonumber(y) or 0 }
end

function translate_part:Draw(ctx)
	self:ComputeOffset()
	ctx:PushTextOffset(self.Offset)
end

chathud:RegisterPart("translate", translate_part)

--[[-----------------------------------------------------------------------------
	Carat Color Component

	Pre-hard-coded colors ready for use.
]]-------------------------------------------------------------------------------
local carat_colors = {
	["0"] = Color(0, 0, 0),
	["1"] = Color(128, 128, 128),
	["2"] = Color(192, 192, 192),
	["3"] = Color(255, 255, 255),
	["4"] = Color(0, 0, 128),
	["5"] = Color(0, 0, 255),
	["6"] = Color(0, 128, 128),
	["7"] = Color(0, 255, 255),
	["8"] = Color(0, 128, 0),
	["9"] = Color(0, 255, 0),
	["10"] = Color(128, 128, 0),
	["11"] = Color(255, 255, 0),
	["12"] = Color(128, 0, 0),
	["13"] = Color(255, 0, 0),
	["14"] = Color(128, 0, 128),
	["15"] = Color(255, 0, 255),
}

local carat_color_part = {
	Usage = "^number or <caratcol=number>",
	Examples = {
		"^5this is blue",
		"^13this is red"
	}
}

function carat_color_part:Ctor(num)
	local col = carat_colors[num:Trim()]
	if col then
		self.Color = col
	else
		self.Color = Color(255, 255, 255)
	end

	return self
end

function carat_color_part:Draw(ctx)
	ctx:UpdateColor(self.Color)
end

chathud:RegisterPart("caratcol", carat_color_part, "%^([0-9][1-5]?)", {
	"%S+%^[%d|%.]+%s", -- chatsounds modifier in middle of sentence
	"%S+%^[%d|%.]+$", -- chatsounds modifier in end of sentence
})

--[[-----------------------------------------------------------------------------
	Wrong Component

	Marks text as "wrong".
]]-------------------------------------------------------------------------------
local wrong_part = {
	Usage = "<wrong>",
	Examples = {
		"<wrong>This text is wrong"
	}
}

function wrong_part:Ctor()
	return self
end

local wrong_col = Color(255, 0, 0)
function wrong_part:PostTextDraw(ctx, x, y, w, h)
	wrong_col.a = ctx.Alpha
	surface_SetDrawColor(wrong_col)
	surface_DrawLine(x, y + h, x + w, y + h)
	surface_SetDrawColor(ctx.Color)
end

function wrong_part:Draw(ctx)
	ctx:PushPostTextDraw(self)
end

-- we need the "<wrong>" pattern here because otherwise players need to type "<wrong=>"
chathud:RegisterPart("wrong", wrong_part, "%<(wrong)%>")

--[[-----------------------------------------------------------------------------
	Background Component

	Draws text background a certain color.
]]-------------------------------------------------------------------------------
local background_part = {
	Usage = "<background=r,g,b>",
	Examples = {
		"<background=0,255,255>Cyan background",
	}
}

function background_part:Ctor(str)
	local col_components = str:Split(",")
	local r, g, b =
		tonumber(col_components[1]) or 255,
		tonumber(col_components[2]) or 255,
		tonumber(col_components[3]) or 255
	self.Color = Color(r, g, b)

	return self
end

function background_part:PreTextDraw(ctx, x, y, w, h)
	self.Color.a = ctx.Alpha
	surface_SetDrawColor(self.Color)
	surface_DrawRect(x, y, w, h)
	surface_SetDrawColor(ctx.Color)
end

function background_part:Draw(ctx)
	ctx:PushPreTextDraw(self)
end

chathud:RegisterPart("background", background_part)

--[[-----------------------------------------------------------------------------
	Minecraft Color Component

	Colors from Minecraft, based off of carat color
]]-------------------------------------------------------------------------------
local mc_colors = {
	["0"] = Color(0, 0, 0),
	["1"] = Color(0, 0, 170),
	["2"] = Color(0, 170, 0),
	["3"] = Color(0, 170, 170),
	["4"] = Color(170, 0, 0),
	["5"] = Color(170, 0, 170),
	["6"] = Color(255, 170, 0),
	["7"] = Color(170, 170, 170),
	["8"] = Color(85, 85, 85),
	["9"] = Color(85, 85, 255),
	["a"] = Color(85, 255, 85),
	["b"] = Color(85, 255, 255),
	["c"] = Color(255, 85, 85),
	["d"] = Color(255, 85, 255),
	["e"] = Color(255, 255, 85),
	["f"] = Color(255, 255, 255),
	["r"] = Color(255, 255, 255),
}

local mc_color_part = {
	Usage = "&value or <mccol=value>",
	Examples = {
		"&6this is orange",
		"&ethis is yellow"
	}
}

function mc_color_part:Ctor(num)
	local col = mc_colors[num:Trim()]
	if col then
		self.Color = col
	else
		self.Color = Color(255, 255, 255)
	end

	return self
end

function mc_color_part:Draw(ctx)
	ctx:UpdateColor(self.Color)
end

chathud:RegisterPart("mccol", mc_color_part, "[&\xc2]\xa7?([0-9a-fr])")

return "ChatHUD Extra Tags"
