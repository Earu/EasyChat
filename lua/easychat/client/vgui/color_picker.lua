local color_white = color_white

local PICKER = {
	Init = function(self)
		self:SetSize(200, 300)
		self:DockPadding(5, 5, 5, 5)

		self.BtnColor = self:Add("DButton")
		self.BtnColor:Dock(BOTTOM)
		self.BtnColor.DoClick = function(btn) self:DoClick(btn) end
		self.BtnColor:SetText("<color=255,255,255>")
		self.BtnColor.CurrentColorString = "<color=255,255,255>"

		self.Mixer = self:Add("DColorMixer")
		self.Mixer:Dock(FILL)
		self.Mixer:DockMargin(0, 0, 0, 10)
		self.Mixer.ValueChanged = function(_, new_col)
			local col_str = ("<color=%d,%d,%d>"):format(new_col.r or 255, new_col.g or 255, new_col.b or 255)
			self.BtnColor:SetText(col_str)
			self.BtnColor:SetColor(new_col)
			self.BtnColor.CurrentColorString = col_str
		end
		self.Mixer:SetColor(table.Copy(color_white))

		if not EasyChat.UseDermaSkin then
			self.Paint = function(_, w, h)
				surface.SetDrawColor(EasyChat.TabColor)
				surface.DrawRect(0, 0, w, h)

				local line_col =
					EasyChat.OutlayOutlineColor.a == 0
						and EasyChat.OutlayColor
						or EasyChat.OutlayOutlineColor
				surface.SetDrawColor(line_col)
				surface.DrawOutlinedRect(0, 0, w, h)
			end

			self.BtnColor:SetTextColor(EasyChat.TextColor)
			self.BtnColor:SetFont("EasyChatFont")
			self.BtnColor.Paint = function(_, w, h)
				surface.SetDrawColor(EasyChat.OutlayColor)
				surface.DrawRect(0, 0, w, h)
			end
		else
			self.Paint = function(self, w, h)
				derma.SkinHook("Paint", "Frame", self, w, h)
			end
		end
	end,
	MouseInBounds = function(self)
		local x, y = self:LocalToScreen(0, 0)
		local mouse_x, mouse_y = gui.MouseX(), gui.MouseY()

		return mouse_x >= x and mouse_x <= x + self:GetWide()
			and mouse_y >= y and mouse_y <= y + self:GetTall()
	end,
	DoClick = function(btn)
	end
}

vgui.Register("ECColorPicker", PICKER, "EditablePanel")