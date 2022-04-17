local function update_settings_font(name, size)
	surface.CreateFont("ECSettingsFont", {
		font = name,
		extended = true,
		size = size - 1,
		weight = 530,
		shadow = false,
		additive = false,
	})
end

update_settings_font(EasyChat.Font, EasyChat.FontSize)

local color_white = color_white

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
	self:SetSize(640, 480)
	self:SetTitle("EasyChat Settings")
	self:DockPadding(0, 25, 0, 0)

	self.lblTitle:SetFont("EasyChatFont")

	self.btnMaxim:Hide()
	self.btnMinim:Hide()

	self.btnClose:SetSize(30, 30)
	self.btnClose:SetZPos(10)
	self.btnClose.DoClick = function()
		self:SetVisible(false)
	end

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

	local old_add_sheet = self.Categories.AddSheet
	self.Categories.AddSheet = function(self, label, panel, material)
		local sheet = old_add_sheet(self, label, panel, material)
		if not EasyChat.UseDermaSkin then
			sheet.Button:SetTextColor(self:GetSkin().text_normal)

			if #self.Items == 1 then
				sheet.Button:SetTextColor(EasyChat.TextColor)
			end
		end

		return sheet
	end

	if not EasyChat.UseDermaSkin then
		self.lblTitle:SetTextColor(EasyChat.TextColor)

		self.btnClose:SetFont("DermaDefaultBold")
		self.btnClose:SetText("X")
		self.btnClose:SetTextColor(EasyChat.TextColor)
		self.btnClose.Paint = function() end

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

		EasyChat.BlurPanel(self, 0, 0, 0, 0)
		self.Paint = function(self, w, h)
			surface.SetDrawColor(EasyChat.OutlayColor)
			surface.DrawRect(0, 0, w, 25)
		end

		self.PaintOver = function(self, w, h)
			surface.SetDrawColor(EasyChat.TabOutlineColor)
			surface.DrawLine(0, 25, w, 25)

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
	number_wang:SetFont("ECSettingsFont")
	number_wang:DockMargin(10, 10, 10, 10)

	local title_color = EasyChat.UseDermaSkin and self:GetSkin().text_normal or EasyChat.TextColor
	number_wang.PaintOver = function(self, w, h)
		surface.DisableClipping(true)
			surface.SetTextPos(0, -draw.GetFontHeight("ECSettingsFont") - 2)
			surface.SetTextColor(title_color)
			surface.SetFont("ECSettingsFont")
			surface.DrawText(name)
		surface.DisableClipping(false)
	end

	if not EasyChat.UseDermaSkin then
		number_wang.Paint = function(self, w, h)
			surface.SetDrawColor(EasyChat.TabColor)
			surface.DrawRect(0, 0, w, h)

			surface.SetDrawColor(EasyChat.OutlayColor)
			surface.DrawOutlinedRect(0, 0, w, h)

			surface.SetDrawColor(EasyChat.TabOutlineColor)
			surface.DrawOutlinedRect(0, 0, w, h)

			self:DrawTextEntryText(color_white, EasyChat.OutlayColor, color_white)
		end
	end

	return number_wang
end

function SETTINGS:CreateStringSetting(panel, name)
	local text_entry = panel:Add("DTextEntry")
	text_entry:Dock(TOP)
	text_entry:DockMargin(10, 10, 10, 10)
	text_entry:SetFont("ECSettingsFont")

	local title_color = EasyChat.UseDermaSkin and self:GetSkin().text_normal or EasyChat.TextColor
	text_entry.PaintOver = function(self, w, h)
		surface.DisableClipping(true)
			surface.SetTextPos(0, -draw.GetFontHeight("ECSettingsFont") - 2)
			surface.SetTextColor(title_color)
			surface.SetFont("ECSettingsFont")
			surface.DrawText(name)
		surface.DisableClipping(false)
	end

	if not EasyChat.UseDermaSkin then
		text_entry.Paint = function(self, w, h)
			surface.SetDrawColor(EasyChat.TabColor)
			surface.DrawRect(0, 0, w, h)

			surface.SetDrawColor(EasyChat.OutlayColor)
			surface.DrawOutlinedRect(0, 0, w, h)

			surface.SetDrawColor(EasyChat.TabOutlineColor)
			surface.DrawOutlinedRect(0, 0, w, h)

			self:DrawTextEntryText(color_white, EasyChat.OutlayColor, color_white)
		end
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

			surface.SetDrawColor(EasyChat.TabOutlineColor)
			surface.DrawOutlinedRect(0, 0, w, h)
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
		local font_height = draw.GetFontHeight("ECSettingsFont")

		self:SetTall(font_height + 25)

		self.Title = self:Add("DLabel")
		self.Title:SetFont("ECSettingsFont")
		self.Title:SetTall(font_height)
		self.Title:SetText("Unknown")
		self.Title:Dock(TOP)
		self.Title:DockMargin(0, 0, 0, 5)

		self.Red = self:CreateWang()
		self.Red.OnValueChanged = function(_, val)
			self.Color.r = val
			self:OnValueChanged(self.Color)
		end

		self.Green = self:CreateWang()
		self.Green.OnValueChanged = function(_, val)
			self.Color.g = val
			self:OnValueChanged(self.Color)
		end

		self.Blue = self:CreateWang()
		self.Blue.OnValueChanged = function(_, val)
			self.Color.b = val
			self:OnValueChanged(self.Color)
		end

		self.Alpha = self:CreateWang()
		self.Alpha.OnValueChanged = function(_, val)
			self.Color.a = val
			self:OnValueChanged(self.Color)
		end

		self.Preview = self:Add("DPanel")
		self.Preview:Dock(LEFT)
		self.Preview:SetSize(30, 30)
		self.Preview:DockMargin(0, 0, 10, 0)
		self.Preview.Paint = function(_, w, h)
			local col = self.Color
			surface.SetDrawColor(col.r, col.g, col.b, col.a)
			surface.DrawRect(0, 0, w, h)

			surface.SetDrawColor(EasyChat.TabOutlineColor)
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
		wang:SetFont("ECSettingsFont")

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

	if not EasyChat.UseDermaSkin then
		color_setting.Title:SetTextColor(EasyChat.TextColor)

		local function entry_paint(self, w, h, text_color)
			surface.SetDrawColor(EasyChat.TabColor)
			surface.DrawRect(0, 0, w, h)

			surface.SetDrawColor(EasyChat.OutlayColor)
			surface.DrawOutlinedRect(0, 0, w, h)

			surface.SetDrawColor(EasyChat.TabOutlineColor)
			surface.DrawOutlinedRect(0, 0, w, h)

			self:DrawTextEntryText(text_color, EasyChat.OutlayColor, color_white)
		end

		color_setting.Paint = function() end
		color_setting.Red.Paint = function(self, w, h) entry_paint(self, w, h, Color(200, 0, 50)) end
		color_setting.Green.Paint = function(self, w, h) entry_paint(self, w, h, Color(0, 200, 70)) end
		color_setting.Blue.Paint = function(self, w, h) entry_paint(self, w, h, Color(0, 50, 200)) end
		color_setting.Alpha.Paint = function(self, w, h) entry_paint(self, w, h, color_white) end
	end

	return color_setting
end

function SETTINGS:CreateListSetting(panel, name)
	local list_setting = panel:Add("DPanel")
	list_setting:Dock(TOP)
	list_setting:DockMargin(10, 0, 10, 10)
	list_setting:SetTall(110)
	list_setting.Paint = function() end

	local title = list_setting:Add("DLabel")
	title:SetFont("ECSettingsFont")
	title:SetText(name)
	title:Dock(TOP)
	list_setting.Title = title

	local list_view = list_setting:Add("DListView")
	list_view:Dock(FILL)
	list_view:SetTall(100)
	list_setting.List = list_view

	if not EasyChat.UseDermaSkin then
		title:SetTextColor(EasyChat.TextColor)
		list_view.Paint = function(self, w, h)
			surface.SetDrawColor(EasyChat.OutlayColor)
			surface.DrawOutlinedRect(0, 0, w, h)

			surface.SetDrawColor(EasyChat.TabOutlineColor)
			surface.DrawOutlinedRect(0, 0, w, h)
		end

		local old_AddColumn = list_view.AddColumn
		list_view.AddColumn = function(self, ...)
			local column = old_AddColumn(self, ...)
			column.Header:SetFont("ECSettingsFont")
			column.Header:SetTextColor(EasyChat.TextColor)
			column.Header.Paint = function(self, w, h)
				surface.SetDrawColor(EasyChat.OutlayColor)
				surface.DrawRect(0, 0, w, h)

				surface.SetDrawColor(EasyChat.TabOutlineColor)
				surface.DrawOutlinedRect(0, 0, w, h)
			end

			return column
		end

		local old_AddLine = list_view.AddLine
		list_view.AddLine = function(self, ...)
			local line = old_AddLine(self, ...)
			for _, column in pairs(line.Columns) do
				column:SetTextColor(EasyChat.TextColor)
				column:SetFont("ECSettingsFont")
			end

			return line
		end
	end

	return list_setting
end

function SETTINGS:AddCategory(category_name, icon)
	category_name = category_name or "???"
	if self.CategoryList[category_name] then return end

	local panel = vgui.Create("DScrollPanel")
	panel:DockMargin(0, 10, 0, 10)
	panel:Dock(FILL)

	if not EasyChat.UseDermaSkin then
		panel.Paint = function() end

		--[[local scrollbar = panel:GetVBar()
		scrollbar:SetHideButtons(true)
		scrollbar.Paint = function(self, w, h)
			surface.SetDrawColor(EasyChat.OutlayColor)
			surface.DrawLine(0, 0, 0, h)
		end

		scrollbar.btnGrip.Paint = function(self, w, h)
			local outlay_col = EasyChat.OutlayColor
			surface.SetDrawColor(outlay_col.r, outlay_col.g, outlay_col.b, 150)
			surface.DrawRect(0, 0, w, h)
		end]]--
	end

	local new_category = self.Categories:AddSheet(category_name, panel)
	new_category.Button:SetFont("ECSettingsFont")
	new_category.Button:DockPadding(0, 20, 0, 20)

	if icon then
		new_category.Button:SetImage(icon)
	end

	if not EasyChat.UseDermaSkin then
		local categories = self.Categories
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

			if self == categories:GetActiveButton() then
				surface.SetDrawColor(color_white)
				surface.DrawOutlinedRect(0, 0, w, h)
				surface.DrawRect(w - 4, 0, 4, h)
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

local orange_color = Color(244, 135, 2)
local convar_type_callbacks = {
	["number"] = function(self, panel, cvar, name, max, min)
		local number_wang = self:CreateNumberSetting(panel, name, max, min)
		number_wang:SetValue(cvar:GetInt())

		local btn = number_wang:Add("DButton")
		btn:SetText("Save")
		btn:SetImage("icon16/bullet_disk.png")
		btn:SetFont("ECSettingsFont")
		btn:SetTall(number_wang:GetTall())
		btn:SetWide(100)
		btn:Dock(RIGHT)

		if not EasyChat.UseDermaSkin then
			btn:SetTextColor(color_white)
			btn.Paint = function() end
		end

		local old_value = number_wang:GetValue()
		local old_paint = number_wang.Paint
		number_wang.Paint = function(self, w, h)
			old_paint(self, w, h)

			local cur_value = self:GetValue()
			if cur_value ~= old_value then
				surface.SetDrawColor(orange_color)
				surface.DrawOutlinedRect(0, 0, w, h)
				btn:SetVisible(true)
			else
				btn:SetVisible(false)
			end
		end

		number_wang.OnEnter = function(self)
			local new_value = self:GetValue()
			cvar:SetInt(new_value)
			old_value = new_value
			notification.AddLegacy(("Applied setting changes: %s -> %d"):format(cvar:GetName(), new_value), NOTIFY_HINT, 5)
		end

		btn.DoClick = function(self)
			number_wang:OnEnter()
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

		local btn = text_entry:Add("DButton")
		btn:SetText("Save")
		btn:SetImage("icon16/bullet_disk.png")
		btn:SetFont("ECSettingsFont")
		btn:SetTall(text_entry:GetTall())
		btn:SetWide(100)
		btn:Dock(RIGHT)

		if not EasyChat.UseDermaSkin then
			btn:SetTextColor(color_white)
			btn.Paint = function() end
		end

		local old_value = text_entry:GetText():Trim()
		local old_paint = text_entry.Paint
		text_entry.Paint = function(self, w, h)
			old_paint(self, w, h)

			local cur_value = self:GetText()
			if cur_value ~= old_value then
				surface.SetDrawColor(orange_color)
				surface.DrawOutlinedRect(0, 0, w, h)
				btn:SetVisible(true)
			else
				btn:SetVisible(false)
			end
		end

		text_entry.OnEnter = function(self)
			local new_value = self:GetText():Trim()
			cvar:SetString(new_value)
			old_value = new_value
			notification.AddLegacy(("Applied setting changes: %s -> %s"):format(cvar:GetName(), new_value), NOTIFY_HINT, 5)
		end

		btn.DoClick = function(self)
			text_entry:OnEnter()
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
	local setting_panel = convar_type_callbacks[type](self, category_panel, cvar, ...)
	setting_panel:SetTooltip(cvar:GetName())
	return setting_panel
end

function SETTINGS:AddConvarSettingsSet(category_name, options)
	for cvar, description in pairs(options) do
		self:AddConvarSetting(category_name, "boolean", cvar, description)
	end

	local setting_reset_options = self:AddSetting(category_name, "action", "Reset Options")
	setting_reset_options.DoClick = function()
		for cvar, _ in pairs(options) do
			local default_value = tobool(cvar:GetDefault())
			cvar:SetBool(default_value)
		end
	end
end

local type_callbacks = {
	["number"] = SETTINGS.CreateNumberSetting,
	["string"] = SETTINGS.CreateStringSetting,
	["boolean"] = SETTINGS.CreateBooleanSetting,
	["action"] = SETTINGS.CreateActionSetting,
	["color"] = SETTINGS.CreateColorSetting,
	["list"] = SETTINGS.CreateListSetting,
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

	return spacer
end

vgui.Register("ECSettingsMenu", SETTINGS, "DFrame")