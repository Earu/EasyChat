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
	self._click_list = {}

	self.InsertClickableTextStart = function(self, value)
		local prev = self._click_list[#self._click_list]

		table.insert(self._click_list, {value, prev, false})

		if #self._click_list > 1024 then
			table.Empty(self._click_list[1])
			table.remove(self._click_list, 1)
		end

		old_insert_clickable_text_start(self, value)
		local parent = self:GetParent()
	end
end

-- compat for RichTextX
function PANEL:AppendImageURL(url)
end

function PANEL:OnChildAdded(clickpanel)
	if clickpanel:GetClassName() == "ClickPanel" then
		local now = RealTime()
		if not next(self._click_list) then return end
		local click_data = self._click_list[#self._click_list]
		if not click_data or next(click_data) == nil then return end
		local signal_value, click_data_prevpos, clickpanel_old = unpack(click_data)
		click_data[3] = clickpanel
		clickpanel._click_data = click_data
		clickpanel.signal_value = signal_value
		self._think_dirty = true

		for i = 1, 1024 do
			print("SHIFT", i, signal_value, click_data_prevpos and click_data_prevpos[1])
			-- oops, linkpanels got the wrong linkage, shift them backwards
			if not IsValid(clickpanel_old) then break end
			clickpanel = clickpanel_old
			click_data = click_data_prevpos
			if not click_data or next(click_data) == nil then return end
			signal_value, click_data_prevpos, clickpanel_old = unpack(click_data)
			click_data[3] = clickpanel -- rewrite this
			clickpanel._click_data = click_data
			clickpanel.signal_value = signal_value
		end
	end
end

-- for overrides
function PANEL:OnTextHover(text_value, is_hover)
	--print("OnTextHover", self, text_value, is_hover)
end

function PANEL:CleanupDirtyClickList()
	local data = self._click_list[#self._click_list]
	if not data then return end
	if not data[3] then return end -- haven't assigned all of them yet
	-- latest one has been assigned, the old ones stand no chance of being reassigned
	print("emptying _click_list, len=", table.Count(self._click_list))

	for i = 1, 1025 do
		local data = self._click_list[i]
		if not data then break end
		table.Empty(data)
	end

	table.Empty(self._click_list)
end

function PANEL:ThinkLinkHover()
	if self._think_dirty then
		self._think_dirty = false
		self:CleanupDirtyClickList()
	end

	local hover = vgui.GetHoveredPanel()

	if not hover or hover:GetClassName() ~= "ClickPanel" then
		self._link_hovering = false
		local signal_value = self._last_hover_signal_value

		if signal_value then
			self._last_hover_signal_value = nil
			self:OnTextHover(signal_value, false)
		end

		return
	end

	if hover:GetParent() ~= self then return end
	if self._link_hovering == hover then return end
	self._link_hovering = hover

	if self._last_hover_signal_value then
		local signal_value = self._last_hover_signal_value
		self._last_hover_signal_value = nil
		self:OnTextHover(signal_value, false)
	end

	local signal_value = hover.signal_value
	if not signal_value then return end
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
	frame:SetSizable(true)
	frame:SetVisible(false) -- BUG: Set to false to break hovering links (only created when visible)
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

	richtext:InsertColorChange(255, 255, 224, 255)
	richtext:InsertClickableTextStart("https://example.co")
	richtext:AppendText("AWESOME -1")
	richtext:InsertClickableTextEnd()
	richtext:AppendText(" -DIVIDER_ ")
	richtext:InsertColorChange(255, 255, 224, 255)
	richtext:InsertClickableTextStart("https://example.com/")
	richtext:AppendText(" AWESOME 0")
	richtext:InsertClickableTextEnd()
	richtext:AppendText("\n")

	timer.Simple(0.1, function()
		-- Text segment #2 (light yellow)
		richtext:InsertColorChange(255, 255, 224, 255)
		richtext:InsertClickableTextStart("https://example.com/1")
		richtext:AppendText("AWESOME 1")
		richtext:InsertClickableTextEnd()
		richtext:AppendText("\n")
		richtext:AppendText("\n")
		richtext:AppendText("\n")
		richtext:InsertClickableTextStart("https://example.com/22")
		richtext:AppendText("AWESOME 2 ")
		richtext:InsertClickableTextEnd()
		richtext:AppendText("\n")
		richtext:AppendText("\n")
		richtext:InsertClickableTextStart("https://example.com/333")
		richtext:AppendText("AWESOME 3 ")
		richtext:InsertClickableTextEnd()
		richtext:AppendText("\n")
		-- Text segment #3 (red ESRB notice localized string)
		richtext:InsertColorChange(255, 64, 64, 255)
		richtext:AppendText("#ServerBrowser_ESRBNotice")
	end)

	timer.Simple(3, function()
		frame:SetVisible(true)

		timer.Simple(0.1, function()
			richtext:AppendText("\n")
			richtext:InsertClickableTextStart("https://example.com/4444")
			richtext:AppendText("AWESOME 4 ")
			richtext:InsertClickableTextEnd()
			richtext:AppendText(" -divider is required- ")
			richtext:InsertClickableTextStart("https://example.com/55555")
			richtext:AppendText("AWESOME 5 ")
			richtext:InsertClickableTextEnd()
			richtext:AppendText("\n")
		end)
	end)
end

if false then
	-- BAD
	for i = 1, 3 do
		timer.Simple(3 + i, function()
			for j = 1, 2 do
				hook.Run("OnPlayerChat", table.Random(player.GetHumans()), "testing https://example.com hmm state=" .. i .. '-' .. j)
			end
		end)
	end
end

if false then
	-- GOOD
	for i = 1, 3 do
		timer.Simple(3 + i, function()
			for j = 1, 2 do
				hook.Run("OnPlayerChat", table.Random(player.GetHumans()), "testing without links. state=" .. i .. '-' .. j)
			end
		end)
	end
end
