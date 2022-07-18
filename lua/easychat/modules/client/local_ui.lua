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

panel:SetWide(150)
panel.old_paint = panel.Paint
local panel_title = "Message Receivers"
local ec_cvar_dist = GetConVar("easychat_local_msg_distance")
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
	local tw, th = surface.GetTextSize(panel_title)
	surface.SetTextPos(w / 2 - tw / 2, 5)
	surface.SetTextColor(EasyChat.TextColor)
	surface.DrawText(panel_title)

	local i = 1
	for _, ply in pairs(player.GetAll()) do
		if ply ~= LocalPlayer() and ply:GetPos():Distance(LocalPlayer():GetPos()) <= ec_cvar_dist:GetInt() then
			self:SetTall(5 + (20 * (i + 1)))

			ec_markup.CachePlayer("LocalUI", ply, function()
				return ec_markup.AdvancedParse(ply:RichNick(), {
					nick = true,
					default_font = "EasyChatFont",
					default_color = team.GetColor(ply:Team()),
				})
			end):Draw(15, 5 + (20 * i))

			i = i + 1
		end
	end

	if i == 1 then
		self:SetTall(5 + th + 5)
	end
end

EasyChat.GUI.LocalPanel = panel

return "Local Message UI"
