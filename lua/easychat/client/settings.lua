-- general
local EC_TICK_SOUND = GetConVar("easychat_tick_sound")
local EC_TIMESTAMPS = GetConVar("easychat_timestamps")
local EC_TIMESTAMPS_12 = GetConVar("easychat_timestamps_12")
local EC_TEAMS = GetConVar("easychat_teams")
local EC_TEAMS_COLOR = GetConVar("easychat_teams_colored")
local EC_PLAYER_COLOR = GetConVar("easychat_players_colored")

-- chatbox
local EC_USE_DERMASKIN = GetConVar("easychat_use_dermaskin")
local EC_HISTORY = GetConVar("easychat_history")
local EC_GLOBAL_ON_OPEN = GetConVar("easychat_global_on_open")
local EC_FONT = GetConVar("easychat_font")
local EC_FONT_SIZE = GetConVar("easychat_font_size")

-- chathud
local EC_HUD_FOLLOW = GetConVar("easychat_hud_follow")
local EC_HUD_TTL = GetConVar("easychat_hud_ttl")
local EC_HUD_SMOOTH = GetConVar("easychat_hud_smooth")

local function create_option_set(settings, category_name, options)
	for cvar, description in pairs(options) do
		settings:AddConvarSetting(category_name, "boolean", cvar, description)
	end

	local setting_reset_options = settings:AddSetting(category_name, "action", "Reset Options")
	setting_reset_options.DoClick = function()
		for cvar, _ in pairs(options) do
			RunConsoleCommand(cvar:GetName(), cvar:GetDefault())
		end
	end
end

local function create_default_settings()
	local settings = EasyChat.Settings

	-- general settings
	do
		local category_name = "General"
		settings:AddCategory(category_name)

		create_option_set(settings, category_name, {
			[EC_TIMESTAMPS] = "Display timestamps",
			[EC_TIMESTAMPS_12] = "12 hours mode timestamps",
			[EC_TEAMS] = "Display teams",
			[EC_TEAMS_COLOR] = "Color the team tags",
			[EC_PLAYER_COLOR] = "Color players in their team color",
			[EC_TICK_SOUND] = "Tick sound on new messages",
		})

		settings:AddSpacer(category_name)

		local setting_reload_ec = settings:AddSetting(category_name, "action", "Reload EasyChat")
		setting_reload_ec.DoClick = function() RunConsoleCommand("easychat_reload") end

		local setting_disable_ec = settings:AddSetting(category_name, "action", "Disable EasyChat")
		setting_disable_ec.DoClick = function() RunConsoleCommand("easychat_enable", "0") end
	end

	-- chatbox settings
	do
		local category_name = "Chatbox"
		settings:AddCategory(category_name)

		create_option_set(settings, category_name, {
			[EC_GLOBAL_ON_OPEN] = "Open in the global tab",
			[EC_HISTORY] = "Enable history",
		})

		settings:AddSpacer(category_name)

		if not EasyChat.UseDermaskin then
			local setting_outlay_color = settings:AddSetting(category_name, "color", "Outlay Color")
			setting_outlay_color:SetColor(EasyChat.OutlayColor)
			setting_outlay_color.OnValueChanged = function(_, color) EasyChat.OutlayColor = color end

			local setting_outlay_outline_color = settings:AddSetting(category_name, "color", "Outlay Outline Color")
			setting_outlay_outline_color:SetColor(EasyChat.OutlayOutlineColor)
			setting_outlay_outline_color.OnValueChanged = function(_, color) EasyChat.OutlayOutlineColor = color end

			local setting_tab_color = settings:AddSetting(category_name, "color", "Tab Color")
			setting_tab_color:SetColor(EasyChat.TabColor)
			setting_tab_color.OnValueChanged = function(_, color) EasyChat.TabColor = color end

			local setting_tab_outline_color = settings:AddSetting(category_name, "color", "Tab Outline Color")
			setting_tab_outline_color:SetColor(EasyChat.TabOutlineColor)
			setting_tab_outline_color.OnValueChanged = function(_, color) EasyChat.TabOutlineColor = color end

			local setting_save_colors = settings:AddSetting(category_name, "action", "Save Colors")
			setting_save_colors.DoClick = function()
				file.Write("easychat/colors.txt", util.TableToJSON({
					outlay = setting_outlay_color:GetColor(),
					outlayoutline = setting_outlay_outline_color:GetColor(),
					tab = setting_tab_color:GetColor(),
					taboutline = setting_tab_outline_color:GetColor(),
				}, true))
			end

			local setting_reset_colors = settings:AddSetting(category_name, "action", "Reset Colors")
			setting_reset_colors.DoClick = function()
				EasyChat.OutlayColor = Color(62, 62, 62, 255)
				EasyChat.OutlayOutlineColor = Color(0, 0, 0, 0)
				EasyChat.TabColor = Color(36, 36, 36, 255)
				EasyChat.TabOutlineColor = Color(0, 0, 0, 0)

				setting_outlay_color:SetColor(EasyChat.OutlayColor)
				setting_outlay_outline_color:SetColor(EasyChat.OutlayOutlineColor)
				setting_tab_color:SetColor(EasyChat.TabColor)
				setting_tab_outline_color:SetColor(EasyChat.TabOutlineColor)

				file.Write("easychat/colors.txt", util.TableToJSON({
					outlay = EasyChat.OutlayColor,
					outlayoutline = EasyChat.OutlayOutlineColor,
					tab = EasyChat.TabColor,
					taboutline = EasyChat.TabOutlineColor,
				}, true))
			end

			settings:AddSpacer(category_name)
		end

		settings:AddConvarSetting(category_name, "string", EC_FONT, "Font")
		settings:AddConvarSetting(category_name, "number", EC_FONT_SIZE, "Font Size", 128, 5)

		local setting_reset_font = settings:AddSetting(category_name, "action", "Reset Font")
		setting_reset_font.DoClick = function()
			RunConsoleCommand(EC_FONT:GetName(), EC_FONT:GetDefault())
			RunConsoleCommand(EC_FONT_SIZE:GetName(), EC_FONT_SIZE:GetDefault())
		end

		settings:AddSpacer(category_name)

		local setting_dermaskin = settings:AddSetting(category_name, "action", EC_USE_DERMASKIN:GetBool() and "Use Custom Skin" or "Use Dermaskin")
		setting_dermaskin.DoClick = function()
			local new_value = EC_USE_DERMASKIN:GetBool() and "0" or "1"
			RunConsoleCommand(EC_USE_DERMASKIN:GetName(), new_value)
		end

		local setting_clear_history = settings:AddSetting(category_name, "action", "Clear History")
		setting_clear_history.DoClick = function()
			local files, _ = file.Find("easychat/history/*_history.txt", "DATA")
			for _, f in pairs(files) do
				file.Delete("easychat/" .. f)
			end

			RunConsoleCommand("easychat_reload")
		end
	end

	-- chathud settings
	do
		local category_name = "Chat HUD"
		settings:AddCategory(category_name)

		create_option_set(settings, category_name, {
			[EC_HUD_FOLLOW] = "Follow chatbox window",
			[EC_HUD_SMOOTH] = "Smooth message transitions"
		})

		settings:AddSpacer(category_name)

		settings:AddConvarSetting(category_name, "number", EC_HUD_TTL, "Message Duration", 60, 2)

		local setting_reset_duration = settings:AddSetting(category_name, "action", "Reset Duration")
		setting_reset_duration.DoClick = function() RunConsoleCommand(EC_HUD_TTL:GetName(), EC_HUD_TTL:GetDefault()) end
	end
end

local function add_chathud_markup_settings()
	local settings = EasyChat.Settings
	local category_name = "Chat HUD"

	settings:AddSpacer(category_name)

	local tag_options = {}
	for part_name, _ in pairs(EasyChat.ChatHUD.Parts) do
		local cvar = GetConVar("easychat_tag_" .. part_name)
		if cvar then
			tag_options[cvar] = ("%s tags"):format(part_name)
		end
	end

	create_option_set(settings, category_name, tag_options)

	settings:AddSpacer(category_name)

	local setting_font_editor = settings:AddSetting(category_name, "action", "Font Editor")
	setting_font_editor.DoClick = function()
		local editor = vgui.Create("ECChatHUDFontEditor")
		editor:MakePopup()
		editor:Center()
	end
end

local function add_legacy_settings()
	for _, registered_cvar in pairs(EasyChat.GetRegisteredConvars()) do
		EasyChat.Settings:AddConvarSetting("Others", "boolean", registered_cvar.Convar, registered_cvar.Description)
	end
end

hook.Add("ECPreLoadModules", "EasyChatDefaultSettings", create_default_settings)
hook.Add("ECPostLoadModules", "EasyChatDefaultSettings", function()
	add_chathud_markup_settings()
	add_legacy_settings()
end)