--not finished but example of a module you could do
if CLIENT then
	local panel  = vgui.Create("DPanel")
	local plys   = panel:Add("DComboBox")
	local add    = panel:Add("DButton")
	local tabs   = panel:Add("DColumnSheet")
	local tentry = panel:Add("DTextEntry")

	EasyChat.AddTab("PMs",panel)
	
	plys:Dock(LEFT)
	plys:DockMargin(5,5,15,5)
	add:Dock(LEFT)
	tentry:Dock(BOTTOM)
	tabs:Dock(FILL)

	for _,pl in pairs(player.GetAll()) do
		plys:AddChoice(pl:GetName(),pl)
	end

	gameevent.Listen("player_connect")
	hook.Add("player_connect","EasyChatPMRefreshListAdd",function(data)
		local pl = Player(data.userid)
		plys:AddChoice(pl:GetName(),pl)
	end)

	gameevent.Listen("player_disconnect")
	hook.Add("player_disconnect","EasyChatPMRefreshListAdd",function(data)
		plys:Clear()
		for _,pl in pairs(player.GetAll()) do
			plys:AddChoice(pl:GetName(),pl)
		end
	end)

	tentry.OnKeyCodeTyped = function( self, code )
		if code == KEY_ESCAPE then
			EasyChat.Close()
			gui.HideGameUI()
		elseif code == KEY_ENTER then
			if string.Trim( self:GetText() ) != "" then
				--[[net.Start(netreceivePM)
				net.WriteString(string.sub(self:GetText(),1,3000))
				net.SendToServer()]]--
			end

			self:AddHistory(self:GetText())

			self.HistoryPos = 0
		end

		if code == KEY_UP then
			self.HistoryPos = self.HistoryPos - 1
			self:UpdateFromHistory()
		elseif code == KEY_DOWN then
			self.HistoryPos = self.HistoryPos + 1
			self:UpdateFromHistory()
		end

		if code == KEY_TAB then
			local a = hook.Run("OnChatTab", self:GetText())	
			self:SetText(a)
			timer.Simple(0, function() self:RequestFocus() self:SetCaretPos(#self:GetText()) end)
			return true
		end

	end

	local CreatePM = function(ply)
		local PM     = vgui.Create("DPanel")
		local richt  = PM:Add("RichText")
		local tentry = PM:Add("tentry")

		tabs:AddSheet(ply:GetName(),PM)
		PM:Dock(FILL)
		richt:Dock(FILL)

		tabs["PM_"..ply:EntIndex()] = {
			Player    = ply,
			Panel     = PM,
			RichText  = richt,
		}

	end

	local GetPM = function(ply)
		return tabs["PM_"..ply:EntIndex()]
	end

	local AppendPM = function(ply,msg)
		local PM = GetPM(ply)
		local isurl,_ = EasyChat.IsURL(msg)
		
		PM.RichText:InsertColorChange(team.GetColor(ply:Team()))
		PM.RichText:AppendText(ply:GetName())
		PM.RichText:InsertColorChange(255,255,255,255)
		PM.RichText:AppendText(":")
		
		if isurl then -- CANCER V2
			local poses = EasyChat.GetURLPoses(msg)
			for k,pos in pairs(poses) do
				local lspos,lepos = pos.Start,pos.End
				PM.RichText:AppendText(string.sub(msg,k == 1 and 1 or pos[k - 1].End + 1,lspos - 1))
				
				local insert = string.sub(msg,lspos,lepos)
				local url,_ = string.gsub(insert,"^%s:","")
				local _,www = EasyChat.IsURL(insert)
				PM.RichText:InsertClickableTextStart(www and "http://"..url or url)
				PM.RichText:AppendText(insert)
				PM.RichText:InsertClickableTextEnd()
				
				PM.RichText:AppendText(string.sub(msg,lepos + 1,pos[k + 1] and pos[k + 1].Start - 1 or nil))
			end
		
		else
			PM.RichText:AppendText(msg)
		end

		PM.RichText:AppendText("\n")

		--if EasyChat.TabControl:GetActiveTab() == 
	end

end

if SERVER then

end
