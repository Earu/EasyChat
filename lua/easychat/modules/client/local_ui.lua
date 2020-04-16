local panel = vgui.Create("DFrame")
panel:SetTitle("")
panel.btnClose:Hide()
panel.btnMaxim:Hide()
panel.btnMinim:Hide()

function panel:Think()
	if not IsValid(EasyChat.GUI.ChatBox) then return end
	local chat_x, chat_y, chat_w, _ = EasyChat.GUI.ChatBox:GetBounds()
	local w = self:GetWide()

	if EasyChat.IsOnRightSide() then
		self:SetPos(chat_x - w, chat_y)
	else
		self:SetPos(chat_x + chat_w, chat_y)
	end
end

local nick_cache = setmetatable({}, { __mode = "k" })
local function cache_nick(ply)
	local nick, team_color = ply:Nick(), team.GetColor(ply:Team())
	local cache = nick_cache[ply]
	if cache and cache.Nick == nick and cache.TeamColor == team_color then
		return cache.Markup
	end

	local mk = ec_markup.Parse(nick, nil, true, team_color, "EasyChatFont")
	nick_cache[ply] = { Markup = mk, Nick = nick, TeamColor = team_color }

	return mk
end

panel:SetWide(150)
panel.old_paint = panel.Paint
function panel:Paint(w, h)
	if not EasyChat.IsOpened() then return end
	if EasyChat.GetActiveTab().Name ~= "Global" then return end
	if EasyChat.GetCurrentMode().Name ~= "Local" then return end

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

EasyChat.GUI.LocalPanel = panel

hook.Add("ECDestroyed", "EasyChatModuleLocalUI", function()
	if IsValid(panel) then panel:Remove() end
end)

return "Local Message UI"
