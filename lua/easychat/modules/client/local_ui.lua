local panel = vgui.Create("DFrame")
panel:SetTitle("")
panel.btnClose:Hide()
panel.btnMaxim:Hide()
panel.btnMinim:Hide()

panel.Think = function(self)
	if not IsValid(EasyChat.GUI.ChatBox) then return end
	local x,y,w,h = EasyChat.GUI.ChatBox:GetBounds()
	self:SetPos(x + w,y)
end

panel:SetWide(150)
panel.old_paint = panel.Paint
panel.Paint = function(self,w,h)
	if EasyChat.IsOpened() and EasyChat.Modes[EasyChat.Mode] and EasyChat.Modes[EasyChat.Mode].Name == "Local" then
		if EasyChat.UseDermaSkin then
			self.old_paint(self,w,h)
		else
			surface.SetDrawColor(EasyChat.OutlayColor)
			surface.DrawRect(0,0,w,h)
			surface.SetDrawColor(EasyChat.OutlayOutlineColor)
			surface.DrawOutlinedRect(0,0,w,h)
		end
		surface.SetFont("EasyChatFont")
		surface.SetTextPos(15,5)
		surface.SetTextColor(EasyChat.TextColor)
		surface.DrawText("Message receivers")
		local index = 1
		for k,v in pairs(player.GetAll()) do
			if v ~= LocalPlayer() and v:GetPos():Distance(LocalPlayer():GetPos()) <= GetConVar("easychat_local_msg_distance"):GetInt() then
				surface.SetTextPos(15,25*index)
				local col = team.GetColor(v:Team())
				surface.SetTextColor(col.r,col.g,col.g,255)
				local x,y = surface.GetTextSize(v:GetName())
				self:SetTall((25 * index) + y + 10)
				surface.DrawText(string.gsub(v:Nick(),"<.->",""))
				index = index + 1
			end
		end
	end
end

EasyChat.GUI.LocalPanel = panel

return "Local Message UI"
