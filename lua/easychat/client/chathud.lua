--[[-----------------------------------------------------------------------------
	Micro Optimization
]]-------------------------------------------------------------------------------
local ipairs, pairs = _G.ipairs, _G.pairs
local Color, Vector, Matrix = _G.Color, _G.Vector, _G.Matrix
local RealTime = _G.RealTime
local type = _G.type

local table_copy = _G.table.Copy
local table_insert = _G.table.insert
local table_remove = _G.table.remove

local surface_SetDrawColor = _G.surface.SetDrawColor
local surface_SetTextColor = _G.surface.SetTextColor
local surface_GetTextSize = _G.surface.GetTextSize
local surface_DrawOutlinedRect = _G.surface.DrawOutlinedRect
local surface_SetFont = _G.surface.SetFont
local surface_SetTextPos = _G.surface.SetTextPos
local surface_DrawText = _G.surface.DrawText

local math_min = _G.math.min

local cam_PopModelMatrix = _G.cam.PopModelMatrix
local cam_PushModelMatrix = _G.cam.PushModelMatrix

local hook_run = _G.hook.Run
---------------------------------------------------------------------------------

local chat_x, chat_y = chat.GetChatBoxPos()
local chat_w, chat_h = chat.GetChatBoxSize()

local chathud = {
	FadeTime = 10,
	Pos = { X = chat_x, Y = chat_y },
	Size = { W = chat_w, H = chat_h },
	Lines = {},
	Parts = {},
	TagPattern = "<(.-)=(.-)>",
}

--[[local EC_HUD_TTL = GetConVar("easychat_hud_ttl")
chathud.FadeTime = EC_HUD_TTL:GetInt()
cvars.AddChangeCallback("easychat_hud_ttl", function(_, _, new)
    chathud.FadeTime = new
end)]]--

local default_part = {
	Pos = { X = 0, Y = 0 },
	Size =  { W = 0, H = 0 },
	-- fading and color
	LifeTime = 0,
	NextLifeTimeUpdate = 0,
	Alpha = 255,
	Usable = true,
}

function default_part:Ctor()
	self:ComputeSize()
	return self
end

function default_part:ComputeSize()
	self.Size = { W = 25, H = 25 }
end

function default_part:Draw(ctx)
	surface_DrawOutlinedRect(self.Pos.X, self.Pos.Y, self.Size.W, self.Size.H)
end

function chathud:RegisterPart(name, part)
	if not name or not part then return end
	local new_part = table_copy(default_part)
	for k, v in pairs(part) do
		new_part[k] = v
	end

	self.Parts[name] = new_part
end

--[[-----------------------------------------------------------------------------
	Stop Component

	/!\ NEVER EVER REMOVE OR THE CHATHUD WILL BREAK HORRIBLY /!\

	This guarantees all matrixes and generally every change made
	to the drawing context is set back to a "default" state.
]]-------------------------------------------------------------------------------
local stop_part = {
	Usable = false
}

function stop_part:ComputeSize()
	self.Size = { W = 0, H = 0 }
end

function stop_part:Draw(ctx)
	while ctx.MatrixCount > 0 do
		ctx:PopMatrix()
	end

	ctx:ResetColors()
	ctx:ResetFont()
end

chathud:RegisterPart("stop", stop_part)

--[[-----------------------------------------------------------------------------
	Scale Component

	Scales other components up and down.
]]-------------------------------------------------------------------------------
local scale_part = {
	Scale = Vector(1, 1, 1)
}

function scale_part:Ctor(scale)
	self:ComputeSize()
	self.Scale = scale
end

function stop_part:ComputeSize()
	self.Size = { W = 0, H = 0 }
end

function scale_part:Draw(ctx)
	local mat = Matrix()
	mat:SetScale(mat)
	ctx:PushMatrix(mat)
end

chathud:RegisterPart("scale", scale_part)

--[[-----------------------------------------------------------------------------
	Color Component

	Color modulation.
]]-------------------------------------------------------------------------------
local color_part = {
	Color = Color(255, 255, 255)
}

function color_part:Ctor(col)
	self:ComputeSize()
	self.Color = col
end

function stop_part:ComputeSize()
	self.Size = { W = 0, H = 0 }
end

function color_part:Draw(ctx)
	self.Color.a = self.Line.Alpha
	surface.SetDrawColor(self.Color)
	surface.SetTextColor(self.Color)
end

chathud:RegisterPart("color", color_part)

--[[-----------------------------------------------------------------------------
	Text Component

	Draws normal text.
]]-------------------------------------------------------------------------------
local text_part = {
	Font = "DermaDefault",
	Content = "",
	Usable = false
}

function text_part:Ctor(content, font)
	self.Content = content
	self.Font = font

	self:ComputeSize()
end

function text_part:ComputeSize()
	surface_SetFont(self.Font)
	local w, h = surface_GetTextSize(self.Content)
	self.Size = { W = w, H = h }
end

function text_part:Draw()
	surface_SetFont(self.Font)
	surface_SetTextPos(self.Pos.X, self.Pos.Y)
	surface_DrawText(self.Content)
end

chathud:RegisterPart("text", text_part)

--[[-----------------------------------------------------------------------------
	ChatHUD base
]]-------------------------------------------------------------------------------
local base_line = {
	Components = {},
	Pos = { X = 0, Y = 0 },
	Height = 0
}

function base_line:Remove()
	table_remove(chathud.Lines, self.Index)
	chathud:InvalidateLayout()
end

function base_line:Update()
	local time = RealTime()
	if time < self.NextLifeTimeUpdate then return end

	self.LifeTime = self.LifeTime + 1
	self.NextLifeTimeUpdate = time + 1

	if self.LifeTime >= chathud.FadeTime then
		self.Alpha = math_min(self.Alpha - 1, 0)
		if self.Alpha == 0 then
			self:Remove()
		end
	end
end

function base_line:Draw(ctx)
	self:Update()
	for _, component in ipairs(self.Components) do
		component:Draw()
	end
end

function chathud:CreateLine()
	local new_line = table_copy(base_line)
	new_line.Index = table_insert(self.Lines, new_line)
end

function chathud:InvalidateLayout()
end

function chathud:CreatePartComponent(name, ...)
	local part = self.Parts[name]
	if not part then return end

	local component = table_copy(part):Ctor(...)
	local line = self.Lines[#self.Lines]
	if not line or need_new_line then
		line = self:CreateLine()
	end

	if component.Height > line.Height then -- update line height to the tallest possible
		line.Height = component.Height
	end

	component.Line = line
	component.Pos = { X = line.Pos.X, Y = line.Pos.Y }
	table_insert(line.Components, component)
end

--[[-----------------------------------------------------------------------------
	Actual ChatHUD drawing here
]]-------------------------------------------------------------------------------
local draw_context = {
	MatrixCount = 0,
	DefaultColor = Color(255, 255, 255), -- white
	DefaultFont = "DermaDefault"
}

function draw_context:PushMatrix(mat)
	cam_PushModelMatrix(mat)
	self.MatrixCount = self.MatrixCount + 1
end

function draw_context:PopMatrix()
	if self.MatrixCount <= 0 then return end

	cam_PopModelMatrix()
	self.MatrixCount = self.MatrixCount - 1
end

function draw_context:ResetColors()
	surface_SetDrawColor(self.DefaultColor)
	surface_SetTextColor(self.DefaultColor)
end

function draw_context:ResetFont()
	surface_SetFont(self.DefaultFont)
end

chathud.DrawContext = draw_context

function chathud:Draw()
	if hook_run("HUDShouldDraw","CHudChat") == false then return end
	for _, line in ipairs(self.Lines) do
		line:Draw(draw_context)
	end
end

local black = Color(0, 0, 0, 255)
hook.Add("HUDPaint", "EASYCHAT_CHATHUD", function()
	surface_SetDrawColor(black)
	surface_DrawOutlinedRect(chathud.Pos.X, chathud.Pos.Y, chathud.Size.W, chathud.Size.H)
	chathud:Draw()
end)

--[[-----------------------------------------------------------------------------
	Parsing and pushing of new components
]]-------------------------------------------------------------------------------
local function is_color(c)
	return c.r and c.g and c.b and c.a
end

function chathud:ParseString(str)
	local parts = str:Explode(self.TagPattern, str, true)
	local enumerator = str:gmatch(self.TagPattern)
	for tag, content in enumerator do

	end
end

function chathud:AddText(...)
	local args = { ... }
	for _, arg in ipairs(args) do
		local t = type(arg)
		if t == "Player" then

		elseif t == "table" and is_color(arg) then
			self:CreatePartComponent("color", arg)
		end
	end
end

-- testing
chat.MetaAddText = chat.MetaAddText or chat.AddText
function chat.AddText(...)
	chathud:AddText(...)
	chat.MetaAddText(...)
end