include("easychat/client/vgui/textentryx.lua")
include("easychat/client/vgui/emote_picker.lua")

local HAS_CHROMIUM = BRANCH ~= "dev" and BRANCH ~= "unknown"
local MAIN_TAB = {
	Init = function(self)
		self.RichText = self:Add("RichText")
		self.RichText.PerformLayout = function(self)
			self:SetFontInternal("EasyChatFont")
			self:SetFGColor(EasyChat.UseDermaSkin and EasyChat.TextColor or Color(0, 0, 0, 255))
		end

		self.BtnSwitch = self:Add("DButton")
		self.BtnSwitch:SetText("Say")
		self.BtnSwitch:SetFont("EasyChatFont")
		self.BtnSwitch:SetSize(65, 20)
		self.BtnSwitch.Think = function(self)
			if EasyChat.Mode == 0 then
				self:SetText("Say")
			else
				self:SetText(EasyChat.Modes[EasyChat.Mode].Name)
			end
		end
		self.BtnSwitch.DoClick = function()
			local next_mode = EasyChat.Mode + 1
			EasyChat.Mode = next_mode > EasyChat.ModeCount and 0 or next_mode
		end

		if HAS_CHROMIUM then
			self.TextEntry = self:Add("TextEntryX")
		else
			self.TextEntry = self:Add("DTextEntry")
			self.TextEntry.OnTab = function() end

			local last_key = KEY_ENTER
			self.TextEntry.OnKeyCodeTyped = function(self, key_code)
				EasyChat.SetupHistory(self, key_code)
				EasyChat.UseRegisteredShortcuts(self, last_key, code)

				if key_code == KEY_TAB then
					self:OnTab()
				elseif key_code == KEY_ENTER or key_code == KEY_PAD_ENTER then
					self:OnEnter()
				end

				last_key = key_code
			end
		end

		self.Picker = vgui.Create("ECEmotePicker")
		self.Picker:SetVisible(false)
		self.Picker.OnEmoteClicked = function(_, emote_name)
			local text = ("%s :%s:"):format(self.TextEntry:GetText():Trim(), emote_name)
			self.TextEntry:SetText(text)

			if input.IsKeyDown(KEY_LSHIFT) or input.IsKeyDown(KEY_RSHIFT) then return end
			self.Picker:SetVisible(false)
			self.TextEntry:RequestFocus()
		end

		self.Picker.Think = function(self)
			if self:MouseInBounds() then self.Entered = true end
			if not self.Entered then return end

			if input.IsKeyDown(KEY_LSHIFT) or input.IsKeyDown(KEY_RSHIFT) then return end
			if not self:MouseInBounds() then
				self:SetVisible(false)
				self.Entered = false
			end
		end

		local function picker_hook()
			if not IsValid(self) then return end
			if not IsValid(self.Picker) then return end

			if not self.Picker:MouseInBounds() then
				self.Picker:SetVisible(false)
			end
		end

		hook.Add("GUIMousePressed", self.Picker, picker_hook)
		hook.Add("VGUIMousePressed", self.Picker, picker_hook)

		self.Picker.OnRemove = function(self)
			hook.Remove("GUIMousePressed", self)
			hook.Remove("VGUIMousePressed", self)
		end

		self.BtnPicker = self:Add("DButton")
		self.BtnPicker:SetText(":D")
		self.BtnPicker:SetFont("EasyChatFont")
		self.BtnPicker:SetSize(30, 20)
		self.BtnPicker.DoClick = function()
			local btn_x, btn_y = self.BtnPicker:LocalToScreen(0, 0)
			self.Picker:SetPos(btn_x - (self.Picker:GetWide() / 2), btn_y - self.Picker:GetTall())
			self.Picker:SetVisible(true)

			timer.Simple(0, function()
				self.Picker:MakePopup()
				self.Picker.Search:RequestFocus()
				self.Picker:Populate()
			end)
		end

		if not EasyChat.UseDermaSkin then
			local black_color = Color(0, 0, 0)
			if HAS_CHROMIUM then
				self.TextEntry:SetBackgroundColor(color_white)
				self.TextEntry:SetBorderColor(color_white)
				self.TextEntry:SetTextColor(black_color)
			else
				self.TextEntry.Paint = function(self, w, h)
					surface.SetDrawColor(color_white)
					surface.DrawRect(0, 0, w, h)

					self:DrawTextEntryText(black_color, EasyChat.OutlayColor, black_color)
				end
			end

			local function btn_paint(self, w, h)
				local col1, col2 = EasyChat.OutlayColor, EasyChat.TabOutlineColor
				if self:IsHovered() then
					col1 = Color(col1.r + 50, col1.g + 50, col1.b + 50, col1.a + 50)
					col2 = Color(255 - col2.r, 255 - col2.g, 255 - col2.b, 255 - col2.a)
				end

				surface.SetDrawColor(col1)
				surface.DrawRect(0, 0, w, h)
				surface.SetDrawColor(col2)
				surface.DrawOutlinedRect(0, 0, w, h)
			end

			self.BtnSwitch:SetTextColor(EasyChat.TextColor)
			self.BtnSwitch.Paint = btn_paint

			self.BtnPicker:SetTextColor(EasyChat.TextColor)
			self.BtnPicker.Paint = btn_paint
		end
	end,
	PerformLayout = function(self, w, h)
		self.RichText:SetSize(w, h - 25)
		self.BtnSwitch:SetPos(0, h - self.BtnSwitch:GetTall())
		self.TextEntry:SetSize(w - self.BtnSwitch:GetWide() - self.BtnPicker:GetWide(), 20)
		self.TextEntry:SetPos(self.BtnSwitch:GetWide(), h - 20)
		self.BtnPicker:SetPos(w - self.BtnPicker:GetWide(), h - self.BtnPicker:GetTall())
	end
}

vgui.Register("ECChatTab", MAIN_TAB, "DPanel")