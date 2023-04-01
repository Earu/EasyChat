local surface_SetDrawColor = _G.surface.SetDrawColor
local surface_DrawRect = _G.surface.DrawRect
local surface_DrawOutlinedRect = _G.surface.DrawOutlinedRect

local CHATBOX = {
	Init = function(self)
		local frame = self

		self:ShowCloseButton(true)
		self:SetScreenLock(true)
		self:SetDraggable(true)
		self:SetSizable(true)
		self:SetDeleteOnClose(false)
		self:SetTitle("")
		self:SetMinimumSize(200, 200)

		self.btnClose:Hide()
		self.btnMaxim:Hide()
		self.btnMinim:Hide()

		self.BtnClose = self:Add("DButton")
		self.BtnMaxim = self:Add("DButton")
		self.BtnSettings = self:Add("DButton")
		--self.BtnDonate = self:Add("DButton")
		self.Tabs = self:Add("DPropertySheet")
		self.Scroller = self.Tabs.tabScroller
		self.OldTab = NULL

		self.BtnClose:SetSize(30, 30)
		self.BtnClose:SetZPos(10)
		self.BtnClose:SetFont("DermaDefaultBold")
		self.BtnClose:SetText("X")
		self.BtnClose:SetTooltip("Close")

		self.BtnMaxim:SetSize(30, 33)
		self.BtnMaxim:SetZPos(10)
		self.BtnMaxim:SetFont("DermaLarge")
		self.BtnMaxim:SetText("▭")
		self.BtnMaxim:SetTooltip("Maximize")
		self.BtnMaxim.IsFullScreen = false
		self.BtnMaxim.DoClick = function(self)
			if not self.IsFullScreen then
				local x, y, w, h = frame:GetBounds()
				self.Before = { x = x, y = y, w = w, h = h }
				frame:SetSize(ScrW(), ScrH())
				frame:SetPos(0, 0)
				self.IsFullScreen = true
			else
				frame:SetPos(self.Before.x, self.Before.y)
				frame:SetSize(self.Before.w, self.Before.h)
				self.IsFullScreen = false
			end
		end

		self.BtnSettings:SetSize(30, 29)
		self.BtnSettings:SetZPos(10)
		self.BtnSettings:SetText("")
		self.BtnSettings:SetTooltip("Settings")
		self.BtnSettings:SetImage("icon16/cog.png")
		self.BtnSettings.DoClick = function()
			if not EasyChat.OpenSettings then return end -- too early
			if not IsValid(EasyChat.Settings) then return end

			-- if its already opened close it instead
			if EasyChat.Settings:IsVisible() then
				EasyChat.Settings:SetVisible(false)
				return
			end

			EasyChat.OpenSettings()
		end

		--[[self.BtnDonate:SetSize(30, 29)
		self.BtnDonate:SetZPos(10)
		self.BtnDonate:SetText("")
		self.BtnDonate:SetTooltip("Donate")
		self.BtnDonate:SetImage("icon16/heart.png")
		self.BtnDonate.DoClick = function()
			gui.OpenURL("https://paypal.me/easychat")
		end

		self.BtnDonate.DoRightClick = function(self)
			local donate_menu = DermaMenu()
			donate_menu:AddOption("Hide", function()
				cookie.Set("ECShowDonateButton", "1")
				self:Hide()
			end)
			donate_menu:AddSpacer()
			donate_menu:AddOption("Cancel", function() donate_menu:Remove() end)

			donate_menu:Open()
		end

		if cookie.GetNumber("ECShowDonateButton") == 1 then
			self.BtnDonate:Hide()
		end]]--

		self.Tabs:SetPos(6, 6)
		self.Tabs:SetFadeTime(0)
		self.Tabs.old_PerformLayout = self.Tabs.PerformLayout
		self.Tabs.PerformLayout = function(self)
			self:old_PerformLayout()
			self.tabScroller:SetTall(22)
		end

		local tab_class_blacklist = {
			["ECChatTab"] = true,
			["ECSettingsTab"] = true,
		}
		local function tab_do_right_click(self)
			local sheet = self:GetPropertySheet()
			if not IsValid(sheet) then return end

			local tabs_menu = DermaMenu()

			if not tab_class_blacklist[self.m_pPanel.ClassName] then
				tabs_menu:AddOption("Hide Tab", function()
					if not IsValid(self) then return end
					self:SetVisible(false)
				end):SetIcon("icon16/plugin_delete.png")

				tabs_menu:AddSpacer()
			end

			-- add tabs to the menu
			for _, item in pairs(sheet.Items) do
				if item and IsValid(item.Tab) and item.Tab:IsVisible() then
					local tab = item.Tab
					local option = tabs_menu:AddOption(tab:GetText(), function()
						if not IsValid(tab) or not IsValid(sheet) or not IsValid(sheet.tabScroller) then return end
						tab:DoClick()
						sheet.tabScroller:ScrollToChild(tab)
					end)

					if IsValid(tab.Image) then
						option:SetIcon(tab.Image:GetImage())
					end
				end
			end

			tabs_menu:AddSpacer()
			tabs_menu:AddOption("Cancel", function() tabs_menu:Remove() end)
			tabs_menu:Open()
		end

		self.Tabs.old_AddSheet = self.Tabs.AddSheet
		self.Tabs.AddSheet = function(self, ...)
			local ret = self:old_AddSheet(...)
			ret.Tab:Droppable("ECTabDnD")
			ret.Tab.DoRightClick = tab_do_right_click
			return ret
		end

		self.Scroller:MakeDroppable("ECTabDnD", false)
		self.Scroller.m_iOverlap = -2
		self.Scroller:SetDragParent(self)
		self.Scroller.OnMousePressed = function(self)
			if self:IsHovered() then
				self.Dragging = { gui.MouseX() - frame.x, gui.MouseY() - frame.y }
				self:MouseCapture(true)
			end
		end

		self.Scroller.OnMouseReleased = function(self)
			self.Dragging = nil
			self:MouseCapture(false)
		end

		self.Scroller.Think = function(self)
			-- necessary for letting the user scroll if they have many tabs
			local frame_rate = VGUIFrameTime() - self.FrameTime
			self.FrameTime = VGUIFrameTime()

			if self.btnRight:IsDown() then
				self.OffsetX = self.OffsetX + (500 * frame_rate)
				self:InvalidateLayout(true)
			end

			if self.btnLeft:IsDown() then
				self.OffsetX = self.OffsetX - (500 * frame_rate)
				self:InvalidateLayout(true)
			end

			-- drag the chatbox when dragging this instead of scrolling
			local mouse_x = math.Clamp(gui.MouseX(), 1, ScrW() - 1)
			local mouse_y = math.Clamp(gui.MouseY(), 1, ScrH() - 1)

			if self.Dragging then
				local x = mouse_x - self.Dragging[1]
				local y = mouse_y - self.Dragging[2]

				if frame:GetScreenLock() then
					x = math.Clamp(x, 0, ScrW() - self:GetWide())
					y = math.Clamp(y, 0, ScrH() - self:GetTall())
				end

				frame:SetPos(x, y)
			end

			self:SetCursor(self:IsHovered() and "sizeall" or "arrow")
		end

		if not EasyChat.UseDermaSkin then
			self.BtnClose:SetTextColor(EasyChat.TextColor) --Color(200, 20, 20))
			self.BtnMaxim:SetTextColor(EasyChat.TextColor) --Color(125, 125, 125))

			EasyChat.BlurPanel(self, 6, 0, -13, -5)
			self.Paint = function(self, w, h)
				surface_SetDrawColor(EasyChat.OutlayColor)
				surface_DrawRect(6, 0, w - 13, 28)
				surface_SetDrawColor(EasyChat.OutlayOutlineColor)
				surface_DrawOutlinedRect(6, 0, w - 13, 28)
			end

			self.BtnMaxim.Paint = function() end
			self.BtnClose.Paint = function() end
			self.BtnSettings.Paint = function() end
			--self.BtnDonate.Paint = function() end

			local no_color = Color(0, 0, 0, 0)
			self.Tabs.Paint = function(self, w, h)
				surface_SetDrawColor(no_color)
				surface_DrawRect(0, 0, w, h)
			end
		end
	end,
	PerformLayout = function(self, w, h)
		self.Tabs:SetSize(w - 13, h - 11)
		--self.BtnDonate:SetPos(w - self.BtnDonate:GetWide() - 93, -1)
		self.BtnSettings:SetPos(w - self.BtnSettings:GetWide() - 64, -1)
		self.BtnMaxim:SetPos(w - self.BtnMaxim:GetWide() - 35, -5)
		self.BtnClose:SetPos(w - self.BtnClose:GetWide() - 6, -2)
	end
}

vgui.Register("ECChatBox", CHATBOX, "DFrame")
