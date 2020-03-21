-- general
local EC_ENABLE = GetConVar("easychat_enable")
local EC_NO_MODULES = GetConVar("easychat_no_modules")

-- teams and colors
local EC_TEAMS = GetConVar("easychat_teams")
local EC_TEAMS_COLOR = GetConVar("easychat_teams_colored")
local EC_PLAYER_COLOR = GetConVar("easychat_players_colored")
local EC_PLAYER_PASTEL = GetConVar("easychat_pastel")

-- misc
local EC_SECONDARY = GetConVar("easychat_secondary_mode")
local EC_ALWAYS_LOCAL = GetConVar("easychat_always_local")
local EC_LOCAL_MSG_DIST = GetConVar("easychat_local_msg_distance")
local EC_TICK_SOUND = GetConVar("easychat_tick_sound")
local EC_USE_ME = GetConVar("easychat_use_me")
local EC_IMAGES = GetConVar("easychat_images")
local EC_TIMESTAMPS_12 = GetConVar("easychat_timestamps_12")
local EC_LINKS_CLIPBOARD = GetConVar("easychat_links_to_clipboard")
local EC_GM_COMPLETE = GetConVar("easychat_gm_complete")
local EC_NICK_COMPLETE = GetConVar("easychat_nick_complete")

-- chatbox
local EC_USE_DERMASKIN = GetConVar("easychat_use_dermaskin")
local EC_HISTORY = GetConVar("easychat_history")
local EC_GLOBAL_ON_OPEN = GetConVar("easychat_global_on_open")
local EC_FONT = GetConVar("easychat_font")
local EC_FONT_SIZE = GetConVar("easychat_font_size")
local EC_TIMESTAMPS = GetConVar("easychat_timestamps")
local EC_PEEK_COMPLETION = GetConVar("easychat_peek_completion")
local EC_LEGACY_ENTRY = GetConVar("easychat_legacy_entry")
local EC_LEGACY_TEXT = GetConVar("easychat_legacy_text")

-- chathud
local EC_HUD_FOLLOW = GetConVar("easychat_hud_follow")
local EC_HUD_TTL = GetConVar("easychat_hud_ttl")
local EC_HUD_SMOOTH = GetConVar("easychat_hud_smooth")
local EC_HUD_TIMESTAMPS = GetConVar("easychat_hud_timestamps")
local EC_HUD_SH_CLEAR = GetConVar("easychat_hud_sh_clear")
local EC_HUD_CUSTOM = GetConVar("easychat_hud_custom")
local EC_HUD_POS_X = GetConVar("easychat_hud_pos_x")
local EC_HUD_POS_Y = GetConVar("easychat_hud_pos_y")
local EC_HUD_WIDTH = GetConVar("easychat_hud_width")

local function create_option_set(settings, category_name, options)
	for cvar, description in pairs(options) do
		settings:AddConvarSetting(category_name, "boolean", cvar, description)
	end

	local setting_reset_options = settings:AddSetting(category_name, "action", "Reset Options")
	setting_reset_options.DoClick = function()
		for cvar, _ in pairs(options) do
			local default_value = tobool(cvar:GetDefault())
			cvar:SetBool(default_value)
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
			[EC_ALWAYS_LOCAL] = "Always talk in local mode by default",
			[EC_LINKS_CLIPBOARD] = "Automatically copy links to your clipboard",
			[EC_TIMESTAMPS_12] = "12 hours mode timestamps",
			[EC_TEAMS] = "Display teams",
			[EC_TEAMS_COLOR] = "Color the team tags",
			[EC_PLAYER_COLOR] = "Color players in their team color",
			[EC_PLAYER_PASTEL] = "Pastellize player colors",
			[EC_TICK_SOUND] = "Tick sound on new messages",
			[EC_USE_ME] = "Replaces your name in the chat with \"me\"",
			[EC_GM_COMPLETE] = "Uses the default gamemode name auto-completion",
			[EC_NICK_COMPLETE] = "Auto-complete player names",
		})

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
					timer.Simple(0, function()
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
				timer.Simple(0, function()
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

		local setting_disable_modules = settings:AddSetting(category_name, "action", EC_NO_MODULES:GetBool() and "Run Modules" or "Disallow Modules")
		setting_disable_modules.DoClick = function() EC_NO_MODULES:SetBool(not EC_NO_MODULES:GetBool()) end

		local setting_reload_ec = settings:AddSetting(category_name, "action", "Reload EasyChat")
		setting_reload_ec.DoClick = function() EasyChat.Reload() end

		local setting_disable_ec = settings:AddSetting(category_name, "action", "Disable EasyChat")
		setting_disable_ec.DoClick = function() EC_ENABLE:SetBool(false) end
	end

	-- chatbox settings
	do
		local category_name = "Chatbox"
		settings:AddCategory(category_name)

		create_option_set(settings, category_name, {
			[EC_GLOBAL_ON_OPEN] = "Open in the global tab",
			[EC_TIMESTAMPS] = "Display timestamps",
			[EC_HISTORY] = "Enable history",
			[EC_IMAGES] = "Display images",
			[EC_PEEK_COMPLETION] = "Peek at the possible chat completion",
		})

		settings:AddSpacer(category_name)

		if not EasyChat.UseDermaSkin then
			local built_in_themes = {
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
				EasyChat.OutlayColor = Color(color:Unpack())

				local text_entry = EasyChat.GUI.TextEntry
				if IsValid(text_entry) and text_entry.ClassName == "TextEntryX" then
					text_entry:SetBorderColor(EasyChat.OutlayColor)
				end
			end

			local setting_outlay_outline_color = settings:AddSetting(category_name, "color", "Outlay Outline Color")
			setting_outlay_outline_color:SetColor(EasyChat.OutlayOutlineColor)
			setting_outlay_outline_color.OnValueChanged = function(_, color)
				EasyChat.OutlayOutlineColor = Color(color:Unpack())
			end

			local setting_tab_color = settings:AddSetting(category_name, "color", "Tab Color")
			setting_tab_color:SetColor(EasyChat.TabColor)
			setting_tab_color.OnValueChanged = function(_, color)
				EasyChat.TabColor = Color(color:Unpack())

				local text_entry = EasyChat.GUI.TextEntry
				if IsValid(text_entry) and text_entry.ClassName == "TextEntryX" then
					text_entry:SetBackgroundColor(EasyChat.TabColor)
				end
			end

			local setting_tab_outline_color = settings:AddSetting(category_name, "color", "Tab Outline Color")
			setting_tab_outline_color:SetColor(EasyChat.TabOutlineColor)
			setting_tab_outline_color.OnValueChanged = function(_, color)
				EasyChat.TabOutlineColor = Color(color:Unpack())
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
				themes_menu:Open()
			end

			local setting_save_colors = settings:AddSetting(category_name, "action", "Save Colors")
			setting_save_colors.DoClick = function()
				local text_entry = EasyChat.GUI.TextEntry
				if IsValid(text_entry) and text_entry.ClassName == "TextEntryX" then
					text_entry:SetBackgroundColor(EasyChat.TabColor)
					text_entry:SetBorderColor(EasyChat.OutlayColor)
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
				local outlay_color = Color(62, 62, 62, 235)
				local outlay_outline_color = Color(0, 0, 0, 0)
				local tab_color = Color(36, 36, 36, 235)
				local tab_outline_color = Color(0, 0, 0, 0)

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
		tab_list.OnRemove = function(self)
			hook.Remove("ECSettingsOpened", self)
		end

		local setting_apply_tab = settings:AddSetting(category_name, "action", "Hide / Show Tab")
		setting_apply_tab.DoClick = function()
			local selected_lines = tab_list:GetSelected()
			for _, selected_line in pairs(selected_lines) do
				local tab_name = selected_line:GetColumnText(1)
				local tab_data = EasyChat.GetTab(tab_name)
				if tab_data then
					local is_visible = tab_data.Tab:IsVisible()
					tab_data.Tab:SetVisible(not is_visible)

					-- this is inverted, because we get IsVisible before setting it
					selected_line:SetColumnText(2, is_visible and "Yes" or "No")
				end
			end
		end

		settings:AddSpacer(category_name)

		local setting_legacy_entry = settings:AddSetting(category_name, "action", EC_LEGACY_ENTRY:GetBool() and "Use Modern Textbox" or "Use Legacy Textbox")
		setting_legacy_entry.DoClick = function()
			EC_LEGACY_ENTRY:SetBool(not EC_LEGACY_ENTRY:GetBool())
		end

		local setting_legacy_text = settings:AddSetting(category_name, "action", EC_LEGACY_TEXT:GetBool() and "Use Modern RichText" or "Use Legacy RichText")
		setting_legacy_text.DoClick = function()
			EC_LEGACY_TEXT:SetBool(not EC_LEGACY_TEXT:GetBool())
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

		local setting_font_editor = settings:AddSetting(category_name, "action", "Font Editor")
		setting_font_editor.DoClick = function()
			local editor = vgui.Create("ECChatHUDFontEditor")
			editor:MakePopup()
			editor:Center()
		end

		concommand.Add("chathud_font_editor", setting_font_editor.DoClick)

		settings:AddSpacer(category_name)

		create_option_set(settings, category_name, {
			[EC_HUD_FOLLOW] = "Follow chatbox window",
			[EC_HUD_TIMESTAMPS] = "Display timestamps",
			[EC_HUD_SMOOTH] = "Smooth message transitions",
			[EC_HUD_SH_CLEAR] = "Clear the tags upon saying \'sh\'",
			[EC_HUD_CUSTOM] = "Use EasyChat's custom hud",
		})

		settings:AddSpacer(category_name)

		local setting_hud_w = settings:AddConvarSetting(category_name, "number", EC_HUD_WIDTH, "HUD Width", 1250, 250)
		local setting_hud_x = settings:AddConvarSetting(category_name, "number", EC_HUD_POS_X, "HUD X Pos", 5000, 0)
		local setting_hud_y = settings:AddConvarSetting(category_name, "number", EC_HUD_POS_Y, "HUD Y Pos", 5000, 0)

		local setting_reset_hud_bounds = settings:AddSetting(category_name, "action", "Reset HUD Bounds")
		setting_reset_hud_bounds.DoClick = function()
			EC_HUD_WIDTH:SetInt(-1)
			EC_HUD_POS_X:SetInt(-1)
			EC_HUD_POS_Y:SetInt(-1)
		end

		settings:AddSpacer(category_name)

		settings:AddConvarSetting(category_name, "number", EC_HUD_TTL, "Message Duration", 60, 2)

		local setting_reset_duration = settings:AddSetting(category_name, "action", "Reset Duration")
		setting_reset_duration.DoClick = function()
			local default_duration = tonumber(EC_HUD_TTL:GetDefault())
			EC_HUD_TTL:SetInt(default_duration)
		end
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
end

local function add_legacy_settings()
	local registered_cvars = EasyChat.GetRegisteredConvars()
	if #registered_cvars == 0 then return end

	local options = {}
	for _, registered_cvar in pairs(registered_cvars) do
		options[registered_cvar.Convar] = registered_cvar.Description
	end

	create_option_set(EasyChat.Settings, "Others", options)
end

hook.Add("ECPreLoadModules", "EasyChatDefaultSettings", create_default_settings)
hook.Add("ECPostLoadModules", "EasyChatDefaultSettings", function()
	add_chathud_markup_settings()
	add_legacy_settings()
end)
