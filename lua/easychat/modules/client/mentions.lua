local EC_MENTION = CreateConVar("easychat_mentions", "1", FCVAR_ARCHIVE, "Highlights messages containing your name")
local EC_MENTION_FLASH = CreateConVar("easychat_mentions_flash_window", "1", FCVAR_ARCHIVE, "Flashes your window when you get mentioned")
local EC_MENTION_COLOR = CreateConVar("easychat_mentions_color", "244 167 66", FCVAR_ARCHIVE, "Color of the mentions")
local EC_MENTION_SHOW_MISSED = CreateConVar("easychat_mentions_show_missed", "1", FCVAR_ARCHIVE, "Show mentions you have missed when AFK / tabbed out")

local EC_MENTION_FILTERS = CreateConVar("easychat_mentions_filters", "1", FCVAR_ARCHIVE, "Enables mention filters")
local FILTER_PATH = "easychat/mention_filters.txt"

local mentions = {}
EasyChat.Mentions = mentions

if file.Exists(FILTER_PATH, "DATA") then
	local contents = file.Read(FILTER_PATH, "DATA")
	if #contents:Trim() > 0 then
		mentions.Filters = ("\r?\n"):Explode(contents, true)
	else
		mentions.Filters = {}
	end
else
	mentions.Filters = {}
end

local function save_filters()
	local filter_content = table.concat(mentions.Filters, "\n")
	file.Write(FILTER_PATH, filter_content)
end

function mentions:GetColor()
	local r, g, b = EC_MENTION_COLOR:GetString():match("^(%d%d?%d?) (%d%d?%d?) (%d%d?%d?)")
	r = r and tonumber(r) or 244
	g = g and tonumber(g) or 167
	b = b and tonumber(b) or 66

	return Color(r, g, b)
end

do
	local settings = EasyChat.Settings
	local category_name = "Mentions"

	settings:AddCategory(category_name)

	settings:AddConvarSettingsSet(category_name, {
		[EC_MENTION] = "Color messages containing your name",
		[EC_MENTION_FLASH] = "Flashes your game when you are mentioned",
		[EC_MENTION_SHOW_MISSED] = "Show mentions you have missed when AFK / tabbed out"
	})

	settings:AddSpacer(category_name)

	local setting_mention_color = settings:AddSetting(category_name, "color", "Mention Color")
	setting_mention_color:SetColor(mentions:GetColor())

	local setting_save_color = settings:AddSetting(category_name, "action", "Save Mention Color")
	setting_save_color.DoClick = function()
		local color = setting_mention_color:GetColor()
		EC_MENTION_COLOR:SetString(("%d %d %d"):format(color.r, color.g, color.b))
	end

	settings:AddSpacer(category_name)

	settings:AddConvarSetting(category_name, "boolean", EC_MENTION_FILTERS, "Enable mention filters")
	local setting_filters = settings:AddSetting(category_name, "list", "Filters")
	setting_filters.List:SetMultiSelect(false)
	setting_filters.List:AddColumn("Filter")

	local function build_filter_list()
		setting_filters.List:Clear()
		for _, filter in pairs(mentions.Filters) do
			setting_filters.List:AddLine(filter)
		end
	end

	build_filter_list()

	local setting_add_filter = settings:AddSetting(category_name, "action", "Add Filter")
	setting_add_filter.DoClick = function()
		EasyChat.AskForInput("Add Filter", function(filter)
			table.insert(mentions.Filters, filter)
			save_filters()
			build_filter_list()
		end, false)
	end

	local setting_remove_filter = settings:AddSetting(category_name, "action", "Remove Filter")
	setting_remove_filter.DoClick = function()
		local _, selected_line = setting_filters.List:GetSelectedLine()
		if not IsValid(selected_line) then return end

		local selected_filter = selected_line:GetColumnText(1)
		for i, filter in pairs(mentions.Filters) do
			if selected_filter == filter then
				table.remove(mentions.Filters, i)
				break
			end
		end

		save_filters()
		build_filter_list()
	end

	concommand.Add("easychat_mentions_add_filter", function(_, _, _, filter)
		table.insert(mentions.Filters, filter)
		save_filters()
		build_filter_list()
	end)
end

local mentions_frame = nil
local function create_mention_panel()
	local frame = vgui.Create("DFrame")
	frame.btnMaxim:Hide()
	frame.btnMinim:Hide()
	frame.btnClose:SetSize(30, 30)
	frame.btnClose:SetZPos(10)
	frame.btnClose:SetFont("DermaDefaultBold")
	frame.btnClose:SetText("X")

	frame:SetTitle("Missed Mentions")
	frame.lblTitle:SetFont("EasyChatFont")

	local btn_ok = frame:Add("DButton")
	btn_ok:SetText("Ok")
	btn_ok:SetTall(30)
	btn_ok:Dock(BOTTOM)
	btn_ok:DockMargin(5, 5, 5, 5)
	btn_ok.DoClick = function() frame:Close() end

	local richtext = frame:Add("RichTextLegacy")
	richtext:Dock(FILL)
	richtext:DockMargin(5, 5, 5, 5)
	richtext.ActionSignal = EasyChat.GUI.RichText.ActionSignal
	richtext.PerformLayout = function(self)
		self:SetFontInternal("EasyChatFont")
		self:SetUnderlineFont("EasyChatFont")
		if not EasyChat.UseDermaSkin then
			self:SetFGColor(EasyChat.TextColor)
		end
	end

	frame.RichText = richtext

	if not EasyChat.UseDermaSkin then
		frame.lblTitle:SetTextColor(EasyChat.TextColor)
		frame.btnClose:SetTextColor(EasyChat.TextColor)
		frame.btnClose.Paint = function() end

		EasyChat.BlurPanel(frame, 0, 0, 0, 0)

		frame.Paint = function(self, w, h)
			surface.SetDrawColor(EasyChat.OutlayColor)
			surface.DrawRect(0, 0, w, 25)

			local tab_col = EasyChat.TabColor
			surface.SetDrawColor(tab_col.r, tab_col.g, tab_col.b, tab_col.a)
			surface.DrawRect(0, 25, w, h - 25)

			surface.SetDrawColor(EasyChat.OutlayOutlineColor)
			surface.DrawOutlinedRect(0, 0, w, h)
		end

		btn_ok:SetTextColor(EasyChat.TextColor)
		btn_ok.Paint = function(self,w,h)
			local col1, col2 = EasyChat.OutlayColor, EasyChat.TabOutlineColor
			if self:IsHovered() then
				col1 = Color(col1.r + 50, col1.g + 50, col1.b + 50, col1.a + 50)
				col2 = Color(255 - col2.r, 255 - col2.g, 255 - col2.b, 255 - col2.a)
			end

			surface.SetDrawColor(col1)
			surface.DrawRect(0, 0, w, h)
			surface.SetDrawColor(col2)
			surface.DrawOutlinedRect(0, 0, w, h)
		end
	end

	frame:SetSize(400, 400)
	frame:SetVisible(false)

	mentions_frame = frame
end

function mentions:ShowMissedMentions()
	if not IsValid(mentions_frame) then return end

	mentions_frame:SetVisible(true)
	mentions_frame:Center()
	mentions_frame:MakePopup()
end

function mentions:AddMissedMention(data)
	if not EC_MENTION_SHOW_MISSED:GetBool() then return end

	if not IsValid(mentions_frame) then
		create_mention_panel()
	end

	EasyChat.AddText(mentions_frame.RichText, unpack(data))
end

local function filter_match(text)
	if not EC_MENTION_FILTERS:GetBool() then return false end

	-- if its using malformed patterns, we dont want to break
	local succ, ret = pcall(function()
		for _, filter in pairs(mentions.Filters) do
			if text:match(filter) then return true end
		end

		return false
	end)

	if succ then return ret end
	return false
end

function mentions:IsValidPlayer(ply)
	local lp = LocalPlayer()
	if not IsValid(lp) then return false end
	if ply == lp then return false end
	if IsValid(ply) and ply:IsBot() then return false end

	return true
end

function mentions:IsMention(msg)
	if not EC_MENTION:GetBool() then return false end

	local should_mention = EasyChat.SafeHookRun("ECShouldBeMention", msg)
	if should_mention == false then return false end

	local stripped_msg = ec_markup.GetText(msg):lower()
	if filter_match(stripped_msg) then return true end

	local ply = LocalPlayer()
	if not IsValid(ply) then return false end
	if not ply.Nick then return false end

	local ply_name = (ply:Nick() or ""):lower():PatternSafe()
	local nick_mention = stripped_msg:match(ply_name)
	local is_nick_match = not stripped_msg:match("^[%!%.%/]") and nick_mention
	return is_nick_match and #nick_mention > 1
end

local old_focus = true
hook.Add("Think", "EasyChatModuleMention", function()
	local has_focus = system.HasFocus()
	if old_focus ~= has_focus and has_focus then
		mentions:ShowMissedMentions()
	end

	old_focus = has_focus
end)

function GAMEMODE:ECPlayerMention(ply, msg, is_team, is_dead, is_local, data)
	if not system.HasFocus() then
		mentions:AddMissedMention(data)
	end
end

local function reset_cvar(cvar) cvar:SetString(cvar:GetDefault()) end
hook.Add("ECFactoryReset", "EasyChatModuleMention", function()
	reset_cvar(EC_MENTION)
	reset_cvar(EC_MENTION_COLOR)
	reset_cvar(EC_MENTION_FILTERS)
	reset_cvar(EC_MENTION_FLASH)
	reset_cvar(EC_MENTION_SHOW_MISSED)
end)

local color_white = color_white
hook.Add("OnPlayerChat", "EasyChatModuleMention", function(ply, msg, is_team, is_dead, is_local)
	if not mentions:IsValidPlayer(ply) then return end
	if not mentions:IsMention(msg) then return end

	if EC_MENTION_FLASH:GetBool() then
		system.FlashWindow()
	end

	EasyChat.FlashTab("Global")

	local msg_components = {}
	if is_dead then
		EasyChat.AddDeadTag(msg_components)
	end

	if is_team then
		EasyChat.AddTeamTag(msg_components)
	end

	if is_local then
		EasyChat.AddLocalTag(msg_components)
	end

	if IsValid(ply) then
		EasyChat.AddNameTags(ply, msg_components)
	end

	table.insert(msg_components, ply)
	table.insert(msg_components, color_white)
	table.insert(msg_components, ": ")

	table.insert(msg_components, mentions:GetColor())
	table.insert(msg_components, msg)
	chat.AddText(unpack(msg_components))

	EasyChat.SafeHookRun("ECPlayerMention", ply, msg, is_team, is_dead, is_local, msg_components)
	return true -- hide chat message
end)

return "Mentions"
