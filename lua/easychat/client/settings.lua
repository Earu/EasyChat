local settings = EasyChat.Settings

local EC_TICK_SOUND     = GetConVar("easychat_tick_sound")
local EC_HISTORY        = GetConVar("easychat_history")
local EC_GLOBAL_ON_OPEN = GetConVar("easychat_global_on_open")
local EC_TIMESTAMPS		= GetConVar("easychat_timestamps")
local EC_TIMESTAMPS_12  = GetConVar("easychat_timestamps_12")
local EC_TEAMS 			= GetConVar("easychat_teams")
local EC_TEAMS_COLOR 	= GetConVar("easychat_teams_colored")
local EC_PLAYER_COLOR 	= GetConVar("easychat_players_colored")

local EC_FONT 	    = GetConVar("easychat_font")
local EC_FONT_SIZE  = GetConVar("easychat_font_size")
local EC_HUD_FOLLOW = GetConVar("easychat_hud_follow")
local EC_HUD_TTL    = GetConVar("easychat_hud_ttl")
local EC_HUD_SMOOTH = GetConVar("easychat_hud_smooth")

-- general settings
do
	local category_name = "General"
	settings:AddCategory(category_name)
		settings:AddConvarSetting(category_name, "boolean", EC_TIMESTAMPS, "Display timestamps")
		settings:AddConvarSetting(category_name, "boolean", EC_TIMESTAMPS_12, "12 hours mode timestamps")
		settings:AddConvarSetting(category_name, "boolean", EC_TEAMS, "Display teams")
		settings:AddConvarSetting(category_name, "boolean", EC_TEAMS_COLOR, "Color the team tags")
		settings:AddConvarSetting(category_name, "boolean", EC_PLAYER_COLOR, "Color players in their team color")
		settings:AddConvarSetting(category_name, "boolean", EC_TICK_SOUND, "Tick sound on new messages")
		settings:AddSetting(category_name, "action", "Reset Options")

		settings:AddSpacer(category_name)

		settings:AddSetting(category_name, "action", "Reload EasyChat")
		settings:AddSetting(category_name, "action", "Disable EasyChat")
end

-- chatbox settings
do
	local category_name = "Chatbox"
	settings:AddCategory(category_name)
		settings:AddConvarSetting(category_name, "boolean", EC_GLOBAL_ON_OPEN, "Open in the global tab")
		settings:AddConvarSetting(category_name, "boolean", EC_HISTORY, "Enable history")

		settings:AddSpacer(category_name)

		settings:AddSetting(category_name, "color", "Outlay Color")
		settings:AddSetting(category_name, "color", "Outlay Outline Color")
		settings:AddSetting(category_name, "color", "Tab Color")
		settings:AddSetting(category_name, "color", "Tab Outline Color")
		settings:AddSetting(category_name, "action", "Reset Colors")

		settings:AddSpacer(category_name)

		settings:AddConvarSetting(category_name, "string", EC_FONT, "Font")
		settings:AddConvarSetting(category_name, "number", EC_FONT_SIZE, "Font Size", 128, 5)
		settings:AddSetting(category_name, "action", "Reset Font")

		settings:AddSpacer(category_name)

		settings:AddSetting(category_name, "action", "Use Dermaskin")
		settings:AddSetting(category_name, "action", "Clear History")
end

-- chathud settings
do
	local category_name = "Chat HUD"
	settings:AddCategory(category_name)
		settings:AddConvarSetting(category_name, "boolean", EC_HUD_FOLLOW, "Follow chatbox window")
		settings:AddConvarSetting(category_name, "boolean", EC_HUD_SMOOTH, "Smooth message transitions")

		settings:AddSpacer(category_name)

		settings:AddConvarSetting(category_name, "number", EC_HUD_TTL, "Message Duration", 2, 60)
		settings:AddSetting(category_name, "action", "Reset Duration")
end