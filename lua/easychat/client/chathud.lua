--[[
	TODO:
	- Linebreak to get rid of overflowing text
	- Handle font changes
	- Fix matrices not working / text not displaying when using them
]]--

--[[-----------------------------------------------------------------------------
	Expressions for usage inside chathud components
]]-------------------------------------------------------------------------------
local expr_env = {
	PI = math.pi,
	pi = math.pi,
	rand = math.random,
	random = math.random,
	randx = function(a,b)
		a = a or -1
		b = b or 1
		return math.Rand(a, b)
	end,

	abs = math.abs,
	sgn = function (x)
		if x < 0 then return -1 end
		if x > 0 then return  1 end
		return 0
	end,

	pwm = function(offset, w)
		w = w or 0.5
		return offset%1 > w and 1 or 0
	end,

	square = function(x)
		x = math.sin(x)

		if x < 0 then return -1 end
		if x > 0 then return  1 end

		return 0
	end,

	acos = math.acos,
	asin = math.asin,
	atan = math.atan,
	atan2 = math.atan2,
	ceil = math.ceil,
	cos = math.cos,
	cosh = math.cosh,
	deg = math.deg,
	exp = math.exp,
	floor = math.floor,
	frexp = math.frexp,
	ldexp = math.ldexp,
	log = math.log,
	log10 = math.log10,
	max = math.max,
	min = math.min,
	rad = math.rad,
	sin = math.sin,
	sinc = function (x)
		if x == 0 then return 1 end
		return math.sin(x) / x
	end,
	sinh = math.sinh,
	sqrt = math.sqrt,
	tanh = math.tanh,
	tan = math.tan,

	clamp = math.Clamp,
	pow = math.pow,

	t = RealTime,
	time = RealTime,
}

local blacklist = { "repeat", "until", "function", "end" }

local function compile_expression(str)
    for _, word in pairs(blacklist) do
        if str:find("[%p%s]" .. word) or str:find(word .. "[%p%s]") then
            return false, string.format("illegal characters used %q", word)
        end
    end

    local functions = {}

    for k,v in pairs(expr_env) do functions[k] = v end

    functions.select = select
    str = "local IN = select(1, ...) return " .. str

    local func = CompileString(str, "easychat_expression", false)

    if type(func) == "string" then
        return false, func
    else
        setfenv(func, functions)
        return true, func
    end
end

--[[-----------------------------------------------------------------------------
	Micro Optimization
]]-------------------------------------------------------------------------------
local ipairs, pairs, tonumber = _G.ipairs, _G.pairs, _G.tonumber
local Color, Vector, Matrix = _G.Color, _G.Vector, _G.Matrix
local type, tostring, RealFrameTime = _G.type, _G.tostring, _G.RealFrameTime

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

local math_max = _G.math.max
local math_floor = _G.math.floor
local math_clamp = _G.math.Clamp

local cam_PopModelMatrix = _G.cam.PopModelMatrix
local cam_PushModelMatrix = _G.cam.PushModelMatrix

local hook_run = _G.hook.Run

local string_explode = _G.string.Explode
local string_gmatch = _G.string.gmatch
local string_replace = _G.string.Replace
local string_sub = _G.string.sub
local string_len = _G.string.len
---------------------------------------------------------------------------------

local chat_x, chat_y = chat.GetChatBoxPos()
local chat_w, chat_h = chat.GetChatBoxSize()

local chathud = {
	FadeTime = 16,
	Pos = { X = chat_x, Y = chat_y },
	Size = { W = chat_w, H = chat_h },
	Lines = {},
	Parts = {},
	TagPattern = "<(.-)=(.-)>",
	ShouldClean = false,
}

--[[local EC_HUD_TTL = GetConVar("easychat_hud_ttl")
chathud.FadeTime = EC_HUD_TTL:GetInt()
cvars.AddChangeCallback("easychat_hud_ttl", function(_, _, new)
    chathud.FadeTime = new
end)]]--

local default_part = {
	Type = "default",
	Pos = { X = 0, Y = 0 },
	Size =  { W = 0, H = 0 },
	-- fading and color
	Usable = true,
}

function default_part:Ctor()
	self:ComputeSize()
	return self
end

-- meant to be overriden
function default_part:ComputeSize() end

-- meant to be overriden
function default_part:Draw() end

function chathud:RegisterPart(name, part)
	if not name or not part then return end
	name = string.lower(name)

	local new_part = table_copy(default_part)
	for k, v in pairs(part) do
		new_part[k] = v
	end

	new_part.Type = name
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

--[[-----------------------------------------------------------------------------
	Color Component

	Color modulation with rgb values.
]]-------------------------------------------------------------------------------
local color_part = {
	Color = Color(255, 255, 255)
}

function color_part:Ctor(str)
	self:ComputeSize()
	local col_components = string_explode("%s*,%s*", str, true)
	local r, g, b =
		tonumber(col_components[1]) or 255,
		tonumber(col_components[2]) or 255,
		tonumber(col_components[3]) or 255
	self.Color = Color(r, g, b)

	return self
end

function color_part:Draw(ctx)
	self.Color.a = ctx.Alpha
	surface_SetDrawColor(self.Color)
	surface_SetTextColor(self.Color)
end

chathud:RegisterPart("color", color_part)

--[[-----------------------------------------------------------------------------
	Color Component

	Color modulation with hexadecimal values.
]]-------------------------------------------------------------------------------
local color_hex_part = {
	Color = Color(255, 255, 255)
}

function color_hex_part:HexToRGB(hex)
	local hex = string_replace(hex, "#","")
	local function n(input) return tonumber(input) or 255 end

    if string_len(hex) == 3 then
    	return (n("0x" .. string_sub(hex, 1, 1)) * 17), (n("0x" .. string_sub(hex, 2, 2)) * 17), (n("0x" .. string_sub(hex, 3, 3)) * 17)
    else
      	return n("0x" .. string_sub(hex, 1, 2)), n("0x" .. string_sub(hex, 3, 4)), n("0x" .. string_sub(hex, 5, 6))
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
	Color = Color(255, 255, 255),
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
	s = math_clamp(tonumber(s) or 1, 0, 1)
	v = math_clamp(tonumber(v) or 1, 0, 1)

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
	Text Component

	Draws normal text.
]]-------------------------------------------------------------------------------
local text_part = {
	Font = "DermaLarge",
	Content = "",
	Usable = false
}

function text_part:Ctor(content, font)
	self.Content = content
	self.Font = font or self.Font
	self:ComputeSize()

	return self
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
	Size = { W = 0, H = 0 },
	LifeTime = 0,
	Alpha = 255,
}

function base_line:Update()
	local time = RealFrameTime()
	self.LifeTime = self.LifeTime + time
	if self.LifeTime >= chathud.FadeTime then
		self.Alpha = math_floor(math_max(self.Alpha - (time * 10), 0))
		if self.Alpha == 0 then
			self.ShouldRemove = true
			chathud.ShouldClean = true
		end
	end
end

function base_line:Draw(ctx)
	self:Update()
	ctx.Alpha = self.Alpha
	for _, component in ipairs(self.Components) do
		component:Draw(ctx)
	end
end

function chathud:NewLine()
	local new_line = table_copy(base_line)
	new_line.Index = table_insert(self.Lines, new_line)

	-- we never want to display that many lines
	if #self.Lines > 50 then
		table_remove(self.Lines, 1)
	end

	self:InvalidateLayout()

	return new_line
end

function chathud:InvalidateLayout()
	local line_count, total_height = #self.Lines, 0
	-- process from bottom to top (most recent to ancient)
	for i=line_count, 1, -1 do
		local line = self.Lines[i]
		line.Size.W = 0
		line.Index = i

		for _, component in ipairs(line.Components) do
			component:ComputeSize()

			component.Pos.X = chathud.Pos.X + line.Size.W
			line.Size.W = line.Size.W + component.Size.W

			-- update line height to the tallest possible
			if component.Size.H > line.Size.H then
				line.Size.H = component.Size.H
			end
		end

		total_height = total_height + line.Size.H
		line.Pos = { X = chathud.Pos.X, Y = chathud.Pos.Y + chathud.Size.H - total_height }

		for _, component in ipairs(line.Components) do
			component.Pos.Y = line.Pos.Y
		end
	end
end

function chathud:PushPartComponent(name, ...)
	local part = self.Parts[name]
	if not part then return end

	local component = table_copy(part):Ctor(...)

	local line = self.Lines[#self.Lines]
	--[[if line.Size.W + component.Size.W > self.Size.W then
		if component.Type == "text" then
			-- line breaking HERE
		else
			-- insert new line for everything else than text with width?
		end
	else]]--
		component.Pos = { X = line.Pos.X + line.Size.W, Y = line.Pos.Y }
		table_insert(line.Components, component)

		-- need to update width for inserting next components properly
		line.Size.W = line.Size.W + component.Size.W
	--end
end

--[[-----------------------------------------------------------------------------
	Actual ChatHUD drawing here
]]-------------------------------------------------------------------------------
local draw_context = {
	MatrixCount = 0,
	DefaultColor = Color(255, 255, 255),
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
	--if hook_run("HUDShouldDraw","CHudChat") == false then return end
	for _, line in ipairs(self.Lines) do
		line:Draw(draw_context)
	end

	-- this is done here so we can freely draw without odd behaviors
	if self.ShouldClean then
		for i, line in ipairs(self.Lines) do
			if line.ShouldRemove then
				table_remove(self.Lines, i)
			end
		end
		self.ShouldClean = false
		self:InvalidateLayout()
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

local function color_to_expr(c)
	return string_replace(tostring(c), " ", ",")
end

function chathud:PushString(str)
	local str_parts = string_explode(self.TagPattern, str, true)
	local enumerator = string_gmatch(str, self.TagPattern)
	local i = 1
	for tag, content in enumerator do
		self:PushPartComponent("text", str_parts[i])
		i = i + 1

		local part = self.Parts[tag]
		if part and part.Usable then
			self:PushPartComponent(tag, content)
		end
	end

	self:PushPartComponent("text", str_parts[#str_parts])
end

function chathud:Clear()
	self.Lines = {}
end

function chathud:AddText(...)
	local args = { ... }
	self:NewLine()
	for _, arg in ipairs(args) do
		local t = type(arg)
		if t == "Player" then
			local team_color = team.GetColor(arg:Team())
			self:PushPartComponent("color", color_to_expr(team_color))
			self:PushString(arg:Nick())
		elseif t == "table" and is_color(arg) then
			self:PushPartComponent("color", color_to_expr(arg))
		elseif t == "string" then
			self:PushString(arg)
		else
			self:PushString(tostring(arg))
		end
	end
	self:PushPartComponent("stop")
	self:InvalidateLayout()
end

-- testing
chat.MetaAddText = chat.MetaAddText or chat.AddText
function chat.AddText(...)
	chathud:AddText(...)
	chat.MetaAddText(...)
end

_G.ChatHUD = chathud