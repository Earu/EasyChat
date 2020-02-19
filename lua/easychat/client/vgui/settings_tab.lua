local black_color = Color(0, 0, 0)
local function update_settings_font(name, size)
	surface.CreateFont("ECSettingsFont",{
		font = name,
		extended = true,
		size = size - 1,
		weight = 530,
		shadow = false,
		additive = false,
	})
end

update_settings_font(EasyChat.Font, EasyChat.FontSize)

local EC_FONT = GetConVar("easychat_font")
local EC_FONT_SIZE = GetConVar("easychat_font_size")
cvars.AddChangeCallback(EC_FONT:GetName(), function(_, _, new_font_name)
	update_settings_font(new_font_name, EasyChat.FontSize)
end)

cvars.AddChangeCallback(EC_FONT_SIZE:GetName(), function(_, _, new_font_size)
	update_settings_font(EasyChat.FontName, tonumber(new_font_size))
end)

local SETTINGS = {}

function SETTINGS:Init()
	self.CategoryList = {}

	self.Categories = self:Add("DColumnSheet")
	self.Categories:Dock(FILL)
	self.Categories.Navigation:DockMargin(0, 0, 0, 0)

	self.Categories.OnCategoryChanged = function(self, old_btn, new_btn)
		if EasyChat.UseDermaSkin then return end

		if IsValid(old_btn) then
			old_btn:SetTextColor(self:GetSkin().text_normal)
		end

		new_btn:SetTextColor(EasyChat.TextColor)
	end

	local old_set_active_button = self.Categories.SetActiveButton
	self.Categories.SetActiveButton = function(self, btn)
		local old_btn = self:GetActiveButton()
		old_set_active_button(self, btn)
		self:OnCategoryChanged(old_btn, btn)
	end

	if not EasyChat.UseDermaSkin then
		self.Categories.Paint = function(self, w, h)
			surface.SetDrawColor(EasyChat.TabColor)
			surface.DrawRect(0, 0, w, h)

			local nagivation_w = self.Navigation:GetWide()
			local line_col =
				EasyChat.TabOutlineColor.a == 0
					and EasyChat.OutlayColor
					or EasyChat.TabOutlineColor
			surface.SetDrawColor(line_col)
			surface.DrawLine(nagivation_w, 0, nagivation_w, h)
		end

		self.PaintOver = function(self, w, h)
			surface.SetDrawColor(EasyChat.OutlayOutlineColor)
			surface.DrawOutlinedRect(0, 0, w, h)
		end
	end
end

function SETTINGS:CreateNumberSetting(panel, name, max, min)
	local number_wang = panel:Add("DNumberWang")
	number_wang:SetMax(max)
	number_wang:SetMin(min)
	number_wang:Dock(TOP)
	number_wang:DockMargin(10, 10, 10, 10)

	local title_color = EasyChat.UseDermaSkin and self:GetSkin().text_normal or EasyChat.TextColor
	number_wang.Paint = function(self, w, h)
		surface.SetDrawColor(color_white)
		surface.DrawRect(0, 0, w, h)
		self:DrawTextEntryText(black_color, EasyChat.OutlayColor, black_color)

		surface.DisableClipping(true)
			surface.SetTextPos(0, -15)
			surface.SetTextColor(title_color)
			surface.SetFont("ECSettingsFont")
			surface.DrawText(name)
		surface.DisableClipping(false)
	end

	return number_wang
end

function SETTINGS:CreateStringSetting(panel, name)
	local text_entry = panel:Add("DTextEntry")
	text_entry:Dock(TOP)
	text_entry:DockMargin(10, 10, 10, 10)

	local title_color = EasyChat.UseDermaSkin and self:GetSkin().text_normal or EasyChat.TextColor
	text_entry.Paint = function(self, w, h)
		surface.SetDrawColor(color_white)
		surface.DrawRect(0, 0, w, h)
		self:DrawTextEntryText(black_color, EasyChat.OutlayColor, black_color)

		surface.DisableClipping(true)
			surface.SetTextPos(0, -15)
			surface.SetTextColor(title_color)
			surface.SetFont("ECSettingsFont")
			surface.DrawText(name)
		surface.DisableClipping(false)
	end

	return text_entry
end

function SETTINGS:CreateBooleanSetting(panel, description)
	local checkbox_label = panel:Add("DCheckBoxLabel")
	checkbox_label:SetText(description)
	checkbox_label:SetFont("ECSettingsFont")
	checkbox_label:Dock(TOP)
	checkbox_label:DockMargin(10, 0, 10, 10)

	if not EasyChat.UseDermaSkin then
		checkbox_label:SetTextColor(EasyChat.TextColor)
		checkbox_label.Button.Paint = function(self, w, h)
			surface.SetDrawColor(EasyChat.OutlayColor)
			surface.DrawRect(0, 0, w, h)

			if self:GetChecked() then
				surface.SetDrawColor(EasyChat.TextColor)
				surface.DrawRect(2, 2, w - 4, h - 4)
			end
		end
	end

	return checkbox_label
end

function SETTINGS:CreateActionSetting(panel, name)
	local btn = panel:Add("DButton")
	btn:Dock(TOP)
	btn:DockMargin(10, 0, 10, 10)
	btn:SetTall(25)
	btn:SetText(name)
	btn:SetFont("ECSettingsFont")

	if not EasyChat.UseDermaSkin then
		btn:SetTextColor(EasyChat.TextColor)
		btn.Paint = function(self, w, h)
			local prim_color, sec_color = EasyChat.OutlayColor, EasyChat.TabOutlineColor
			if self:IsHovered() then
				prim_color = Color(prim_color.r + 50, prim_color.g + 50, prim_color.b + 50, prim_color.a + 50)
				sec_color = Color(255 - sec_color.r, 255 - sec_color.g, 255 - sec_color.b, 255 - sec_color.a)
			end

			surface.SetDrawColor(prim_color)
			surface.DrawRect(0, 0, w, h)
			surface.SetDrawColor(sec_color)
			surface.DrawOutlinedRect(0, 0, w, h)
		end
	end

	return btn
end

local COLOR_SETTING = {
	Init = function(self)
		self.Color = Color(0, 0, 0, 0)
		self:SetTall(30)

		self.Title = self:Add("DLabel")
		self.Title:SetFont("ECSettingsFont")
		self.Title:SetTall(10)
		self.Title:SetText("Unknown")
		self.Title:Dock(TOP)
		self.Title:DockMargin(0, 0, 0, 5)

		self.Red = self:CreateWang()
		self.Red:SetTextColor(Color(255, 0, 0))
		self.Red.OnValueChanged = function(_, val)
			self.Color.r = val
			self:OnValueChanged(self.Color)
		end

		self.Green = self:CreateWang()
		self.Green:SetTextColor(Color(0, 255, 0))
		self.Green.OnValueChanged = function(_, val)
			self.Color.g = val
			self:OnValueChanged(self.Color)
		end

		self.Blue = self:CreateWang()
		self.Blue:SetTextColor(Color(0, 0, 255))
		self.Blue.OnValueChanged = function(_, val)
			self.Color.b = val
			self:OnValueChanged(self.Color)
		end

		self.Alpha = self:CreateWang()
		self.Alpha:SetTextColor(black_color)
		self.Alpha.OnValueChanged = function(_, val)
			self.Color.a = val
			self:OnValueChanged(self.Color)
		end

		self.Preview = self:Add("DPanel")
		self.Preview:Dock(LEFT)
		self.Preview:SetSize(30, 30)
		self.Preview:DockMargin(0, 0, 10, 0)
		self.Preview.Paint = function(_, w, h)
			surface.SetDrawColor(self.Color:Unpack())
			surface.DrawRect(0, 0, w, h)

			surface.SetDrawColor(black_color)
			surface.DrawOutlinedRect(0, 0, w, h)
		end
	end,
	CreateWang = function(self)
		local wang = self:Add("DNumberWang")
		wang:SetMax(255)
		wang:SetMin(0)
		wang:SetValue(0)
		wang:Dock(LEFT)
		wang:DockMargin(0, 0, 10, 0)
		wang:SetSize(50, 30)

		return wang
	end,
	GetColor = function(self) return self.Color end,
	SetColor = function(self, color)
		local new_col = Color(color.r, color.g, color.b, color.a)
		self.Color = new_col
		self.Red:SetValue(new_col.r)
		self.Green:SetValue(new_col.g)
		self.Blue:SetValue(new_col.b)
		self.Alpha:SetValue(new_col.a)
	end,
	SetTitle = function(self, title)
		self.Title:SetText(title)
	end,
	OnValueChanged = function(self, color)
	end,
}

vgui.Register("ECColorSetting", COLOR_SETTING, "DPanel")

function SETTINGS:CreateColorSetting(panel, name)
	local color_setting = panel:Add("ECColorSetting")
	color_setting:Dock(TOP)
	color_setting:DockMargin(10, 0, 10, 10)
	color_setting:SetTitle(name)
	color_setting:SetColor(color_white)

	local function entry_paint(self, w, h)
		surface.SetDrawColor(color_white)
		surface.DrawRect(0, 0, w, h)
		self:DrawTextEntryText(self.m_colText, EasyChat.OutlayColor, black_color)
	end

	if not EasyChat.UseDermaSkin then
		color_setting.Title:SetTextColor(EasyChat.TextColor)
	end

	color_setting.Paint = function() end
	color_setting.Red.Paint = entry_paint
	color_setting.Green.Paint = entry_paint
	color_setting.Blue.Paint = entry_paint
	color_setting.Alpha.Paint = entry_paint

	return color_setting
end

function SETTINGS:AddCategory(category_name)
	category_name = category_name or "???"
	if self.CategoryList[category_name] then return end

	local panel = vgui.Create("DScrollPanel")
	panel:DockMargin(0, 10, 0, 10)
	panel:Dock(FILL)

	if not EasyChat.UseDermaSkin then
		panel.Paint = function() end

		local scrollbar = panel:GetVBar()
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

	local new_category = self.Categories:AddSheet(category_name, panel)
	new_category.Button:SetFont("ECSettingsFont")
	new_category.Button:DockPadding(0, 20, 0, 20)

	if not EasyChat.UseDermaSkin then
		new_category.Button.Paint = function(self, w, h)
			local line_col =
				EasyChat.TabOutlineColor.a == 0
					and EasyChat.OutlayColor
					or EasyChat.TabOutlineColor
			surface.SetDrawColor(line_col)
			surface.DrawLine(0, h - 1, w, h - 1)

			if self:IsHovered() then
				surface.DrawRect(0, 0, w, h)
			end
		end
	end

	new_category.Button:DockMargin(0, 0, 0, 0)
	self.CategoryList[category_name] = panel
end

function SETTINGS:GetCategory(category_name)
	category_name = category_name or "???"

	-- create the category if it doesnt exist
	if not self.CategoryList[category_name] then
		self:AddCategory(category_name)
	end

	return self.CategoryList[category_name]
end

function SETTINGS:AddChangeCallback(cvar, on_change)
	local cvar_name = cvar:GetName()
	local callback_name = ("EasyChatSetting_%s"):format(cvar_name)
	cvars.RemoveChangeCallback(cvar_name, callback_name)
	cvars.AddChangeCallback(cvar_name, on_change, callback_name)
end

local convar_type_callbacks = {
	["number"] = function(self, panel, cvar, name, max, min)
		local number_wang = self:CreateNumberSetting(panel, name, max, min)
		number_wang:SetValue(cvar:GetInt())
		number_wang.OnValueChanged = function(_, new_value)
			cvar:SetInt(new_value)
		end

		self:AddChangeCallback(cvar, function()
			if not IsValid(number_wang) then return end
			number_wang:SetValue(cvar:GetInt())
		end)

		return number_wang
	end,
	["string"] = function(self, panel, cvar, name)
		local text_entry = self:CreateStringSetting(panel, name)
		text_entry:SetText(cvar:GetString())
		text_entry.OnEnter = function(self)
			cvar:SetString(self:GetText():Trim())
		end

		self:AddChangeCallback(cvar, function()
			if not IsValid(text_entry) then return end
			text_entry:SetText(cvar:GetString())
		end)

		return text_entry
	end,
	["boolean"] = function(self, panel, cvar, description)
		local checkbox_label = self:CreateBooleanSetting(panel, description)
		checkbox_label:SetChecked(cvar:GetBool())
		checkbox_label.OnChange = function(_, new_value)
			cvar:SetBool(new_value)
		end

		self:AddChangeCallback(cvar, function()
			if not IsValid(checkbox_label) then return end
			checkbox_label:SetChecked(cvar:GetBool())
		end)

		return checkbox_label
	end,
}

function SETTINGS:AddConvarSetting(category_name, type, cvar, ...)
	if not convar_type_callbacks[type] then return end
	if not cvar then return end

	local category_panel = self:GetCategory(category_name)
	return convar_type_callbacks[type](self, category_panel, cvar, ...)
end

local type_callbacks = {
	["number"] = SETTINGS.CreateNumberSetting,
	["string"] = SETTINGS.CreateStringSetting,
	["boolean"] = SETTINGS.CreateBooleanSetting,
	["action"] = SETTINGS.CreateActionSetting,
	["color"] = SETTINGS.CreateColorSetting,
}
function SETTINGS:AddSetting(category_name, type, ...)
	if not type_callbacks[type] then return end
	local category_panel = self:GetCategory(category_name)
	return type_callbacks[type](self, category_panel, ...)
end

function SETTINGS:AddSpacer(category_name)
	local category_panel = self:GetCategory(category_name)
	local spacer = category_panel:Add("DPanel")
	spacer:SetTall(2)
	spacer:Dock(TOP)
	spacer:DockMargin(0, 0, 0, 10)

	if not EasyChat.UseDermaSkin then
		spacer.Paint = function(_, w, h)
			local line_col =
				EasyChat.TabOutlineColor.a == 0
					and EasyChat.OutlayColor
					or EasyChat.TabOutlineColor
			surface.SetDrawColor(line_col)
			surface.DrawLine(0, h - 1, w, h - 1)
		end
	else
		spacer.Paint = function() end
	end
end

vgui.Register("ECSettingsTab", SETTINGS, "DPanel")