local panel = vgui.Create("DFrame")
panel:SetTitle("")
panel.btnClose:Hide()
panel.btnMaxim:Hide()
panel.btnMinim:Hide()

function panel:Think()
	if not IsValid(EasyChat.GUI.ChatBox) then return end
	local x, y, w, _ = EasyChat.GUI.ChatBox:GetBounds()
	self:SetPos(x + w, y)
end

local nick_cache = {}
local function cache_nick(ply)
	local nick, team_color = ply:Nick(), team.GetColor(ply:Team())
	local cache = nick_cache[nick]
	if cache and cache.DefaultColor == team_color then
		return cache
	end

	local mk = ec_markup.Parse(nick, nil, true, team_color, "EasyChatFont")
	nick_cache[nick] = mk

	return mk
end

panel:SetWide(150)
panel.old_paint = panel.Paint
function panel:Paint(w, h)
	local cur_mode = EasyChat.Modes[EasyChat.Mode]
	if EasyChat.IsOpened() and cur_mode and cur_mode.Name == "Local" then
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
		surface.DrawText("Message Receivers")

		local i = 1
		for _, ply in pairs(player.GetAll()) do
			if ply ~= LocalPlayer()
				and ply:GetPos():Distance(LocalPlayer():GetPos()) <= GetConVar("easychat_local_msg_distance"):GetInt()
			then
				self:SetTall(5 + (20 * (i + 1)))

				local mk = cache_nick(ply)
				mk:Draw(15, 5 + (20 * i))

				i = i + 1
			end
		end
	end
end

EasyChat.GUI.LocalPanel = panel

hook.Add("ECDestroyed", "EasyChatModuleLocalUI", function()
	if IsValid(panel) then panel:Remove() end
end)

return "Local Message UI"
