local PANEL = {}

function PANEL:Init()
	local last_color = self:GetFGColor()
	local old_insert_color_change = self.InsertColorChange

	self.InsertColorChange = function(self, r, g, b, a)
		last_color = istable(r) and Color(r.r, r.g, r.b) or Color(r, g, b)
		old_insert_color_change(self, last_color.r, last_color.g, last_color.b, last_color.a)
	end

	self.GetLastColorChange = function(self) return last_color end
	local old_is_hovered = self.IsHovered
	self.IsHovered = function(self) return old_is_hovered(self) or self:IsChildHovered() end
	--  HACK: determine whether a clickable segment of text is being hovered or not
	local old_insert_clickable_text_start = self.InsertClickableTextStart

	self.InsertClickableTextStart = function(self, value)
		--TODO: should this be a queue?
		self._link_clickable_value = value
		self._link_clickable_time = RealTime()
		old_insert_clickable_text_start(self, value)
		local parent = self:GetParent()
	end
end

-- compat for RichTextX
function PANEL:AppendImageURL(url)
end

function PANEL:OnChildAdded(child)
	if child:GetClassName() == "ClickPanel" then
		local now = RealTime()
		local signal_value = self._link_clickable_value

		if signal_value and now - (self._link_clickable_time or 0) < 0.1 then
			child.signal_value = signal_value
			self._link_clickable_value = nil
			self._link_clickable_time = nil
		end
	end
end

-- for overrides
function PANEL:OnTextHover(text_value, is_hover)
	--print("OnTextHover", self, text_value, is_hover)
end

function PANEL:ThinkLinkHover()
	local hover = vgui.GetHoveredPanel()

	if not hover or hover:GetClassName() ~= "ClickPanel" then
		local signal_value = self._last_hover_signal_value

		if signal_value then
			self._last_hover_signal_value = nil
			self:OnTextHover(signal_value, false)
		end

		return
	end

	if hover:GetParent() ~= self then return end
	if self._link_hovering == hover then return end
	local old_link = self._link_hovering
	self._link_hovering = hover
	local signal_value = hover.signal_value
	if not signal_value then return end

	if self._last_hover_signal_value then
		-- TODO: store signal_
		self:OnTextHover(self._last_hover_signal_value, false)
	end

	self._last_hover_signal_value = signal_value
	self:OnTextHover(signal_value, true)
end

function PANEL:Think()
	--self.BaseClass.Think(self)
	local now = RealTime()
	local nt = self._next_think_hover or 0
	if nt > now then return end
	self._next_think_hover = now + 0.1
	self:ThinkLinkHover()
end

vgui.Register("RichTextLegacy", PANEL, "RichText")

if false then
	if IsValid(_G.TESTDFRAME) then
		_G.TESTDFRAME:Remove()
	end

	local frame = vgui.Create'DFrame'
	frame:Center()
	frame:SetVisible(true) -- BUG: Set to false to break hovering links (only created when visible)
	--frame:MakePopup()
	_G.TESTDFRAME = frame
	frame:SetSize(512, 512)
	local richtext = vgui.Create("RichTextLegacy", frame)
	richtext:Dock(FILL)
	-- Text segment #1 (grayish color)
	richtext:InsertColorChange(192, 192, 192, 255)
	richtext:AppendText("This \nRichText \nis \n")

	function richtext:OnTextHover(text_value, is_hover)
		print("OnTextHover", self, text_value, is_hover)
	end

	timer.Simple(0.1, function()
		-- Text segment #2 (light yellow)
		richtext:InsertColorChange(255, 255, 224, 255)
		richtext:InsertClickableTextStart("https://example.com/1")
		richtext:AppendText("AWESOME 1")
		richtext:InsertClickableTextEnd()
		richtext:AppendText("\n")
		richtext:AppendText("\n")
		richtext:AppendText("\n")
		richtext:InsertClickableTextStart("https://example.com/2")
		richtext:AppendText("AWESOME 2 ")
		richtext:InsertClickableTextEnd()
		richtext:AppendText("\n")
		-- Text segment #3 (red ESRB notice localized string)
		richtext:InsertColorChange(255, 64, 64, 255)
		richtext:AppendText("#ServerBrowser_ESRBNotice")
	end)

	timer.Simple(3, function()
		frame:SetVisible(true)
	end)
end
