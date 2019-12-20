local chathud = EasyChat.ChatHUD
local compile_expression = EasyChat.Expressions.Compile
local surface_SetDrawColor = surface.SetDrawColor
local surface_SetTextColor = surface.SetTextColor

--[[-----------------------------------------------------------------------------
	Color Component

	Color modulation with hexadecimal values.
]]-------------------------------------------------------------------------------
local color_hex_part = {}

function color_hex_part:HexToRGB(hex)
	local hex = string.Replace(hex, "#","")
	local function n(input) return tonumber(input) or 255 end

    if string_len(hex) == 3 then
    	return (n("0x" .. string.sub(hex, 1, 1)) * 17), (n("0x" .. string.sub(hex, 2, 2)) * 17), (n("0x" .. string.sub(hex, 3, 3)) * 17)
    else
      	return n("0x" .. string.sub(hex, 1, 2)), n("0x" .. string.sub(hex, 3, 4)), n("0x" .. string.sub(hex, 5, 6))
    end
end

function color_hex_part:Ctor(str)
	self:ComputeSize()
	local r, g, b = self:HexToRGB(str)
	self.Color = Color(r, g, b)

	return self
end

function color_hex_part:Draw(ctx)
	self.Color.a = ctx.Alpha
	surface_SetDrawColor(self.Color)
	surface_SetTextColor(self.Color)
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
	self.Color.a = ctx.Alpha
	surface_SetDrawColor(self.Color)
	surface_SetTextColor(self.Color)
end

chathud:RegisterPart("hsv", hsv_part)
--[[-----------------------------------------------------------------------------
	Scale Component

	Scales other components up and down.
]]-------------------------------------------------------------------------------
local scale_part = {
	OkInNicks = false,
}

function scale_part:Ctor(str)
	self:ComputeSize()
	local n = tonumber(str) or 1
	self.Scale = Vector(n, n, n)

	return self
end

function scale_part:Draw(ctx)
	local mat = Matrix()
	mat:SetScale(self.Scale)
	ctx:PushMatrix(mat)
end

chathud:RegisterPart("scale", scale_part)