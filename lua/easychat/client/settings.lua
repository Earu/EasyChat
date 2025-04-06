local setting_cvars = {}

local function get_cvar(cvar_name)
	local cvar = GetConVar(cvar_name)
	table.insert(setting_cvars, cvar)
	return cvar
end

local color_white = color_white

-- general
local EC_ENABLE = get_cvar("easychat_enable")
local EC_NO_MODULES = get_cvar("easychat_no_modules")

-- teams and colors
local EC_TEAMS = get_cvar("easychat_teams")
local EC_TEAMS_COLOR = get_cvar("easychat_teams_colored")
local EC_PLAYER_COLOR = get_cvar("easychat_players_colored")
local EC_PLAYER_PASTEL = get_cvar("easychat_pastel")

-- misc
local EC_SECONDARY = get_cvar("easychat_secondary_mode")
local EC_ALWAYS_LOCAL = get_cvar("easychat_always_local")
local EC_ONLY_LOCAL = get_cvar("easychat_only_local")
local EC_LOCAL_MSG_DIST = get_cvar("easychat_local_msg_distance")
local EC_TICK_SOUND = get_cvar("easychat_tick_sound")
local EC_USE_ME = get_cvar("easychat_use_me")
local EC_IMAGES = get_cvar("easychat_images")
local EC_LINKS_CLIPBOARD = get_cvar("easychat_links_to_clipboard")
local EC_GM_COMPLETE = get_cvar("easychat_gm_complete")
local EC_NICK_COMPLETE = get_cvar("easychat_nick_complete")
local EC_NICK_PRIORITIZE = get_cvar("easychat_nick_prioritize")
local EC_OUT_CLICK_CLOSE = get_cvar("easychat_out_click_close")
local EC_SERVER_MSG = get_cvar("easychat_server_msg")
local EC_SKIP_STARTUP_MSG = get_cvar("easychat_skip_startup_msg")
local EC_SYNC_STEAM_BLOCKS = get_cvar("easychat_sync_steam_blocks")

-- timestamps
local EC_TIMESTAMPS = get_cvar("easychat_timestamps")
local EC_TIMESTAMPS_12 = get_cvar("easychat_timestamps_12")
local EC_HUD_TIMESTAMPS = get_cvar("easychat_hud_timestamps")
local EC_TIMESTAMPS_COLOR = get_cvar("easychat_timestamps_color")

-- chatbox
local EC_TAGS_IN_CHATBOX = get_cvar("easychat_tags_in_chatbox")
local EC_USE_DERMASKIN = get_cvar("easychat_use_dermaskin")
local EC_HISTORY = get_cvar("easychat_history")
local EC_PRESERVE_MESSAGE_IN_PROGRESS = get_cvar("easychat_preserve_message_in_progress")
local EC_GLOBAL_ON_OPEN = get_cvar("easychat_global_on_open")
local EC_FONT = get_cvar("easychat_font")
local EC_FONT_SIZE = get_cvar("easychat_font_size")
local EC_PEEK_COMPLETION = get_cvar("easychat_peek_completion")
local EC_LEGACY_ENTRY = get_cvar("easychat_legacy_entry")
local EC_LEGACY_TEXT = get_cvar("easychat_legacy_text")
local EC_MODERN_TEXT_HISTORY_LIMIT = get_cvar("easychat_modern_text_history_limit")
local EC_NON_QWERTY = get_cvar("easychat_non_qwerty")
local EC_BLUR_IMAGES = get_cvar("easychat_blur_images")
local EC_BLUR_BACKGROUND = get_cvar("easychat_background_blur")

-- chathud
local EC_HUD_FOLLOW = get_cvar("easychat_hud_follow")
local EC_HUD_TTL = get_cvar("easychat_hud_ttl")
local EC_HUD_FADELEN = get_cvar("easychat_hud_fadelen")
local EC_HUD_SMOOTH = get_cvar("easychat_hud_smooth")
local EC_HUD_SH_CLEAR = get_cvar("easychat_hud_sh_clear")
local EC_HUD_CUSTOM = get_cvar("easychat_hud_custom")
local EC_HUD_POS_X = get_cvar("easychat_hud_pos_x")
local EC_HUD_POS_Y = get_cvar("easychat_hud_pos_y")
local EC_HUD_WIDTH = get_cvar("easychat_hud_width")

-- translation
local EC_TRANSLATE_INC_MSG = get_cvar("easychat_translate_inc_msg")
local EC_TRANSLATE_INC_SRC_LANG = get_cvar("easychat_translate_inc_source_lang")
local EC_TRANSLATE_INC_TARGET_LANG = get_cvar("easychat_translate_inc_target_lang")
local EC_TRANSLATE_OUT_MSG = get_cvar("easychat_translate_out_msg")
local EC_TRANSLATE_OUT_SRC_LANG = get_cvar("easychat_translate_out_source_lang")
local EC_TRANSLATE_OUT_TARGET_LANG = get_cvar("easychat_translate_out_target_lang")
local EC_TRANSLATE_API_KEY = get_cvar("easychat_translate_api_key")

local function create_default_settings()
	local settings = EasyChat.Settings

	-- general settings
	do
		local category_name = "General"
		settings:AddCategory(category_name)

		settings:AddConvarSettingsSet(category_name, {
			[EC_ALWAYS_LOCAL] = "Always talk in local mode by default",
			[EC_ONLY_LOCAL] = "Only receive local messages",
			[EC_LINKS_CLIPBOARD] = "Automatically copy links to your clipboard",
			[EC_TEAMS] = "Display teams",
			[EC_TEAMS_COLOR] = "Color the team tags",
			[EC_PLAYER_COLOR] = "Color players in their team color",
			[EC_PLAYER_PASTEL] = "Pastellize player colors",
			[EC_TICK_SOUND] = "Tick sound on new messages",
			[EC_USE_ME] = "Replaces your name in the chat with \"me\"",
			[EC_GM_COMPLETE] = "Use the default gamemode auto-completion",
			[EC_NICK_COMPLETE] = "Auto-complete player names",
			[EC_NICK_PRIORITIZE] = "Prioritize player name completions over everything else",
			[EC_OUT_CLICK_CLOSE] = "Close the chat when clicking away",
			[EC_SERVER_MSG] = "Show changes made to the server cvars",
			[EC_SKIP_STARTUP_MSG] = "Skips annoying addon startup messages (displays in console)",
			[EC_SYNC_STEAM_BLOCKS] = "Synchronize your steam block list with EasyChat",
		})

		settings:AddSpacer(category_name)

		local setting_blocked_players = settings:AddSetting(category_name, "list", "Blocked Users")
		local blocked_players_list = setting_blocked_players.List
		blocked_players_list:SetMultiSelect(true)
		blocked_players_list:AddColumn("SteamID")
		blocked_players_list:AddColumn("Name")

		blocked_players_list.DoDoubleClick = function(_, _, line)
			local steam_id = line:GetColumnText(1)
			if not steam_id or #steam_id:Trim() <= 0 then return end

			local steam_id64 = util.SteamIDTo64(steam_id)
			EasyChat.OpenURL("https://steamcommunity.com/profiles/" .. steam_id64)
		end

		local function build_blocked_players_list()
			blocked_players_list:Clear()

			for steam_id, _ in pairs(EasyChat.BlockedPlayers) do
				local steam_id64 = util.SteamIDTo64(steam_id)
				steamworks.RequestPlayerInfo(steam_id64, function(steam_name)
					if not IsValid(blocked_players_list) then return end
					blocked_players_list:AddLine(steam_id, steam_name)
				end)
			end
		end

		build_blocked_players_list()
		hook.Add("ECBlockedPlayer", blocked_players_list, build_blocked_players_list)
		hook.Add("ECUnblockedPlayer", blocked_players_list, build_blocked_players_list)

		local setting_unblock_player = settings:AddSetting(category_name, "action", "Unblock Player(s)")
		setting_unblock_player.DoClick = function()
			local lines = blocked_players_list:GetSelected()
			for _, line in pairs(lines) do
				local steam_id = line:GetColumnText(1)
				EasyChat.BlockedPlayers[steam_id] = nil
			end

			file.Write("easychat/blocked_players.json", util.TableToJSON(EasyChat.BlockedPlayers))
			build_blocked_players_list()
		end

		local setting_blocked_strings = settings:AddSetting(category_name, "list", "Blocked Words")
		local blocked_strings_list = setting_blocked_strings.List
		blocked_strings_list:SetMultiSelect(true)
		blocked_strings_list:AddColumn("Id")
		blocked_strings_list:AddColumn("Content")
		blocked_strings_list:AddColumn("Pattern")

		local function build_blocked_strings_list()
			blocked_strings_list:Clear()
			for i = 1, #EasyChat.BlockedStrings do
				local blocked_str = EasyChat.BlockedStrings[i]
				blocked_strings_list:AddLine(tostring(i), blocked_str.Content, tostring(blocked_str.IsPattern))
			end
		end

		build_blocked_strings_list()

		local setting_block_string = settings:AddSetting(category_name, "action", "Block Word")
		setting_block_string.DoClick = function()
			local frame
			frame = EasyChat.AskForInput("Block a word", function(str)
				EasyChat.BlockString(str, frame.IsPattern:GetChecked())
				build_blocked_strings_list()
			end, false)

			frame:SetTall(125)
			frame.IsPattern = frame:Add("DCheckBoxLabel")
			frame.IsPattern:SetText("Pattern")
			frame.IsPattern:Dock(FILL)
		end

		local setting_unblock_string = settings:AddSetting(category_name, "action", "Unblock Word")
		setting_unblock_string.DoClick = function()
			local lines = blocked_strings_list:GetSelected()
			for _, line in pairs(lines) do
				local id = tonumber(line:GetColumnText(1))
				if not id then continue end
				EasyChat.UnblockString(id)
			end

			build_blocked_strings_list()
		end

		settings:AddSpacer(category_name)

		local setting_secondary_mode = settings:AddConvarSetting(category_name, "string", EC_SECONDARY, "Secondary Message Mode")
		setting_secondary_mode.GetAutoComplete = function(self, text)
			local suggestions = {}
			for _, mode in pairs(EasyChat.Modes) do
				table.insert(suggestions, mode.Name:lower())
			end

			return suggestions
		end

		local secondary_mode_selection = 1
		local secondary_mode_input = ""
		setting_secondary_mode.OnKeyCodeTyped = function(self, key_code)
			if key_code == KEY_TAB then
				local suggestion = self:GetAutoComplete(secondary_mode_input)[secondary_mode_selection]
				if suggestion then
					self:SetText(suggestion)
					EasyChat.RunOnNextFrame(function()
						self:RequestFocus()  -- keep focus
						self:SetCaretPos(#self:GetText())
					end)
				end

				secondary_mode_selection = secondary_mode_selection + 1
				if secondary_mode_selection > (EasyChat.ModeCount + 1) then
					secondary_mode_selection = 1
				end
			elseif key_code == KEY_ENTER or key_code == KEY_PAD_ENTER then
				if IsValid(self.Menu) then self.Menu:Remove() end
				self:OnEnter()
				EasyChat.RunOnNextFrame(function()
					self:RequestFocus()  -- keep focus
					self:SetCaretPos(#self:GetText())
				end)
			else
				secondary_mode_input = self:GetText()
				secondary_mode_selection = 1
			end
		end

		settings:AddConvarSetting(category_name, "number", EC_LOCAL_MSG_DIST, "Local Message Distance", 1000, 100)

		local setting_reset_misc = settings:AddSetting(category_name, "action", "Reset Options")
		setting_reset_misc.DoClick = function()
			local default_distance = tonumber(EC_LOCAL_MSG_DIST:GetDefault())
			EC_LOCAL_MSG_DIST:SetInt(default_distance)
			EC_SECONDARY:SetString(EC_SECONDARY:GetDefault())
		end

		settings:AddSpacer(category_name)

		settings:AddConvarSetting(category_name, "boolean", EC_TIMESTAMPS, "Display timestamps")
		settings:AddConvarSetting(category_name, "boolean", EC_TIMESTAMPS_12, "12 hours mode timestamps")
		settings:AddConvarSetting(category_name, "boolean", EC_HUD_TIMESTAMPS, "Display timestamps in Chat HUD")

		local setting_timestamps_color = settings:AddSetting(category_name, "color", "Timestamp Color")
		setting_timestamps_color:SetColor(EasyChat.TimestampColor)
		setting_timestamps_color.OnValueChanged = function(_, color)
			EC_TIMESTAMPS_COLOR:SetString(("%d %d %d"):format(color.r, color.g, color.b))
		end

		local setting_reset_timestamps = settings:AddSetting(category_name, "action", "Reset Options")
		setting_reset_timestamps.DoClick = function()
			EC_TIMESTAMPS:SetBool(tobool(EC_TIMESTAMPS:GetDefault()))
			EC_TIMESTAMPS_12:SetBool(tobool(EC_TIMESTAMPS_12:GetDefault()))
			EC_HUD_TIMESTAMPS:SetBool(tobool(EC_HUD_TIMESTAMPS:GetDefault()))
			setting_timestamps_color:SetColor(Color(255, 255, 255, 255))
			EC_TIMESTAMPS_COLOR:SetString(EC_TIMESTAMPS_COLOR:GetDefault())
		end

		settings:AddSpacer(category_name)

		local setting_ignored_modules = settings:AddSetting(category_name, "list", "Ignored Modules")
		local ignored_modules_list = setting_ignored_modules.List
		ignored_modules_list:SetMultiSelect(true)
		ignored_modules_list:AddColumn("Path (Relative to Lua folder)")

		local function build_ignore_module_list()
			ignored_modules_list:Clear()

			for _, module_path in pairs(EasyChat.Config.ModuleIgnoreList) do
				ignored_modules_list:AddLine(module_path)
			end
		end

		build_ignore_module_list()
		hook.Add("ECServerConfigUpdate", ignored_modules_list, build_ignore_module_list)

		local setting_ignore_module = settings:AddSetting(category_name, "action", "Ignore Module")
		setting_ignore_module:SetImage("icon16/shield.png")
		setting_ignore_module.DoClick = function()
			EasyChat.AskForInput("Ignore Module (Type a path relative to the Lua folder)", function(ignored_module_path)
				local old_list = table.Copy(EasyChat.Config.ModuleIgnoreList)
				local current_list = EasyChat.Config.ModuleIgnoreList
				table.insert(current_list, ignored_module_path)

				local succ, err = EasyChat.Config:WriteModuleIgnoreList(current_list)
				if not succ then
					EasyChat.Config.ModuleIgnoreList = old_list
					notification.AddLegacy(err, NOTIFY_ERROR, 3)
					surface.PlaySound("buttons/button11.wav")
				end
			end, false):SetWide(600)
		end

		local setting_unignore_module = settings:AddSetting(category_name, "action", "Unignore Module")
		setting_unignore_module:SetImage("icon16/shield.png")
		setting_unignore_module.DoClick = function()
			local old_list = table.Copy(EasyChat.Config.ModuleIgnoreList)
			local current_list = EasyChat.Config.ModuleIgnoreList

			local lines = ignored_modules_list:GetSelected()
			for _, line in pairs(lines) do
				local ignore_path = line:GetColumnText(1)
				table.RemoveByValue(current_list, ignore_path)
			end

			local succ, err = EasyChat.Config:WriteModuleIgnoreList(current_list)
			if not succ then
				EasyChat.Config.ModuleIgnoreList = old_list
				notification.AddLegacy(err, NOTIFY_ERROR, 3)
				surface.PlaySound("buttons/button11.wav")
			end
		end

		settings:AddSpacer(category_name)

		local setting_disable_modules = settings:AddSetting(category_name, "action", EC_NO_MODULES:GetBool() and "Run Modules" or "Disallow Modules")
		setting_disable_modules.DoClick = function() EC_NO_MODULES:SetBool(not EC_NO_MODULES:GetBool()) end

		local setting_reload_ec = settings:AddSetting(category_name, "action", "Reload EasyChat")
		setting_reload_ec.DoClick = function() EasyChat.Reload() end

		local setting_disable_ec = settings:AddSetting(category_name, "action", "Disable EasyChat")
		setting_disable_ec.DoClick = function() EC_ENABLE:SetBool(false) end

		local function delete_dir(dir_path)
			local files, folders = file.Find(dir_path .. "/*", "DATA")
			for _, f in pairs(files) do
				local file_path = dir_path .. "/" .. f
				file.Delete(file_path)
			end

			for _, folder in pairs(folders) do
				delete_dir(dir_path .. "/" .. folder)
			end

			file.Delete(dir_path)
		end

		local function factory_reset()
			EasyChat.AskForValidation(
				"Factory Reset",
				"Are you sure you want to factory reset EasyChat? All your data will be deleted.",
				{
					ok_text = "Reset",
					ok_btn_color = Color(255, 0, 0),
					callback = function()
						EasyChat.SafeHookRun("ECFactoryReset")

						for _, cvar in pairs(setting_cvars) do
							cvar:SetString(cvar:GetDefault())
						end

						delete_dir("easychat")
						EasyChat.RunOnNextFrame(function() EasyChat.Reload() end)
					end
				}
			)
		end

		local setting_factory_reset = settings:AddSetting(category_name, "action", "Factory Reset")
		setting_factory_reset.DoClick = factory_reset
		concommand.Add("easychat_factory_reset", factory_reset, nil, "Factory reset EasyChat")
	end

	-- chatbox settings
	do
		local category_name = "Chatbox"
		settings:AddCategory(category_name)

		settings:AddConvarSettingsSet(category_name, {
			[EC_GLOBAL_ON_OPEN] = "Open in the global tab",
			[EC_HISTORY] = "Enable history",
			[EC_PRESERVE_MESSAGE_IN_PROGRESS] = "Preserve message in progress",
			[EC_TAGS_IN_CHATBOX] = "Shows tags in the chatbox",
			[EC_IMAGES] = "Display images",
			[EC_PEEK_COMPLETION] = "Peek at the possible chat completion",
			[EC_NON_QWERTY] = "Specify whether you have a QWERTY keyboard or not",
			[EC_BLUR_IMAGES] = "Blur images in the chatbox",
			[EC_BLUR_BACKGROUND] = "Blurs the chatbox background and its windows",
		})

		settings:AddSpacer(category_name)

		if not EasyChat.UseDermaSkin then
			local built_in_themes = {
				Legacy = {
					outlay        = Color(62, 62, 62, 235),
					outlayoutline = Color(0, 0, 0, 0),
					tab           = Color(36, 36, 36, 235),
					taboutline    = Color(0, 0, 0, 0),
				},
				Standard = EasyChat.DefaultColors,
				Crimson = {
					outlay        = Color(62, 32, 32, 255),
					outlayoutline = Color(0, 0, 0, 0),
					tab           = Color(32, 15, 15, 255),
					taboutline    = Color(0, 0, 0, 0),
				},
				Ocean = {
					outlay        = Color(30, 30, 128, 235),
					outlayoutline = Color(0, 0, 0, 0),
					tab           = Color(15, 15, 62, 235),
					taboutline    = Color(0, 0, 0, 0)
				},
				["High Contrast"] = {
					outlay        = Color(0, 0, 0, 255),
					outlayoutline = Color(255, 255, 255, 255),
					tab           = Color(0, 0, 0, 255),
					taboutline    = Color(255, 255, 255, 255),
				},
				["80s"] = {
					outlay        = Color(128, 30, 128, 235),
					outlayoutline = Color(0, 0, 0, 0),
					tab           = Color(0, 0, 36, 255),
					taboutline    = Color(0, 0, 0, 0),
				},
				Desert = {
					outlay        = Color(220, 100, 0, 235),
					outlayoutline = Color(0, 0, 0, 0),
					tab           = Color(36, 15, 0, 255),
					taboutline    = Color(0, 0, 0, 0),
				},
				["Red Light"] = {
					outlay        = Color(220, 0, 75, 235),
					outlayoutline = Color(0, 0, 0, 0),
					tab           = Color(25, 25, 25, 255),
					taboutline    = Color(0, 0, 0, 0),
				}
			}

			local setting_built_in_themes = settings:AddSetting(category_name, "action", "Built-in Themes")

			local setting_outlay_color = settings:AddSetting(category_name, "color", "Outlay Color")
			setting_outlay_color:SetColor(EasyChat.OutlayColor)
			setting_outlay_color.OnValueChanged = function(_, color)
				EasyChat.OutlayColor = Color(color.r, color.g, color.b, color.a)

				local text_entry = EasyChat.GUI.TextEntry
				if IsValid(text_entry) and text_entry.ClassName == "TextEntryX" then
					local border_color = EasyChat.TabOutlineColor.a == 0
						and EasyChat.OutlayColor or EasyChat.TabOutlineColor
					text_entry:SetBorderColor(border_color)
				end
			end

			local setting_outlay_outline_color = settings:AddSetting(category_name, "color", "Outlay Outline Color")
			setting_outlay_outline_color:SetColor(EasyChat.OutlayOutlineColor)
			setting_outlay_outline_color.OnValueChanged = function(_, color)
				EasyChat.OutlayOutlineColor = Color(color.r, color.g, color.b, color.a)
			end

			local setting_tab_color = settings:AddSetting(category_name, "color", "Tab Color")
			setting_tab_color:SetColor(EasyChat.TabColor)
			setting_tab_color.OnValueChanged = function(_, color)
				EasyChat.TabColor = Color(color.r, color.g, color.b, color.a)

				local text_entry = EasyChat.GUI.TextEntry
				if IsValid(text_entry) and text_entry.ClassName == "TextEntryX" then
					text_entry:SetBackgroundColor(EasyChat.TabColor)
				end
			end

			local setting_tab_outline_color = settings:AddSetting(category_name, "color", "Tab Outline Color")
			setting_tab_outline_color:SetColor(EasyChat.TabOutlineColor)
			setting_tab_outline_color.OnValueChanged = function(_, color)
				EasyChat.TabOutlineColor = Color(color.r, color.g, color.b, color.a)
				local text_entry = EasyChat.GUI.TextEntry

				if IsValid(text_entry) and text_entry.ClassName == "TextEntryX" then
					local border_color = EasyChat.TabOutlineColor.a == 0
						and EasyChat.OutlayColor or EasyChat.TabOutlineColor
					text_entry:SetBorderColor(border_color)
				end
			end

			-- needs to be done after color settings so we can apply the new colors to them
			setting_built_in_themes.DoClick = function()
				local themes_menu = DermaMenu()
				for theme_name, theme_data in pairs(built_in_themes) do
					themes_menu:AddOption(theme_name, function()
						setting_outlay_color:SetColor(theme_data.outlay)
						setting_outlay_outline_color:SetColor(theme_data.outlayoutline)
						setting_tab_color:SetColor(theme_data.tab)
						setting_tab_outline_color:SetColor(theme_data.taboutline)
					end)
				end

				themes_menu:AddSpacer()
				themes_menu:AddOption("Cancel", function() themes_menu:Remove() end)
				themes_menu:Open()
			end

			local setting_save_colors = settings:AddSetting(category_name, "action", "Save Colors")
			setting_save_colors.DoClick = function()
				local text_entry = EasyChat.GUI.TextEntry
				if IsValid(text_entry) and text_entry.ClassName == "TextEntryX" then
					local border_color = EasyChat.TabOutlineColor.a == 0
						and EasyChat.OutlayColor or EasyChat.TabOutlineColor

					text_entry:SetBackgroundColor(EasyChat.TabColor)
					text_entry:SetBorderColor(border_color)
					text_entry:SetTextColor(EasyChat.TextColor)
				end

				file.Write("easychat/colors.txt", util.TableToJSON({
					outlay = EasyChat.OutlayColor,
					outlayoutline = EasyChat.OutlayOutlineColor,
					tab = EasyChat.TabColor,
					taboutline = EasyChat.TabOutlineColor,
				}, true))
			end

			local setting_reset_colors = settings:AddSetting(category_name, "action", "Reset Colors")
			setting_reset_colors.DoClick = function()
				local outlay_color = EasyChat.DefaultColors.outlay
				local outlay_outline_color = EasyChat.DefaultColors.outlayoutline
				local tab_color = EasyChat.DefaultColors.tab
				local tab_outline_color = EasyChat.DefaultColors.taboutline

				setting_outlay_color:SetColor(outlay_color)
				setting_outlay_outline_color:SetColor(outlay_outline_color)
				setting_tab_color:SetColor(tab_color)
				setting_tab_outline_color:SetColor(tab_outline_color)

				file.Write("easychat/colors.txt", util.TableToJSON({
					outlay = outlay_color,
					outlayoutline = outlay_outline_color,
					tab = tab_color,
					taboutline = tab_outline_color,
				}, true))

				EasyChat.OutlayColor = outlay_color
				EasyChat.OutlayOutlineColor = outlay_outline_color
				EasyChat.TabColor = tab_color
				EasyChat.TabOutlineColor = tab_outline_color
			end

			settings:AddSpacer(category_name)
		end

		settings:AddConvarSetting(category_name, "string", EC_FONT, "Font")
		settings:AddConvarSetting(category_name, "number", EC_FONT_SIZE, "Font Size", 128, 5)

		cvars.RemoveChangeCallback(EC_FONT:GetName(), EC_FONT:GetName())
		cvars.RemoveChangeCallback(EC_FONT_SIZE:GetName(), EC_FONT_SIZE:GetName())

		local function font_change_callback() settings:InvalidateChildren(true) end
		cvars.AddChangeCallback(EC_FONT:GetName(), font_change_callback, EC_FONT:GetName())
		cvars.AddChangeCallback(EC_FONT_SIZE:GetName(), font_change_callback, EC_FONT_SIZE:GetName())

		local setting_reset_font = settings:AddSetting(category_name, "action", "Reset Font")
		setting_reset_font.DoClick = function()
			local default_font, default_font_size = EC_FONT:GetDefault(), tonumber(EC_FONT_SIZE:GetDefault())
			EC_FONT:SetString(default_font)
			EC_FONT_SIZE:SetInt(default_font_size)
		end

		settings:AddSpacer(category_name)

		local setting_tabs = settings:AddSetting(category_name, "list", "Tabs")
		local tab_list = setting_tabs.List
		tab_list:SetMultiSelect(true)
		tab_list:AddColumn("Name")
		tab_list:AddColumn("Hidden")

		local function show_or_hide_tab(selected_line)
			local tab_name = selected_line:GetColumnText(1)
			local tab_data = EasyChat.GetTab(tab_name)
			if tab_data then
				local is_visible = tab_data.Tab:IsVisible()
				tab_data.Tab:SetVisible(not is_visible)

				-- this is inverted, because we get IsVisible before setting it
				selected_line:SetColumnText(2, is_visible and "Yes" or "No")
			end
		end

		tab_list.DoDoubleClick = function(_, _, line)
			show_or_hide_tab(line)
		end

		tab_list.OnRowRightClick = function(_, _, line)
			local tab_menu = DermaMenu()

			tab_menu:AddOption(line:GetColumnText(2) == "Yes" and "Show" or "Hide", function()
				show_or_hide_tab(line)
			end)
			tab_menu:AddSpacer()
			tab_menu:AddOption("Restrict", function()
				local succ, err = EasyChat.Config:WriteTab(line:GetColumnText(1), false)
				if not succ then
					notification.AddLegacy(err, NOTIFY_ERROR, 3)
					surface.PlaySound("buttons/button11.wav")
				end
			end):SetImage("icon16/shield.png")
			tab_menu:AddSpacer()
			tab_menu:AddOption("Cancel", function() tab_menu:Remove() end)

			tab_menu:Open()
		end

		local tab_class_blacklist = {
			["ECChatTab"] = true,
			["ECSettingsTab"] = true,
		}

		local function build_tab_list()
			tab_list:Clear()

			for tab_name, tab_data in pairs(EasyChat.GetTabs()) do
				if not tab_class_blacklist[tab_data.Panel.ClassName] then
					tab_list:AddLine(tab_name, tab_data.Tab:IsVisible() and "No" or "Yes")
				end
			end
		end

		build_tab_list()
		hook.Add("ECSettingsOpened", tab_list, build_tab_list)

		local setting_apply_tab = settings:AddSetting(category_name, "action", "Hide / Show Tab")
		setting_apply_tab.DoClick = function()
			local selected_lines = tab_list:GetSelected()
			for _, selected_line in pairs(selected_lines) do
				show_or_hide_tab(selected_line)
			end
		end

		local setting_manage_tabs = settings:AddSetting(category_name, "action", "(ADMIN) Manage Tabs")
		setting_manage_tabs:SetImage("icon16/shield.png")
		setting_manage_tabs.DoClick = function()
			local frame = EasyChat.CreateFrame()
			frame:SetSize(400, 285)
			frame:SetTitle("Manage Tabs")

			local setting_restricted_tabs = settings:AddSetting(category_name, "list", "Restricted Tabs")
			setting_restricted_tabs:SetParent(frame)

			local frame_tab_list = setting_restricted_tabs.List
			frame_tab_list:SetMultiSelect(true)
			frame_tab_list:AddColumn("Tab Name")

			local function build_frame_tab_list()
				frame_tab_list:Clear()

				for tab_name, is_allowed in pairs(EasyChat.Config.Tabs) do
					if not is_allowed then
						frame_tab_list:AddLine(tab_name)
					end
				end
			end

			build_frame_tab_list()
			hook.Add("ECServerConfigUpdate", frame, build_frame_tab_list)

			local setting_unrestrict_tab = settings:AddSetting(category_name, "action", "Unrestrict Tab")
			setting_unrestrict_tab:SetParent(frame)
			setting_unrestrict_tab:SetImage("icon16/shield.png")
			setting_unrestrict_tab.DoClick = function()
				local lines = frame_tab_list:GetSelected()
				for _, line in pairs(lines) do
					local succ, err = EasyChat.Config:WriteTab(line:GetColumnText(1), true)
					if not succ then
						notification.AddLegacy(err, NOTIFY_ERROR, 3)
						surface.PlaySound("buttons/button11.wav")
						break
					end
				end
			end

			local spacer = settings:AddSpacer(category_name)
			spacer:SetParent(frame)
			spacer:DockMargin(10, 0, 10, 20)

			local setting_restrict_tab_name = settings:AddSetting(category_name, "string", "Tab Name")
			setting_restrict_tab_name:SetParent(frame)
			setting_restrict_tab_name.OnEnter = function(self)
				local succ, err = EasyChat.Config:WriteTab(self:GetText(), false)
				if not succ then
					notification.AddLegacy(err, NOTIFY_ERROR, 3)
					surface.PlaySound("buttons/button11.wav")
				end
			end

			local setting_restrict_tab = settings:AddSetting(category_name, "action", "Restrict Tab")
			setting_restrict_tab:SetParent(frame)
			setting_restrict_tab:SetImage("icon16/shield.png")
			setting_restrict_tab.DoClick = function()
				setting_restrict_tab_name:OnEnter()
			end

			frame:Center()
			frame:MakePopup()
		end

		settings:AddSpacer(category_name)

		if EasyChat.GUI.RichText and EasyChat.GUI.RichText.ClassName == "RichTextX" then
			settings:AddConvarSetting(category_name, "number", EC_MODERN_TEXT_HISTORY_LIMIT, "History Line Limit", 5000, -1)
		end

		if EasyChat.CanUseCEFFeatures() then
			local setting_legacy_entry = settings:AddSetting(category_name, "action", EC_LEGACY_ENTRY:GetBool() and "Use Modern Textbox" or "Use Legacy Textbox")
			setting_legacy_entry.DoClick = function()
				EC_LEGACY_ENTRY:SetBool(not EC_LEGACY_ENTRY:GetBool())
			end

			local setting_legacy_text = settings:AddSetting(category_name, "action", EC_LEGACY_TEXT:GetBool() and "Use Modern RichText" or "Use Legacy RichText")
			setting_legacy_text.DoClick = function()
				EC_LEGACY_TEXT:SetBool(not EC_LEGACY_TEXT:GetBool())
			end
		end

		local setting_dermaskin = settings:AddSetting(category_name, "action", EC_USE_DERMASKIN:GetBool() and "Use Custom Skin" or "Use Dermaskin")
		setting_dermaskin.DoClick = function()
			EC_USE_DERMASKIN:SetBool(not EC_USE_DERMASKIN:GetBool())
		end

		local setting_clear_history = settings:AddSetting(category_name, "action", "Clear History")
		setting_clear_history.DoClick = function()
			local files, _ = file.Find("easychat/history/*_history.txt", "DATA")
			for _, f in pairs(files) do
				file.Delete("easychat/" .. f)
			end

			EasyChat.Reload()
		end
	end

	-- chathud settings
	do
		local category_name = "Chat HUD"
		settings:AddCategory(category_name)

		local function create_admin_shield_icon(src_panel)
			local icon = vgui.Create("DButton", src_panel:GetParent())
			icon:SetImage("icon16/shield.png")
			icon:SetSize(20, 20)
			icon.Paint = function() end

			icon.Think = function(self)
				if not IsValid(src_panel) then return end
				local x, y = src_panel:GetPos()
				surface.SetFont(src_panel.Label:GetFont() or "DermaDefault")
				local w, _ = surface.GetTextSize(src_panel.Label:GetText() .. (" "):rep(4))

				self:SetPos(x + w + 5, y)
			end

			return icon
		end

		local setting_tags_names = settings:AddSetting(category_name, "boolean", "(ADMIN) Allow tags in names")
		create_admin_shield_icon(setting_tags_names)

		local setting_tags_msgs = settings:AddSetting(category_name, "boolean", "(ADMIN) Allow tags in messages")
		create_admin_shield_icon(setting_tags_msgs)

		setting_tags_names:SetChecked(EasyChat.Config.AllowTagsInNames)
		setting_tags_msgs:SetChecked(EasyChat.Config.AllowTagsInMessages)

		setting_tags_names.OnChange = function(self, enabled)
			local succ, err = EasyChat.Config:WriteTagsInNames(enabled)
			if not succ then
				notification.AddLegacy(err, NOTIFY_ERROR, 3)
				surface.PlaySound("buttons/button11.wav")
				self:SetChecked(EasyChat.Config.AllowTagsInNames)
			end
		end

		setting_tags_msgs.OnChange = function(self, enabled)
			local succ, err = EasyChat.Config:WriteTagsInMessages(enabled)
			if not succ then
				notification.AddLegacy(err, NOTIFY_ERROR, 3)
				surface.PlaySound("buttons/button11.wav")
				self:SetChecked(EasyChat.Config.AllowTagsInMessages)
			end
		end

		hook.Add("ECServerConfigUpdate", setting_tags_msgs, function(_, config)
			setting_tags_names:SetChecked(config.AllowTagsInNames)
			setting_tags_msgs:SetChecked(config.AllowTagsInMessages)
		end)

		settings:AddSpacer(category_name)

		local setting_font_editor = settings:AddSetting(category_name, "action", "Font Editor")
		setting_font_editor.DoClick = function()
			local editor = vgui.Create("ECChatHUDFontEditor")
			editor:MakePopup()
			editor:Center()
		end

		concommand.Add("chathud_font_editor", setting_font_editor.DoClick)

		settings:AddSpacer(category_name)

		settings:AddConvarSettingsSet(category_name, {
			[EC_HUD_FOLLOW] = "Follow the chatbox window",
			[EC_HUD_SMOOTH] = "Smooth message transitions",
			[EC_HUD_SH_CLEAR] = "Clear the tags upon saying \'sh\'",
			[EC_HUD_CUSTOM] = "Use EasyChat's custom hud",
		})

		settings:AddSpacer(category_name)

		settings:AddConvarSetting(category_name, "number", EC_HUD_WIDTH, "HUD Width", 1250, 250)
		settings:AddConvarSetting(category_name, "number", EC_HUD_POS_X, "HUD X Pos", 5000, 0)
		settings:AddConvarSetting(category_name, "number", EC_HUD_POS_Y, "HUD Y Pos", 5000, 0)

		local setting_reset_hud_bounds = settings:AddSetting(category_name, "action", "Reset HUD Bounds")
		setting_reset_hud_bounds.DoClick = function()
			EC_HUD_WIDTH:SetInt(-1)
			EC_HUD_POS_X:SetInt(-1)
			EC_HUD_POS_Y:SetInt(-1)
		end

		settings:AddSpacer(category_name)

		settings:AddConvarSetting(category_name, "number", EC_HUD_TTL, "Message Life Time", 60, 2)
		settings:AddConvarSetting(category_name, "number", EC_HUD_FADELEN, "Message Fadeout Time", 5, 1)

		local setting_reset_duration = settings:AddSetting(category_name, "action", "Reset Message Life/Fadeout Time")
		setting_reset_duration.DoClick = function()
			local default_duration = tonumber(EC_HUD_TTL:GetDefault())
			EC_HUD_TTL:SetInt(default_duration)

			local default_fadelen = tonumber(EC_HUD_FADELEN:GetDefault())
			EC_HUD_FADELEN:SetInt(default_fadelen)
		end
	end

	-- ranks / usergroups settings
	do
		local category_name = "Ranks"
		settings:AddCategory(category_name)

		local setting_override_client_settings = settings:AddSetting(category_name, "boolean", "Server settings override client settings")
		setting_override_client_settings:SetChecked(EasyChat.Config.OverrideClientSettings)
		setting_override_client_settings.OnChange = function(self, enabled)
			local succ, err = EasyChat.Config:WriteSettingOverride(enabled)
			if not succ then
				notification.AddLegacy(err, NOTIFY_ERROR, 3)
				surface.PlaySound("buttons/button11.wav")
				self:SetChecked(EasyChat.Config.OverrideClientSettings)
			end
		end

		settings:AddSpacer(category_name)

		local setting_usergroups = settings:AddSetting(category_name, "list", "Rank Prefixes")
		local prefix_list = setting_usergroups.List
		prefix_list:SetMultiSelect(true)
		prefix_list:AddColumn("Usergroup")
		prefix_list:AddColumn("Emote")
		prefix_list:AddColumn("Tag")

		local function build_emote_tag(emote_name, emote_size, emote_provider)
			local emote_tag = ""
			if #emote_name > 0 then
				emote_tag = ("<emote=%s"):format(emote_name)
				if emote_size ~= -1 then
					emote_tag = ("%s,%d"):format(emote_tag, emote_size)
				end

				if #emote_provider > 0 then
					-- add a comma for proper markup parsing
					if emote_size == -1 then
						emote_tag = ("%s,"):format(emote_tag)
					end

					emote_tag = ("%s,%s"):format(emote_tag, emote_provider)
				end

				emote_tag = ("%s>"):format(emote_tag)
			end

			return emote_tag
		end

		local function setup_rank(usergroup)
			-- usergroup = usergroup or "user"

			-- sanity check to see if wanted usergroup actually exists
			--if usergroup and not EasyChat.Config.UserGroups[usergroup] then return end

			local frame = EasyChat.CreateFrame()
			frame:SetSize(400, 400)
			frame:SetTitle(usergroup and "Modify Rank" or "New Rank")

			local setting_usergroup = settings:AddSetting(category_name, "string", "Usergroup")
			setting_usergroup:SetParent(frame)
			setting_usergroup:DockMargin(5, 20, 5, 10)
			if usergroup then
				setting_usergroup:SetText(usergroup)
			end

			local setting_emote_name = settings:AddSetting(category_name, "string", "Emote")
			setting_emote_name:SetParent(frame)
			setting_emote_name:DockMargin(5, 15, 5, 10)
			if usergroup then
				local prefix_data = EasyChat.Config.UserGroups[usergroup]
				local text = build_emote_tag(prefix_data.EmoteName, prefix_data.EmoteSize or -1, prefix_data.EmoteProvider or ""):match("<emote=(.*)>")
				if text then
					setting_emote_name:SetText(text)
				end
			end

			local setting_tag = settings:AddSetting(category_name, "string", "Tag")
			setting_tag:SetParent(frame)
			setting_tag:DockMargin(5, 15, 5, 10)
			if usergroup then
				setting_tag:SetText(EasyChat.Config.UserGroups[usergroup].Tag)
			end

			local setting_save = settings:AddSetting(category_name, "action", "Save")
			setting_save:SetParent(frame)
			setting_save:Dock(BOTTOM)
			setting_save:DockMargin(5, 10, 5, 5)
			setting_save.DoClick = function()
				local emote_components = setting_emote_name:GetText():Split(",")
				-- emote_name, emote_size, emote_provider

				local succ, err = EasyChat.Config:WriteUserGroup(
					setting_usergroup:GetText(),
					setting_tag:GetText(),
					emote_components[1], -- emote name
					emote_components[2], -- emote size
					emote_components[3] -- emote provider
				)

				if not succ then
					notification.AddLegacy(err, NOTIFY_ERROR, 3)
					surface.PlaySound("buttons/button11.wav")
				else
					frame:Close()
				end
			end

			local mk = nil
			local function build_mk()
				if not IsValid(frame) then return end

				local input_str = ("%s<stop>"):format(setting_tag:GetText():Trim())
				local emote_components =  setting_emote_name:GetText():Split(",")
				local emote_tag = build_emote_tag(
					emote_components[1]:Trim(), -- emote name
					tonumber(emote_components[2]) or -1, -- emote size
					(emote_components[3] or ""):Trim() -- emote provider
				)

				if #emote_tag > 0 then
					input_str = ("%s %s"):format(input_str, emote_tag)
				end

				input_str = ("%s %s<stop>: Hello!"):format(input_str, LocalPlayer():RichNick())
				mk = ec_markup.Parse(input_str)
			end

			build_mk()
			setting_emote_name.OnChange = function()
				timer.Create("ECUserGroupPrefixSetup", 0.25, 1, build_mk)
			end

			setting_tag.OnChange = function()
				timer.Create("ECUserGroupPrefixSetup", 0.25, 1, build_mk)
			end

			local setting_canvas = frame:Add("DPanel")
			setting_canvas:Dock(FILL)
			setting_canvas:DockMargin(5, 10, 5, 5)
			setting_canvas.Paint = function(_, w, h)
				surface.SetDrawColor(color_white)
				surface.DrawOutlinedRect(0, 0, w, h)

				if mk then
					local mk_w, mk_h = mk:GetWide(), mk:GetTall()
					mk:Draw(w / 2 - mk_w / 2, h / 2 - mk_h / 2)
				end
			end

			frame:MakePopup()
			frame:Center()
		end

		local function modify_rank()
			local selected_lines = prefix_list:GetSelected()
			for _, line in pairs(selected_lines) do
				local usergroup = line:GetColumnText(1)
				setup_rank(usergroup)
			end
		end

		local function delete_rank()
			local selected_lines = prefix_list:GetSelected()
			for _, line in pairs(selected_lines) do
				local usergroup = line:GetColumnText(1)
				local succ, err = EasyChat.Config:DeleteUserGroup(usergroup)
				if not succ then
					notification.AddLegacy(err, NOTIFY_ERROR, 3)
					surface.PlaySound("buttons/button11.wav")
					break
				end
			end
		end

		prefix_list.DoDoubleClick = function(_, _, line)
			setup_rank(line:GetColumnText(1))
		end

		prefix_list.OnRowRightClick = function()
			local prefix_menu = DermaMenu()
			prefix_menu:AddOption("Modify", modify_rank):SetImage("icon16/shield.png")
			prefix_menu:AddOption("Delete", delete_rank):SetImage("icon16/shield.png")
			prefix_menu:AddSpacer()
			prefix_menu:AddOption("Cancel", function() prefix_menu:Remove() end)
			prefix_menu:Open()
		end

		local function build_usergroup_list()
			prefix_list:Clear()

			for usergroup, prefix_data in pairs(EasyChat.Config.UserGroups) do
				local emote_display = build_emote_tag(prefix_data.EmoteName, prefix_data.EmoteSize or -1, prefix_data.EmoteProvider or "")
				local line = prefix_list:AddLine(usergroup, emote_display, prefix_data.Tag)

				local input_str = ("%s<stop>"):format(prefix_data.Tag)
				if #emote_display > 0 then
					input_str = ("%s %s"):format(input_str, emote_display)
				end

				input_str = ("%s %s"):format(input_str, LocalPlayer():RichNick())
				local mk = ec_markup.Parse(input_str)
				local mk_w, mk_h = mk:GetWide(), mk:GetTall()

				local tooltip = vgui.Create("Panel")
				tooltip:SetVisible(false)
				tooltip:SetDrawOnTop(true)
				tooltip:SetWide(mk_w + 10)
				tooltip:SetTall(mk_h + 10)
				tooltip.Paint = function(_, w, h)
					if not settings:IsVisible() then return end
					mk:Draw(w / 2 - mk_w / 2, h / 2 - mk_h / 2)
				end

				line.Think = function(self)
					local is_hovered = self:IsHovered()
					tooltip:SetVisible(is_hovered)
					local mx, my = gui.MousePos()
					tooltip:SetPos(mx, my)
				end

				line.OnRemove = function()
					if not IsValid(tooltip) then return end
					tooltip:Remove()
				end
			end
		end

		build_usergroup_list()

		local setting_add_usergroup = settings:AddSetting(category_name, "action", "(ADMIN) Setup New Rank")
		setting_add_usergroup:SetImage("icon16/shield.png")
		setting_add_usergroup.DoClick = function()
			setup_rank()
		end

		local setting_modify_usergroup = settings:AddSetting(category_name, "action", "(ADMIN) Modify Rank")
		setting_modify_usergroup:SetImage("icon16/shield.png")
		setting_modify_usergroup.DoClick = modify_rank

		local setting_del_usergroup = settings:AddSetting(category_name, "action", "(ADMIN) Delete Rank")
		setting_del_usergroup:SetImage("icon16/shield.png")
		setting_del_usergroup.DoClick = delete_rank

		hook.Add("ECServerConfigUpdate", settings, function(_, config)
			setting_override_client_settings:SetChecked(config.OverrideClientSettings)
			build_usergroup_list()
		end)
	end

	-- translation
	do
		local category_name = "Translation"
		settings:AddCategory(category_name)

		local valid_languages = {
			["Automatic"] = "auto",

			["Afrikaans"] = "af", ["Irish"] = "ga", ["Albanian"] = "sq", ["Italian"] = "it", ["Arabic"] = "ar", ["Japanese"] = "ja",
			["Azerbaijani"] = "az", ["Kannada"] = "kn", ["Basque"] = "eu", ["Korean"] = "ko", ["Bengali"] = "bn", ["Latin"] = "la",
			["Belarusian"] = "be", ["Latvian"] = "lv", ["Bulgarian"] =	"bg", ["Lithuanian"] = "lt", ["Catalan"] = "ca",
			["Macedonian"] = "mk", ["Chinese Simplified"] = "zh-CN", ["Malay"] =	"ms", ["Chinese Traditional"] = "zh-TW", ["Maltese"] = "mt",
			["Croatian"] = "hr", ["Norwegian"] = "no", ["Czech"] = "cs", ["Persian"] = "fa", ["Danish"] = "da", ["Polish"] = "pl", ["Dutch"] = "nl",
			["Portuguese"] = "pt", ["English"] = "en", ["Romanian"] = "ro", ["Esperanto"] =	"eo", ["Russian"] = "ru", ["Estonian"] = "et", ["Serbian"] = "sr",
			["Filipino"] = "tl", ["Slovak"] = "sk", ["Finnish"] = "fi", ["Slovenian"] =	"sl", ["French"] = "fr", ["Spanish"] = "es", ["Galician"] = "gl",
			["Swahili"] = "sw", ["Georgian"] = "ka", ["Swedish"] = "sv", ["German"] = "de", ["Tamil"] =	"ta", ["Greek"] = "el", ["Telugu"] = "te",
			["Gujarati"] = "gu", ["Thai"] = "th", ["Haitian Creole"] = "ht", ["Turkish"] = "tr", ["Hebrew"] = "iw", ["Ukrainian"] =	"uk", ["Hindi"] = "hi",
			["Urdu"] = "ur", ["Hungarian"] = "hu", ["Vietnamese"] = "vi", ["Icelandic"] = "is", ["Welsh"] = "cy", ["Indonesian"] = "id", ["Yiddish"] = "yi",
		}

		local language_count = table.Count(valid_languages)

		local function build_translation_auto_complete(text_entry)
			text_entry.GetAutoComplete = function(self, text)
				text = text:lower()

				local suggestions = {}
				for complete_name, shortcut in pairs(valid_languages) do
					if complete_name:lower():match(text) or shortcut:match(text) then
						table.insert(suggestions, ("%s (%s)"):format(shortcut, complete_name))
					end
				end

				return suggestions
			end

			local language_selection = 1
			local language_input = ""
			text_entry.OnKeyCodeTyped = function(self, key_code)
				if key_code == KEY_TAB then
					local suggestion = self:GetAutoComplete(language_input)[language_selection]
					if suggestion then
						local country_code = suggestion:match("^(.+)%s%(")
						self:SetText(country_code)
						EasyChat.RunOnNextFrame(function()
							self:RequestFocus()  -- keep focus
							self:SetCaretPos(#self:GetText())
						end)
					end

					language_selection = language_selection + 1
					if language_selection > language_count then
						language_selection = 1
					end
				elseif key_code == KEY_ENTER or key_code == KEY_PAD_ENTER then
					if IsValid(self.Menu) then self.Menu:Remove() end
					self:OnEnter()
					EasyChat.RunOnNextFrame(function()
						self:RequestFocus()  -- keep focus
						self:SetCaretPos(#self:GetText())
					end)
				else
					language_input = self:GetText()
					language_selection = 1
				end
			end

			local old_enter = text_entry.OnEnter
			function text_entry.OnEnter(self)
				local country_code = self:GetText():match("^(.+)%s%(")
				if country_code then
					self:SetText(country_code)
				end

				country_code = self:GetText():Trim()
				if not table.HasValue(valid_languages, country_code) then
					notification.AddLegacy("Invalid country code", NOTIFY_ERROR, 3)
					surface.PlaySound("buttons/button11.wav")
					return
				elseif not EC_TRANSLATE_API_KEY:GetString():find("trnsl.1.1.") then
					notification.AddLegacy("You do not have a Yandex API Key.", NOTIFY_ERROR, 3)
					surface.PlaySound("buttons/button11.wav")
					return
				end

				old_enter(self)
			end
		end

		local yandex_link = settings:GetCategory(category_name):Add("DLabelURL")
		yandex_link:SetText("Click here for a key to use our thirdparty translation provider.")
		yandex_link:SetURL("https://translate.yandex.com/developers/keys")
		yandex_link:Dock(TOP)
		yandex_link:DockMargin(10, 0, 10, 5)
		yandex_link:SetColor(Color(220, 0, 0))

		settings:AddConvarSetting(category_name, "string", EC_TRANSLATE_API_KEY, "Yandex API Key (Required)")

		settings:AddSpacer(category_name)

		settings:AddConvarSetting(category_name, "boolean", EC_TRANSLATE_OUT_MSG, "Translate your chat messages")
		build_translation_auto_complete(settings:AddConvarSetting(category_name, "string", EC_TRANSLATE_OUT_SRC_LANG, "Your language"))
		build_translation_auto_complete(settings:AddConvarSetting(category_name, "string", EC_TRANSLATE_OUT_TARGET_LANG, "Their language"))

		settings:AddSpacer(category_name)

		settings:AddConvarSetting(category_name, "boolean", EC_TRANSLATE_INC_MSG, "Translate other's chat messages")
		build_translation_auto_complete(settings:AddConvarSetting(category_name, "string", EC_TRANSLATE_INC_TARGET_LANG, "Your language"))
		build_translation_auto_complete(settings:AddConvarSetting(category_name, "string", EC_TRANSLATE_INC_SRC_LANG, "Their language"))
	end
end

local function add_chathud_markup_settings()
	local settings = EasyChat.Settings
	local category_name = "Chat HUD"

	settings:AddSpacer(category_name)

	local setting_help = settings:AddSetting(category_name, "action", "Show Help & Examples")
	setting_help.DoClick = function()
		RunConsoleCommand("easychat_hud_examples")
	end

	local tag_options = {}
	for part_name, _ in pairs(EasyChat.ChatHUD.Parts) do
		local cvar = get_cvar("easychat_tag_" .. part_name)
		if cvar then
			tag_options[cvar] = ("%s tags"):format(part_name)
		end
	end

	settings:AddConvarSettingsSet(category_name, tag_options)
end

local function add_legacy_settings()
	local registered_cvars = EasyChat.GetRegisteredConvars()
	if #registered_cvars == 0 then return end

	local options = {}
	for _, registered_cvar in pairs(registered_cvars) do
		options[registered_cvar.Convar] = registered_cvar.Description
	end

	EasyChat.Settings:AddConvarSettingsSet("Others", options)
end

hook.Add("ECPreLoadModules", "EasyChatDefaultSettings", create_default_settings)
hook.Add("ECPostLoadModules", "EasyChatDefaultSettings", function()
	add_chathud_markup_settings()
	add_legacy_settings()
end)
