include("easychat/client/vgui/richtextx.lua")
include("easychat/client/vgui/richtext_legacy.lua")
include("easychat/client/vgui/textentryx.lua")
include("easychat/client/vgui/textentry_legacy.lua")
include("easychat/client/vgui/emote_picker.lua")
include("easychat/client/vgui/color_picker.lua")

local NEW_LINE_PATTERN = "\n"
local EC_LEGACY_ENTRY = GetConVar("easychat_legacy_entry")
local EC_LEGACY_TEXT = GetConVar("easychat_legacy_text")
local MAIN_TAB = {
	Init = function(self)
		local can_use_cef = EasyChat.CanUseCEFFeatures()
		local use_new_richtext = (EC_LEGACY_TEXT and not EC_LEGACY_TEXT:GetBool()) or not EC_LEGACY_TEXT
		self.RichText = self:Add((can_use_cef and use_new_richtext) and "RichTextX" or "RichTextLegacy")

		self.RichText.PerformLayout = function(self)
			self:SetFontInternal("EasyChatFont")
			self:SetUnderlineFont("EasyChatFont")
			self:SetFGColor(EasyChat.UseDermaSkin and EasyChat.TextColor or Color(0, 0, 0, 255))
		end

		self.BtnSwitch = self:Add("DButton")
		self.BtnSwitch:SetText("Say")
		self.BtnSwitch:SetFont("EasyChatFont")
		self.BtnSwitch:SetTall(25)
		self.BtnSwitch:SizeToContentsX(20)

		local old_font_size = draw.GetFontHeight("EasyChatFont")
		self.BtnSwitch.Think = function(self)
			local cur_mode = EasyChat.GetCurrentMode()
			local cur_text = self:GetText()
			local cur_font_size = draw.GetFontHeight("EasyChatFont")
			if cur_font_size ~= old_font_size or cur_text ~= cur_mode.Name then
				old_font_size = cur_font_size
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
			switch_menu:AddSpacer()
			switch_menu:AddOption("Cancel", function() switch_menu:Remove() end)
			switch_menu:Open()
		end

		local use_new_text_entry = (EC_LEGACY_ENTRY and not EC_LEGACY_ENTRY:GetBool()) or not EC_LEGACY_ENTRY
		self.TextEntry = self:Add((can_use_cef and use_new_text_entry) and "TextEntryX" or "TextEntryLegacy")
		self.TextEntry:SetPlaceholderText("type something...")

		self.EmotePicker = vgui.Create("ECEmotePicker")
		self.EmotePicker:SetVisible(false)
		self.EmotePicker.OnEmoteClicked = function(_, emote_name, provider_name)
			local text = ("%s <emote=%s,32,%s>"):format(self.TextEntry:GetText():Trim(), emote_name, provider_name)
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

			if IsValid(self.EmotePicker) and not self.EmotePicker:MouseInBounds() then
				self.EmotePicker:SetVisible(false)
			end

			if IsValid(self.ColorPicker) and not self.ColorPicker:MouseInBounds() then
				self.ColorPicker:SetVisible(false)
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
		self.BtnEmotePicker:SetIcon("icon16/emoticon_grin.png")
		self.BtnEmotePicker:SetSize(25, 25)
		self.BtnEmotePicker.DoClick = function()
			local btn_x, btn_y = self.BtnEmotePicker:LocalToScreen(0, 0)
			local x, y = btn_x - (self.EmotePicker:GetWide() / 2), btn_y - self.EmotePicker:GetTall()
			if x + self.EmotePicker:GetWide() > ScrW() then
				x = ScrW() - self.EmotePicker:GetWide()
			end

			self.EmotePicker:SetPos(x, y)
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
			local x, y = btn_x - (self.ColorPicker:GetWide() / 2), btn_y - self.ColorPicker:GetTall()
			if x + self.ColorPicker:GetWide() > ScrW() then
				x = ScrW() - self.ColorPicker:GetWide()
			end

			self.ColorPicker:SetPos(x, y)
			self.ColorPicker:SetVisible(true)
			self.ColorPicker:MakePopup()
		end

		if not EasyChat.UseDermaSkin then
			local text_color = EasyChat.TextColor
			local placeholder_color = Color(text_color.r - 100, text_color.g - 100, text_color.b - 100)
			self.TextEntry:SetPlaceholderColor(placeholder_color)
			if can_use_cef and use_new_text_entry then
				self.TextEntry:SetBackgroundColor(EasyChat.TabColor)

				local border_color = EasyChat.TabOutlineColor.a == 0
					and EasyChat.OutlayColor or EasyChat.TabOutlineColor
				self.TextEntry:SetBorderColor(border_color)
				self.TextEntry:SetTextColor(EasyChat.TextColor)
			else
				self.TextEntry.Paint = function(_, w, h)
					local border_color = EasyChat.TabOutlineColor.a == 0
						and EasyChat.OutlayColor or EasyChat.TabOutlineColor
					surface.SetDrawColor(border_color)
					surface.DrawOutlinedRect(0, 0, w, h)
				end

				-- this is an ugly hack so we can render the text inside the legacy text entry
				-- with proper padding as gmod doesnt allow us to do any other way :(
				local text_entry_fix = self:Add("DPanel")
				text_entry_fix:SetMouseInputEnabled(false)
				text_entry_fix:SetKeyboardInputEnabled(false)
				text_entry_fix:SetZPos(9999)

				self.TextEntry.PerformLayout = function(_, w, h)
					local tb_x, tb_y = self.TextEntry:GetPos()
					text_entry_fix:SetPos(tb_x, tb_y + 4)
					text_entry_fix:SetWide(self.TextEntry:GetWide())
					text_entry_fix:SetTall(self.TextEntry:GetTall() - 4)
				end

				local selection_color = Color(255, 0, 0, 127)
				text_entry_fix.Paint = function()
					self.TextEntry:DrawTextEntryText(EasyChat.TextColor, selection_color, EasyChat.TextColor)
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
	ComputeNewLineCount = function(self)
		local _, line_count = self.TextEntry:GetText():gsub(NEW_LINE_PATTERN, "\n")
		surface.SetFont("EasyChatCompletionFont")
		local tw, _ = surface.GetTextSize(self.TextEntry:GetText())
		line_count = line_count + math.floor(tw / self.TextEntry:GetWide())
		return math.min(25 + (line_count * 10), 100)
	end,
	PerformLayout = function(self, w, h)
		local text_entry_height = self:ComputeNewLineCount()
		local old_richtext_height = self.RichText:GetTall()
		self.RichText:SetSize(w - 10, h - (text_entry_height + 10))
		self.RichText:SetPos(5, 5)
		if self.RichText:GetTall() ~= old_richtext_height then
			self.RichText:GotoTextEnd()
		end

		self.TextEntry:SetSize(w - self.BtnSwitch:GetWide() - self.BtnEmotePicker:GetWide() - self.BtnColorPicker:GetWide(), text_entry_height)
		self.TextEntry:SetPos(self.BtnSwitch:GetWide(), h - text_entry_height)

		self.BtnSwitch:SetPos(0, h - text_entry_height)
		self.BtnEmotePicker:SetPos(w - self.BtnEmotePicker:GetWide() - self.BtnColorPicker:GetWide(), h - text_entry_height)
		self.BtnColorPicker:SetPos(w - self.BtnColorPicker:GetWide(), h - text_entry_height)
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