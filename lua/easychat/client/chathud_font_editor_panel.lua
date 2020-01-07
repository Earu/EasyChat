local file_path = "easychat/chud_font_settings.txt"
local default_font_data = {
	font = "Verdana",
	extended = true,
	size = 17,
	weight = 600,
	shadow = true,
	read_speed = 100,
}

local props = {
	antialias = true,
	underline = false,
	italic = false,
	strikeout = false,
	symbol = false,
	rotary = false,
	shadow = false,
	additive = false,
	outline = false,
}

local EDITOR = {
	Init = function(self)
		self:LoadFontData()

		self:SetSize(600, 410)
		self:SetPos(ScrW() / 2 - 300, ScrH() / 2 - 200)
		self:SetTitle("EC ChatHUD Font Editor")
		self.lblTitle:SetFont("EasyChatFont")

		self.BaseFont = self:Add("DTextEntry")
		self.FontSize = self:Add("DNumSlider")
		self.FontWeight = self:Add("DNumSlider")
		self.FontScanlines = self:Add("DNumSlider")
		self.ResetFont = self:Add("DButton")
		self.ApplyFont = self:Add("DButton")

		local width, x = 580, 10
		local total_height = 30

		self.BaseFont:SetSize(width, 20)
		self.BaseFont:SetPos(x, total_height)
		self.BaseFont:SetValue(self.FontData.font)
		total_height = total_height + self.BaseFont:GetTall() + 5

		self.FontSize:SetSize(width, 20)
		self.FontSize:SetPos(x, total_height)
		self.FontSize:SetText("Font size")
		self.FontSize:SetMax(254)
		self.FontSize:SetMin(5)
		self.FontSize:SetValue(self.FontData.size)
		total_height = total_height + self.FontSize:GetTall() + 5

		self.FontWeight:SetSize(width, 20)
		self.FontWeight:SetPos(x, total_height)
		self.FontWeight:SetText("Font weight")
		self.FontWeight:SetMax(1000)
		self.FontWeight:SetMin(200)
		self.FontWeight:SetValue(self.FontData.weight)
		total_height = total_height + self.FontWeight:GetTall() + 5

		self.FontScanlines:SetSize(width, 20)
		self.FontScanlines:SetPos(x, total_height)
		self.FontScanlines:SetText("Font scanlines")
		self.FontScanlines:SetMin(0)
		self.FontScanlines:SetMax(10)
		self.FontScanlines:SetValue(self.FontData.scanlines)
		total_height = total_height + self.FontScanlines:GetTall() + 5

		for prop_name, prop_default in pairs(props) do
			local checkbox = self:Add("DCheckBoxLabel")
			if self.FontData[prop_name] ~= nil then
				checkbox:SetChecked(self.FontData[prop_name])
			else
				checkbox:SetChecked(prop_default)
			end

			checkbox:SetText("Font " .. prop_name)
			checkbox:SetSize(width, 20)
			checkbox:SetPos(x, total_height)

			self[prop_name] = checkbox

			total_height = total_height + checkbox:GetTall() + 5
		end

		self.ResetFont:SetPos(x, total_height)
		self.ResetFont:SetSize(width, 20)
		self.ResetFont:SetText("Reset Font")
		self.ResetFont.DoClick = function(_)
			self:ResetFontData()
		end
		total_height = total_height + self.ResetFont:GetTall() + 5

		self.ApplyFont:SetPos(x, total_height)
		self.ApplyFont:SetSize(width, 20)
		self.ApplyFont:SetText("Apply Font")
		self.ApplyFont.DoClick = function(_)
			self:SaveFontData()
		end

		if not EasyChat.UseDermaSkin then
			--self.FontSize:SetTextColor(EasyChat.TextColor)
			--self.FontWeight:SetTextColor(EasyChat.TextColor)
			--self.FontScanlines:SetTextColor(EasyChat.TextColor)
			self.ResetFont:SetTextColor(EasyChat.TextColor)
			self.ApplyFont:SetTextColor(EasyChat.TextColor)

			local ECButtonPaint = function(self,w,h)
				local col1, col2 = EasyChat.TabColor, EasyChat.TabOutlineColor
				if self:IsHovered() then
					col1 = Color(col1.r + 50, col1.g + 50, col1.b + 50, col1.a + 50)
					col2 = Color(255 - col2.r, 255 - col2.g, 255 - col2.b, 255 - col2.a)
				end

				surface.SetDrawColor(col1)
				surface.DrawRect(0, 0, w, h)
				surface.SetDrawColor(col2)
				surface.DrawOutlinedRect(0, 0, w, h)
			end

			self.ResetFont.Paint = ECButtonPaint
			self.ApplyFont.Paint = ECButtonPaint

			for prop_name, _ in pairs(props) do
				local checkbox = self[prop_name]
				checkbox.Button.Paint = function(self, w, h)
					surface.SetDrawColor(EasyChat.TabColor)
					surface.DrawRect(0, 0, w, h)

					if self:GetChecked() then
						surface.SetDrawColor(EasyChat.TextColor)
						surface.DrawRect(2, 2, w - 4, h - 4)
					end
				end
			end
		end
	end,
	LoadFontData = function(self)
		if file.Exists(file_path, "DATA") then
			local json = file.Read(file_path, "DATA")
			self.FontData = util.JSONToTable(json)
		else
			self.FontData = default_font_data
		end
	end,
	SaveFontData = function(self)
		local data = {
			font = self.BaseFont:GetValue(),
			extended = true,
			blursize = 0,
			size = self.FontSize:GetValue(),
			weight = self.FontWeight:GetValue(),
			scanlines = self.FontScanlines:GetValue(),
		}

		for prop_name, _ in pairs(props) do
			local checkbox = self[prop_name]
			data[prop_name] = checkbox:GetChecked()
		end

		local shadow_data = table.Copy(data)
		shadow_data.blursize = 1

		local chathud = EasyChat.ChatHUD
		surface.CreateFont(chathud.DefaultFont, data)
		surface.CreateFont(chathud.DefaultShadowFont, shadow_data)
		chathud:InvalidateLayout()

		local json = util.TableToJSON(data, true)
		file.Write(file_path, json)
	end,
	ResetFontData = function(self)
		local shadow_data = table.Copy(default_font_data)
		shadow_data.blursize = 1

		local chathud = EasyChat.ChatHUD
		surface.CreateFont(chathud.DefaultFont, default_font_data)
		surface.CreateFont(chathud.DefaultShadowFont, shadow_data)
		chathud:InvalidateLayout()

		if file.Exists(file_path, "DATA") then
			file.Delete(file_path)
		end
	end,
	Paint = function(self, w, h)
		surface.SetDrawColor(EasyChat.OutlayColor)
		surface.DrawRect(0, 0, w, h)
		surface.SetDrawColor(EasyChat.OutlayOutlineColor)
		surface.DrawOutlinedRect(0, 0, w, h)
	end,
}

vgui.Register("ECChatHUDFontEditor", EDITOR, "DFrame")

hook.Add("ECInitialized", "EasyChatChatHUDFontEditor", function()
	if not file.Exists(file_path, "DATA") then return end

	local json = file.Read(file_path, "DATA")
	local data = util.JSONToTable(json)
	local shadow_data = table.Copy(data)
	shadow_data.blursize = 1

	local chathud = EasyChat.ChatHUD
	surface.CreateFont(chathud.DefaultFont, data)
	surface.CreateFont(chathud.DefaultShadowFont, shadow_data)
	chathud:InvalidateLayout()
end)