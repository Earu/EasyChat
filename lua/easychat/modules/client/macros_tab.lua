local black_color = Color(0, 0, 0)
local gray_color = Color(75, 75, 75)
local macro_processor = EasyChat.MacroProcessor

local MACRO_PANEL = {
	Init = function(self)
		self:SetTall(160)

		self.Title = self:Add("DLabel")
		self.Title:SetWide(self:GetWide())
		self.Title:SetPos(10, 0)

		self.TitleEdit = self:Add("DButton")
		self.TitleEdit:SetText("")
		self.TitleEdit:SetWide(self:GetWide())
		self.TitleEdit:SetPos(10, 0)
		self.TitleEdit.Paint = function() end
		self.TitleEdit.DoClick = function()
			EasyChat.AskForInput("New Macro Name", function(macro_name)
				self.Title:SetText(("<%s>"):format(macro_name))
				macro_processor:RegisterMacro(macro_name, {
					IsLua = self.IsLua:GetChecked(),
					PerCharacter = not self.IsLua:GetChecked() and self.PerChar:GetChecked() or false,
					Value = self.Value:GetText(),
				})

				self:DeleteMacro()
			end)
		end

		self.Value = self:Add("DTextEntry")
		self.Value:SetPos(10, 25)
		self.Value:SetSize(self:GetWide() - 160, 25)
		self.Value:SetMultiline(true)
		self.Value:SetVerticalScrollbarEnabled(true)
		self.Value.OnChange = function()
			self.Title:SetText(("<%s> (unsaved)"):format(self.MacroName))
			self:CacheMarkup()
		end

		self.Canvas = self:Add("DPanel")
		self.Canvas:SetPos(20 + self.Value:GetWide(), 100)
		self.Canvas:SetSize(130, 100)
		self.Canvas.Paint = function(_, w, h)
			surface.SetDrawColor(black_color)
			surface.DrawRect(0, 0, w, h)

			if self.Markup then
				self.Markup:Draw(w / 2 - self.Markup:GetWide() / 2, h / 2 - self.Markup:GetTall() / 2)
			end
		end

		self.PerChar = self:Add("DCheckBoxLabel")
		self.PerChar:SetText("Per Character")
		self.PerChar:SetPos(10, 135)
		self.PerChar.OnChange = function()
			self.Title:SetText(("<%s> (unsaved)"):format(self.MacroName))
			self:CacheMarkup()
		end

		self.IsLua = self:Add("DCheckBoxLabel")
		self.IsLua:SetText("Lua Macro")
		self.IsLua:SetPos(110, 135)
		self.IsLua.OnChange = function(_, is_lua)
			self.PerChar:SetDisabled(is_lua)
			self.Title:SetText(("<%s> (unsaved)"):format(self.MacroName))
			self:CacheMarkup()
		end

		self.Delete = self:Add("DButton")
		self.Delete:SetText("Delete")
		self.Delete:SetSize(75, 25)
		self.Delete:SetPos(self:GetWide() - 165, 130)
		self.Delete.DoClick = function() self:DeleteMacro() end

		self.Save = self:Add("DButton")
		self.Save:SetText("Save")
		self.Save:SetSize(75, 25)
		self.Save:SetPos(self:GetWide() - 85, 130)
		self.Save.DoClick = function() self:SaveMacro() end

		if not EasyChat.UseDermaSkin then
			self.Paint = function(self, w, h)
				surface.SetDrawColor(EasyChat.OutlayColor)
				surface.DrawRect(0, 0, w, h)
				surface.SetDrawColor(EasyChat.TabOutlineColor)
				surface.DrawOutlinedRect(0, 0, w, h)
			end

			self.Title:SetTextColor(EasyChat.TextColor)

			self.Value.Paint = function(self, w, h)
				surface.SetDrawColor(color_white)
				surface.DrawRect(0, 0, w, h)

				self:DrawTextEntryText(black_color, EasyChat.OutlayColor, black_color)
			end

			local function checkbox_paint(self, w, h)
				if self:GetDisabled() then return end

				surface.SetDrawColor(EasyChat.TabColor)
				surface.DrawRect(0, 0, w, h)

				if self:GetChecked() then
					surface.SetDrawColor(EasyChat.TextColor)
					surface.DrawRect(2, 2, w - 4, h - 4)
				end
			end

			local function button_paint(self, w, h)
				surface.SetDrawColor(EasyChat.TabColor)
				surface.DrawRect(0, 0, w, h)
				surface.SetDrawColor(EasyChat.TabOutlineColor)
				surface.DrawOutlinedRect(0, 0, w, h)

				if self:IsHovered() then
					surface.SetDrawColor(EasyChat.TextColor)
					surface.DrawOutlinedRect(0, 0, w, h)
				end
			end

			self.PerChar:SetTextColor(EasyChat.TextColor)
			self.PerChar.Button.Paint = checkbox_paint
			self.IsLua:SetTextColor(EasyChat.TextColor)
			self.IsLua.Button.Paint = checkbox_paint

			self.Delete:SetTextColor(EasyChat.TextColor)
			self.Delete.Paint = button_paint
			self.Save:SetTextColor(EasyChat.TextColor)
			self.Save.Paint = button_paint
		end
	end,
	CacheMarkup = function(self)
		if self.IsLua:GetChecked() then
			local macro = {
				IsLua = true,
				Value = self.Value:GetText(),
			}
			if macro_processor:CompileLuaMacro(macro) then
				macro_processor.Macros[self.MacroName] = macro
			end
		else
			local macro = {
				PerCharacter = self.PerChar:GetChecked(),
				Value = self.Value:GetText(),
			}
			macro_processor.Macros[self.MacroName] = macro
		end

		local str = ("<%s>Hello World!"):format(self.MacroName)
		str = macro_processor:ProcessString(str)

		self.Markup = ec_markup.AdvancedParse(str, {
			no_shadow = true,
			default_color = color_white,
		})
	end,
	SetMacro = function(self, macro_name, macro)
		self.MacroName = macro_name
		self.Title:SetText(("<%s>"):format(macro_name))
		self.Value:SetText(macro.Value)
		self.PerChar:SetChecked(macro.PerCharacter)
		self.IsLua:SetChecked(macro.IsLua)

		if macro.IsLua then
			self.PerChar:SetDisabled(true)
		end

		self:CacheMarkup()
	end,
	SaveMacro = function(self)
		self.Title:SetText(("<%s>"):format(self.MacroName))
		macro_processor:RegisterMacro(self.MacroName, {
			IsLua = self.IsLua:GetChecked(),
			PerCharacter = not self.IsLua:GetChecked() and self.PerChar:GetChecked() or false,
			Value = self.Value:GetText(),
		})
	end,
	DeleteMacro = function(self)
		macro_processor:DeleteMacro(self.MacroName)
	end,
	PerformLayout = function(self, w)
		self:SetWide(w)
		self.Title:SetWide(w)
		self.TitleEdit:SetWide(w)
		self.Value:SetSize(w - 160, 100)
		self.Canvas:SetPos(20 + self.Value:GetWide(), 25)
		self.Delete:SetPos(w - 165, 130)
		self.Save:SetPos(w - 85, 130)
	end,
}

vgui.Register("EasyChatMacroPanel", MACRO_PANEL, "DPanel")

local MACRO_TAB = {
	Init = function(self)
		self.Search = self:Add("DTextEntry")
		self.Search:SetPos(10, 10)
		self.Search:SetSize(self:GetWide() - 55, 25)
		self.Search.OnChange = function(search)
			local text = search:GetText()
			self:ReloadMacroPanels(text)
		end

		self.AddMacro = self:Add("DButton")
		self.AddMacro:SetText("+")
		self.AddMacro:SetSize(25, 25)
		self.AddMacro:SetPos(self.Search:GetWide() + 10, 10)
		self.AddMacro.DoClick = function()
			EasyChat.AskForInput("New Macro", function(macro_name)
				self:AddMacroPanel(macro_name, {
					PerCharacter = false,
					IsLua = false,
					Value = "",
				}, true)
			end)
		end

		self.List = self:Add("DScrollPanel")
		self.List:SetPos(0, 45)
		self.List:SetSize(self:GetWide(), self:GetTall() - 45)

		for macro_name, macro in pairs(macro_processor.Macros) do
			self:AddMacroPanel(macro_name, macro, false)
		end

		if not EasyChat.UseDermaSkin then
			self.Search.Paint = function(self, w, h)
				surface.SetDrawColor(color_white)
				surface.DrawRect(0, 0, w, h)

				self:DrawTextEntryText(black_color, EasyChat.OutlayColor, black_color)
			end

			self.AddMacro:SetTextColor(EasyChat.TextColor)
			self.AddMacro.Paint = function(self, w, h)
				surface.SetDrawColor(EasyChat.OutlayColor)
				surface.DrawRect(0, 0, w, h)
				surface.SetDrawColor(EasyChat.TabOutlineColor)
				surface.DrawOutlinedRect(0, 0, w, h)

				if self:IsHovered() then
					surface.SetDrawColor(EasyChat.TextColor)
					surface.DrawOutlinedRect(0, 0, w, h)
				end
			end

			local scrollbar = self.List:GetVBar()
			scrollbar:SetHideButtons(true)
			scrollbar.Paint = function(self, w, h)
				surface.SetDrawColor(EasyChat.OutlayColor)
				surface.DrawLine(0, 0, 0, h)
			end

			local grip_color = table.Copy(EasyChat.OutlayColor)
			grip_color.a = 150
			scrollbar.btnGrip.Paint = function(self, w, h)
				surface.SetDrawColor(grip_color)
				surface.DrawRect(0, 0, w, h)
			end
		end
	end,
	KnownMacros = {},
	AddMacroPanel = function(self, macro_name, macro, is_new)
		local macro_panel = vgui.Create("EasyChatMacroPanel", self.List)
		macro_panel:SetMacro(macro_name, macro)
		macro_panel:Dock(TOP)
		macro_panel:DockMargin(10, 5, 10, 0)

		if is_new then
			macro_panel.Title:SetText(("<%s> (unsaved)"):format(macro_name))
		end

		self.KnownMacros[macro_name] = true
	end,
	ReloadMacroPanels = function(self, search_input)
		search_input = search_input or ""

		self.KnownMacros = {}
		self.List:Clear()
		for macro_name, macro in pairs(macro_processor.Macros) do
			if search_input:Trim() == "" or macro_name:match(search_input) then
				self:AddMacroPanel(macro_name, macro, false)
			end
		end
	end,
	PerformLayout = function(self)
		self.Search:SetSize(self:GetWide() - 55, 25)
		self.AddMacro:SetPos(self.Search:GetWide() + 20, 10)
		self.List:SetSize(self:GetWide(), self:GetTall() - 45)
	end,
	Paint = function() end
}

vgui.Register("EasyChatMacroTab", MACRO_TAB, "DPanel")

-- example macros
if not cookie.GetNumber("EasyChatExampleMacros") then
	macro_processor:RegisterMacro("reee", {
		PerCharacter = false,
		Value = "<translate=rand(-5,5), rand(-5,5)>",
	})

	macro_processor:RegisterMacro("rainbow", {
		PerCharacter = false,
		Value = "<hsv=t()*300>",
	})

	macro_processor:RegisterMacro("eyefuck", {
		PerCharacter = true,
		Value = "<hsv=rand(0,255)>"
	})

	macro_processor:RegisterMacro("drop", {
		IsLua = true,
		Value = [[
			-- MACRO_INPUT: string, the input passed to the macro
			-- ^ this does not exclude other macros, tags, whatsoever, youll have to do it yourself

			local chars = MACRO_INPUT:Split("")
			for i=1, #chars do
				chars[i] = ("<translate=0,%d>%s"):format(i, chars[i])
			end

			-- returning here "applies" your changes
			return table.concat(chars)
		]]
	})

	cookie.Set("EasyChatExampleMacros", "1")
end

local macro_tab = vgui.Create("EasyChatMacroTab")
hook.Add("ECMacroRegistered", "EasyChatModuleMacroTab", function(macro_name, macro)
	if not IsValid(macro_tab) then return end
	if macro_tab.KnownMacros[macro_name] then return end

	macro_tab:AddMacroPanel(macro_name, macro, false)
end)

hook.Add("ECMacroDeleted", "EasyChatModuleMacroTab", function()
	if not IsValid(macro_tab) then return end

	macro_tab:ReloadMacroPanels()
end)

EasyChat.AddTab("Macros", macro_tab)

return "Macros Tab"