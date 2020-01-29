local EC_GLOBAL_ON_OPEN = GetConVar("easychat_global_on_open")
local EC_TIMESTAMPS		= GetConVar("easychat_timestamps")
local EC_TEAMS 			= GetConVar("easychat_teams")
local EC_TEAMS_COLOR 	= GetConVar("easychat_teams_colored")
local EC_PLAYER_COLOR 	= GetConVar("easychat_players_colored")
local EC_HUD_FOLLOW 	= GetConVar("easychat_hud_follow")
local EC_FONT 			= GetConVar("easychat_font")
local EC_FONT_SIZE 		= GetConVar("easychat_font_size")
local EC_HUD_TTL        = GetConVar("easychat_hud_ttl")

local UpdateSettingsFont = function(name,size)
	size = size - 3
	surface.CreateFont("ECSettingsFont",{
		font      = fontname,
		extended  = true,
		size      = size,
		weight    = 530,
		shadow	  = false,
		additive  = false,
	})
end

UpdateSettingsFont(EasyChat.Font,EasyChat.FontSize)

local ConvarCallbacks = {}

local SETTINGS_TAB = {
	Checkboxes = {},

	Init = function(self)
		local frame = self

		-- So we dont keep invalid panels in, when we reload
		self.Checkboxes = {}

		self.TBoxOutlayColor        = self:Add("DCheckBoxLabel")
		self.TBoxOutlayOutlineColor = self:Add("DCheckBoxLabel")
		self.TBoxTabColor           = self:Add("DCheckBoxLabel")
		self.TBoxTabOutlineColor    = self:Add("DCheckBoxLabel")
		self.ColorMixer             = self:Add("DColorMixer")
		self.BtnApplyColors         = self:Add("DButton")
		self.BtnResetColors         = self:Add("DButton")
		self.TxtFontName            = self:Add("DTextEntry")
		self.BtnApplyFont           = self:Add("DButton")
		self.LblFontSize            = self:Add("DLabel")
		self.NbrWFontSize           = self:Add("DNumberWang")
		self.BtnFontReset           = self:Add("DButton")
		self.LblHUDTTL              = self:Add("DLabel")
		self.NbrWHUDTTL             = self:Add("DNumberWang")
		self.BtnApplyTTL            = self:Add("DButton")
		self.BtnResetTTL            = self:Add("DButton")
		self.BtnResetOptions        = self:Add("DButton")
		self.BtnResetAll            = self:Add("DButton")
		self.BtnReloadChat          = self:Add("DButton")
		self.BtnUseDermaSkin        = self:Add("DButton")
		self.BtnClearHistory        = self:Add("DButton")
		self.BtnHUDFontEditor       = self:Add("DButton")
		self.BtnDisableEC           = self:Add("DButton")

		self.TBoxOutlayColor:SetText("Outlay Color")
		self.TBoxOutlayColor:SetFont("ECSettingsFont")
		self.TBoxOutlayColor:SetPos(15,15)
		table.insert(self.Checkboxes,self.TBoxOutlayColor)

		self.TBoxOutlayOutlineColor:SetText("Outlay Outline Color")
		self.TBoxOutlayOutlineColor:SetFont("ECSettingsFont")
		self.TBoxOutlayOutlineColor:SetPos(15,40)
		table.insert(self.Checkboxes,self.TBoxOutlayOutlineColor)

		self.TBoxTabColor:SetText("Tab Color")
		self.TBoxTabColor:SetFont("ECSettingsFont")
		self.TBoxTabColor:SetPos(15,65)
		table.insert(self.Checkboxes,self.TBoxTabColor)

		self.TBoxTabOutlineColor:SetText("Tab Outline Color")
		self.TBoxTabOutlineColor:SetFont("ECSettingsFont")
		self.TBoxTabOutlineColor:SetPos(15,90)
		table.insert(self.Checkboxes,self.TBoxTabOutlineColor)

		if not EasyChat.UseDermaSkin then
			for _, checkbox in pairs(self.Checkboxes) do
				checkbox.Button.Paint = function(self, w, h)
					surface.SetDrawColor(EasyChat.OutlayColor)
					surface.DrawRect(0, 0, w, h)

					if self:GetChecked() then
						surface.SetDrawColor(EasyChat.TextColor)
						surface.DrawRect(2, 2, w - 4, h - 4)
					end
				end
			end
		end

		self.ColorMixer:Dock(RIGHT)
		self.ColorMixer:DockMargin(0,15,15,0)

		self.BtnApplyColors:SetPos(15,115)
		self.BtnApplyColors:SetText("Apply Color")
		self.BtnApplyColors:SetFont("ECSettingsFont")
		self.BtnApplyColors:SetSize(100,25)
		self.BtnApplyColors.DoClick = function(self)
			frame:SaveColors()
		end

		self.BtnResetColors:SetPos(15,150)
		self.BtnResetColors:SetText("Reset Colors")
		self.BtnResetColors:SetFont("ECSettingsFont")
		self.BtnResetColors:SetSize(100,25)
		self.BtnResetColors.DoClick = function(self)
			frame:ResetColors()
		end

		if EasyChat.UseDermaSkin then
			self.TBoxOutlayColor:SetVisible(false)
			self.TBoxOutlayOutlineColor:SetVisible(false)
			self.TBoxTabColor:SetVisible(false)
			self.TBoxTabOutlineColor:SetVisible(false)
			self.ColorMixer:SetVisible(false)
			self.BtnApplyColors:SetVisible(false)
			self.BtnResetColors:SetVisible(false)
		end

		self.TxtFontName:SetPos(15,190)
		self.TxtFontName:SetSize(100,25)
		self.TxtFontName:SetText("font name here")

		self.LblFontSize:SetPos(15,220)
		self.LblFontSize:SetSize(100,10)
		self.LblFontSize:SetText("Font size")
		self.LblFontSize:SetFont("ECSettingsFont")

		self.NbrWFontSize:SetPos(15,230)
		self.NbrWFontSize:SetSize(100,25)
		self.NbrWFontSize:SetMin(0)
		self.NbrWFontSize:SetMax(40)
		self.NbrWFontSize:SetValue(EasyChat.FontSize)
		if ConvarCallbacks["NbrWFontSize"] then
			cvars.RemoveChangeCallback("easychat_font_size","NbrWFontSize")
		end
		cvars.AddChangeCallback("easychat_font_size",function(name,old,new)
			self.NbrWFontSize:SetValue(tonumber(new))
			UpdateSettingsFont(EasyChat.Font,tonumber(new))
		end,"NbrWFontSize")
		ConvarCallbacks["NbrWFontSize"] = true

		self.BtnApplyFont:SetPos(15,270) --270
		self.BtnApplyFont:SetSize(100,25)
		self.BtnApplyFont:SetText("Apply Font")
		self.BtnApplyFont:SetFont("ECSettingsFont")
		self.BtnApplyFont.DoClick = function()
			RunConsoleCommand("easychat_font",self.TxtFontName:GetValue())
			RunConsoleCommand("easychat_font_size",self.NbrWFontSize:GetValue())
			UpdateSettingsFont(self.TxtFontName:GetValue(),tonumber(self.NbrWFontSize:GetValue()))
		end

		self.BtnFontReset:SetPos(15,305)
		self.BtnFontReset:SetSize(100,25)
		self.BtnFontReset:SetText("Reset Font")
		self.BtnFontReset:SetFont("ECSettingsFont")
		self.BtnFontReset.DoClick = function(self)
			frame:ResetFont()
		end

		self.LblHUDTTL:SetPos(15,340)
		self.LblHUDTTL:SetSize(100,10)
		self.LblHUDTTL:SetText("Message Duration")
		self.LblHUDTTL:SetFont("ECSettingsFont")

		self.NbrWHUDTTL:SetPos(15,350)
		self.NbrWHUDTTL:SetSize(100,25)
		self.NbrWHUDTTL:SetMin(0)
		self.NbrWHUDTTL:SetMax(50)
		self.NbrWHUDTTL:SetValue(EC_HUD_TTL:GetInt())
		if ConvarCallbacks["NbrWHUDTTL"] then
			cvars.RemoveChangeCallback("easychat_hud_ttl","NbrWHUDTTL")
		end
		cvars.AddChangeCallback("easychat_hud_ttl",function(name,old,new)
			self.NbrWHUDTTL:SetValue(tonumber(new))
		end,"NbrWHUDTTL")
		ConvarCallbacks["NbrWHUDTTL"] = true

		self.BtnApplyTTL:SetPos(15,390)
		self.BtnApplyTTL:SetSize(100,25)
		self.BtnApplyTTL:SetText("Apply Duration")
		self.BtnApplyTTL:SetFont("ECSettingsFont")
		self.BtnApplyTTL.DoClick = function()
			RunConsoleCommand("easychat_hud_ttl",self.NbrWHUDTTL:GetValue())
		end

		self.BtnResetTTL:SetPos(15,425)
		self.BtnResetTTL:SetSize(100,25)
		self.BtnResetTTL:SetText("Reset Duration")
		self.BtnResetTTL:SetFont("ECSettingsFont")
		self.BtnResetTTL.DoClick = function()
			frame:ResetTTL()
		end

		local ConventionizeString = function(str)
			local str = string.gsub(str,"easychat_","")
			local parts = string.Explode("_",str)
			for index,part in pairs(parts) do
				parts[index] = string.SetChar(part,1,string.upper(part[1]))
			end
			return table.concat(parts,"")
		end

		local ypos = 15
		for _,v in pairs(EasyChat.GetRegisteredConvars()) do
			local cvar = v.Convar
			local index = "TBox"..ConventionizeString(cvar:GetName())
			self[index] = self:Add("DCheckBoxLabel")
			self[index]:SetText(v.Description)
			self[index]:SetFont("ECSettingsFont")
			self[index]:SetPos(170,ypos)
			self[index]:SetChecked(cvar:GetBool())
			self[index].OnChange = function(self,val)
				RunConsoleCommand(cvar:GetName(),(val and "1" or "0"))
			end
			if not EasyChat.UseDermaSkin then
				self[index].Button.Paint = function(self, w, h)
					surface.SetDrawColor(EasyChat.OutlayColor)
					surface.DrawRect(0, 0, w, h)

					if self:GetChecked() then
						surface.SetDrawColor(EasyChat.TextColor)
						surface.DrawRect(2, 2, w - 4, h - 4)
					end
				end
			end
			if ConvarCallbacks[index] then
				cvars.RemoveChangeCallback(cvar:GetName(),index)
			end
			cvars.AddChangeCallback(cvar:GetName(),function(name,old,new)
				self[index]:SetChecked(old == "0")
			end,index)
			ConvarCallbacks[index] = true
			ypos = ypos + self[index]:GetTall() + 5
		end

		self.BtnResetOptions:SetPos(170,ypos)
		self.BtnResetOptions:SetText("Reset Options")
		self.BtnResetOptions:SetFont("ECSettingsFont")
		self.BtnResetOptions:SetSize(100,25)
		self.BtnResetOptions.DoClick = function(self)
			frame:ResetOptions()
		end
		ypos = ypos + self.BtnResetOptions:GetTall() + 10

		self.BtnResetAll:SetPos(170,ypos)
		self.BtnResetAll:SetText("Reset Everything")
		self.BtnResetAll:SetFont("ECSettingsFont")
		self.BtnResetAll:SetSize(100,25)
		self.BtnResetAll.DoClick = function(self)
			frame:ResetAll()
		end
		ypos = ypos + self.BtnResetAll:GetTall() + 10

		concommand.Add("easychat_reset_settings",self.ResetAll)

		self.BtnReloadChat:SetPos(170,ypos)
		self.BtnReloadChat:SetText("Reload Chatbox")
		self.BtnReloadChat:SetFont("ECSettingsFont")
		self.BtnReloadChat:SetSize(100,25)
		self.BtnReloadChat.DoClick = function(self)
			frame:ReloadChat()
		end
		ypos = ypos + self.BtnReloadChat:GetTall() + 10

		self.BtnUseDermaSkin:SetPos(170,ypos)
		self.BtnUseDermaSkin:SetText(EasyChat.UseDermaSkin and "Use Custom Skin" or "Use Dermaskin")
		self.BtnUseDermaSkin:SetFont("ECSettingsFont")
		self.BtnUseDermaSkin:SetSize(100,25)
		self.BtnUseDermaSkin.DoClick = function()
			RunConsoleCommand("easychat_use_dermaskin",(EasyChat.UseDermaSkin and "0" or "1"))
		end
		ypos = ypos + self.BtnUseDermaSkin:GetTall() + 10

		self.BtnClearHistory:SetPos(170,ypos)
		self.BtnClearHistory:SetText("Clear History")
		self.BtnClearHistory:SetFont("ECSettingsFont")
		self.BtnClearHistory:SetSize(100,25)
		self.BtnClearHistory.DoClick = function()
			local files, _ = file.Find("easychat/*_history.txt", "DATA")
			for _, f in pairs(files) do
				file.Delete("easychat/" .. f)
			end
			frame:ReloadChat()
		end
		ypos = ypos + self.BtnClearHistory:GetTall() + 10

		self.BtnHUDFontEditor:SetPos(170,ypos)
		self.BtnHUDFontEditor:SetText("HUD Font Editor")
		self.BtnHUDFontEditor:SetFont("ECSettingsFont")
		self.BtnHUDFontEditor:SetSize(100,25)
		self.BtnHUDFontEditor.DoClick = function()
			local editor = vgui.Create("ECChatHUDFontEditor")
			editor:MakePopup()
		end
		ypos = ypos + self.BtnHUDFontEditor:GetTall() + 10

		self.BtnDisableEC:SetPos(170,ypos)
		self.BtnDisableEC:SetText("Disable EC")
		self.BtnDisableEC:SetFont("ECSettingsFont")
		self.BtnDisableEC:SetSize(100,25)
		self.BtnDisableEC.DoClick = function()
			RunConsoleCommand("easychat_enable","0")
		end
		ypos = ypos + self.BtnDisableEC:GetTall() + 10

		if not EasyChat.UseDermaSkin then
			local black_color = Color(0, 0, 0)
			self.TxtFontName.Paint = function(self, w, h)
				surface.SetDrawColor(color_white)
				surface.DrawRect(0, 0, w, h)

				self:DrawTextEntryText(black_color, EasyChat.OutlayColor, black_color)
			end
			self.NbrWFontSize.Paint = function(self, w, h)
				surface.SetDrawColor(color_white)
				surface.DrawRect(0, 0, w, h)

				self:DrawTextEntryText(black_color, EasyChat.OutlayColor, black_color)
			end
			self.NbrWHUDTTL.Paint = function(self, w, h)
				surface.SetDrawColor(color_white)
				surface.DrawRect(0, 0, w, h)

				self:DrawTextEntryText(black_color, EasyChat.OutlayColor, black_color)
			end

			self.BtnApplyColors:SetTextColor(EasyChat.TextColor)
			self.BtnResetColors:SetTextColor(EasyChat.TextColor)
			self.BtnApplyFont:SetTextColor(EasyChat.TextColor)
			self.BtnFontReset:SetTextColor(EasyChat.TextColor)
			self.BtnApplyTTL:SetTextColor(EasyChat.TextColor)
			self.BtnResetTTL:SetTextColor(EasyChat.TextColor)
			self.BtnResetOptions:SetTextColor(EasyChat.TextColor)
			self.BtnResetAll:SetTextColor(EasyChat.TextColor)
			self.BtnReloadChat:SetTextColor(EasyChat.TextColor)
			self.BtnUseDermaSkin:SetTextColor(EasyChat.TextColor)
			self.BtnClearHistory:SetTextColor(EasyChat.TextColor)
			self.BtnHUDFontEditor:SetTextColor(EasyChat.TextColor)
			self.BtnDisableEC:SetTextColor(EasyChat.TextColor)

			local ECButtonPaint = function(self,w,h)
				local col1,col2 = EasyChat.OutlayColor, EasyChat.TabOutlineColor
				if self:IsHovered() then
					col1 = Color(col1.r + 50, col1.g + 50, col1.b + 50, col1.a + 50)
					col2 = Color(255 - col2.r, 255 - col2.g, 255 - col2.b, 255 - col2.a)
				end

				surface.SetDrawColor(col1)
				surface.DrawRect(0,0,w,h)
				surface.SetDrawColor(col2)
				surface.DrawOutlinedRect(0,0,w,h)
			end

			self.BtnUseDermaSkin.Paint  = ECButtonPaint
			self.BtnApplyColors.Paint   = ECButtonPaint
			self.BtnResetColors.Paint   = ECButtonPaint
			self.BtnApplyFont.Paint     = ECButtonPaint
			self.BtnFontReset.Paint     = ECButtonPaint
			self.BtnApplyTTL.Paint      = ECButtonPaint
			self.BtnResetTTL.Paint      = ECButtonPaint
			self.BtnResetOptions.Paint  = ECButtonPaint
			self.BtnResetAll.Paint      = ECButtonPaint
			self.BtnReloadChat.Paint    = ECButtonPaint
			self.BtnClearHistory.Paint  = ECButtonPaint
			self.BtnHUDFontEditor.Paint = ECButtonPaint
			self.BtnDisableEC.Paint     = ECButtonPaint
		end

	end,

	ResetColors = function(self)
		EasyChat.OutlayColor        = Color(62, 62, 62, 255)
		EasyChat.OutlayOutlineColor = Color(0, 0, 0, 0)
		EasyChat.TabOutlineColor    = Color(0, 0, 0, 0)
		EasyChat.TabColor     		= Color(36, 36, 36, 255)
		local tab = {
			outlay		  = EasyChat.OutlayColor,
			outlayoutline = EasyChat.OutlayOutlineColor,
			tab 		  = EasyChat.TabColor,
			taboutline 	  = EasyChat.TabOutlineColor,
		}
		local json = util.TableToJSON(tab,true)
		file.Write("easychat/colors.txt",json)
	end,

	SaveColors = function(self)
		for k,v in pairs(self.Checkboxes) do
			if v:IsValid() and v:GetChecked() then -- v manages to be a NULL panel sometimes ??? don't ask me why idk
				if v:GetText() == "Outlay Color" then
					EasyChat.OutlayColor = self.ColorMixer:GetColor()
				elseif v:GetText() == "Outlay Outline Color" then
					EasyChat.OutlayOutlineColor = self.ColorMixer:GetColor()
				elseif v:GetText() == "Tab Color" then
					EasyChat.TabColor = self.ColorMixer:GetColor()
				elseif v:GetText() == "Tab Outline Color" then
					EasyChat.TabOutlineColor = self.ColorMixer:GetColor()
				end
			end
		end
		local tab = {
			outlay        = EasyChat.OutlayColor,
			outlayoutline = EasyChat.OutlayOutlineColor,
			tab           = EasyChat.TabColor,
			taboutline    = EasyChat.TabOutlineColor,
		}
		local json = util.TableToJSON(tab,true)
		file.Write("easychat/colors.txt",json)
	end,

	ResetTTL = function(self)
		RunConsoleCommand("easychat_hud_ttl","16")
	end,

	ResetFont = function(self)
		RunConsoleCommand("easychat_font", "Roboto")
		RunConsoleCommand("easychat_font_size","15")
	end,

	ResetChatHUDFont = function(self)
		local hud_font_editor = vgui.Create("ECChatHUDFontEditor")
		hud_font_editor:ResetFontData()
		hud_font_editor:Remove()
	end,

	ResetOptions = function(self)
		for _,v in pairs(EasyChat.GetRegisteredConvars()) do
			local cvar = v.Convar
			RunConsoleCommand(cvar:GetName(),cvar:GetDefault())
		end
	end,

	ResetAll = function(self)
		self:ResetColors()
		self:ResetFont()
		self:ResetChatHUDFont()
		self:ResetTTL()
		self:ResetOptions()
	end,

	ReloadChat = function(self)
		RunConsoleCommand("easychat_reload")
	end,
}

vgui.Register("ECSettingsTab",SETTINGS_TAB,"DScrollPanel")
