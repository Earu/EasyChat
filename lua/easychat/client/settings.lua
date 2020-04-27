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
local EC_NICK_PRIORITIZE = GetConVar("easychat_nick_prioritize")
local EC_OUT_CLICK_CLOSE = GetConVar("easychat_out_click_close")

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
local EC_HUD_FADELEN = GetConVar("easychat_hud_fadelen")
local EC_HUD_SMOOTH = GetConVar("easychat_hud_smooth")
local EC_HUD_TIMESTAMPS = GetConVar("easychat_hud_timestamps")
local EC_HUD_SH_CLEAR = GetConVar("easychat_hud_sh_clear")
local EC_HUD_CUSTOM = GetConVar("easychat_hud_custom")
local EC_HUD_POS_X = GetConVar("easychat_hud_pos_x")
local EC_HUD_POS_Y = GetConVar("easychat_hud_pos_y")
local EC_HUD_WIDTH = GetConVar("easychat_hud_width")
local EC_HUD_FADELEN = GetConVar("easychat_hud_fadelen")

-- translation
local EC_TRANSLATE_INC_MSG = GetConVar("easychat_translate_inc_msg")
local EC_TRANSLATE_INC_SRC_LANG = GetConVar("easychat_translate_inc_source_lang")
local EC_TRANSLATE_INC_TARGET_LANG = GetConVar("easychat_translate_inc_target_lang")
local EC_TRANSLATE_OUT_MSG = GetConVar("easychat_translate_out_msg")
local EC_TRANSLATE_OUT_SRC_LANG = GetConVar("easychat_translate_out_source_lang")
local EC_TRANSLATE_OUT_TARGET_LANG = GetConVar("easychat_translate_out_target_lang")

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
			[EC_NICK_PRIORITIZE] = "Prioritize player nick completion over everything else",
			[EC_OUT_CLICK_CLOSE] = "Clicking outside the chat closes it",
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
				EasyChat.OutlayColor = Color(color:Unpack())

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
		prefix_list:SetMultiSelect(false)
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

		local function build_usergroup_list()
			prefix_list:Clear()

			for usergroup, prefix_data in pairs(EasyChat.Config.UserGroups) do
				local emote_display = build_emote_tag(prefix_data.EmoteName, prefix_data.EmoteSize or -1, prefix_data.EmoteProvider or "")
				local line = prefix_list:AddLine(usergroup, emote_display, prefix_data.Tag)

				local input_str = ("%s<stop>"):format(prefix_data.Tag)
				if #emote_display > 0 then
					input_str = ("%s %s"):format(input_str, emote_display)
				end

				input_str = ("%s %s"):format(input_str, LocalPlayer():Nick())
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

		local function setup_rank(usergroup)
			-- sanity check to see if wanted usergroup actually exists
			if usergroup and not EasyChat.Config.UserGroups[usergroup] then return end

			local frame = vgui.Create("DFrame")
			frame:SetSize(400, 400)
			frame:SetTitle(usergroup and "Modify Rank" or "New Rank")
			frame.lblTitle:SetFont("EasyChatFont")

			local setting_usergroup = settings:AddSetting(category_name, "string", "Usergroup")
			setting_usergroup:SetParent(frame)
			setting_usergroup:Dock(TOP)
			setting_usergroup:DockMargin(5, 20, 5, 10)
			if usergroup then
				setting_usergroup:SetText(usergroup)
			end

			local setting_emote_name = settings:AddSetting(category_name, "string", "Emote")
			setting_emote_name:SetParent(frame)
			setting_emote_name:Dock(TOP)
			setting_emote_name:DockMargin(5, 15, 5, 10)
			if usergroup then
				local prefix_data = EasyChat.Config.UserGroups[usergroup]
				local text = build_emote_tag(prefix_data.EmoteName, prefix_data.EmoteSize or -1, prefix_data.EmoteProvider or ""):match("<emote=(.*)>")
				setting_emote_name:SetText(text)
			end

			local setting_tag = settings:AddSetting(category_name, "string", "Tag")
			setting_tag:SetParent(frame)
			setting_tag:Dock(TOP)
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

				input_str = ("%s %s<stop>: Hello!"):format(input_str, LocalPlayer():Nick())
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

			if not EasyChat.UseDermaSkin then
				frame.lblTitle:SetTextColor(EasyChat.TextColor)

				frame.btnMaxim:Hide()
				frame.btnMinim:Hide()
				frame.btnClose:SetText("x")
				frame.btnClose:SetFont("DermaDefaultBold")
				frame.btnClose:SetTextColor(EasyChat.TextColor)
				frame.btnClose.Paint = function() end

				EasyChat.BlurPanel(frame, 0, 0, 0, 0)
				frame.Paint = function(self, w, h)
					surface.SetDrawColor(EasyChat.OutlayColor)
					surface.DrawRect(0, 0, w, 25)

					surface.SetDrawColor(EasyChat.TabColor)
					surface.DrawRect(0, 25, w, h - 25)

					surface.SetDrawColor(EasyChat.TabOutlineColor)
					surface.DrawOutlinedRect(0, 0, w, 25)

					surface.SetDrawColor(EasyChat.OutlayOutlineColor)
					surface.DrawOutlinedRect(0, 0, w, h)
				end
			end

			frame:MakePopup()
			frame:Center()
		end

		local setting_add_usergroup = settings:AddSetting(category_name, "action", "Setup New Rank")
		setting_add_usergroup.DoClick = function()
			setup_rank()
		end

		local setting_modify_usergroup = settings:AddSetting(category_name, "action", "Modify Rank")
		setting_modify_usergroup.DoClick = function()
			local selected_line = prefix_list:GetSelected()[1]
			if not IsValid(selected_line) then return end

			local usergroup = selected_line:GetColumnText(1)
			setup_rank(usergroup)
		end

		local setting_del_usergroup = settings:AddSetting(category_name, "action", "Delete Rank")
		setting_del_usergroup.DoClick = function()
			local selected_line = prefix_list:GetSelected()[1]
			if not IsValid(selected_line) then return end

			local usergroup = selected_line:GetColumnText(1)
			local succ, err = EasyChat.Config:DeleteUserGroup(usergroup)
			if not succ then
				notification.AddLegacy(err, NOTIFY_ERROR, 3)
				surface.PlaySound("buttons/button11.wav")
			end
		end

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
						timer.Simple(0, function()
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
					timer.Simple(0, function()
						self:RequestFocus()  -- keep focus
						self:SetCaretPos(#self:GetText())
					end)
				else
					language_input = self:GetText()
					language_selection = 1
				end
			end
		end

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
