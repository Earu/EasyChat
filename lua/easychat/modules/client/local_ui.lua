local panel = vgui.Create("DFrame")
panel:SetTitle("")
panel.btnClose:Hide()
panel.btnMaxim:Hide()
panel.btnMinim:Hide()

function panel:Think()
	if not IsValid(EasyChat.GUI.ChatBox) then return end
	local x, y, w, h = EasyChat.GUI.ChatBox:GetBounds()
	self:SetPos(x + w, y)
end

panel:SetWide(150)
panel.old_paint = panel.Paint
function panel:Paint(w, h)
	if EasyChat.IsOpened() and EasyChat.Modes[EasyChat.Mode] and EasyChat.Modes[EasyChat.Mode].Name == "Local" then
		if EasyChat.UseDermaSkin then
			self:old_paint(w, h)
		else
			surface.SetDrawColor(EasyChat.OutlayColor)
			surface.DrawRect(0, 0, w, h)
			surface.SetDrawColor(EasyChat.OutlayOutlineColor)
			surface.DrawOutlinedRect(0, 0, w, h)
		end

		surface.SetFont("EasyChatFont")
		surface.SetTextPos(15, 5)
		surface.SetTextColor(EasyChat.TextColor)
		surface.DrawText("Message receivers")

		local i = 1
		for _, ply in pairs(player.GetAll()) do
			if ply ~= LocalPlayer()
				and ply:GetPos():Distance(LocalPlayer():GetPos()) <= GetConVar("easychat_local_msg_distance"):GetInt()
			then
				local team_color = team.GetColor(ply:Team())

				surface.SetTextPos(15, 25 * i)
				surface.SetTextColor(team_color.r, team_color.g, team_color.g, 255)

				local x, y = surface.GetTextSize(ply:GetName())
				self:SetTall((25 * i) + y + 10)

				surface.DrawText(string.gsub(ply:Nick(), "<.->", ""))
				i = i + 1
			end
		end
	end
end

EasyChat.GUI.LocalPanel = panel

return "Local Message UI"
