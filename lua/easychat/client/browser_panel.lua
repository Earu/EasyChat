local BROWSER = {
    History = {},
    HistoryPos = 0,
    HistoryMove = false,
    Init = function(self)
        local frame = self

        self:SetSize(ScrW()-100,ScrH()-100)
        self:SetPos(ScrW()/2 - self:GetWide()/2,ScrH()/2 - self:GetTall()/2)
        self:SetTitle("EC-Browser")
        self.lblTitle:SetFont("EasyChatFont")
        self:SetSizable(true)
        self.btnClose:Hide()
		self.btnMaxim:Hide()
		self.btnMinim:Hide()

        self.Page     = self:Add("DHTML")
        self.URL      = self:Add("DTextEntry")
        self.Previous = self:Add("DButton")
        self.Next     = self:Add("DButton")
        self.Refresh  = self:Add("DButton")
        self.BtnClose = self:Add("DButton")
        self.BtnMaxim = self:Add("DButton")

        self.URL:Dock(TOP)
        self.URL:SetTall(20)
        self.URL:DockMargin(100,5,100,5)
        self.URL.OnEnter = function(self)
            frame.Page:OpenURL(self:GetText())
        end

        self.Page:Dock(FILL)
        self.Page.Paint = function(self,w,h)
            surface.SetDrawColor(255,255,255)
            surface.DrawRect(0,0,w,h)
        end

        self.Page.OnDocumentReady = function(self,url)
            if not frame.HistoryMove then
                frame.URL:SetText(url)
                frame.HistoryPos = frame.HistoryPos + 1
                table.insert(frame.History,frame.HistoryPos,url)
                frame.HistoryMove = false
            end
        end

        self.Previous:SetSize(30,22)
        self.Previous:SetPos(15,33)
        self.Previous:SetText("◄◄")
        self.Previous.DoClick = function(self)
            frame:PreviousURL()
        end

        self.Next:SetSize(30,22)
        self.Next:SetPos(55,33)
        self.Next:SetText("►►")
        self.Next.DoClick = function(self)
            frame:NextURL()
        end

        self.Refresh:SetSize(80,22)
        self.Refresh:SetPos(self:GetWide()-90,33)
        self.Refresh:SetText("Refresh")
        self.Refresh.DoClick = function(self)
            frame:RefreshURL()
        end

        self.Refresh.Think = function(self)
            self:SetPos(frame:GetWide()-90,33)
        end

        self.BtnClose:SetSize(45,18)
        self.BtnClose:SetZPos(10)
        self.BtnClose:SetTextColor(Color(200,20,20))
        self.BtnClose:SetFont("DermaDefaultBold")
        self.BtnClose:SetText("X")
        self.BtnClose.DoClick = function()
            frame:Remove()
        end
        self.BtnClose.Think = function(self)
            local x,y,w,h = frame:GetBounds()
            self:SetPos(w-self:GetWide()-6,-2)
        end

        self.BtnMaxim:SetSize(35,23)
        self.BtnMaxim:SetZPos(10)
        self.BtnMaxim:SetTextColor(Color(125,125,125))
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

        if not EasyChat.UseDermaSkin then
            self.Previous:SetTextColor(EasyChat.TextColor)
            self.Next:SetTextColor(EasyChat.TextColor)
            self.Refresh:SetTextColor(EasyChat.TextColor)

            local ECTabPaint = function(_,w,h)
                surface.SetDrawColor(EasyChat.TabColor)
                surface.DrawRect(0,0,w,h)
                surface.SetDrawColor(EasyChat.TabOutlineColor)
                surface.DrawOutlinedRect(0,0,w,h)
            end

            self.Previous.Paint = ECTabPaint
            self.Next.Paint     = ECTabPaint
            self.Refresh.Paint  = ECTabPaint

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
        end
    end,

    Paint = function(self,w,h)
        surface.SetDrawColor(EasyChat.OutlayColor)
        surface.DrawRect(0,0,w,h)
        surface.SetDrawColor(EasyChat.OutlayOutlineColor)
        surface.DrawOutlinedRect(0,0,w,h)
    end,

    PreviousURL = function(self)
        self.HistoryPos = self.HistoryPos - 1
        if self.HistoryPos == 0 then
            self.HistoryPos = #self.History
        end
        self.HistoryMove = true
        self.Page:OpenURL(self.History[self.HistoryPos])
    end,

    NextURL = function(self)
        self.HistoryPos = self.HistoryPos + 1
        if self.HistoryPos == #self.History + 1 then
            self.HistoryPos = 1
        end
        self.HistoryMove = true
        self.Page:OpenURL(self.History[self.HistoryPos])
    end,

    RefreshURL = function(self)
        self.HistoryMove = true
        self.Page:OpenURL((self.History[self.HistoryPos] or self.URL:GetText()))
    end,

    OpenURL = function(self,url)
        self.URL:SetText(url)
        self.Page:OpenURL(url)
    end,

    GetURL = function(self)
        return self.URL:GetText()
    end,

}

vgui.Register("ECBrowser", BROWSER, "DFrame")