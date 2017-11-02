local CHATBOX = {
    Init = function(self)
        local frame = self
        self:ShowCloseButton(true)
        self:SetDraggable(true)
        self:SetSizable(true)
        self:SetDeleteOnClose(false)
        self:SetTitle("")

        self.btnClose:Hide()
        self.btnMaxim:Hide()
        self.btnMinim:Hide()

        self.BtnClose = self:Add("DButton")
        self.BtnMaxim = self:Add("DButton")
        self.Tabs     = self:Add("DPropertySheet")
        self.Scroller = self.Tabs.tabScroller
        self.OldTab   = NULL

        self.BtnClose:SetSize(45,18)
        self.BtnClose:SetZPos(10)
        if not EasyChat.UseDermaSkin then
            self.BtnClose:SetTextColor(Color(200,20,20))
        end
        self.BtnClose:SetFont("DermaDefaultBold")
        self.BtnClose:SetText("X")

        self.BtnClose.Think = function(self)
            local x,y,w,h = frame:GetBounds()
            self:SetPos(w-self:GetWide()-6,-2)
        end

        self.BtnMaxim:SetSize(35,23)
        self.BtnMaxim:SetZPos(10)
        if not EasyChat.UseDermaSkin then
            self.BtnMaxim:SetTextColor(Color(125,125,125))
        end
        self.BtnMaxim:SetFont("DermaLarge")
        self.BtnMaxim:SetText("▭")
        self.BtnMaxim.IsFullScreen = false
        self.BtnMaxim.DoClick = function(self)
            if not self.IsFullScreen then
                local a,b,c,d = frame:GetBounds()
                self.Before = {
                    x = a,
                    y = b,
                    w = c,
                    h = d,
                }
                frame:SetSize(ScrW(),ScrH())
                frame:SetPos(0,0)
                self.IsFullScreen = true
            else
                frame:SetPos(self.Before.x,self.Before.y)
                frame:SetSize(self.Before.w,self.Before.h)
                self.IsFullScreen = false
            end
        end
        self.BtnMaxim.Think = function(self)
            local x,y,w,h = frame:GetBounds()
            self:SetPos(w-self:GetWide()-50,-7)
        end

        self.Tabs:SetPos(6,6)

        self.Tabs.old_performlayout = self.Tabs.PerformLayout
        self.Tabs.PerformLayout = function(self)
            self.old_performlayout(self)
            frame.Scroller:SetTall(20)
        end

        self.Tabs.Think = function(self)
            local x,y,w,h = frame:GetBounds()
            self:SetSize(w-13,h-11)
            local current = self:GetActiveTab()
            if current ~= frame.OldTab then
                hook.Run("ECTabChanged",frame.OldTab.Name,current.Name)
                frame.OldTab = current
            end
        end

        self.Scroller:SetParent(self.Tabs)
        self.Scroller:Dock(TOP)
        self.Scroller:SetSize(0,20)
        self.Scroller.m_iOverlap = -2

        if not EasyChat.UseDermaSkin then
            self.Paint = function(self,w,h)
                surface.SetDrawColor(EasyChat.OutlayColor)
                surface.DrawRect(0,0,w,h)
                surface.SetDrawColor(EasyChat.OutlayOutlineColor)
                surface.DrawOutlinedRect(0,0,w,h)
            end

            self.BtnClose.Paint = function(self,w,h)
                draw.RoundedBoxEx(3,0,0,w,h,EasyChat.OutlayOutlineColor,false,true,false,true)
                draw.RoundedBoxEx(3,1,1,w-2,h-2,Color(246,40,40),false,true,false,true)
                surface.SetDrawColor(EasyChat.OutlayOutlineColor)
                surface.DrawLine(0,2,w,2)
            end

            self.BtnMaxim.Paint = function(self,w,h)
                draw.RoundedBoxEx(3,0,0,w,h,EasyChat.OutlayOutlineColor,true,false,true,false)
                draw.RoundedBoxEx(3,1,1,w-2,h-2,Color(225,225,225),true,false,true,false)
                surface.SetDrawColor(EasyChat.OutlayOutlineColor)
                surface.DrawLine(0,7,w,7)
            end


            self.Tabs.Paint = function(self,w,h)
                surface.SetDrawColor(0,0,0,0)
                surface.DrawRect(0, 0, w, h)
            end
        end
    end,
}

vgui.Register("ECChatBox",CHATBOX,"DFrame")
