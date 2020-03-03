include("easychat/client/vgui/richtextx.lua")
include("easychat/client/vgui/textentryx.lua")
include("easychat/client/vgui/emote_picker.lua")

local HAS_CHROMIUM = BRANCH ~= "dev" and BRANCH ~= "unknown"
local MAIN_TAB = {
	Init = function(self)
		self.RichText = self:Add(HAS_CHROMIUM and "RichTextX" or "RichText")
		if not HAS_CHROMIUM then
			-- compat for RichTextX
			self.RichText.AppendImageURL = function(self, url)
			end
		end

		self.RichText.PerformLayout = function(self)
			self:SetFontInternal("EasyChatFont")
			self:SetFGColor(EasyChat.UseDermaSkin and EasyChat.TextColor or Color(0, 0, 0, 255))
		end

		self.BtnSwitch = self:Add("DButton")
		self.BtnSwitch:SetText("Say")
		self.BtnSwitch:SetFont("EasyChatFont")
		self.BtnSwitch:SetTall(20)
		self.BtnSwitch:SizeToContentsX(20)
		self.BtnSwitch.Think = function(self)
			local cur_mode = EasyChat.GetCurrentMode()
			local cur_text = self:GetText()
			if cur_text ~= cur_mode.Name then
				self:SetText(cur_mode.Name)
				self:SizeToContentsX(20)
				self:InvalidateParent()
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

		self.TextEntry:SetPlaceholderText("type something...")

		self.Picker = vgui.Create("ECEmotePicker")
		self.Picker:SetVisible(false)
		self.Picker.OnEmoteClicked = function(_, emote_name)
			local text = ("%s :%s:"):format(self.TextEntry:GetText():Trim(), emote_name)
			self.TextEntry:SetText(text)

			if input.IsKeyDown(KEY_LSHIFT) or input.IsKeyDown(KEY_RSHIFT) then return end
			self.Picker:SetVisible(false)
			self.TextEntry:RequestFocus()
		end

		local function on_key_code_typed(_, key_code)
			if key_code == KEY_ENTER or key_code == KEY_PAD_ENTER then
				self.TextEntry:OnEnter()
			end
		end

		self.Picker.Search.OnKeyCodeTyped = on_key_code_typed
		self.Picker.OnKeyCodePressed = on_key_code_typed

		local function on_picker_mouse_pressed()
			if not IsValid(self) then return end
			if not IsValid(self.Picker) then return end

			if not self.Picker:MouseInBounds() then
				self.Picker:SetVisible(false)
			end
		end

		hook.Add("GUIMousePressed", self.Picker, on_picker_mouse_pressed)
		hook.Add("VGUIMousePressed", self.Picker, on_picker_mouse_pressed)
		hook.Add("ECClosed", self.Picker, function()
			if not IsValid(self) then return end
			if not IsValid(self.Picker) then return end

			self.Picker:SetVisible(false)
		end)

		self.Picker.OnRemove = function(self)
			hook.Remove("GUIMousePressed", self)
			hook.Remove("VGUIMousePressed", self)
			hook.Remove("ECClosed", self)
		end

		self.BtnPicker = self:Add("DButton")
		self.BtnPicker:SetText("")
		self.BtnPicker:SetIcon("icon16/emoticon_smile.png")
		self.BtnPicker:SetSize(25, 20)
		self.BtnPicker.DoClick = function()
			local btn_x, btn_y = self.BtnPicker:LocalToScreen(0, 0)
			self.Picker:SetPos(btn_x - (self.Picker:GetWide() / 2), btn_y - self.Picker:GetTall())
			self.Picker:SetVisible(true)

			self.Picker:MakePopup()
			self.Picker.Search:SetText("")
			self.Picker.Search:RequestFocus()
			self.Picker:Populate()
		end

		self.BtnSettings = self:Add("DButton")
		self.BtnSettings:SetText("")
		self.BtnSettings:SetIcon("icon16/cog.png")
		self.BtnSettings:SetSize(25, 20)
		self.BtnSettings.DoClick = function()
			EasyChat.OpenSettings()
		end

		if not EasyChat.UseDermaSkin then
			local text_color = EasyChat.TextColor
			self.TextEntry:SetPlaceholderColor(Color(text_color.r - 100, text_color.g - 100, text_color.b - 100))

			if HAS_CHROMIUM then
				self.TextEntry:SetBackgroundColor(EasyChat.TabColor)
				self.TextEntry:SetBorderColor(EasyChat.OutlayColor)
				self.TextEntry:SetTextColor(EasyChat.TextColor)
			else
				self.TextEntry.Paint = function(self, w, h)
					surface.SetDrawColor(EasyChat.TabColor)
					surface.DrawRect(0, 0, w, h)

					surface.SetDrawColor(EasyChat.OutlayColor)
					surface.DrawOutlinedRect(0, 0, w, h)

					self:DrawTextEntryText(EasyChat.TextColor, EasyChat.OutlayColor, EasyChat.TextColor)
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
			self.BtnPicker.Paint = btn_paint
			self.BtnSettings.Paint = btn_paint
		end
	end,
	PerformLayout = function(self, w, h)
		self.RichText:SetSize(w - 10, h - 30)
		self.RichText:SetPos(5, 5)
		self.BtnSwitch:SetPos(0, h - self.BtnSwitch:GetTall())
		self.TextEntry:SetSize(w - self.BtnSwitch:GetWide() - self.BtnPicker:GetWide() - self.BtnSettings:GetWide(), 20)
		self.TextEntry:SetPos(self.BtnSwitch:GetWide(), h - 20)
		self.BtnPicker:SetPos(w - self.BtnPicker:GetWide() - self.BtnSettings:GetWide(), h - self.BtnPicker:GetTall())
		self.BtnSettings:SetPos(w - self.BtnSettings:GetWide(), h - self.BtnSettings:GetTall())
	end,
	OnRemove = function(self)
		self.Picker:Remove()
	end
}

vgui.Register("ECChatTab", MAIN_TAB, "DPanel")