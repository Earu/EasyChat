local TAG = "EasyChatModuleVoiceHUD"
local EC_VOICE_HUD = CreateClientConVar("easychat_voice_hud", "1", true, false, "Should we use EasyChat's voice hud")
local EC_VOICE_RINGS = CreateClientConVar("easychat_voice_rings", "1", true, false, "Should we draw voice rings under the player")
EasyChat.RegisterConvar(EC_VOICE_HUD, "Use EasyChat's voice HUD")
EasyChat.RegisterConvar(EC_VOICE_RINGS, "Draw voice rings under players")

local ply_voice_panels = {}
cvars.RemoveChangeCallback(EC_VOICE_HUD:GetName(), TAG)
cvars.AddChangeCallback(EC_VOICE_HUD:GetName(), function()
	if EC_VOICE_HUD:GetBool() and IsValid(g_VoicePanelList) then
		g_VoicePanelList:Clear()
		return
	end

	if not EC_VOICE_HUD:GetBool() and IsValid(EasyChat.GUI.VoiceList) then
		EasyChat.GUI.VoiceList:Remove()
	end
end, TAG)

local VOICE_LOOPBACK = GetConVar("voice_loopback")
local function get_player_volume(ply)
	if not IsValid(ply) then return 0 end

	if ply == LocalPlayer() then
		return VOICE_LOOPBACK:GetBool() and ply:VoiceVolume() or 0.15 + math.sin(CurTime() * 10) / 20
	end

	return ply:VoiceVolume()
end

local PANEL = {}
local MAX_VOICE_DATA = 50
local PANEL_HEIGHT = 40

function PANEL:Init()
	self.LabelName = vgui.Create("DLabel", self)
	self.LabelName:SetFont("GModNotify")
	self.LabelName:Dock(FILL)
	self.LabelName:DockMargin(8, 0, 0, 0)
	self.LabelName:SetTextColor(color_white)

	self.Avatar = vgui.Create("AvatarImage", self)
	self.Avatar:Dock(LEFT)
	self.Avatar:SetSize(PANEL_HEIGHT, PANEL_HEIGHT)
	self.Avatar:SetPaintedManually(true)

	self.Color = color_transparent
	self.VoiceData = {}
	self.NextVoiceData = 0

	self:SetSize(250, PANEL_HEIGHT + 8)
	self:DockPadding(4, 4, 4, 4)
	self:DockMargin(2, 2, 2, 2)
	self:Dock(BOTTOM)

	for _ = 1, MAX_VOICE_DATA do
		table.insert(self.VoiceData, 2)
	end

	EasyChat.BlurPanel(self, 0, 0, 0, 0)
end

function PANEL:Setup(ply)
	self.ply = ply

	self.Markup = ec_markup.Parse(ply:RichNick(), nil, true)
	self.LabelName:SetText("")

	self.Avatar:SetPlayer(ply, 64)
	self.Color = team.GetColor(ply:Team())
	self:InvalidateLayout()
end

local GMOD_VOCAL_DISTANCE_THRESHOLD = 3000
local function is_in_audible_area(ply)
	if not IsValid(ply) then return false end

	local lp = LocalPlayer()
	if not IsValid(lp) then return false end -- this can be run early, and LocalPlayer can be invalid

	return ply:GetPos():Distance(lp:GetPos()) < GMOD_VOCAL_DISTANCE_THRESHOLD
end

function PANEL:Paint(w, h)
	if not IsValid(self.ply) then return end

	if self.NextVoiceData <= CurTime() then
		if is_in_audible_area(self.ply) then
			table.insert(self.VoiceData, 2 + (get_player_volume(self.ply) * h * 2))
		else
			table.insert(self.VoiceData, 2)
		end

		if #self.VoiceData > MAX_VOICE_DATA then
			table.remove(self.VoiceData, 1)
		end

		self.NextVoiceData = CurTime() + 0.025
	end

	local wep = LocalPlayer():GetActiveWeapon()
	if IsValid(wep) and wep:GetClass() == "gmod_camera" then return end

	local bg_color = EasyChat.OutlayColor
	surface.SetDrawColor(bg_color.r, bg_color.g, bg_color.b, bg_color.a)
	surface.DrawRect(0, 0, w, h)

	local visualizer_color = Color(255 - bg_color.r, 255 - bg_color.g, 255 - bg_color.b)
	surface.SetDrawColor(visualizer_color.r, visualizer_color.g, visualizer_color.b, 255)
	local ratio = w / MAX_VOICE_DATA
	for i, vdata in ipairs(self.VoiceData) do
		surface.DrawRect((i - 1) * ratio, h - vdata, ratio, vdata)
	end

	local outline_color = Color(EasyChat.OutlayOutlineColor:Unpack())
	surface.SetDrawColor(outline_color.r, outline_color.g, outline_color.b, 100 + get_player_volume(self.ply) * 155)
	surface.DrawOutlinedRect(0, 0, w, h)

	if self.Markup then
		self.Markup:Draw(PANEL_HEIGHT + 10, h / 2 - self.Markup:GetTall() / 2)
	end

	self.Avatar:PaintManual()
end

function PANEL:Think()
	if IsValid(self.ply) and not self.Markup then
		self.LabelName:SetText(self.ply:RichNick())
	end

	if self.RemoveTime and CurTime() >= self.RemoveTime then
		self:Remove()
		ply_voice_panels[self.ply] = nil
	end
end

vgui.Register("ECVoiceNotify", PANEL, "DPanel")

local function create_voice_vgui()
	EasyChat.GUI.VoiceList = vgui.Create("DPanel")
	EasyChat.GUI.VoiceList:ParentToHUD()
	EasyChat.GUI.VoiceList:SetPos(ScrW() - 300, 200)
	EasyChat.GUI.VoiceList:SetSize(250, ScrH() - 400)
	EasyChat.GUI.VoiceList:SetPaintBackground(false)
end

local function player_end_voice(ply)
	local voice_panel = ply_voice_panels[ply]
	if IsValid(voice_panel) then
		voice_panel.RemoveTime = CurTime() + 1
	end
end

local function player_start_voice(ply)
	if not IsValid(EasyChat.GUI.VoiceList) then
		create_voice_vgui()
	end

	local voice_panel = ply_voice_panels[ply]
	if IsValid(voice_panel) then
		if voice_panel.RemoveTime then
			voice_panel.RemoveTime = nil
		end

		return
	end

	if not IsValid(ply) then return end

	local panel = EasyChat.GUI.VoiceList:Add("ECVoiceNotify")
	panel:Setup(ply)
	ply_voice_panels[ply] = panel
end

GAMEMODE.old_PlayerStartVoice = GAMEMODE.old_PlayerStartVoice or GAMEMODE.PlayerStartVoice
GAMEMODE.old_PlayerEndVoice = GAMEMODE.old_PlayerEndVoice or GAMEMODE.PlayerEndVoice

function GAMEMODE:PlayerStartVoice(ply)
	if EC_VOICE_HUD:GetBool() then
		player_start_voice(ply)
	else
		self:old_PlayerStartVoice(ply)
	end
end

function GAMEMODE:PlayerEndVoice(ply)
	if EC_VOICE_HUD:GetBool() then
		player_end_voice(ply)
	else
		self:old_PlayerEndVoice(ply)
	end
end

local function voice_clean()
	for ply, _ in pairs(ply_voice_panels) do
		if not IsValid(ply) then
			player_end_voice(ply)
		else
			if not is_in_audible_area(ply) then
				player_end_voice(ply)
			end
		end
	end
end

timer.Create(TAG, 2, 0, voice_clean)

local circle_mat = Material("SGM/playercircle")
local function draw_voice_ring(ply)
	if not IsValid(ply) then return end
	if not ply:Alive() then return end
	if not ply:IsSpeaking() then return end

	local trace = {}
	trace.start = ply:GetPos() + Vector(0, 0, 50)
	trace.endpos = trace.start + Vector(0, 0, -300)
	trace.filter = ply

	local tr = util.TraceLine(trace)
	if not tr.HitWorld then
		tr.HitPos = ply:GetPos()
	end

	local color = team.GetColor(ply:Team())
	color.a = 80 + (100 * get_player_volume(ply) * 6)
	if not ply:IsVoiceAudible() then color.a = 0 end

	render.SetMaterial(circle_mat)
	render.DrawQuadEasy(tr.HitPos + tr.HitNormal, tr.HitNormal, 128, 128, color)
end

hook.Add("PostDrawTranslucentRenderables", TAG, function()
	if not EC_VOICE_RINGS:GetBool() then return end

	for _, ply in ipairs(player.GetAll()) do
		draw_voice_ring(ply)
	end
end)

hook.Add("ECResolutionChanged", TAG, function()
	if IsValid(EasyChat.GUI.VoiceList) then
		EasyChat.GUI.VoiceList:Remove()
	end
end)

return "Voice HUD"
