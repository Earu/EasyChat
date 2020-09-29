local surface_SetDrawColor = _G.surface.SetDrawColor
local surface_SetMaterial = _G.surface.SetMaterial
local surface_DrawTexturedRect = _G.surface.DrawTexturedRect
local surface_DrawRect = _G.surface.DrawRect
local surface_DrawOutlinedRect = _G.surface.DrawOutlinedRect
local surface_DrawLine = _G.surface.DrawLine

local color_white = color_white

local PICKER = {
	Init = function(self)
		self.Categories = {}
		self:SetSize(200, 300)
		self:SetKeyboardInputEnabled(true)

		self.Search = self:Add("DTextEntry")
		self.Search:SetTall(25)
		self.Search:Dock(TOP)
		self.Search:SetZPos(9999)
		self.Search:DockMargin(5, 5, 5, 10)
		self.Search.OnChange = function(text_entry)
			local search = text_entry:GetText()
			-- dont search while typing?
			timer.Create("ECEmotePickerSearch", 0.5, 1, function()
				if not IsValid(self) then return end
				self:Populate(search)
			end)
		end

		local black_color = Color(0, 0, 0)
		self.Search.Paint = function(self, w, h)
			surface_SetDrawColor(color_white)
			surface_DrawRect(0, 0, w, h)
			self:DrawTextEntryText(black_color, EasyChat.OutlayColor, black_color)
		end

		self.ScrollPanel = self:Add("DScrollPanel")
		self.ScrollPanel:Dock(FILL)
		self.ScrollPanel.Paint = function() end

		if not EasyChat.UseDermaSkin then
			self.Paint = function(_, w, h)
				surface_SetDrawColor(EasyChat.TabColor)
				surface_DrawRect(0, 0, w, h)

				local line_col =
					EasyChat.OutlayOutlineColor.a == 0
						and EasyChat.OutlayColor
						or EasyChat.OutlayOutlineColor
				surface_SetDrawColor(line_col)
				surface_DrawOutlinedRect(0, 0, w, h)
			end

			local scrollbar = self.ScrollPanel:GetVBar()
			scrollbar:SetHideButtons(true)
			scrollbar.Paint = function(_, _, h)
				surface_SetDrawColor(EasyChat.OutlayColor)
				surface_DrawLine(0, 0, 0, h)
			end

			scrollbar.btnGrip.Paint = function(_, w, h)
				local outlay_col = EasyChat.OutlayColor
				surface_SetDrawColor(outlay_col.r, outlay_col.g, outlay_col.b, 150)
				surface_DrawRect(0, 0, w, h)
			end
		else
			self.Paint = function(self, w, h)
				derma.SkinHook("Paint", "Frame", self, w, h)
			end
		end

		self:Populate()
	end,
	MouseInBounds = function(self)
		local x, y = self:LocalToScreen(0, 0)
		local mouse_x, mouse_y = gui.MouseX(), gui.MouseY()

		return mouse_x >= x and mouse_x <= x + self:GetWide()
			and mouse_y >= y and mouse_y <= y + self:GetTall()
	end,
	-- meant for override
	OnEmoteClicked = function(self, emote_name)
	end,
	Populate = function(self, search)
		search = (search or ""):Trim()
		no_search = search == ""

		for category_name, category_panel in pairs(self.Categories) do
			category_panel:Remove()
			self.Categories[category_name] = nil
		end

		local providers = list.Get("EasyChatEmoticonProviders")
		for lookup_name, lookup_table in pairs(EasyChat.GetEmoteLookupTables()) do
			if providers[lookup_name] then
				local category = self.ScrollPanel:Add("DCollapsibleCategory")
				category:Dock(TOP)
				category:DockMargin(5, 2, 5, 0)
				category:SetExpanded(not no_search)

				if not EasyChat.UseDermaSkin then
					category.Header.Paint = function(_, w, h)
						surface_SetDrawColor(EasyChat.OutlayColor)
						surface_DrawRect(0, 0, w, h)
					end
				end

				local category_panel = self.ScrollPanel:Add("DScrollPanel")
				category_panel:Dock(TOP)

				local category_list = category_panel:Add("DIconLayout")
				category_list:Dock(TOP)
				category_list:SetSpaceY(5)
				category_list:SetSpaceX(5)

				local i = 1
				for emote_name, _ in pairs(lookup_table) do
					if i >= 50 then break end -- lets stop adding
					if (not no_search and emote_name:match(search)) or no_search then
						local succ, emote = pcall(function() return providers[lookup_name](emote_name) end)
						if succ and emote ~= false then
							local set_emote_material = function() end
							if type(emote) == "IMaterial" then
								set_emote_material = function() surface_SetMaterial(emote) end
							elseif emote == nil then
								set_emote_material = function()
									local mat = providers[lookup_name](emote_name)
									if mat then surface_SetMaterial(mat) end
								end
							end

							local emote_panel = category_list:Add("DButton")
							emote_panel:DockMargin(0, 5, 0, 0)
							emote_panel:SetSize(30, 30)
							emote_panel:SetText("")
							emote_panel:SetTooltip(emote_name)
							emote_panel.Paint = function(_, w, h)
								surface_SetDrawColor(color_white)
								set_emote_material()
								surface_DrawTexturedRect(0, 0, w, h)
							end
							emote_panel.DoClick = function()
								self:OnEmoteClicked(emote_name, lookup_name)
							end

							i = i + 1
						end
					end
				end

				local emote_count = no_search and table.Count(lookup_table) or i
				category:SetLabel(("%s (%d emotes)"):format(lookup_name, emote_count - 1))
				category:SetContents(category_panel)
				self.Categories[lookup_name] = category
			end
		end

		self:InvalidateChildren(true)
	end,
}

vgui.Register("ECEmotePicker", PICKER, "EditablePanel")