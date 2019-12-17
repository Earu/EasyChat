local MAIN_TAB = {
    Init = function(self)
        local frame = self

        self.RichText  = self:Add("RichText")
        self.BtnSwitch = self:Add("DButton")
        self.TextEntry = self:Add("DTextEntry")

        self.RichText:SetVerticalScrollbarEnabled(true)
        self.RichText.Think = function(self)
            local x,y,w,h = frame:GetBounds()
            self:SetSize(w,h-20)
        end
        self.RichText.PerformLayout = function(self)
            self:SetFontInternal("EasyChatFont")
            self:SetFGColor(EasyChat.UseDermaSkin and EasyChat.TextColor or Color(0,0,0,255))
        end

        self.BtnSwitch:SetText("Say")
        self.BtnSwitch:SetFont("EasyChatFont")
        self.BtnSwitch:SetSize(65,20)
        self.BtnSwitch:SetZPos(10)
        self.BtnSwitch.Think = function(self)
            local x,y,w,h = frame:GetBounds()
            self:SetPos(0,h-self:GetTall())
            if EasyChat.Mode == 0 then
                self:SetText("Say")
            else
                self:SetText(EasyChat.Modes[EasyChat.Mode].Name)
            end
        end
        self.BtnSwitch.DoClick = function()
            local modeplus = EasyChat.Mode + 1
            EasyChat.Mode = modeplus > EasyChat.ModeCount and 0 or modeplus
        end

        self.TextEntry.Think = function(self)
            local x,y,w,h = frame:GetBounds()
            self:SetSize(w-frame.BtnSwitch:GetWide(),20)
            self:SetPos(frame.BtnSwitch:GetWide(),h-20)
        end
        self.TextEntry:SetHistoryEnabled(true)
        self.TextEntry.HistoryPos = 0
        self.TextEntry:SetUpdateOnType(true)
        self.TextEntry:SetZPos(10)

        if not EasyChat.UseDermaSkin then
            self.BtnSwitch:SetTextColor(EasyChat.TextColor)
            self.BtnSwitch.Paint = function(self,w,h)
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
        end
    end,
}

vgui.Register("ECChatTab",MAIN_TAB,"DPanel")
