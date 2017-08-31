local ec_global_on_open = GetConVar("easychat_global_on_open")
local ec_timestamps		= GetConVar("easychat_timestamps")
local ec_teams 			= GetConVar("easychat_teams")
local ec_teams_color 	= GetConVar("easychat_teams_colored")
local ec_player_color 	= GetConVar("easychat_players_colored")
local ec_hud_follow 	= GetConVar("easychat_hud_follow")

local settings_tab = {
    Checkboxes = {},

    Init = function(self)
        local frame = self

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
        self.TBoxHUDFollow          = self:Add("DCheckBoxLabel")
        self.TBoxTimeStamps         = self:Add("DCheckBoxLabel")
        self.TBoxDisplayTeam        = self:Add("DCheckBoxLabel")
        self.TBoxColorTeamTags      = self:Add("DCheckBoxLabel")
        self.TBoxColorPlayerNames   = self:Add("DCheckBoxLabel")
        self.TBoxGlobalTabOnOpen    = self:Add("DCheckBoxLabel")
        self.BtnResetOptions        = self:Add("DButton")
        self.BtnResetAll            = self:Add("DButton")
        self.BtnReloadChat          = self:Add("DButton")
        self.BtnUseDermaSkin        = self:Add("DButton")

        self.TBoxOutlayColor:SetText("Outlay Color")
        self.TBoxOutlayColor:SetPos(15,15)
        table.insert(self.Checkboxes,self.TBoxOutlayColor)

        self.TBoxOutlayOutlineColor:SetText("Outlay Outline Color")
        self.TBoxOutlayOutlineColor:SetPos(15,40)
        table.insert(self.Checkboxes,self.TBoxOutlayOutlineColor)

        self.TBoxTabColor:SetText("Tab Color")
        self.TBoxTabColor:SetPos(15,65)
        table.insert(self.Checkboxes,self.TBoxTabColor)

        self.TBoxTabOutlineColor:SetText("Tab Outline Color")
        self.TBoxTabOutlineColor:SetPos(15,90)
        table.insert(self.Checkboxes,self.TBoxTabOutlineColor)

        self.ColorMixer:Dock(RIGHT)
        self.ColorMixer:DockMargin(0,15,15,0)

        self.BtnApplyColors:SetPos(15,115)
        self.BtnApplyColors:SetText("Apply Color")
        self.BtnApplyColors:SetTextColor(EasyChat.TextColor)
        self.BtnApplyColors:SetSize(100,25)
        self.BtnApplyColors.DoClick = function(self)
            frame:SaveColors()
        end

        self.BtnResetColors:SetPos(15,150)
        self.BtnResetColors:SetText("Reset Colors")
        self.BtnResetColors:SetTextColor(EasyChat.TextColor)
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

        self.NbrWFontSize:SetPos(15,230)
        self.NbrWFontSize:SetSize(100,25)
        self.NbrWFontSize:SetMin(0)
        self.NbrWFontSize:SetMax(40)
        self.NbrWFontSize:SetValue(EasyChat.FontSize)
        self.NbrWFontSize.OnValueChanged = function(self,val)
            RunConsoleCommand("easychat_font_size",val)
        end
        cvars.AddChangeCallback("easychat_font_size",function(name,old,new)
            self.NbrWFontSize:SetValue(tonumber(new))
        end)

        self.BtnApplyFont:SetPos(15,270) --270
        self.BtnApplyFont:SetSize(100,25)
        self.BtnApplyFont:SetText("Apply Font")
        self.BtnApplyFont:SetTextColor(EasyChat.TextColor)

        self.BtnApplyFont.DoClick = function()
            RunConsoleCommand("easychat_font",self.TxtFontName:GetValue())
        end

        self.BtnFontReset:SetPos(15,300)
        self.BtnFontReset:SetSize(100,25)
        self.BtnFontReset:SetText("Reset Font")
        self.BtnFontReset:SetTextColor(EasyChat.TextColor)
        self.BtnFontReset.DoClick = function(self)
            frame:ResetFont()
        end

        self.TBoxHUDFollow:SetText("HUD follows chatbox")
        self.TBoxHUDFollow:SetPos(170,15)
        self.TBoxHUDFollow:SetChecked(ec_hud_follow:GetBool())
        self.TBoxHUDFollow.OnChange = function(self,val)
            RunConsoleCommand("easychat_hud_follow",(val and "1" or "0"))
        end
        cvars.AddChangeCallback("easychat_hud_follow",function(name,old,new)
            self.TBoxHUDFollow:SetChecked(old == "0")
        end)

        self.TBoxTimeStamps:SetText("Display timestamps")
        self.TBoxTimeStamps:SetPos(170,40)
        self.TBoxTimeStamps:SetChecked(ec_timestamps:GetBool())
        self.TBoxTimeStamps.OnChange = function(self,val)
            RunConsoleCommand("easychat_timestamps",(val and "1" or "0"))
        end
        cvars.AddChangeCallback("easychat_timestamps",function(name,old,new)
            self.TBoxTimeStamps:SetChecked(old == "0")
        end)

        self.TBoxDisplayTeam:SetText("Display team tags")
        self.TBoxDisplayTeam:SetPos(170,65)
        self.TBoxDisplayTeam:SetChecked(ec_teams:GetBool())
        self.TBoxDisplayTeam.OnChange = function(self,val)
            RunConsoleCommand("easychat_teams",(val and "1" or "0"))
        end
        cvars.AddChangeCallback("easychat_teams",function(name,old,new)
            self.TBoxDisplayTeam:SetChecked(old == "0")
        end)

        self.TBoxColorTeamTags:SetText("Color team tags")
        self.TBoxColorTeamTags:SetPos(170,90)
        self.TBoxColorTeamTags:SetChecked(ec_teams_color:GetBool())
        self.TBoxColorTeamTags.OnChange = function(self,val)
            RunConsoleCommand("easychat_teams_colored",(val and "1" or "0"))
        end
        cvars.AddChangeCallback("easychat_teams_colored",function(name,old,new)
            self.TBoxColorTeamTags:SetChecked(old == "0")
        end)

        self.TBoxColorPlayerNames:SetText("Color players")
        self.TBoxColorPlayerNames:SetPos(170,115)
        self.TBoxColorPlayerNames:SetChecked(ec_player_color:GetBool())
        self.TBoxColorPlayerNames.OnChange = function(self,val)
            RunConsoleCommand("easychat_players_colored",(val and "1" or "0"))
        end
        cvars.AddChangeCallback("easychat_players_colored",function(name,old,new)
            self.TBoxColorPlayerNames:SetChecked(old == "0")
        end)

        self.TBoxGlobalTabOnOpen:SetText("Global tab on open")
        self.TBoxGlobalTabOnOpen:SetPos(170,140)
        self.TBoxGlobalTabOnOpen:SetChecked(ec_global_on_open:GetBool())
        self.TBoxGlobalTabOnOpen.OnChange = function(self,val)
            RunConsoleCommand("easychat_global_on_open",(val and "1" or "0"))
        end
        cvars.AddChangeCallback("easychat_global_on_open",function(name,old,new)
            self.TBoxGlobalTabOnOpen:SetChecked(old == "0")
        end)

        self.BtnResetOptions:SetPos(170,165)
        self.BtnResetOptions:SetText("Reset Options")
        self.BtnResetOptions:SetTextColor(EasyChat.TextColor)
        self.BtnResetOptions:SetSize(100,25)
        self.BtnResetOptions.DoClick = function(self)
            frame:ResetOptions()
        end

        self.BtnResetAll:SetPos(170,200)
        self.BtnResetAll:SetText("Reset Everything")
        self.BtnResetAll:SetTextColor(EasyChat.TextColor)
        self.BtnResetAll:SetSize(100,25)
        self.BtnResetAll.DoClick = function(self)
            frame:ResetAll()
        end

        concommand.Add("easychat_reset_settings",self.ResetAll)

        self.BtnReloadChat:SetPos(170,235)
        self.BtnReloadChat:SetText("Restart")
        self.BtnReloadChat:SetTextColor(EasyChat.TextColor)
        self.BtnReloadChat:SetSize(100,25)
        self.BtnReloadChat.DoClick = function(self)
            frame:ReloadChat()
        end

        self.BtnUseDermaSkin:SetPos(170,270)
        self.BtnUseDermaSkin:SetText(EasyChat.UseDermaSkin and "Use custom skin" or "Use dermaskin")
        self.BtnUseDermaSkin:SetTextColor(EasyChat.TextColor)
        self.BtnUseDermaSkin:SetSize(100,25)

        self.BtnUseDermaSkin.DoClick = function()
            RunConsoleCommand("easychat_use_dermaskin",(EasyChat.UseDermaSkin and "0" or "1"))
        end

        if not EasyChat.UseDermaSkin then

            local ECButtonPaint = function(self,w,h)
                surface.SetDrawColor(EasyChat.OutlayColor)
                surface.DrawRect(0,0,w,h)
                surface.SetDrawColor(EasyChat.TabOutlineColor)
                surface.DrawOutlinedRect(0,0,w,h)
            end

            self.BtnUseDermaSkin.Paint = ECButtonPaint
            self.BtnApplyColors.Paint  = ECButtonPaint
            self.BtnResetColors.Paint  = ECButtonPaint
            self.BtnApplyFont.Paint    = ECButtonPaint
            self.BtnFontReset.Paint    = ECButtonPaint
            self.BtnResetOptions.Paint = ECButtonPaint
            self.BtnResetAll.Paint     = ECButtonPaint
            self.BtnReloadChat.Paint   = ECButtonPaint

        end

    end,

    ResetColors = function(self)
        EasyChat.OutlayColor        = Color(62,62,62,173)
        EasyChat.OutlayOutlineColor = Color(104,104,104,103)
        EasyChat.TabOutlineColor    = Color(74,72,72,255)
        EasyChat.TabColor     		= Color(43,43,43,255)
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
            if v:GetChecked() then
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

    ResetFont = function(self)
        RunConsoleCommand("easychat_font","HL2MPTypeDeath")
        RunConsoleCommand("easychat_font_size","17")
    end,

    ResetOptions = function(self)
        RunConsoleCommand("easychat_timestamps","0")
        RunConsoleCommand("easychat_teams","0")
        RunConsoleCommand("easychat_teams_colored","0")
        RunConsoleCommand("easychat_global_on_open","1")
        RunConsoleCommand("easychat_players_colored","1")
    end,

    ResetAll = function(self)
        self:ResetColors()
        self:ResetFont()
        self:ResetOptions()
    end,

    ReloadChat = function(self)
        RunConsoleCommand("easychat_reload")
    end,
}

vgui.Register("ECSettingsTab",settings_tab,"DPanel")
