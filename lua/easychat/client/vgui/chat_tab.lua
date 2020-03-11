include("easychat/client/vgui/richtextx.lua")
include("easychat/client/vgui/textentryx.lua")
include("easychat/client/vgui/emote_picker.lua")
include("easychat/client/vgui/color_picker.lua")

local EC_LEGACY_ENTRY = GetConVar("easychat_legacy_entry")
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
		self.BtnSwitch:SetTall(25)
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
		self.BtnSwitch.DoRightClick = function()
			local switch_menu = DermaMenu()
			for mode_index, mode in pairs(EasyChat.Modes) do
				switch_menu:AddOption(mode.Name, function()
					EasyChat.Mode = mode_index
				end)
			end
			switch_menu:Open()
		end

		local use_new_text_entry = (EC_LEGACY_ENTRY and not EC_LEGACY_ENTRY:GetBool()) or not EC_LEGACY_ENTRY
		if HAS_CHROMIUM and use_new_text_entry then
			self.TextEntry = self:Add("TextEntryX")
		else
			self.TextEntry = self:Add("DTextEntry")
			self.TextEntry:SetFont("EasyChatCompletionFont")
			self.TextEntry:SetUpdateOnType(true)

			self.TextEntry.OnKeyCodeTyped = function(self, key_code)
				if key_code == KEY_TAB then self:OnTab() end
			end

			self.TextEntry.OnTab = function() end

			self.TextEntry.SetCompletionText = function(self, text)
				if not text or text:Trim() == "" then
					self.CompletionText = nil
				else
					self.CompletionText = text
				end
			end

			self.TextEntry.PaintOver = function(self, w, h)
				if not self.CompletionText then return end

				local cur_value = self:GetText()
				local r, g, b = self.PlaceholderColor:Unpack()
				surface.SetDrawColor(r, g, b)
				surface.SetFont("EasyChatCompletionFont")
				local cur_text_w = surface.GetTextSize(cur_value)
				local start_pos, end_pos = string.find(self.CompletionText, cur_value, 1, true)
				if start_pos then
					local sub_completion = string.sub(self.CompletionText, end_pos + 1)
					local _, completion_text_h = surface.GetTextSize(sub_completion)
					surface.SetTextPos(cur_text_w + 3, h / 2 - completion_text_h / 2)
					surface.DrawText(sub_completion)
				else
					local sub_completion = string.format("<< %s >>", self.CompletionText)
					local _, completion_text_h = surface.GetTextSize(sub_completion)
					surface.SetTextPos(cur_text_w + 15, h / 2 - completion_text_h / 2)
					surface.DrawText(sub_completion)
				end
			end

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

		self.EmotePicker = vgui.Create("ECEmotePicker")
		self.EmotePicker:SetVisible(false)
		self.EmotePicker.OnEmoteClicked = function(_, emote_name)
			local text = ("%s :%s:"):format(self.TextEntry:GetText():Trim(), emote_name)
			self.TextEntry:SetText(text)

			if input.IsKeyDown(KEY_LSHIFT) or input.IsKeyDown(KEY_RSHIFT) then return end
			self.EmotePicker:SetVisible(false)
			self.TextEntry:RequestFocus()
		end

		self.ColorPicker = vgui.Create("ECColorPicker")
		self.ColorPicker:SetVisible(false)
		self.ColorPicker.DoClick = function(_, btn)
			local col_str = btn.CurrentColorString
			local text = ("%s%s"):format(self.TextEntry:GetText():Trim(), col_str)
			self.TextEntry:SetText(text)
			self.ColorPicker:SetVisible(false)
			self.TextEntry:RequestFocus()
		end

		local function on_key_code_typed(_, key_code)
			if key_code == KEY_ENTER or key_code == KEY_PAD_ENTER then
				self.TextEntry:OnEnter()
			end
		end

		self.EmotePicker.Search.OnKeyCodeTyped = on_key_code_typed
		self.EmotePicker.OnKeyCodePressed = on_key_code_typed
		self.ColorPicker.OnKeyCodePressed = on_key_code_typed

		local function on_picker_mouse_pressed()
			if not IsValid(self) then return end

			if IsValid(self.EmotePicker) then
				if not self.EmotePicker:MouseInBounds() then
					self.EmotePicker:SetVisible(false)
				end
			end

			if IsValid(self.ColorPicker) then
				if not self.ColorPicker:MouseInBounds() then
					self.ColorPicker:SetVisible(false)
				end
			end
		end

		hook.Add("GUIMousePressed", self, on_picker_mouse_pressed)
		hook.Add("VGUIMousePressed", self, on_picker_mouse_pressed)
		hook.Add("ECClosed", self, function()
			if not IsValid(self) then return end

			if IsValid(self.EmotePicker) then
				self.EmotePicker:SetVisible(false)
			end

			if IsValid(self.ColorPicker) then
				self.ColorPicker:SetVisible(false)
			end
		end)

		self.BtnEmotePicker = self:Add("DButton")
		self.BtnEmotePicker:SetText("")
		self.BtnEmotePicker:SetIcon("icon16/emoticon_smile.png")
		self.BtnEmotePicker:SetSize(25, 25)
		self.BtnEmotePicker.DoClick = function()
			local btn_x, btn_y = self.BtnEmotePicker:LocalToScreen(0, 0)
			self.EmotePicker:SetPos(btn_x - (self.EmotePicker:GetWide() / 2), btn_y - self.EmotePicker:GetTall())
			self.EmotePicker:SetVisible(true)

			self.EmotePicker:MakePopup()
			self.EmotePicker.Search:SetText("")
			self.EmotePicker.Search:RequestFocus()
			self.EmotePicker:Populate()
		end

		self.BtnColorPicker = self:Add("DButton")
		self.BtnColorPicker:SetText("")
		self.BtnColorPicker:SetIcon("icon16/color_wheel.png")
		self.BtnColorPicker:SetSize(25, 25)
		self.BtnColorPicker.DoClick = function()
			local btn_x, btn_y = self.BtnColorPicker:LocalToScreen(0, 0)
			self.ColorPicker:SetPos(btn_x - (self.ColorPicker:GetWide() / 2), btn_y - self.ColorPicker:GetTall())
			self.ColorPicker:SetVisible(true)
			self.ColorPicker:MakePopup()
		end

		if not EasyChat.UseDermaSkin then
			local text_color = EasyChat.TextColor
			local placeholder_color = Color(text_color.r - 100, text_color.g - 100, text_color.b - 100)
			if HAS_CHROMIUM and use_new_text_entry then
				self.TextEntry:SetBackgroundColor(EasyChat.TabColor)
				self.TextEntry:SetBorderColor(EasyChat.OutlayColor)
				self.TextEntry:SetTextColor(EasyChat.TextColor)
				self.TextEntry:SetPlaceholderColor(placeholder_color)
			else
				self.TextEntry.PlaceholderColor = placeholder_color
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
			self.BtnEmotePicker.Paint = btn_paint
			self.BtnColorPicker.Paint = btn_paint
		end
	end,
	PerformLayout = function(self, w, h)
		self.RichText:SetSize(w - 10, h - 35)
		self.RichText:SetPos(5, 5)
		self.BtnSwitch:SetPos(0, h - self.BtnSwitch:GetTall())
		self.TextEntry:SetSize(w - self.BtnSwitch:GetWide() - self.BtnEmotePicker:GetWide() - self.BtnColorPicker:GetWide(), 25)
		self.TextEntry:SetPos(self.BtnSwitch:GetWide(), h - self.TextEntry:GetTall())
		self.BtnEmotePicker:SetPos(w - self.BtnEmotePicker:GetWide() - self.BtnColorPicker:GetWide(), h - self.BtnEmotePicker:GetTall())
		self.BtnColorPicker:SetPos(w - self.BtnColorPicker:GetWide(), h - self.BtnColorPicker:GetTall())
	end,
	OnRemove = function(self)
		self.EmotePicker:Remove()
		self.ColorPicker:Remove()

		hook.Remove("GUIMousePressed", self)
		hook.Remove("VGUIMousePressed", self)
		hook.Remove("ECClosed", self)
	end
}

vgui.Register("ECChatTab", MAIN_TAB, "DPanel")