local chathud = EasyChat.ChatHUD
local compile_expression = EasyChat.Expressions.Compile

local surface_SetDrawColor = surface.SetDrawColor
local surface_SetTextColor = surface.SetTextColor
local surface_SetMaterial = surface.SetMaterial
local surface_DrawTexturedRect = surface.DrawTexturedRect

local draw_NoTexture = draw.NoTexture

--[[-----------------------------------------------------------------------------
	Color Component

	Color modulation with hexadecimal values.
]]-------------------------------------------------------------------------------
local color_hex_part = {}

function color_hex_part:HexToRGB(hex)
	local hex = string.Replace(hex, "#","")
	local function n(input) return tonumber(input) or 255 end

    if string.len(hex) == 3 then
		return
			(n("0x" .. string.sub(hex, 1, 1)) * 17),
			(n("0x" .. string.sub(hex, 2, 2)) * 17),
			(n("0x" .. string.sub(hex, 3, 3)) * 17)
    else
		return
			n("0x" .. string.sub(hex, 1, 2)),
			n("0x" .. string.sub(hex, 3, 4)),
			n("0x" .. string.sub(hex, 5, 6))
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
	RunExpression = function() return 360, 1, 1 end
}

function hsv_part:Ctor(expr)
	local succ, ret = compile_expression(expr)
	if succ then
		self.RunExpression = ret
	end

	return self
end

function hsv_part:ComputeHSV()
	local h, s, v = self.RunExpression()

	h = (tonumber(h) or 360) % 360
	s = math.Clamp(tonumber(s) or 1, 0, 1)
	v = math.Clamp(tonumber(v) or 1, 0, 1)

	self.Color = HSVToColor(h, s, v)
end

function hsv_part:Draw(ctx)
	self:ComputeHSV()
	ctx:UpdateColor(self.Color)
end

chathud:RegisterPart("hsv", hsv_part)

--[[-----------------------------------------------------------------------------
	Scale Component

	Scales other components up and down.
]]-------------------------------------------------------------------------------
local scale_part = {
	OkInNicks = false,
	RunExpression = function() return 1 end
}

function scale_part:Ctor(expr)
	self:ComputeSize()

	local succ, ret = compile_expression(expr)
	if succ then
		self.RunExpression = ret
	end

	return self
end

function scale_part:ComputeScale()
	local ret = self.RunExpression()
	local n = tonumber(ret) or 1
	self.Scale = Vector(n, n, n)
end

function scale_part:Draw(ctx)
	self:ComputeScale()

	local translation = Vector(self.Pos.X, self.Pos.Y)
	local mat = Matrix()
	mat:SetTranslation(translation)
	mat:Scale(self.Scale)
	ctx:PushMatrix(mat)
end

chathud:RegisterPart("scale", scale_part)

--[[-----------------------------------------------------------------------------
	Texture Component

	Shows a texture in the chat.
]]-------------------------------------------------------------------------------
local texture_part = {}

local default_mat = CreateMaterial("ECDefaultTexture", "UnlitGeneric", {
	["$basetexture"] = "vgui/white"
})
function texture_part:Ctor(str)
	local texture_components = string.Explode(str, "%s*,%s*", true)

	--if self:TextureExists(texture_components[1]) then
		self.Material = CreateMaterial(string_format("EC_%s", texture_components[1]), "UnlitGeneric", {
			["$basetexture"] = texture_components[1],
		})
	--else
	--	self.Material = default_mat
	--end

	self.TextureSize = math.Clamp(tonumber(texture_components[2]) or 32, 16, 64)

	return self
end

function texture_part:TextureExists(path)
	local t = Material(path):GetTexture("$basetexture")
	if not t then return false end

	return t:IsError()
end

function texture_part:ComputeSize()
	self.Size = { W = self.TextureSize, H = self.TextureSize }
end

function texture_part:Draw(ctx)
	surface_SetMaterial(self.Material)
	surface_DrawTexturedRect(self.Pos.X, self.Pos.Y, self.TextureSize, self.TextureSize)

	draw_NoTexture()
end

chathud:RegisterPart("texture", texture_part)

--[[-----------------------------------------------------------------------------
	Translate Component

	Translates text from its original position to another.
]]-------------------------------------------------------------------------------
local translate_part = {
	RunExpression = function() return 0, 0 end,
	Offset = { X = 0, Y = 0 }
}

function translate_part:Ctor(expr)
	self:ComputeSize()

	local succ, ret = compile_expression(expr)
	if succ then
		self.RunExpression = ret
	end

	return self
end

function translate_part:ComputeOffset()
	local x,y = self.RunExpression()
	self.Offset = { X = tonumber(x) or 0, Y = tonumber(y) or 0 }
end

function translate_part:Draw(ctx)
	self:ComputeOffset()
	ctx:PushTextOffset(self.Offset)
end

chathud:RegisterPart("translate", translate_part)