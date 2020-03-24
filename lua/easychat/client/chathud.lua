--[[-----------------------------------------------------------------------------
	Micro Optimization
]]-------------------------------------------------------------------------------
local ipairs, pairs, tonumber, select = _G.ipairs, _G.pairs, _G.tonumber, _G.select
local Color, Vector, Matrix = _G.Color, _G.Vector, _G.Matrix
local type, tostring, RealFrameTime, ScrH, RealTime = _G.type, _G.tostring, _G.RealFrameTime, _G.ScrH, _G.RealTime
local select, setfenv, CompileString, unpack = _G.select, _G.setfenv, _G.CompileString, _G.unpack

local table_copy = _G.table.Copy
local table_insert = _G.table.insert
local table_remove = _G.table.remove
local table_sort = _G.table.sort
local table_concat = _G.table.concat

local surface_SetDrawColor = _G.surface.SetDrawColor
local surface_SetTextColor = _G.surface.SetTextColor
local surface_GetTextSize = _G.surface.GetTextSize
local surface_DrawOutlinedRect = _G.surface.DrawOutlinedRect
local surface_SetFont = _G.surface.SetFont
local surface_SetTextPos = _G.surface.SetTextPos
local surface_DrawText = _G.surface.DrawText
local surface_CreateFont = _G.surface.CreateFont
local surface_GetLuaFonts = _G.surface.GetLuaFonts
local surface_SetMaterial = _G.surface.SetMaterial
local surface_DrawTexturedRect = _G.surface.DrawTexturedRect

local draw_GetFontHeight = _G.draw.GetFontHeight
local draw_NoTexture = _G.draw.NoTexture

local gui_mousex = _G.gui.MouseX
local gui_mousey = _G.gui.MouseY

--local render_OverrideBlend = _G.render.OverrideBlend
--local BLEND_ZERO, BLEND_ONE_MINUS_SRC_ALPHA = _G.BLEND_ZERO, _G.BLEND_ONE_MINUS_SRC_ALPHA
--local BLENDFUNC_ADD, BLENDFUNC_SUBTRACT = _G.BLENDFUNC_ADD, _G.BLENDFUNC_SUBTRACT

local math_max = _G.math.max
local math_min = _G.math.min
local math_floor = _G.math.floor
local math_clamp = _G.math.Clamp
local math_abs = _G.math.abs
local math_EaseInOut = _G.math.EaseInOut

local cam_PopModelMatrix = _G.cam.PopModelMatrix
local cam_PushModelMatrix = _G.cam.PushModelMatrix

local hook_run = _G.hook.Run

local string_explode = _G.string.Explode
local string_gmatch = _G.string.gmatch
local string_replace = _G.string.Replace
local string_sub = _G.string.sub
local string_len = _G.string.len
local string_find = _G.string.find
local string_format = _G.string.format
local string_lower = _G.string.lower
local string_find = _G.string.find
local string_gsub = _G.string.gsub
local string_match = _G.string.match
local string_byte = _G.string.byte

local utf8_force = utf8.force

local chat_GetPos = chat.GetChatBoxPos
local chat_GetSize = chat.GetChatBoxSize

--[[-----------------------------------------------------------------------------
	Base ChatHUD
]]-------------------------------------------------------------------------------

local CUSTOM_FONT_SETTINGS_PATH = "easychat/chud_font_settings.txt"
local SHADOW_FONT_BLURSIZE = 1
local SMOOTHING_SPEED = 1000
local MAX_TEXT_OFFSET = 400
local MAX_IMAGE_WIDTH = 250

-- this is used later for creating shadow fonts properly
local engine_fonts_info = {}
if file.Exists("sourceengine/resource/clientscheme.res", "BASE_PATH") then
	local content = file.Read("sourceengine/resource/clientscheme.res", "BASE_PATH")
	local key_values = util.KeyValuesToTable(content)
	engine_fonts_info = key_values.fonts
end

engine_fonts_info["dermalarge"] = {
	name = "Roboto",
	tall = 32,
	weight = 550,
	antialias = 1,
}

engine_fonts_info["dermadefault"] = {
	name = "Tahoma",
	tall = 13,
	weight = 500,
	antialias = 1,
}

engine_fonts_info["dermadefaultbold"] = {
	name = "Tahoma",
	tall = 13,
	weight = 600,
}

local chathud = {
	FadeTime = 16,
	-- default bounds for EasyChat
	Pos = { X = 0, Y = 0 },
	Size = { W = 400, H = 0 },
	Lines = {},
	Parts = {},
	SpecialPatterns = {},
	EmotePriorities = {},
	TagPattern = "<(.-)=%[?(.-)%]?>",
	ShouldClean = false,
	DefaultColor = Color(255, 255, 255),
	DefaultFont = "ECHUDDefault",
	DefaultShadowFont = "ECHUDShadowDefault",
}

local EC_HUD_TTL = GetConVar("easychat_hud_ttl")
chathud.FadeTime = EC_HUD_TTL:GetInt()

cvars.AddChangeCallback(EC_HUD_TTL:GetName(), function()
	chathud.FadeTime = EC_HUD_TTL:GetInt()
end)

function chathud:ApplyCustomFontSettings()
	if not file.Exists(CUSTOM_FONT_SETTINGS_PATH, "DATA") then return end

	local json = file.Read(CUSTOM_FONT_SETTINGS_PATH, "DATA")
	local data = util.JSONToTable(json)
	local shadow_data = table_copy(data)
	shadow_data.blursize = SHADOW_FONT_BLURSIZE

	surface_CreateFont(self.DefaultFont, data)
	surface_CreateFont(self.DefaultShadowFont, shadow_data)

	-- when this is called early, this function might not exists
	if self.InvalidateLayout then
		self:InvalidateLayout()
	end
end

function chathud:UpdateFontSize(size)
	surface_CreateFont(self.DefaultFont, {
		font = "Roboto",
		extended = true,
		size = size,
		weight = 530,
		shadow = true,
		read_speed = 100,
	})

	surface_CreateFont(self.DefaultShadowFont, {
		font = "Roboto",
		extended = true,
		size = size,
		weight = 530,
		shadow = true,
		blursize = SHADOW_FONT_BLURSIZE,
		read_speed = 100,
	})

	self:ApplyCustomFontSettings()
end

chathud:UpdateFontSize(16)

-- taken from https://github.com/notcake/glib/blob/master/lua/glib/unicode/utf8.lua#L15
local function utf8_byte(char, offset)
	if char == "" then return -1 end
	offset = offset or 1

	local byte = string_byte(char, offset)
	local length = 1
	if byte >= 128 then
		-- multi-byte sequence
		if byte >= 240 then
			-- 4 byte sequence
			length = 4
			if #char < 4 then return -1, length end
			byte = (byte % 8) * 262144
			byte = byte + (string_byte(char, offset + 1) % 64) * 4096
			byte = byte + (string_byte(char, offset + 2) % 64) * 64
			byte = byte + (string_byte(char, offset + 3) % 64)
		elseif byte >= 224 then
			-- 3 byte sequence
			length = 3
			if #char < 3 then return -1, length end
			byte = (byte % 16) * 4096
			byte = byte + (string_byte(char, offset + 1) % 64) * 64
			byte = byte + (string_byte(char, offset + 2) % 64)
		elseif byte >= 192 then
			-- 2 byte sequence
			length = 2
			if #char < 2 then return -1, length end
			byte = (byte % 32) * 64
			byte = byte + (string_byte(char, offset + 1) % 64)
		else
			-- this is a continuation byte
			-- invalid sequence
			byte = -1
		end
	else
		-- single byte sequence
	end
	return byte, length
end

-- taken from https://github.com/notcake/glib/blob/master/lua/glib/unicode/utf8.lua#L182
local function utf8_len(str)
	local _, length = string_gsub(str, "[^\128-\191]", "")
	return length
end

local function utf8_sub(str, i, j)
	j = j or -1

	local pos = 1
	local bytes = #str
	local length = 0

	-- only set l if i or j is negative
	local l = (i >= 0 and j >= 0) or utf8_len(str)
	local start_char = (i >= 0) and i or l + i + 1
	local end_char   = (j >= 0) and j or l + j + 1

	-- can't have start before end!
	if start_char > end_char then return "" end

	-- byte offsets to pass to string.sub
	local start_byte, end_byte = 1, bytes

	while pos <= bytes do
		length = length + 1

		if length == start_char then
			start_byte = pos
		end

		pos = pos + select(2, utf8_byte(str, pos))

		if length == end_char then
			end_byte = pos - 1
			break
		end
	end

	return string_sub(str, start_byte, end_byte)
end

local EC_HUD_TTL = GetConVar("easychat_hud_ttl")
local EC_HUD_SMOOTH = GetConVar("easychat_hud_smooth")

chathud.FadeTime = EC_HUD_TTL:GetInt()
cvars.AddChangeCallback("easychat_hud_ttl", function(_, _, new)
	chathud.FadeTime = new
end)

cvars.AddChangeCallback("easychat_hud_follow", function()
	chathud:InvalidateLayout()
end)

local default_part = {
	Type = "default",
	Pos = { X = 0, Y = 0 },
	Size =  { W = 0, H = 0 },
	Usable = true,
	OkInNicks = true,
	Enabled = true,
}

function default_part:Ctor()
	self:ComputeSize()
	return self
end

function default_part:ToString()
	return ("<%s=%s>"):format(self.Type, self.TextInput)
end

function default_part:IsHovered()
	local mx = gui_mousex()
	if mx >= self.Pos.X and mx <= self.Pos.X + self.Size.W then
		local my = gui_mousey()
		if my >= self.Pos.Y and my <= self.Pos.Y + self.Size.H then
			return true
		end
	end

	return false
end

-- meant to be overriden
function default_part:LineBreak() end
function default_part:ComputeSize() end
function default_part:Draw(ctx) end
function default_part:Normalize(str) return str end
function default_part:PreLinePush(line, last_index) end
function default_part:PostLinePush() end
function default_part:OnStop() end
function default_part:OnRemove() end

local blacklist = {
	stop = true,
	text = true,
	color = true,
}
function chathud:RegisterPart(name, part, pattern, exception_patterns)
	if not name or not part then return end
	name = string_lower(name)

	local new_part = table_copy(default_part)
	for k, v in pairs(part) do
		new_part[k] = v
	end

	new_part.Type = name

	if pattern then
		self.SpecialPatterns[name] = {
			Pattern = pattern,
			ExceptionPatterns = exception_patterns or {}
		}
	end

	if not blacklist[name] then
		local cvar_name = "easychat_tag_" .. name
		local cvar = CreateClientConVar(cvar_name, new_part.Enabled and "1" or "0", true, false)
		new_part.Enabled = cvar:GetBool()
		cvars.AddChangeCallback(cvar_name, function(_, _, new)
			new_part.Enabled = new
		end)
	end

	self.Parts[name] = new_part
end

--[[-----------------------------------------------------------------------------
	Stop Component

	/!\ NEVER EVER REMOVE OR THE CHATHUD WILL BREAK HORRIBLY /!\

	This guarantees all matrixes and generally every change made
	to the drawing context is set back to a "default" state.
]]-------------------------------------------------------------------------------
local stop_part = {}

function stop_part:Draw(ctx)
	ctx:ResetColors()
	ctx:ResetFont()
	ctx:ResetTextOffset()
	ctx:PopDrawFunctions()
end

chathud:RegisterPart("stop", stop_part, "%<(stop)%>")

--[[-----------------------------------------------------------------------------
	Color Component

	Color modulation with rgb values.
]]-------------------------------------------------------------------------------
local color_part = {}

function color_part:Ctor(str)
	local col_components = string_explode("%s*,%s*", str, true)
	local r, g, b =
		tonumber(col_components[1]) or 255,
		tonumber(col_components[2]) or 255,
		tonumber(col_components[3]) or 255
	self.Color = Color(r, g, b)

	return self
end

function color_part:Draw(ctx)
	ctx:UpdateColor(self.Color)
end

chathud:RegisterPart("color", color_part)

--[[-----------------------------------------------------------------------------
	Font Component

	Font changes.
]]-------------------------------------------------------------------------------
local font_part = {}

function font_part:Ctor(str)
	local succ, _ = pcall(surface_SetFont, str) -- only way to check if a font is valid
	self.Font = succ and str or self.HUD.DefaultFont
	if not succ then
		self.Invalid = true
	elseif self.HUD == EasyChat.ChatHUD and draw_GetFontHeight(self.Font) > 30 then
		self.Invalid = true
	end

	return self
end

function font_part:PreLinePush(line, _)
	if self.Invalid then return end
	line.HasFontTags = true
end

-- we dont need a SetFont call the text part already does it for us
function font_part:Draw() end

chathud:RegisterPart("font", font_part)

--[[-----------------------------------------------------------------------------
	Text Component

	Draws normal text.
]]-------------------------------------------------------------------------------
local text_part = {
	Content = "",
	Font = chathud.DefaultFont,
	Usable = false,
	RealPos = { X = 0, Y = 0 }
}

function text_part:Ctor(content)
	self.Content = utf8_force(content)

	return self
end

function text_part:ToString()
	return self.Content
end

function text_part:SetFont(font)
	self.Font = font
end

function text_part:PreLinePush(line, last_index)
	-- dont waste time trying to find something that does not exist
	if not line.HasFontTags then
		self:SetFont(self.HUD.DefaultFont)
		self:ComputeSize()
		return
	end

	-- look for last font on the same line
	for i = last_index, 1, -1 do
		local component = line.Components[i]
		if component.Type == "font" and not component.Invalid then
			self:SetFont(component.Font)
			self:CreateShadowFont()
			self:ComputeSize()
			return
		elseif component.Type == "stop" then
			self:SetFont(self.HUD.DefaultFont)
			self:ComputeSize()
			return
		end
	end

	local line_index = line.Index or 1 -- 1 if line is not part of the chathud

	-- this is the last line being displayed, nothing before
	if line_index == 1 then
		self:SetFont(self.HUD.DefaultFont)
		self:ComputeSize()
		return
	end

	-- not found, then look for previous lines
	for i = line_index - 1, 1, -1 do
		local line = self.HUD.Lines[i]
		for j = #line.Components, 1, -1 do
			local component = line.Components[j]
			if component.Type == "font" and not component.Invalid then
				self:SetFont(component.Font)
				self:CreateShadowFont()
				self:ComputeSize()
				return
			elseif component.Type == "stop" then
				self:SetFont(self.HUD.DefaultFont)
				self:ComputeSize()
				return
			end
		end
	end

	self:SetFont(self.HUD.DefaultFont)
	self:ComputeSize()
end

function text_part:PostLinePush()
	self.RealPos = table_copy(self.Pos)
end

function text_part:ComputeSize()
	surface_SetFont(self.Font)
	local w, h = surface_GetTextSize(self.Content)
	self.Size = { W = w, H = h }
end

local shadow_fonts = {}
function text_part:CreateShadowFont()
	local name = string_format("ECHUDShadow_%s", self.Font)
	if not shadow_fonts[name] then
		local info = engine_fonts_info[string_lower(self.Font)]
		if info then
			surface_CreateFont(name, {
				font = info.name,
				extended = true,
				size = info.tall,
				weight = info.weight,
				blursize = SHADOW_FONT_BLURSIZE,
				antialias = tobool(info.antialias),
				outline = tobool(info.outline),
			})
		else
			info = surface_GetLuaFonts()[string_lower(self.Font)]
			if info then
				local font_data = table_copy(info)
				font_data.blursize = SHADOW_FONT_BLURSIZE
				surface_CreateFont(name, font_data)
			else
				-- fallback to trying to do something?
				surface_CreateFont(name, {
					font = self.Font,
					extended = true,
					size = draw_GetFontHeight(self.Font),
					blursize = SHADOW_FONT_BLURSIZE,
				})
			end
		end

		shadow_fonts[name] = true
	end

	self.ShadowFont = name
end

function text_part:ComputePos()
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

function text_part:GetTextDrawPos(ctx)
	local offsex_x, offset_y =
		math_clamp(ctx.TextOffset.X, -MAX_TEXT_OFFSET, MAX_TEXT_OFFSET),
		math_clamp(ctx.TextOffset.Y, -MAX_TEXT_OFFSET, MAX_TEXT_OFFSET)
	return self.Pos.X + offsex_x, self.RealPos.Y + offset_y
end

local shadow_col = Color(0, 0, 0, 255)
function text_part:DrawShadow(ctx)
	shadow_col.a = ctx.Alpha
	surface_SetTextColor(shadow_col)
	surface_SetFont(self.ShadowFont and self.ShadowFont or self.HUD.DefaultShadowFont)

	local x, y = self:GetTextDrawPos(ctx)
	for _ = 1, 5 do
		surface_SetTextPos(x, y)
		surface_DrawText(self.Content)
	end
end

function text_part:Draw(ctx)
	self:ComputePos()

	local x, y = self:GetTextDrawPos(ctx)

	-- this is for other components to add shit to our text if necessary
	ctx:CallPreTextDrawFunctions(x, y, self.Size.W, self.Size.H)

	self:DrawShadow(ctx)

	surface_SetTextPos(x, y)
	surface_SetTextColor(ctx.Color)
	surface_SetFont(self.Font)
	surface_DrawText(self.Content)

	-- same here
	ctx:CallPostTextDrawFunctions(x, y, self.Size.W, self.Size.H)
end

function text_part:IsTextWider(text, width)
	surface_SetFont(self.Font)
	local w, _ = surface_GetTextSize(text)
	return w >= width
end

local hard_break_treshold = 10
local breaking_chars = {
	[" "] = true,
	[","] = true,
	["."] = true,
	["\t"] = true,
}

function text_part:FitWidth()
	local last_line = self.HUD:LastLine()
	local left_width = self.HUD.Size.W - last_line.Size.W
	local text = self.Content

	local len = utf8_len(text)
	for i=1, len do
		if self:IsTextWider(utf8_sub(text, 1, i), left_width) then
			local sub_str = utf8_sub(text, i, i)

			-- try n times before hard breaking
			for j=1, hard_break_treshold do
				if breaking_chars[sub_str] then
					-- we found a breaking char, break here
					self.Content = utf8_sub(text, 1, i - j)
					break
				else
					sub_str = utf8_sub(text, i - j, i - j)
				end
			end

			-- check if content is the same, and if it is, hard-break
			if text == self.Content then
				self.Content = utf8_sub(text, 1, i)
			end

			break -- we're done getting our first chunk of text to fit for the last line
		end
	end

	last_line:PushComponent(self)

	-- send back remaining text
	return utf8_sub(text, utf8_len(self.Content) + 1, len)
end

function text_part:LineBreak()
	local remaining_text = self:FitWidth()
	repeat
		local new_line = self.HUD:NewLine()
		local component = self.HUD:CreateComponent("text", remaining_text)
		component.Font = self.Font
		component.ShadowFont = self.ShadowFont
		remaining_text = component:FitWidth()
	until remaining_text == ""
end

chathud:RegisterPart("text", text_part)

--[[-----------------------------------------------------------------------------
	Emote Component

	Displays emotes.
]]-------------------------------------------------------------------------------
local emote_part = {
	SetEmoteMaterial = function() draw_NoTexture() end,
	RealPos = { X = 0, Y = 0 },
	Height = 32,
	HasSetHeight = false,
}

function emote_part:Ctor(str)
	local em_components = string.Explode("%s*,%s*", str, true)
	local name, size = em_components[1], tonumber(em_components[2])
	if size then
		size = math_clamp(size, 16, 64)
		self.Height = size
		self.HasSetHeight = true
	else
		self.Height = draw_GetFontHeight(self.HUD.DefaultFont)
	end

	self:TryGetEmote(name)
	self:ComputeSize()

	return self
end

function emote_part:PreLinePush(line, last_index)
	-- if we have a set valid height by the user dont bother
	if self.HasSetHeight then return end

	-- dont waste time trying to find something that does not exist
	if not line.HasFontTags then return end

	-- look for last font on the same line
	for i = last_index, 1, -1 do
		local component = line.Components[i]
		if component.Type == "font" and not component.Invalid then
			self.Height = draw_GetFontHeight(component.Font)
			self:ComputeSize()
			return
		elseif component.Type == "stop" then return end
	end

	local line_index = line.Index or 1 -- 1 if line is not part of the chathud

	-- this is the last line being displayed, nothing before
	if line_index == 1 then return end

	-- not found, then look for previous lines
	for i = line_index - 1, 1, -1 do
		local line = self.HUD.Lines[i]
		for j = #line.Components, 1, -1 do
			local component = line.Components[j]
			if component.Type == "font" and not component.Invalid then
				self.Height = draw_GetFontHeight(component.Font)
				self:ComputeSize()
				return
			elseif component.Type == "stop" then return end
		end
	end

	self.Height = draw_GetFontHeight(self.HUD.DefaultFont)
	self:ComputeSize()
end

-- the closest the priority is to 1 the more chances it has to display over other matches
function chathud:RegisterEmoteProvider(provider_name, provider_func, priority)
	if type(priority) == "number" and priority > 0 then
		table_insert(self.EmotePriorities, priority, provider_name)
	else
		table_insert(self.EmotePriorities, provider_name)
	end

	list.Set("EasyChatEmoticonProviders", provider_name, provider_func)
end

function emote_part:TryGetEmote(name)
	local providers = list.Get("EasyChatEmoticonProviders")
	local found = false

	-- look for providers with a priority set
	for _, provider in ipairs(self.HUD.EmotePriorities) do
		if providers[provider] then
			local succ, emote = pcall(providers[provider], name)
			if not succ then EasyChat.Print(true, emote) end

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

function emote_part:ComputePos()
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

function emote_part:GetDrawPos(ctx)
	local offsex_x, offset_y =
		math_clamp(ctx.TextOffset.X, -MAX_TEXT_OFFSET, MAX_TEXT_OFFSET),
		math_clamp(ctx.TextOffset.Y, -MAX_TEXT_OFFSET, MAX_TEXT_OFFSET)
	return self.Pos.X + offsex_x, self.RealPos.Y + offset_y
end

function emote_part:PostLinePush()
    self.RealPos = table_copy(self.Pos)
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
	"%d%d:%d%d:%d%d", -- timestamps
	"^FAILED%: .-%:%d%:" -- luadev chat feedback
})

--[[-----------------------------------------------------------------------------
	Image URL Component

	Displays images from urls.
]]-------------------------------------------------------------------------------
local image_part = {
	Usable = false,
	OkInNicks = false,
	ImgWidth = MAX_IMAGE_WIDTH,
	ImgHeight = 0,
}

function image_part:Ctor(url)
	local browser = vgui.Create("DHTML")
	browser:OpenURL(url)
	browser:SetAllowLua(true)
	browser:SetSize(0, 0)
	browser:AddFunction("Img", "Size", function(w, h)
		self.ImgWidth = w
		self.ImgHeight = h

		local perc = self.ImgWidth / MAX_IMAGE_WIDTH
		if perc > 1 then -- rescale
			self.ImgWidth = self.ImgWidth / perc
			self.ImgHeight = self.ImgHeight / perc
		end

		self.HUD:InvalidateLayout()
	end)

	browser:AddFunction("Img", "Remove", function()
		self:OnRemove()
	end)

	function browser:OnDocumentReady()
		self:QueueJavascript([[
			if (!document.rootElement) {
				document.body.style.background = "rgba(0,0,0,0)";
				var img = document.body.getElementsByTagName("img")[0];
				img.style.width = "100%";
				if (img) {
					Img.Size(img.naturalWidth, img.naturalHeight);
				} else {
					Img.Remove();
				}
			} else {
				Img.Remove();
			}
		]])
	end

	function browser:Paint() end

	-- last measure in case its not called somehow?
	timer.Simple(self.HUD.FadeTime + 4, function()
		self:OnRemove()
	end)

	self.Browser = browser
	self:ComputeSize()

	return self
end

function image_part:ComputeSize()
	self.Size = { W = self.ImgWidth, H = self.ImgHeight }
end

function image_part:LineBreak()
	local new_line = self.HUD:NewLine()
	new_line:PushComponent(self)
end

function image_part:GetDrawPos()
	return self.Pos.X, self.RealPos.Y
end

function image_part:PostLinePush()
    self.RealPos = table_copy(self.Pos)
end

function image_part:OnStop()
	if not IsValid(self.Browser) then return end
	self.Browser:Remove()
end
image_part.OnRemove = image_part.OnStop

function image_part:ComputePos()
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

function image_part:Draw(ctx)
	self:ComputePos()

	if not IsValid(self.Browser) then return end
	self.Browser:SetAlpha(ctx.Alpha)

	if self:IsHovered() then
		local w, h = self.ImgWidth * 2, self.ImgHeight * 2
		local x, y = self:GetDrawPos()
		self.Browser:SetSize(w, h)
		self.Browser:SetPos(x, y - self.ImgHeight)
	else
		local x, y = self:GetDrawPos()
		self.Browser:SetSize(self.ImgWidth, self.ImgHeight)
		self.Browser:SetPos(x, y)
	end
end

chathud:RegisterPart("image", image_part)

--[[-----------------------------------------------------------------------------
	ChatHUD layouting
]]-------------------------------------------------------------------------------
local base_line = {
	Components = {},
	Pos = { X = 0, Y = 0 },
	Size = { W = 0, H = 0 },
	LifeTime = 0,
	Alpha = 255,
	Fading = true,
}

function base_line:Update()
	-- dont have fading if you're not used in chathud
	if not self.Index then return end
	if not self.Fading then return end

	if self.LifeTime < RealTime() then
		self.Alpha = self.ShouldRemove and 0
			or math_floor(math_max(self.Alpha - (RealFrameTime() * 100), 0))

		if self.Alpha == 0 then
			self.ShouldRemove = true
			self.HUD.ShouldClean = true
		end
	end
end

function base_line:Draw(ctx)
	self:Update()
	ctx.Alpha = self.Alpha
	for _, component in ipairs(self.Components) do
		component:Draw(ctx)

		if RealTime() - ctx.DrawStart > 0.25 then
			ctx.ShouldDraw = false
			break
		end
	end
end

function base_line:PushComponent(component)
	component.Line = self
	component.Pos = { X = self.Pos.X + self.Size.W, Y = self.Pos.Y }
	component.Index = table_insert(self.Components, component)

	-- need to update width for inserting next components properly
	self.Size.W = self.Size.W + component.Size.W

	component:PostLinePush()
end

function chathud:CreateLine()
	local line = table_copy(base_line)
	line.LifeTime = RealTime() + self.FadeTime
	line.HUD = self

	return line
end

function chathud:NewLine()
	local new_line = self:CreateLine()
	new_line.Index = table_insert(self.Lines, new_line)
	new_line.Pos = { X = self.Pos.X, Y = self.Pos.Y + self.Size.H }

	-- we never want to display that many lines
	if #self.Lines > 50 then
		local oldest_line = self.Lines[1]
		table_remove(self.Lines, 1)

		for _, component in ipairs(oldest_line.Components) do
			component:OnRemove()
		end
	end

	return new_line
end

function chathud:LastLine()
	return self.Lines[#self.Lines]
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

			component.Pos.X = self.Pos.X + line.Size.W
			line.Size.W = line.Size.W + component.Size.W

			-- update line height to the tallest possible
			if component.Size.H > line.Size.H then
				line.Size.H = component.Size.H
			end
		end

		total_height = total_height + line.Size.H
		line.Pos = { X = self.Pos.X, Y = self.Pos.Y + self.Size.H - total_height }

		for _, component in ipairs(line.Components) do
			component.Pos.Y = line.Pos.Y
		end
	end
end

function chathud:CreateComponent(name, ...)
	local part = self.Parts[name]
	if not part then return end

	local copy = table_copy(part)
	copy.HUD = self
	copy.TextInput = table_concat({ ... }, ",")
	return copy:Ctor(...)
end

function chathud:PushPartComponent(name, ...)
	local component = self:CreateComponent(name, ...)
	if not component then return end

	local line = self:LastLine()
	component:PreLinePush(line, #line.Components)
	if line.Size.W + component.Size.W > self.Size.W then
		component:LineBreak()
	else
		line:PushComponent(component)
	end
end

function chathud:PushText(text, multiline)
	if multiline then
		local text_lines = string_explode("\r?\n", text, true)
		self:PushPartComponent("text", text_lines[1])
		table_remove(text_lines, 1)

		for i=1, #text_lines do
			self:NewLine()
			self:PushPartComponent("text", text_lines[i])
		end
	else
		self:PushPartComponent("text", text)
	end
end

local function is_exception_pattern(str, patterns)
	for _, pattern in ipairs(patterns) do
		if string_match(str, pattern) then
			return true
		end
	end

	return false
end

function chathud:NormalizeString(str, is_nick)
	if not str or type(str) ~= "string" then return "" end

	-- valve allows these in player names
	if is_nick then
		str = str:gsub("[\n\t]", "")
	end

	for _, part in pairs(self.Parts) do
		if part.Enabled then
			if (is_nick and part.OkInNicks) or not is_nick then
				str = part:Normalize(str)
			end
		end
	end

	for part_name, part_patterns in pairs(self.SpecialPatterns) do
		if not is_exception_pattern(str, part_patterns.ExceptionPatterns) then
			str = string_gsub(str, part_patterns.Pattern, function(...)
				local args = { ... }
				if #args == 0 then
					return string_format("<%s=>", part_name)
				else
					return string_format("<%s=%s>", part_name, table_concat(args, ","))
				end
			end)
		end
	end

	return str
end

function chathud:PushString(str, is_nick)
	str = self:NormalizeString(str, is_nick)

	local str_parts = string_explode(self.TagPattern, str, true)
	local iterator = string_gmatch(str, self.TagPattern)
	local i = 1
	for tag, content in iterator do
		local part = self.Parts[tag]
		if part and part.Usable and part.Enabled then
			self:PushText(str_parts[i], not is_nick)
			if (is_nick and part.OkInNicks) or not is_nick then
				self:PushPartComponent(tag, content)
			end
		else
			self:PushText(str_parts[i] .. string_format("<%s=%s>", tag, content), not is_nick)
		end

		i = i + 1
	end

	self:PushText(str_parts[#str_parts], not is_nick)
end

function chathud:StopComponents()
	for _, line in ipairs(self.Lines) do
		for _, component in ipairs(line.Components) do
			if not blacklist[component.Type] then
				-- lets try this
				function component:Draw() end
				function component:ComputeSize()
					self.Size = { W = 0, H = 0 }
				end

				component:OnStop()
			end
		end
	end

	self:InvalidateLayout()
end

function chathud:Clear()
	self.Lines = {}
end

--[[-----------------------------------------------------------------------------
	Actual ChatHUD drawing here
]]-------------------------------------------------------------------------------
local draw_context = {
	ShouldDraw = true,
	Color = chathud.DefaultColor,
	TextOffset = { X = 0, Y = 0 },
	PostTextDrawFunctions = {},
	PreTextDrawFunctions = {}
}

function draw_context:UpdateColor(col)
	col.a = self.Alpha
	surface_SetDrawColor(col)
	surface_SetTextColor(col)
	self.Color = col
end

function draw_context:PushTextOffset(offset)
	self.TextOffset.X = self.TextOffset.X + offset.X
	self.TextOffset.Y = self.TextOffset.Y + offset.Y
end

function draw_context:PushPostTextDraw(component)
	if not component.PostTextDraw then return end
	table_insert(self.PostTextDrawFunctions, component)
end

function draw_context:PushPreTextDraw(component)
	if not component.PreTextDraw then return end
	table_insert(self.PreTextDrawFunctions, component)
end

function draw_context:CallPostTextDrawFunctions(x, y, w, h)
	for _, component in ipairs(self.PostTextDrawFunctions) do
		component:PostTextDraw(self, x, y, w, h)
	end
end

function draw_context:CallPreTextDrawFunctions(x, y, w, h)
	for _, component in ipairs(self.PreTextDrawFunctions) do
		component:PreTextDraw(self, x, y, w, h)
	end
end

function draw_context:PopDrawFunctions()
	self.PreTextDrawFunctions = {}
	self.PostTextDrawFunctions = {}
end

function draw_context:ResetColors()
	local default_col = self.HUD.DefaultColor
	surface_SetDrawColor(default_col)
	surface_SetTextColor(default_col)
	self.Color = Color(default_col.r, default_col.g, default_col.b, self.Alpha)
end

function draw_context:ResetFont()
	surface_SetFont(self.HUD.DefaultFont)
end

function draw_context:ResetTextOffset()
	self.TextOffset = { X = 0, Y = 0 }
end

function chathud:CreateDrawContext()
	local ctx = table_copy(draw_context)
	ctx.Color = self.DefaultColor
	ctx.HUD = self

	return ctx
end

chathud.DrawContext = chathud:CreateDrawContext()

function chathud:Draw()
	--if hook_run("HUDShouldDraw", "CHudChat") == false then return end

	self.DrawContext.DrawStart = RealTime()
	for _, line in ipairs(self.Lines) do
		line:Draw(self.DrawContext)

		-- mitigation for very slow rendering
		if not self.DrawContext.ShouldDraw then
			self:Clear()
			EasyChat.Print("/!\\Laggy chathud, emergency clear/!\\")
			self.DrawContext.ShouldDraw = true
			break
		end
	end

	-- this is done here so we can freely draw without odd behaviors
	if self.ShouldClean then
		for i, line in ipairs(self.Lines) do
			if line.ShouldRemove then
				for _, component in ipairs(line.Components) do
					component:OnRemove()
				end

				table_remove(self.Lines, i)
			end
		end
		self.ShouldClean = false
		self:InvalidateLayout()
	end
end

--[[-----------------------------------------------------------------------------
	Input into ChatHUD
]]-------------------------------------------------------------------------------
function chathud:AppendText(txt)
	self:PushString(txt, false)
end

function chathud:AppendNick(nick)
	self:PushString(nick, true)
end

function chathud:AppendImageURL(url)
	if chathud.Parts.image.Enabled then
		self:PushPartComponent("image", url)
	else
		self:PushString(url, false)
	end
end

function chathud:InsertColorChange(r, g, b)
	local expr = ("%d,%d,%d"):format(r, g, b)
	self:PushPartComponent("color", expr)
end

return chathud
