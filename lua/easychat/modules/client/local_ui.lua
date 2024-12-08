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
panel:SetZPos(-32768)
panel:SetPaintedManually(true)
panel.old_paint = panel.Paint
local panel_title = "Message Receivers"
local ec_cvar_dist = GetConVar("easychat_local_msg_distance")
local horizontal_padding = 15
local vertical_padding = 5

hook.Add( "ECChatboxPaint", "LocalUI", function( chatbox, w, h )
	panel:PaintManual()
end )

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
	surface.SetTextPos(w / 2 - tw / 2, vertical_padding)
	surface.SetTextColor(EasyChat.TextColor)
	surface.DrawText(panel_title)

	local me = LocalPlayer()
	local my_pos = me:GetPos()
	local range = ec_cvar_dist:GetInt()
	local range2 = range * range
	local i = 1

	for _, ply in pairs(player.GetAll()) do
		if ply ~= me and ply:GetPos():DistToSqr(my_pos) <= range2 then
			ec_markup.CachePlayer("LocalUI", ply, function()
				return ec_markup.AdvancedParse(ply:RichNick(), {
					nick = true,
					default_font = "EasyChatFont",
					default_color = team.GetColor(ply:Team()),
				})
			end):Draw(horizontal_padding, vertical_padding + i * th)

			i = i + 1
		end
	end

	self:SetTall(vertical_padding * 2 + th * i)
end

if EasyChat and EasyChat.GUI and IsValid(EasyChat.GUI.LocalPanel) then
	EasyChat.GUI.LocalPanel:Remove()
end

EasyChat.GUI.LocalPanel = panel

return "Local Message UI"
