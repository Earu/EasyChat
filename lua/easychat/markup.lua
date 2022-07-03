local chathud = _G.EasyChat.ChatHUD
if not chathud then return end

local clean_chathud = {}
for k,v in pairs(chathud) do
	clean_chathud[k] = v
end
clean_chathud.Pos = { X = 0, Y = 0 }
clean_chathud.Size = { W = 9999, H = 0 }
clean_chathud:Clear()

local smoothed_parts = {
	text = true,
	emote = true,
}
local ec_markup = {}
function ec_markup.AdvancedParse(str, data)
	str = str or ""

	local is_ply_nick = data.nick or false
	local obj = table.Copy(clean_chathud)
	obj.Size = { W = data.maxwidth or 9999, H = 0 }

	obj.DefaultColor = data.default_color or obj.DefaultColor

	if data.default_font then
		obj.DefaultFont = data.default_font
		if data.default_shadow_font then
			obj.DefaultShadowFont = data.default_shadow_font
		else
			-- let the chathud create the shadow
			str = ("<font=%s>"):format(data.default_font) .. str
		end
	end

	local old_CreateComponent = obj.CreateComponent
	function obj:CreateComponent(name, ...)
		local component = old_CreateComponent(self, name, ...)
		if not component then return end

		if smoothed_parts[name] then
			-- disable smoothing of some parts
			function component:ComputePos()
				self.RealPos.Y = self.Pos.Y
			end
		end

		if data.no_shadow then
			if name == "text" then
				component.DrawShadow = function() end
			end
		else
			if data.shadow_intensity then
				data.shadow_intensity = math.max(1, data.shadow_intensity)

				local shadow_col = Color(0, 0, 0, 255)
				local surface_SetTextColor = surface.SetTextColor
				local surface_SetFont = surface.SetFont
				local surface_SetTextPos = surface.SetTextPos
				local surface_DrawText = surface.DrawText

				function component:DrawShadow(ctx)
					surface_SetTextColor(shadow_col)
					surface_SetFont(self.ShadowFont and self.ShadowFont or self.HUD.DefaultShadowFont)

					local x, y = self:GetTextDrawPos(ctx)
					for _ = 1, data.shadow_intensity do
						surface_SetTextPos(x, y)
						surface_DrawText(self.Content)
					end
				end
			end
		end

		return component
	end

	local old_CreateLine = obj.CreateLine
	function obj:CreateLine()
		local line = old_CreateLine(self)
		line.Fading = false
		return line
	end

	function obj:SetPos(x, y)
		if self.Pos.X == x and self.Pos.Y == y then return end

		self.Pos = { X = x, Y = y + self:GetTall() }
		self:InvalidateLayout()
	end

	function obj:GetWide()
		if self.ComputedWidth then return self.ComputedWidth end

		local w = 0
		for _, line in ipairs(self.Lines) do
			if line.Size.W > w then
				w = line.Size.W
			end
		end

		self.ComputedWidth = w
		return w
	end
	obj.GetWidth = obj.GetWide

	function obj:GetTall()
		if self.ComputedHeight then return self.ComputedHeight end

		local h = 0
		for _, line in ipairs(self.Lines) do
			h = h + line.Size.H
		end

		self.ComputedHeight = h
		return h
	end
	obj.GetHeight = obj.GetTall

	local old_InvalidateLayout = obj.InvalidateLayout
	function obj:InvalidateLayout()
		old_InvalidateLayout(self)

		self.ComputedWidth = nil
		self.ComputedHeight = nil
	end

	obj.Size = setmetatable(obj.Size, {
		__call = function()
			return obj:GetWide(), obj:GetTall()
		end
	})

	local old_Draw = obj.Draw
	function obj:Draw(x, y)
		if SERVER then return end

		if x and y then
			self:SetPos(x, y)
		end
		old_Draw(self)
	end

	function obj:GetText()
		if self.CachedGetText then return self.CachedGetText end

		local text = ""
		for i, line in ipairs(self.Lines) do
			for _, component in ipairs(line.Components) do
				if component.Type == "text" then
					text = text .. component.Content
				end
			end

			if i < #self.Lines then
				text = text .. "\n"
			end
		end

		self.CachedGetText = text
		return self.CachedGetText
	end

	function obj:GetString()
		local ret = ""
		for _, line in ipairs(self.Lines) do
			for _, component in ipairs(line.Components) do
				ret = ret .. component:ToString()
			end
		end

		return ret
	end

	obj.DrawContext = obj:CreateDrawContext()

	obj:NewLine()
	if is_ply_nick then
		obj:AppendNick(str)
	else
		obj:AppendText(str)
	end
	obj:PushPartComponent("stop")
	obj:InvalidateLayout()

	return obj
end

function ec_markup.Parse(str, maxwidth, is_ply_nick, default_color, default_font, default_shadow_font)
	return ec_markup.AdvancedParse(str, {
		maxwidth = maxwidth,
		nick = is_ply_nick,
		default_color = default_color,
		default_font = default_font,
		default_shadow_font = default_shadow_font,
	})
end

local player_cache = {}
local function clear_cache(id)
	local sub_cache = player_cache[id]
	for ply, _ in pairs(sub_cache) do
		if not ply:IsValid() then
			sub_cache[ply] = nil
		end
	end
end

local default_mk = ec_markup.Parse("???", nil, true)
function ec_markup.CachePlayer(id, ply, callback)
	if not id or not IsValid(ply) or not isfunction(callback) then
		return default_mk
	end

	local sub_cache
	if not player_cache[id] then
		sub_cache = {}
		player_cache[id] = sub_cache
	else
		sub_cache = player_cache[id]
	end

	local nick, team_color = ply:RichNick(), team.GetColor(ply:Team())
	local cache = sub_cache[ply]
	if cache and cache.Nick == nick and cache.TeamColor == team_color then
		return cache.Markup
	end

	clear_cache(id)
	local mk = callback()
	if not mk then return default_mk end

	sub_cache[ply] = { Markup = mk, Nick = nick, TeamColor = team_color }

	return mk
end

function ec_markup.GetText(str, is_nick)
	return ec_markup.Parse(str, nil, is_nick):GetText()
end

_G.ECMarkup = ec_markup.Parse
_G.ec_markup = ec_markup