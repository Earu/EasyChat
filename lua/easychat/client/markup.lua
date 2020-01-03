local chathud = _G.EasyChat.ChatHUD
if not chathud then return end

local clean_chathud = {}
for k,v in pairs(chathud) do
	clean_chathud[k] = v
end
clean_chathud.Pos = { X = 0, Y = 0 }
clean_chathud.Size = { W = maxwidth or 9999, H = 0 }
clean_chathud:Clear()

local smoothed_parts = {
	text = true,
	emote = true,
}
local ec_markup = {}
function ec_markup.Parse(str, maxwidth, is_ply_nick)
	local obj = table.Copy(clean_chathud)
	obj.Size.W = maxwidth or 9999
	obj.DrawContext = obj:CreateDrawContext()

	local old_CreateComponent = obj.CreateComponent
	function obj:CreateComponent(name, ...)
		local component = old_CreateComponent(self, name, ...)
		if smoothed_parts[name] and component then
			-- disable smoothing of some parts
			function component:ComputePos()
				self.RealPos.Y = self.Pos.Y
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
		local w = 0
		for _, line in ipairs(self.Lines) do
			if line.Size.W > w then
				w = line.Size.W
			end
		end

		return w
	end
	obj.GetWidth = obj.GetWide

	function obj:GetTall()
		local h = 0
		for _, line in ipairs(self.Lines) do
			h = h + line.Size.H
		end

		return h
	end
	obj.GetHeight = obj.GetTall

	obj.Size = setmetatable(obj.Size, {
		__call = function()
			return obj:GetWide(), obj:GetTall()
		end
	})

	local old_Draw = obj.Draw
	function obj:Draw(x, y)
		if x and y then
			self:SetPos(x, y)
		end
		old_Draw(self)
	end

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

_G.ECMarkup = markup.Parse
_G.ec_markup = ec_markup