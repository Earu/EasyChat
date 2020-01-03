local chathud = EasyChat.ChatHUD
local compile_expression = EasyChat.Expressions.Compile
local pcall = _G.pcall

local surface_SetDrawColor = surface.SetDrawColor
local surface_SetTextColor = surface.SetTextColor
local surface_SetMaterial = surface.SetMaterial
local surface_DrawTexturedRect = surface.DrawTexturedRect
local surface_DrawRect = surface.DrawRect
local surface_DrawLine = surface.DrawLine

local draw_NoTexture = draw.NoTexture

local cam_PushModelMatrix = cam.PushModelMatrix
local cam_PopModelMatrix = cam.PopModelMatrix

local math_sin = math.sin
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
	RunExpression = function() return 360, 1, 1 end
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
	Scale Component

	Scales text components up and down.
]]-------------------------------------------------------------------------------
local scale_part = {
	OkInNicks = false,
	RunExpression = function() return 1 end,
	Enabled = false,
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
	cam_PushModelMatrix(m)
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
	RunExpression = function() return 1 end
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
	cam_PushModelMatrix(m)
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
	RunExpression = function() return 1 end
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
	cam_PushModelMatrix(m)
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
local texture_part = {}

function texture_part:Ctor(str)
	local texture_components = string.Explode(str, "%s*,%s*", true)

	local path = texture_components[1]
	local mat = Material(path, (path:EndsWith(".png") and "nocull noclamp" or nil))
	local shader = mat:GetShader()
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
	self.TextureSize = math.Clamp(tonumber(texture_components[2]) or draw.GetFontHeight(self.HUD.DefaultFont), 16, 64)

	return self
end

function texture_part:ComputeSize()
	self.Size = { W = self.TextureSize, H = self.TextureSize }
end

function texture_part:LineBreak()
	local new_line = self.HUD:NewLine()
	new_line:PushComponent(self)
end

function texture_part:Draw(ctx)
	if self.Invalid then return end

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
	OkInNicks = false,
	RunExpression = function() return 0, 0 end,
	Offset = { X = 0, Y = 0 }
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

	if self.Offset.X + self.HUD.Pos.X > self.HUD.Pos.X + self.HUD.Size.W then
		self.Offset.X = self.HUD.Size.W
	end

	if self.Offset.Y + self.HUD.Pos.Y + self.HUD.Size.H < self.HUD.Pos.Y then
		self.Offset.Y = -self.HUD.Size.H
	end
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

local carat_color_part = {}

function carat_color_part:Ctor(num)
	local col = carat_colors[string.Trim(num)]
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

chathud:RegisterPart("caratcol", carat_color_part, "%^([1-9][1-5]?)", {
	"%S+%^[%d|%.]+%s", -- chatsounds modifier in middle of sentence
	"%S+%^[%d|%.]+$", -- chatsounds modifier in end of sentence
})

--[[-----------------------------------------------------------------------------
	Wrong Component

	Marks text as "wrong".
]]-------------------------------------------------------------------------------
local wrong_part = {}

function wrong_part:Ctor()
	return self
end

local wrong_col = Color(255, 0, 0)
function wrong_part:PostTextDraw(ctx, x, y, w, h)
	wrong_col.a = ctx.Alpha
	surface_SetDrawColor(wrong_col)
	for i = x, x + w do
		surface_DrawLine(i, y + h - math_sin(i), i, y + h + math_sin(i))
	end
	surface_SetDrawColor(ctx.Color)
end

function wrong_part:Draw(ctx)
	ctx:PushPostTextDraw(self)
end

-- disable that its way too laggy for now
-- we need the "<wrong>" pattern here because otherwise players need to type "<wrong=>"
--chathud:RegisterPart("wrong", wrong_part, "%<wrong%>")

--[[-----------------------------------------------------------------------------
	Background Component

	Draws text background a certain color.
]]-------------------------------------------------------------------------------
local background_part = {}

function background_part:Ctor(str)
	local col_components = string.Explode("%s*,%s*", str, true)
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
	Emote Component

	Displays emotes.
]]-------------------------------------------------------------------------------
local emote_part = {
	SetEmoteMaterial = function() draw_NoTexture() end,
	RealPos = { X = 0, Y = 0 }
}

function emote_part:Ctor(str)
	local em_components = string.Explode("%s*,%s*", str, true)
	local name, size = em_components[1], em_components[2]
	self.Height = math.Clamp(tonumber(size) or draw.GetFontHeight(self.HUD.DefaultFont), 16, 64)
	self:TryGetEmote(name)

	return self
end

local emote_priority = {
	"twemojis",
	"steam",
}
function emote_part:TryGetEmote(name)
	local providers = list.Get("EasyChatEmoticonProviders")
	local found = false

	-- look for providers with a priority set
	for _, provider in ipairs(emote_priority) do
		if providers[provider] then
			local succ, emote = pcall(function() return providers[provider](name) end)
			-- false indicates that the emote name does not exist for the provider
			if succ and emote ~= false then
				-- material was cached
				if type(emote) == "IMaterial" then
					self.SetEmoteMaterial = function() surface_SetMaterial(emote) end

					found = true
					break
				-- we're still requesting
				elseif emote == nil then
					self.SetEmoteMaterial = function()
						local mat = providers[provider](name)
						if mat then
							surface_SetMaterial(mat)
						end
					end

					found = true
					break
				end
			end
		end
	end

	-- look for non-priotized / unknown providers
	if not found then
		for provider, get_emote in pairs(providers) do
			if not table.HasValue(emote_priority, provider) then
				local succ, emote = pcall(function() return providers[provider](name) end)
				if succ and emote ~= false then
					-- material was cached
					if type(emote) == "IMaterial" then
						self.SetEmoteMaterial = function() surface_SetMaterial(emote) end

						found = true
						break
					-- we're still requesting
					elseif emote == nil then
						self.SetEmoteMaterial = function()
							local mat = providers[provider](name)
							if mat then
								surface_SetMaterial(mat)
							end
						end

						found = true
						break
					end
				end
			end
		end
	end

	if not found then self.Invalid = true end
end

function emote_part:ComputeSize()
	if self.Invalid then
		self.Size = { W = 0, H = 0 }
	else
		self.Size = { W = self.Height, H = self.Height }
	end
end

function emote_part:LineBreak()
	local new_line = self.HUD:NewLine()
	new_line:PushComponent(self)
end

local EC_HUD_SMOOTH = GetConVar("easychat_hud_smooth")
local smoothing_speed = 1000
function emote_part:ComputePos()
	if not EC_HUD_SMOOTH:GetBool() then
		self.RealPos.Y = self.Pos.Y
		return
	end

    if self.RealPos.Y ~= self.Pos.Y then
        if self.RealPos.Y > self.Pos.Y then
            local factor = math.EaseInOut((self.RealPos.Y - self.Pos.Y) / 100, 0.02, 0.02) * smoothing_speed * RealFrameTime()
            self.RealPos.Y = math.max(self.RealPos.Y - factor, self.Pos.Y)
        else
            local factor = math.EaseInOut((self.Pos.Y - self.RealPos.Y) / 100, 0.02, 0.02) * smoothing_speed * RealFrameTime()
            self.RealPos.Y = math.min(self.RealPos.Y + factor, self.Pos.Y)
        end
    end
end

function emote_part:GetDrawPos(ctx)
	return self.Pos.X + ctx.TextOffset.X, self.RealPos.Y + ctx.TextOffset.Y
end

function emote_part:PostLinePush()
    self.RealPos = table.Copy(self.Pos)
end

function emote_part:Draw(ctx)
	if self.Invalid then return end

    self:ComputePos()

    local x, y = self:GetDrawPos(ctx)

    ctx:CallPreTextDrawFunctions(x, y, self.Size.W, self.Size.H)

    self.SetEmoteMaterial()
	surface_DrawTexturedRect(x, y, self.Size.W, self.Size.H)
    draw_NoTexture()

    ctx:CallPostTextDrawFunctions(x, y, self.Size.W, self.Size.H)
end

chathud:RegisterPart("emote", emote_part, "%:([A-Za-z0-9_]+)%:", {
	"STEAM%_%d%:%d%:%d+", -- steamids
	"%d%d:%d%d:%d%d" -- timestamps
})

return "ChatHUD Extra Tags"