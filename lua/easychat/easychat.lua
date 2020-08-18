local EasyChat = _G.EasyChat or {}
_G.EasyChat = EasyChat

local print = _G._print or _G.print -- epoe compat

local NET_BROADCAST_MSG = "EASY_CHAT_BROADCAST_MSG"
local NET_SEND_MSG = "EASY_CHAT_RECEIVE_MSG"
local NET_SET_TYPING = "EASY_CHAT_START_CHAT"
local NET_ADD_TEXT = "EASY_CHAT_ADD_TEXT"

local PLY = FindMetaTable("Player")
local TAG = "EasyChat"

local EC_MAX_CHARS = CreateConVar("easychat_max_chars", "3000", { FCVAR_REPLICATED, SERVER and FCVAR_ARCHIVE or nil }, "Max characters per messages", 50)

local color_red = Color(255, 0, 0)
local color_gray = Color(184, 189, 209)
local color_print_head = Color(244, 167, 66)
local color_print_good = Color(0, 160, 220)
local color_print_bad = Color(255, 127, 127)
function EasyChat.Print(is_err, ...)
	local args = { ... }
	local body_color

	if isstring(is_err) then
		table.insert(args, 1, is_err)
		body_color = color_print_good
	else
		body_color = is_err and color_print_bad or color_print_good
	end

	for k, v in ipairs(args) do args[k] = tostring(v) end
	MsgC(color_print_head, "[EasyChat] ⮞ ", body_color, table.concat(args), "\n")
end

local trim_lookup = {
	-- zero width chars
	[utf8.char(0x200b)] = "", -- ZERO WIDTH SPACE
	[utf8.char(0x200c)] = "", -- ZERO WIDTH NON JOINER
	[utf8.char(0x200d)] = "", -- ZERO WIDTH JOINER
	[utf8.char(0x2060)] = "", -- WORD JOINER

	-- spaces
	[utf8.char(0x00a0)] = " ",   -- NO BREAK SPACE
	[utf8.char(0x1680)] = "  ",  -- OGHAM SPACE MARK
	[utf8.char(0x2000)] = "  ",  -- EN QUAD
	[utf8.char(0x2001)] = "   ", -- EM QUAD
	[utf8.char(0x2002)] = "  ",  -- EN SPACE
	[utf8.char(0x2003)] = "   ", -- EM SPACE
	[utf8.char(0x2004)] = " ",   -- THREE PER EM SPACE
	[utf8.char(0x2005)] = " ",   -- FOUR PER EM SPACE
	[utf8.char(0x2006)] = " ",   -- SIX PER EM SPACE
	[utf8.char(0x2007)] = "  ",  -- FIGURE SPACE
	[utf8.char(0x2008)] = " ",   -- PUNCTUATION SPACE
	[utf8.char(0x2009)] = " ",   -- THIN SPACE
	[utf8.char(0x200a)] = " ",   -- HAIR SPACE
	[utf8.char(0x2028)] = "\n",  -- LINE SEPARATOR
	[utf8.char(0x2029)] = "\n\n",-- PARAGRAPH SEPARATOR
	[utf8.char(0x202f)] = " ",   -- NARROW NO BREAK SPACE
	[utf8.char(0x205f)] = " ",   -- MEDIUM MATHEMATICAL SPACE
	[utf8.char(0x3000)] = "   ", -- IDEOGRAPHIC SPACE
	[utf8.char(0x03164)] = "  ", -- HANGUL FILLER

	-- control chars
	[utf8.char(0x03)] = "^C" -- END OF TEXT
}

-- control_chars are newlines, tabs, etc...
function EasyChat.ExtendedStringTrim(str, control_chars)
	if not str then return "" end

	str = utf8.force(str)
	if control_chars then
		str = str:gsub("%c", "")
	end

	for unicode, replacement in pairs(trim_lookup) do
		str = str:gsub(unicode, replacement)
	end

	return str:Trim()
end

function EasyChat.IsStringEmpty(str)
	return #EasyChat.ExtendedStringTrim(str, true) == 0
end

local load_modules, get_modules = include("easychat/autoloader.lua")
EasyChat.GetModules = get_modules -- maybe useful for modules?

concommand.Add("easychat_show_modules", function()
	MsgC(color_print_head, "---- EasyChat Modules ----\n")
	for _, module in pairs(get_modules()) do
		MsgC(color_print_good, ("%s\n"):format(module.Name))
	end
	MsgC(color_print_head, ("-"):rep(26) .. "\n")
end, nil, "Shows all the loaded EasyChat modules")

function PLY:ECIsEnabled()
	return self:GetInfoNum("easychat_enable", 0) == 1
end

PLY.old_IsTyping = PLY.old_IsTyping or PLY.IsTyping
function PLY:IsTyping()
	if self:ECIsEnabled() then
		return self:GetNWBool("ec_is_typing", false)
	else
		return self:old_IsTyping()
	end
end

-- lets not break the addon with bad third-party code but still notify the
-- developers with an error
local function safe_hook_run(hook_name, ...)
	local succ, a, b, c, d, e, f = xpcall(hook.Run, function(err)
		ErrorNoHalt(debug.traceback(err))
	end, hook_name, ...)
	if not succ then return nil end
	return a, b, c, d, e, f
end
EasyChat.SafeHookRun = safe_hook_run

include("easychat/server_config.lua")

if SERVER then
	util.AddNetworkString(NET_SEND_MSG)
	util.AddNetworkString(NET_BROADCAST_MSG)
	util.AddNetworkString(NET_SET_TYPING)
	util.AddNetworkString(NET_ADD_TEXT)

	local EC_VERSION_WARNING = CreateConVar("easychat_version_warnings", "1", FCVAR_ARCHIVE, "Should we warn users if EasyChat is outdated")

	function EasyChat.PlayerAddText(ply, ...)
		net.Start(NET_ADD_TEXT)
		net.WriteTable({ ... })
		net.Send(ply)
	end

	function EasyChat.Warn(ply, msg)
		EasyChat.PlayerAddText(ply, color_red, "[WARN] " ..  msg)
	end

	function EasyChat.SendGlobalMessage(ply, str, is_team, is_local)
		local msg = hook.Run("PlayerSay", ply, str, is_team, is_local)
		if type(msg) ~= "string" then return end

		msg = EasyChat.ExtendedStringTrim(msg)
		if #msg == 0 then return end

		local filter = {}
		local broken_count = 1
		local function add_to_filter(ply)
			local id = ply:AccountID()
			if not id then
				filter[broken_count] = ply
				broken_count = broken_count + 1
			else
				filter[id] = ply
			end
		end

		add_to_filter(ply)
		for _, listener in ipairs(player.GetAll()) do
			if listener ~= ply then
				local can_see = hook.Run("PlayerCanSeePlayersChat", msg, is_team, listener, ply, is_local)
				if can_see == true then -- can be another type than a bool
					add_to_filter(listener)
				elseif can_see == false then -- can be nil so need to check for false
					filter[listener:AccountID() or 0] = nil
				end
			end
		end

		filter = table.ClearKeys(filter)

		net.Start(NET_BROADCAST_MSG)
		net.WriteEntity(ply)
		net.WriteString(msg)
		net.WriteBool(IsValid(ply) and (not ply:Alive()) or false)
		net.WriteBool(is_team)
		net.WriteBool(is_local)
		net.Send(filter)

		if game.IsDedicated() then
			-- shows in server console
			print(("%s: %s"):format(ply:Nick():gsub("<.->", ""), msg))
		end
	end

	local SPAM_STEP = 1 -- how many messages can be sent per second after burst
	local SPAM_MAX = 5 -- max amount of messages per burst

	local spam_watch_lookup = {}
	local function get_message_cost(msg, is_same_msg)
		local _, real_msg_len = msg:gsub("[^\128-\193]", "")
		if real_msg_len > 1024 then
			return SPAM_MAX - 1
		else
			local is_same_msg_spam = is_same_msg and real_msg_len > 128
			return is_same_msg_spam and 3 or 0
		end
	end

	local function spam_watch(ply, msg)
		local time = RealTime()
		local last_msg = spam_watch_lookup[ply] or { Time = 0, Message = "" }

		-- if the last_msg.Time is inferior to current time it means the player is not
		-- being rate-limited (spamming) update its time to the current one
		if last_msg.Time < time then
			last_msg.Time = time
		end

		local is_same_msg = last_msg.Message == msg
		last_msg.Message = msg

		-- compute what time is appropriate for the current message
		local new_msg_time = last_msg.Time + SPAM_STEP + get_message_cost(msg, is_same_msg)

		-- if the computed time is superior to our limit then its spam, rate-limit the player
		if new_msg_time > time + SPAM_MAX then
			-- we dont want the rate limit to last forever, clamp the max new time
			local max_new_time = time + SPAM_MAX + 3
			if new_msg_time > max_new_time then
				new_msg_time = max_new_time
			end

			spam_watch_lookup[ply] = { Time = new_msg_time, Message = msg }
			return true
		end

		spam_watch_lookup[ply] = { Time = new_msg_time, Message = msg }
		return false
	end
	EasyChat.SpamWatch = spam_watch

	net.Receive(NET_SEND_MSG, function(_, ply)
		local msg = net.ReadString()
		local is_team = net.ReadBool()
		local is_local = net.ReadBool()

		-- we sub the message len clientside if we receive something bigger here
		-- it HAS to be malicious
		if #msg > EC_MAX_CHARS:GetInt() then
			safe_hook_run("ECBlockedMessage", ply, msg, is_team, is_local, "too big")
			EasyChat.Warn(ply, ("NOT SENT (TOO BIG): %s..."):format(msg:sub(1, 100)))
			return
		end

		if spam_watch(ply, msg) then
			safe_hook_run("ECBlockedMessage", ply, msg, is_team, is_local, "spam")
			EasyChat.Warn(ply, ("NOT SENT (SPAM): %s..."):format(msg:sub(1, 100)))
			return
		end

		EasyChat.SendGlobalMessage(ply, msg, is_team, is_local)
	end)

	net.Receive(NET_SET_TYPING, function(_, ply)
		local is_opened = net.ReadBool()
		ply:SetNWBool("ec_is_typing", is_opened)
		safe_hook_run(is_opened and "ECOpened" or "ECClosed", ply)
	end)

	local function retrieve_commit_time(commit)
		local time = -1
		if not commit.commit and commit.commit.author and commit.commit.author.date then
			return time
		end

		commit.commit.author.date:gsub("(%d%d%d%d)%-(%d%d)%-(%d%d)T(%d%d)%:(%d%d)%:(%d%d)Z", function(year, month, day, hour, min, sec)
			time = os.time({
				day = day, month = month, year = year,
				hour = hour, min = min, sec = sec
			})
		end)

		return time
	end

	local WORKSHOP_ID = "1182471500"
	local function is_workshop_install()
		for _, addon_data in ipairs(engine.GetAddons()) do
			if addon_data.wsid == WORKSHOP_ID then
				return true
			end
		end

		return false
	end

	local DEFAULT_FILE_PATH = "lua/easychat/easychat.lua"
	local is_outdated = false
	local old_version, new_version
	local is_new_version = false
	local function check_version()
		if is_workshop_install() then
			EasyChat.Print("Running workshop version")
			return
		end

		http.Fetch("https://api.github.com/repos/Earu/EasyChat/commits/master", function(body, _, _, code)
			if code ~= 200 then return end
			local commit = util.JSONToTable(body)
			if not commit then return end
			if not commit.sha then return end

			local commit_time = retrieve_commit_time(commit)
			local cur_edit_time = file.Time(DEFAULT_FILE_PATH, "GAME")
			if istable(commit.files) and #commit.files > 0 then
				local changed_file = commit.files[1]
				local changed_file_path = commit.files[1].filename or DEFAULT_FILE_PATH
				if changed_file.status == "modified" then
					cur_edit_time = file.Time(changed_file_path, "GAME")
				elseif changed_file.status == "added" then
					cur_edit_time = file.Exists(changed_file_path, "GAME") and commit_time + 1 or 0
				elseif changed_file.status == "removed" then
					cur_edit_time = file.Exists(changed_file_path, "GAME") and 0 or commit_time + 1
				end
			end

			local latest_sha = cookie.GetString("ECLatestSHA")
			if not latest_sha then
				-- we dont want to set the SHA if we have an outdated version
				if commit_time > cur_edit_time then
					is_outdated = true
					EasyChat.Print("Running unknown outdated version")
				else
					is_new_version = true
					cookie.Set("ECLatestSHA", commit.sha)
					EasyChat.Print("Setting and running version ", commit.sha)
				end

				return
			end

			if latest_sha ~= commit.sha then
				if commit_time > cur_edit_time then
					-- same file as old but different sha, new update but not installed ?
					is_outdated = true
					old_version, new_version = latest_sha, commit.sha
					EasyChat.Print("Running outdated version ", latest_sha)
				else
					-- only update version if the last file edit was AFTER the latest commit
					if commit_time ~= -1 and cur_edit_time >= commit_time then
						-- our latest file edit is different than the one we registered which means we installed a new update
						is_new_version = true
						cookie.Set("ECLatestSHA", commit.sha)
						EasyChat.Print("Running version ", commit.sha)
					end
				end
			-- in theory this should never happen but what do I know
			elseif commit_time > cur_edit_time then
				is_outdated = true
				EasyChat.Print("Running unknown outdated version")
			else
				EasyChat.Print("Running version ", latest_sha)
			end
		end)
	end

	function EasyChat.Init()
		safe_hook_run("ECPreLoadModules")
		load_modules()
		safe_hook_run("ECPostLoadModules")
		check_version()
		safe_hook_run("ECInitialized")
	end

	function EasyChat.PlayerCanSeePlayersChat(_, _, listener, speaker, is_local)
		if is_local then
			if not IsValid(listener) or not IsValid(speaker) then
				return false
			end
			if is_local and listener:GetPos():Distance(speaker:GetPos()) > speaker:GetInfoNum("easychat_local_msg_distance", 150) then
				return false
			end
		end
	end

	local NAMING_FUNCTIONS = { "SetNick", "setNick", "SetRPName", "setRPName" }
	local WARN_NAME_FAIL = "Cannot set name for specified player: "
	hook.Add("Initialize", TAG, function()
		EasyChat.Init()

		-- default behavior for changing a player's name from the chat
		function GAMEMODE:ECPlayerNameChange(ply, target_ply, old_name, new_name)
			local is_set = false
			if DarkRP and target_ply.setRPName then
				target_ply:setRPName(new_name)
				is_set = true
			else
				-- fallbacks ?
				for _, func_name in ipairs(NAMING_FUNCTIONS) do
					if target_ply[func_name] then
						local succ, err = pcall(target_ply[func_name], target_ply, new_name)
						if not succ then
							EasyChat.Warn(ply, WARN_NAME_FAIL .. err)
						end

						is_set = true
						break
					end
				end
			end

			if not is_set then
				EasyChat.Warn(ply, WARN_NAME_FAIL .. "Could not find any compatible addon to do so.")
			end
		end

		safe_hook_run("ECPostInitialized")
	end)

	local has_version_warned = false
	hook.Add("ECOpened", TAG, function(ply)
		if has_version_warned then return end

		if is_outdated and EC_VERSION_WARNING:GetBool() then
			local msg_components = { color_gray, "The server is running an", color_red, " outdated ", color_gray, "version of", color_red, " EasyChat" }
			if old_version and new_version then
				table.Add(msg_components, { color_gray, " (current: ", color_red, old_version, color_gray, " | newest: ", color_red, new_version, color_gray, ")." })
			else
				table.Add(msg_components, { color_gray, "." })
			end

			table.insert(msg_components, "\nConsider updating.")
			EasyChat.PlayerAddText(ply, unpack(msg_components))
		elseif is_new_version then
			ply:SendLua([[cookie.Delete("ECChromiumWarn")]])
		end

		has_version_warned = true
	end)

	hook.Add("PlayerCanSeePlayersChat", TAG, EasyChat.PlayerCanSeePlayersChat)
	hook.Add("PlayerDisconnected", TAG, function(ply) spam_watch_lookup[ply] = nil end)
end

if CLIENT then
	local NO_COLOR = Color(0, 0, 0, 0)
	local UPLOADING_TEXT = "[uploading image...]"

	-- general
	local EC_ENABLE = CreateConVar("easychat_enable", "1", {FCVAR_ARCHIVE, FCVAR_USERINFO}, "Use easychat or not")
	local EC_NO_MODULES = CreateConVar("easychat_no_modules", "0", FCVAR_ARCHIVE, "Should easychat load modules or not")

	-- teams and colors
	local EC_TEAMS = CreateConVar("easychat_teams", "0", FCVAR_ARCHIVE, "Display team in front of messages or not")
	local EC_TEAMS_COLOR = CreateConVar("easychat_teams_colored", "0", FCVAR_ARCHIVE, "Display team with its relative color")
	local EC_PLAYER_COLOR = CreateConVar("easychat_players_colored", "1", FCVAR_ARCHIVE, "Display player with its relative team color")
	local EC_PLAYER_PASTEL = CreateConVar("easychat_pastel", "0", FCVAR_ARCHIVE, "Should players have pastelized colors instead of their team color")

	-- misc
	local EC_SECONDARY = CreateConVar("easychat_secondary_mode", "team", FCVAR_ARCHIVE, "Opens the chat in the selected mode with the secondary chat bind")
	local EC_ALWAYS_LOCAL = CreateConVar("easychat_always_local", "0", FCVAR_ARCHIVE, "Should we always type in local chat by default")
	local EC_LOCAL_MSG_DIST = CreateConVar("easychat_local_msg_distance", "300", {FCVAR_ARCHIVE, FCVAR_USERINFO}, "Set the maximum distance for users to receive local messages")
	local EC_TICK_SOUND = CreateConVar("easychat_tick_sound", "0", FCVAR_ARCHIVE, "Should a tick sound be played on new messages or not")
	local EC_USE_ME = CreateConVar("easychat_use_me", "0", FCVAR_ARCHIVE, 'Should the chat display your name or "me"')
	local EC_TIMESTAMPS_12 = CreateConVar("easychat_timestamps_12", "0", FCVAR_ARCHIVE, "Display timestamps in 12 hours mode or not")
	local EC_LINKS_CLIPBOARD = CreateConVar("easychat_links_to_clipboard", "0", FCVAR_ARCHIVE, "Automatically copies links to your clipboard")
	local EC_GM_COMPLETE = CreateConVar("easychat_gm_complete", "0", FCVAR_ARCHIVE, "Use the gamemode bad auto-completion")
	local EC_NICK_COMPLETE = CreateConVar("easychat_nick_complete", "1", FCVAR_ARCHIVE, "Auto-completes player names")
	local EC_NICK_PRIORITIZE = CreateConVar("easychat_nick_prioritize", "0", FCVAR_ARCHIVE, "Prioritize player nick completion over everything else")
	local EC_OUT_CLICK_CLOSE = CreateConVar("easychat_out_click_close", "1", FCVAR_ARCHIVE, "Clicking outside the chatbox closes it")

	-- chatbox panel
	local EC_GLOBAL_ON_OPEN = CreateConVar("easychat_global_on_open", "1", FCVAR_ARCHIVE, "Set the chat to always open global chat tab on open")
	local EC_FONT = CreateConVar("easychat_font", "Roboto", FCVAR_ARCHIVE, "Set the font to use for the chat")
	local EC_FONT_SIZE = CreateConVar("easychat_font_size", "17", FCVAR_ARCHIVE, "Set the font size for chatbox")
	local EC_DERMASKIN = CreateConVar("easychat_use_dermaskin", "0", FCVAR_ARCHIVE, "Use dermaskin look or not")
	local EC_HISTORY = CreateConVar("easychat_history", "1", FCVAR_ARCHIVE, "Should the history be shown")
	local EC_IMAGES = CreateConVar("easychat_images", "1", FCVAR_ARCHIVE, "Display images in the chat window")
	local EC_TIMESTAMPS = CreateConVar("easychat_timestamps", "0", FCVAR_ARCHIVE, "Display timestamps in the chatbox")
	local EC_PEEK_COMPLETION = CreateConVar("easychat_peek_completion", "1", FCVAR_ARCHIVE, "Display a preview of the possible text completion")
	local EC_LEGACY_ENTRY = CreateConVar("easychat_legacy_entry", "0", FCVAR_ARCHIVE, "Uses the legacy textbox entry")
	local EC_LEGACY_TEXT = CreateConVar("easychat_legacy_text", "0", FCVAR_ARCHIVE, "Uses the legacy text output")

	-- chathud
	local EC_HUD_SMOOTH = CreateConVar("easychat_hud_smooth", "1", FCVAR_ARCHIVE, "Enables chat smoothing")
	local EC_HUD_TTL = CreateConVar("easychat_hud_ttl", "16", FCVAR_ARCHIVE, "How long messages stay before vanishing")
	local EC_HUD_FOLLOW = CreateConVar("easychat_hud_follow", "1", FCVAR_ARCHIVE, "Set the chat hud to follow the chatbox")
	local EC_HUD_TIMESTAMPS = CreateConVar("easychat_hud_timestamps", "0", FCVAR_ARCHIVE, "Display timestamps in the chat hud")
	local EC_HUD_SH_CLEAR = CreateConVar("easychat_hud_sh_clear", "1", FCVAR_ARCHIVE, "Should \'sh\' clear the chat hud tags")
	local EC_HUD_CUSTOM = CreateConVar("easychat_hud_custom", "1", FCVAR_ARCHIVE, "Use EasyChat's custom chat hud")
	local EC_HUD_POS_X = CreateConVar("easychat_hud_pos_x", "0", FCVAR_ARCHIVE, "Changes the position of the chat hud on the x axis")
	local EC_HUD_POS_Y = CreateConVar("easychat_hud_pos_y", "0", FCVAR_ARCHIVE, "Changes the position of the chat hud on the y axis")
	local EC_HUD_WIDTH = CreateConVar("easychat_hud_width", "0", FCVAR_ARCHIVE, "Changes the width of the chat hud")
	local EC_HUD_FADELEN = CreateConVar("easychat_hud_fadelen", "1", FCVAR_ARCHIVE, "Changes the amount of time it takes for the hud to fade")

	-- translation
	local EC_TRANSLATE_INC_MSG = CreateConVar("easychat_translate_inc_msg", "0", FCVAR_ARCHIVE, "Translates incoming chat messages")
	local EC_TRANSLATE_INC_SRC_LANG = CreateConVar("easychat_translate_inc_source_lang", "auto", FCVAR_ARCHIVE, "Language used in incoming chat messages")
	local EC_TRANSLATE_INC_TARGET_LANG = CreateConVar("easychat_translate_inc_target_lang", "en", FCVAR_ARCHIVE, "Language to translate incoming chat messages to")
	local EC_TRANSLATE_OUT_MSG = CreateConVar("easychat_translate_out_msg", "0", FCVAR_ARCHIVE, "Translates your chat messages")
	local EC_TRANSLATE_OUT_SRC_LANG = CreateConVar("easychat_translate_out_source_lang", "auto", FCVAR_ARCHIVE, "Language used in your chat messages")
	local EC_TRANSLATE_OUT_TARGET_LANG = CreateConVar("easychat_translate_out_target_lang", "en", FCVAR_ARCHIVE, "Language to translate your chat messages to")
	local EC_TRANSLATE_API_KEY = CreateConVar("easychat_translate_api_key", "", FCVAR_ARCHIVE, "Yandex provided API key")

	EasyChat.UseDermaSkin = EC_DERMASKIN:GetBool()

	cvars.AddChangeCallback(EC_ENABLE:GetName(), function()
		if EC_ENABLE:GetBool() then
			EasyChat.Init()
		else
			EasyChat.Destroy()
			net.Start(NET_SET_TYPING) -- this is useful if a user disable easychat with console mode
			net.WriteBool(true)
			net.SendToServer()
		end
	end)

	cvars.AddChangeCallback(EC_NO_MODULES:GetName(), function() EasyChat.Reload() end)
	cvars.AddChangeCallback(EC_HISTORY:GetName(), function() EasyChat.Reload() end)

	cvars.AddChangeCallback(EC_DERMASKIN:GetName(), function()
		EasyChat.UseDermaSkin = EC_DERMASKIN:GetBool()
		EasyChat.Reload()
	end)

	cvars.AddChangeCallback(EC_LEGACY_ENTRY:GetName(), function() EasyChat.Reload() end)
	cvars.AddChangeCallback(EC_LEGACY_TEXT:GetName(), function() EasyChat.Reload() end)

	EasyChat.FontName = EC_FONT:GetString()
	EasyChat.FontSize = EC_FONT_SIZE:GetInt()

	local function update_chatbox_font(font_name, size)
		EasyChat.FontName = font_name
		EasyChat.FontSize = size
		surface.CreateFont("EasyChatFont",{
			font = font_name,
			extended = true,
			size = size,
			weight = 530,
			shadow = false,
			additive = false
		})

		if EasyChat.GUI and IsValid(EasyChat.GUI.RichText) then
			EasyChat.GUI.RichText:SetFontInternal("EasyChatFont")
		end
	end

	update_chatbox_font(EasyChat.FontName, EasyChat.FontSize)

	cvars.AddChangeCallback(EC_FONT:GetName(), function(_, _, new_font_name)
		update_chatbox_font(new_font_name, EasyChat.FontSize)
	end)

	cvars.AddChangeCallback(EC_FONT_SIZE:GetName(), function(_, _, new_font_size)
		update_chatbox_font(EasyChat.FontName, tonumber(new_font_size))
	end)

	local function to_color(tbl)
		tbl = tbl or {}
		return Color(tbl.r or 0, tbl.g or 0, tbl.b or 0, tbl.a or 0)
	end

	EasyChat.DefaultColors = {
		outlay = Color(0, 0, 0, 240),
		outlayoutline = Color(0, 0, 0, 0),
		tab = Color(0, 0, 0, 220),
		taboutline = Color(0, 0, 0, 0),
	}

	local function load_chatbox_colors()
		local JSON_COLS = file.Read("easychat/colors.txt", "DATA")
		if JSON_COLS then
			local colors = util.JSONToTable(JSON_COLS)
			EasyChat.OutlayColor = to_color(colors.outlay)
			EasyChat.OutlayOutlineColor = to_color(colors.outlayoutline)
			EasyChat.TabColor = to_color(colors.tab)
			EasyChat.TabOutlineColor = to_color(colors.taboutline)
		else
			EasyChat.OutlayColor = EasyChat.DefaultColors.outlay
			EasyChat.OutlayOutlineColor = EasyChat.DefaultColors.outlayoutline
			EasyChat.TabColor = EasyChat.DefaultColors.tab
			EasyChat.TabOutlineColor = EasyChat.DefaultColors.taboutline
		end

		EasyChat.TextColor = Color(255, 255, 255, 255)
	end

	load_chatbox_colors()

	local default_chat_mode = {
		Name = "Say",
		Callback = function(text) EasyChat.SendGlobalMessage(text, false, false) end,
	}

	EasyChat.Mode = 0
	EasyChat.Modes = { [0] = default_chat_mode }
	EasyChat.Expressions = include("easychat/client/expressions.lua")
	EasyChat.Transliterator = include("easychat/client/unicode_transliterator.lua")
	EasyChat.Translator = include("easychat/client/translator.lua")
	EasyChat.ChatHUD = include("easychat/client/chathud.lua")
	EasyChat.MacroProcessor = include("easychat/client/macro_processor.lua")
	EasyChat.ModeCount = 0

	include("easychat/client/blur_panel.lua")
	include("easychat/client/settings.lua")
	include("easychat/client/markup.lua")

	local ec_tabs = {}
	local ec_convars = {}
	local uploading = false
	local queued_upload = nil

	-- after easychat var declarations [necessary]
	include("easychat/client/vgui/chatbox_panel.lua")
	include("easychat/client/vgui/chat_tab.lua")
	include("easychat/client/vgui/settings_menu.lua")
	include("easychat/client/vgui/chathud_font_editor_panel.lua")

	function EasyChat.Warn(msg)
		chat.AddText(color_red, "[WARN] " .. msg)
	end

	-- TODO: Figure out how to check keyboard IME
	function EasyChat.CanUseCEFFeatures()
		if not system.IsWindows() then return false end -- cef is awfully broken on linux / mac
		if BRANCH == "x86-64" or BRANCH == "chromium" then return true end -- chromium also exists in x86 and on the chromium branch
		return jit.arch == "x64" -- when x64 and chromium are finally pushed to stable
	end

	function EasyChat.RegisterConvar(convar, desc)
		table.insert(ec_convars, {
			Convar = convar,
			Description = desc
		})
	end

	function EasyChat.GetRegisteredConvars()
		return ec_convars
	end

	function EasyChat.AddMode(name, callback)
		table.insert(EasyChat.Modes, { Name = name, Callback = callback })
		EasyChat.ModeCount = #EasyChat.Modes
	end

	function EasyChat.GetCurrentMode()
		local mode = EasyChat.Mode or 0
		return EasyChat.Modes[mode]
	end

	function EasyChat.IsOpened()
		return EasyChat.GUI and IsValid(EasyChat.GUI.ChatBox) and EasyChat.GUI.ChatBox:IsVisible()
	end

	function EasyChat.GetDefaultBounds()
		local coef_w, coef_h = (ScrW() / 2560), (ScrH() / 1440)
		return 50 * coef_w, ScrH() - (320 + (coef_h * 300)), 550, 320
	end

	function EasyChat.IsOnRightSide()
		if not IsValid(EasyChat.GUI.ChatBox) then return false end

		local x, _, w, _ = EasyChat.GUI.ChatBox:GetBounds()
		return x + (w / 2) > (ScrW() / 2)
	end

	local function get_secondary_chat_mode()
		local secondary_mode_name = EC_SECONDARY:GetString():lower()
		local handled = safe_hook_run("ECSecondaryOpen", secondary_mode_name)
		if handled ~= true then
			for i = 0, EasyChat.ModeCount do
				local mode = EasyChat.Modes[i]
				if mode.Name:lower() == secondary_mode_name then
					return i
				end
			end
		end

		return 0
	end

	local function open_chatbox(is_secondary, requested_mode)
		if not EC_ENABLE:GetBool() then return false end
		if EasyChat.IsOpened() then return true end

		local ok = safe_hook_run("ECShouldOpen", is_secondary, requested_mode)
		if ok == false then return false end

		is_secondary = is_secondary ~= nil and is_secondary or false
		ok = safe_hook_run("StartChat", is_secondary)
		if ok == true then return false end

		if EC_GLOBAL_ON_OPEN:GetBool() then
			EasyChat.OpenTab("Global")
		end

		-- make sure to get rid of the possible completion
		EasyChat.GUI.TextEntry.TabCompletion = nil
		EasyChat.GUI.TextEntry:SetCompletionText(nil)
		timer.Destroy("ECCompletionPeek")

		EasyChat.GUI.TextEntry:SetText("")

		if is_secondary then
			EasyChat.Mode = get_secondary_chat_mode()
		else
			requested_mode = requested_mode or -1
			if requested_mode ~= -1 then
				EasyChat.Mode = requested_mode
			else
				if EC_ALWAYS_LOCAL:GetBool() then
					EasyChat.Mode = 2
				else
					EasyChat.Mode = 0
				end
			end
		end

		EasyChat.GUI.ChatBox:Show()
		EasyChat.GUI.ChatBox:MakePopup()

		local active_tab = EasyChat.GetActiveTab()
		if EC_GLOBAL_ON_OPEN:GetBool() and active_tab.Name == "Global" then
			EasyChat.GUI.TextEntry:RequestFocus()
		else
			local cur_tab = active_tab.Tab
			if IsValid(cur_tab.FocusOn) then
				cur_tab.FocusOn:RequestFocus()
			end
		end

		timer.Simple(0, function()
			EasyChat.GUI.RichText:GotoTextEnd()
		end)

		safe_hook_run("ECOpened", LocalPlayer())

		net.Start(NET_SET_TYPING)
		net.WriteBool(true)
		net.SendToServer()

		return true
	end
	EasyChat.Open = open_chatbox

	local function save_chatbox_tabs_data()
		local tabs = EasyChat.GUI.ChatBox.Scroller.Panels
		local tabs_data = {}
		for i, tab in pairs(tabs) do
			tabs_data[i] = { Name = tab.Name, Hidden = not tab:IsVisible() }
		end

		file.Write("easychat/tabs.txt", util.TableToJSON(tabs_data, true))
	end

	local function save_chatbox_bounds()
		local x, y, w, h = EasyChat.GUI.ChatBox:GetBounds()
		file.Write("easychat/possize.txt", util.TableToJSON({
			x = x, y = y, w = w, h = h
		}, true))
	end

	local function save_chatbox_data()
		if not file.Exists("easychat", "DATA") then
			file.CreateDir("easychat")
		end

		save_chatbox_tabs_data()
		save_chatbox_bounds()
	end

	local function load_chatbox_bounds()
		local x, y, w, h = EasyChat.GetDefaultBounds()
		local json = file.Read("easychat/possize.txt", "DATA")
		if not json then return x, y, w, h end

		local bounds = util.JSONToTable(json)
		if bounds then
			if bounds.x >= ScrW() then bounds.x = x end
			if bounds.y >= ScrH() then bounds.y = y end
			if bounds.w >= ScrW() then bounds.w = w end
			if bounds.h >= ScrH() then bounds.h = h end

			return bounds.x, bounds.y, bounds.w, bounds.h
		else
			return x, y, w, h
		end
	end

	local function load_chatbox_tabs_data()
		local json = file.Read("easychat/tabs.txt", "DATA")
		if not json then return end

		return util.JSONToTable(json)
	end

	local function close_chatbox(no_user_data_save)
		if not EasyChat.IsOpened() then return end

		EasyChat.GUI.ChatBox:SetMouseInputEnabled(false)
		EasyChat.GUI.ChatBox:SetKeyboardInputEnabled(false)
		EasyChat.GUI.TextEntry:SetText("")
		EasyChat.GUI.TextEntry.HistoryPos = 0 -- reset history also

		gui.EnableScreenClicker(false)
		hook.Run("ChatTextChanged", "")
		hook.Run("FinishChat")

		if not no_user_data_save then
			save_chatbox_data()
		end

		EasyChat.GUI.ChatBox:Hide()

		-- when easychat first initializes this doesnt exists
		if IsValid(EasyChat.Settings) then
			EasyChat.Settings:SetVisible(false)
		end

		safe_hook_run("ECClosed", LocalPlayer())

		net.Start(NET_SET_TYPING)
		net.WriteBool(false)
		net.SendToServer()
	end
	EasyChat.Close = close_chatbox

	function EasyChat.IsURL(str)
		local patterns = {
			"https?://[^%s%\"%>%<]+",
			"ftp://[^%s%\"%>%<]+",
			"steam://[^%s%\"%>%<]+",
			"www%.[^%s%\"]+%.[^%s%\"]+",
			"STEAM_%d%:%d%:%d+"
		}

		for _, pattern in ipairs(patterns) do
			local start_pos, end_pos = str:find(pattern, 1, false)
			if start_pos then
				return start_pos, end_pos
			end
		end

		return false
	end

	function EasyChat.OpenURL(url)
		local has_protocol = url:find("^%w-://")
		if not has_protocol then
			url = ("http://%s"):format(url)
		end

		local ok = safe_hook_run("ECOpenURL", url)
		if ok == false then return end

		gui.OpenURL(url)
	end

	function EasyChat.CreateFrame()
		local frame = vgui.Create("DFrame")
		frame.btnMaxim:Hide()
		frame.btnMinim:Hide()
		frame.lblTitle:SetFont("EasyChatFont")

		if not EasyChat.UseDermaSkin then
			frame.lblTitle:SetTextColor(EasyChat.TextColor)

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

		return frame
	end

	function EasyChat.AskForInput(title, callback, can_be_empty)
		local frame = EasyChat.CreateFrame()
		frame:SetTitle(title)
		frame:SetDrawOnTop(true)
		frame:SetDraggable(false)
		frame:SetSize(200, 90)

		if EasyChat.GUI and IsValid(EasyChat.GUI.ChatBox) then
			local x, y, w, h = EasyChat.GUI.ChatBox:GetBounds()
			frame:SetPos(x + w / 2 - 100, y + h / 2 - 55)
		else
			frame:Center()
		end

		local text_entry = frame:Add("DTextEntry")
		text_entry:SetTall(25)
		text_entry:Dock(TOP)
		text_entry.OnEnter = function(self)
			if not can_be_empty and EasyChat.IsStringEmpty(self:GetText()) then return end

			callback(self:GetText())
			frame:Close()
		end
		frame.TextEntry = text_entry

		local btn = frame:Add("DButton")
		btn:SetText("Confirm")
		btn:SetTextColor(EasyChat.TextColor)
		btn:SetTall(25)
		btn:Dock(BOTTOM)
		btn.DoClick = function()
			if not can_be_empty and EasyChat.IsStringEmpty(text_entry:GetText()) then return end

			callback(text_entry:GetText())
			frame:Close()
		end
		frame.Button = btn

		if not EasyChat.UseDermaSkin then
			btn.Paint = function(self, w, h)
				surface.SetDrawColor(EasyChat.TabColor)
				surface.DrawRect(0, 0, w, h)

				if self:IsHovered() then
					surface.SetDrawColor(color_white)
					surface.DrawOutlinedRect(0, 0, w, h)
				end
			end
		end

		frame:MakePopup()
		text_entry:RequestFocus()

		hook.Add("GUIMousePressed", frame, function()
			frame:MakePopup()
			text_entry:RequestFocus()
			return true
		end)

		hook.Add("VGUIMousePressed", frame, function(self, pnl)
			if pnl == self then return end

			frame:MakePopup()
			text_entry:RequestFocus()
			return true
		end)

		return frame
	end

	local BASE64 = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
	function EasyChat.DecodeBase64(base64)
		if util.Base64Decode then
			return util.Base64Decode(base64)
		end

		base64 = base64:gsub("[^" .. BASE64 .. "=]", "")
		return (base64:gsub(".", function(x)
			if (x == "=") then return "" end
			local r, f = "", (BASE64:find(x) - 1)
			for i = 6, 1, -1 do
				r = r .. (f % 2^i - f % 2^(i - 1) > 0 and "1" or "0")
			end

			return r
		end):gsub("%d%d%d?%d?%d?%d?%d?%d?", function(x)
			if (#x ~= 8) then return "" end
			local c = 0
			for i=1, 8 do
				c = c + (x:sub(i, i) == "1" and 2^(8 - i) or 0)
			end

			return c:char()
		end))
	end

	local function on_imgur_failure(err)
		EasyChat.Print(true, ("imgur upload failed: %s"):format(tostring(err)))
	end

	local function on_imgur_success(code, body, headers)
		if code ~= 200 then
			on_imgur_failure(("error code: %d"):format(code))
			return
		end

		local decoded_body = util.JSONToTable(body)
		if not decoded_body then
			on_imgur_failure("could not json decode body")
			return
		end

		if not decoded_body.success then
			on_imgur_failure(("%s: %s"):format(
				decoded_body.status or "unknown status?",
				decoded_body.data and decoded_body.data.error or "unknown error"
			))
			return
		end

		local url = decoded_body.data and decoded_body.data.link
		if not url then
			on_imgur_failure("success but link wasn't found?")
			return
		end

		EasyChat.Print(("imgur uploaded: %s"):format(tostring(url)))
		return url
	end

	function EasyChat.UploadToImgur(img_base64, callback)
		local ply_nick, ply_steamid = LocalPlayer():Nick(), LocalPlayer():SteamID()
		local params = {
			image = img_base64,
			type = "base64",
			name = tostring(os.time()),
			title = ("%s - %s"):format(ply_nick, ply_steamid),
			description = ("%s (%s) on %s"):format(ply_nick, ply_steamid, os.date("%d/%m/%Y at %H:%M")),
		}

		local headers = {}
		headers["Authorization"] = "Client-ID 62f1e31985e240b"

		local http_data = {
			failed = function(...)
				on_imgur_failure(...)
				callback(nil)
			end,
			success = function(...)
				local url = on_imgur_success(...)
				callback(url)
			end,
			method = "post",
			url = "https://api.imgur.com/3/image.json",
			parameters = params,
			headers = headers,
		}

		HTTP(http_data)
		EasyChat.Print(("sent picture (%s) to imgur"):format(string.NiceSize(#img_base64)))
	end

	local emote_lookup_tables = {}
	function EasyChat.AddEmoteLookupTable(loookup_name, lookup_table)
		emote_lookup_tables[loookup_name] = lookup_table
	end

	function EasyChat.GetEmoteLookupTable(lookup_name)
		return emote_lookup_tables[lookup_name] or {}
	end

	function EasyChat.GetEmoteLookupTables()
		return emote_lookup_tables
	end

	local ec_addtext_handles = {}
	function EasyChat.SetAddTextTypeHandle(type, callback)
		ec_addtext_handles[type] = callback
	end

	function EasyChat.GetSetAddTextTypeHandle(type)
		return ec_addtext_handles[type]
	end

	local function should_use_server_settings(ply)
		local usergroup_prefix = EasyChat.Config.UserGroups[ply:GetUserGroup()]
		if EasyChat.Config.OverrideClientSettings and usergroup_prefix then return true end
		if not EasyChat.Config.OverrideClientSettings and EC_TEAMS:GetBool() and usergroup_prefix then return true end

		return false
	end

	function EasyChat.Init()
		load_chatbox_colors()

		-- reset for reload
		EasyChat.Mode = 0
		EasyChat.Modes = { [0] = default_chat_mode }
		EasyChat.Expressions = include("easychat/client/expressions.lua")
		EasyChat.Transliterator = include("easychat/client/unicode_transliterator.lua")
		EasyChat.Translator = include("easychat/client/translator.lua")
		EasyChat.ChatHUD = include("easychat/client/chathud.lua")
		EasyChat.MacroProcessor = include("easychat/client/macro_processor.lua")
		EasyChat.ModeCount = 0


		include("easychat/client/settings.lua")
		include("easychat/client/markup.lua")

		ec_convars = {}
		ec_addtext_handles = {}
		uploading = false
		queued_upload = nil

		function EasyChat.SendGlobalMessage(msg, is_team, is_local)
			msg = EasyChat.MacroProcessor:ProcessString(msg)

			local source_lang, target_lang =
				EC_TRANSLATE_OUT_SRC_LANG:GetString(),
				EC_TRANSLATE_OUT_TARGET_LANG:GetString()

			if EC_TRANSLATE_OUT_MSG:GetBool() and source_lang ~= target_lang then
				EasyChat.Translator:Translate(msg, source_lang, target_lang, function(success, _, translation)
					net.Start(NET_SEND_MSG)
					net.WriteString(success and translation or msg)
					net.WriteBool(is_team)
					net.WriteBool(is_local)
					net.SendToServer()
				end)
			else
				net.Start(NET_SEND_MSG)
				net.WriteString(msg)
				net.WriteBool(is_team)
				net.WriteBool(is_local)
				net.SendToServer()
			end
		end

		EasyChat.AddMode("Team", function(text)
			EasyChat.SendGlobalMessage(text, true, false)
		end)

		EasyChat.AddMode("Local", function(text)
			EasyChat.SendGlobalMessage(text, false, true)
		end)

		EasyChat.AddMode("Console", function(text)
			LocalPlayer():ConCommand(text)
		end)

		local function append_text(richtext, text)
			if richtext.HistoryName then
				richtext.Log = richtext.Log and richtext.Log .. text or text
			end

			richtext:AppendText(text)
		end

		local function append_text_url(richtext, text)
			local start_pos, end_pos = EasyChat.IsURL(text)
			if not start_pos then
				append_text(richtext, text)
			else
				local url = text:sub(start_pos, end_pos)
				append_text(richtext, text:sub(1, start_pos - 1))
				richtext:InsertClickableTextStart(url)
				append_text(richtext, url)
				richtext:InsertClickableTextEnd()

				if EC_LINKS_CLIPBOARD:GetBool() and richtext:IsVisible() then
					SetClipboardText(url)
				end

				-- recurse for possible other urls after this one
				append_text_url(richtext, text:sub(end_pos + 1))
			end
		end

		local function save_text(richtext)
			if not richtext.HistoryName then return end

			EasyChat.SaveToHistory(richtext.HistoryName, richtext.Log)
			richtext.Log = ""
		end

		local function chathud_append_text(text)
			if not EC_HUD_CUSTOM:GetBool() then return end
			EasyChat.ChatHUD:AppendText(text)
		end

		local function global_append_text(text)
			local data = {}

			chathud_append_text(text)
			append_text(EasyChat.GUI.RichText, text)

			if not ec_markup then
				table.insert(data, text)
				return data
			end

			local mk = ec_markup.Parse(text)
			for _, line in ipairs(mk.Lines) do
				for _, component in ipairs(line.Components) do
					if component.Color then
						table.insert(data, component.Color)
					elseif component.Type == "text" then
						table.insert(data, component.Content)
					end
				end
			end

			return data
		end

		local image_url_patterns = {
			"^https?://steamuserimages%-a%.akamaihd%.net/ugc/[0-9]+/[A-Z0-9]+/",
			"^https?://pbs%.twimg%.com/media/",
		}
		local image_url_exts = { "png", "jpg", "jpeg", "gif", "webp" }
		local function is_image_url(url)
			local simple_url = url:gsub("%?[^/]+", ""):lower() -- remove url args, lower for exts like JPG, PNG
			for _, url_ext in ipairs(image_url_exts) do
				local pattern = (".%s$"):format(url_ext)
				if simple_url:match(pattern) then return true end
			end

			for _, pattern in ipairs(image_url_patterns) do
				if url:match(pattern) then return true end
			end

			return false
		end

		local link_color = Color(68, 151, 206)
		local function global_append_text_url(text)
			local data = {}

			local start_pos, end_pos = EasyChat.IsURL(text)
			if not start_pos then
				table.Add(data, global_append_text(text))
			else
				local url = text:sub(start_pos, end_pos)
				table.Add(data, global_append_text(text:sub(1, start_pos - 1)))

				local previous_color = EasyChat.GUI.RichText:GetLastColorChange()
				EasyChat.GUI.RichText:InsertColorChange(link_color)

				if is_image_url(url) then
					EasyChat.GUI.RichText:InsertClickableTextStart(url)
					append_text(EasyChat.GUI.RichText, url)
					EasyChat.GUI.RichText:InsertClickableTextEnd()

					if EC_HUD_CUSTOM:GetBool() then
						EasyChat.ChatHUD:AppendImageURL(url)
					end

					if EC_IMAGES:GetBool() then
						EasyChat.GUI.RichText:AppendImageURL(url)
					end
				else
					EasyChat.GUI.RichText:InsertClickableTextStart(url)
					global_append_text(url)
					EasyChat.GUI.RichText:InsertClickableTextEnd()
				end

				-- hack that fixes broken URLs for the gmod default RichText panel unti we get a proper fix
				if EC_LEGACY_TEXT:GetBool() then
					EasyChat.GUI.RichText:InsertClickableTextStart(url)
					EasyChat.GUI.RichText:AppendText(" ")
					EasyChat.GUI.RichText:InsertClickableTextEnd()
					EasyChat.GUI.RichText:AppendText(" ")
				end

				EasyChat.GUI.RichText:InsertColorChange(previous_color)

				table.insert(data, link_color)
				table.insert(data, url)
				table.insert(data, previous_color)

				if EC_LINKS_CLIPBOARD:GetBool() and EasyChat.GUI.RichText:IsVisible() then
					SetClipboardText(url)
				end

				-- recurse for possible other urls after this one
				table.Add(data, global_append_text_url(text:sub(end_pos + 1)))
			end

			return data
		end

		local function is_color(tbl)
			if type(tbl) ~= "table" then return false end
			if isnumber(tbl.r) and isnumber(tbl.g) and isnumber(tbl.b) then
				return true
			end

			return false
		end

		local function extract_tags_data(str, is_nick)
			local data = {}

			if not ec_markup then
				table.insert(data, str)
			else
				-- use markup to get text and colors out of the string
				local mk = ec_markup.Parse(str, nil, is_nick)
				for _, line in ipairs(mk.Lines) do
					for _, component in ipairs(line.Components) do
						if component.Color then
							table.insert(data, component.Color)
						elseif component.Type == "text" then
							table.insert(data, component.Content)
						elseif component.Type == "stop" then
							table.insert(data, color_white)
						end
					end
				end
			end

			return data
		end

		local function global_append_nick(str)
			local data = {}

			local tags_data = extract_tags_data(str, true)
			for _, tag_data in ipairs(tags_data) do
				if is_color(tag_data) then
					EasyChat.GUI.RichText:InsertColorChange(tag_data.r, tag_data.g, tag_data.b, 255)
					table.insert(data, tag_data)
				elseif isstring(tag_data) then
					append_text(EasyChat.GUI.RichText, tag_data)
					table.insert(data, tag_data)
				end
			end

			EasyChat.GUI.RichText:InsertColorChange(255, 255, 255, 255)
			table.insert(data, color_white)

			if EC_HUD_CUSTOM:GetBool() then
				-- let the chathud do its own thing
				EasyChat.ChatHUD:AppendNick(str)
				EasyChat.ChatHUD:PushPartComponent("stop")
			end

			return data
		end

		local function global_insert_color_change(r, g, b, a)
			r, g, b, a = r or 255, g or 255, b or 255, isnumber(a) and a or 255

			if EasyChat.UseDermaSkin and r == 255 and g == 255 and b == 255 then
				local new_col = EasyChat.GUI.RichText:GetSkin().text_normal
				EasyChat.GUI.RichText:InsertColorChange(new_col.r, new_col.g, new_col.b, new_col.a)
			else
				EasyChat.GUI.RichText:InsertColorChange(r, g, b, a)
			end

			if EC_HUD_CUSTOM:GetBool() then
				EasyChat.ChatHUD:InsertColorChange(r, g, b)
			end

			return Color(r, g, b, a)
		end

		EasyChat.SetAddTextTypeHandle("table", function(col)
			if is_color(col) then
				return global_insert_color_change(col.r, col.g, col.b, col.a)
			end

			return color_white
		end)

		EasyChat.SetAddTextTypeHandle("string", function(str) return global_append_text_url(str) end)

		local function string_hash(text)
			local counter = 1
			local len = #text
			for i = 1, len, 3 do
				counter =
					math.fmod(counter * 8161, 4294967279) + -- 2^32 - 17: Prime!
					(text:byte(i) * 16776193) +
					((text:byte(i + 1) or (len - i + 256)) * 8372226) +
					((text:byte(i + 2) or (len - i + 256)) * 3932164)
			end

			return math.fmod(counter, 4294967291) -- 2^32 - 5: Prime (and different from the prime in the loop)
		end

		function EasyChat.GetProperNick(ply)
			if not IsValid(ply) then return "???" end

			local ply_nick = ply:Nick()
			if not ec_markup then return ply_nick end
			local mk = ec_markup.CachePlayer("EasyChat", ply, function()
				return ec_markup.Parse(ply_nick, nil, true)
			end)

			return mk and mk:GetText() or ply_nick
		end

		function EasyChat.PastelizeNick(nick)
			local hue = string_hash(nick)
			local saturation, value = hue % 3 == 0, hue % 127 == 0

			-- HSVToColor doesnt return a color with the color metatable...
			local bad_col = HSVToColor(hue % 180 * 2, saturation and 0.3 or 0.6, value and 0.6 or 1)
			return Color(bad_col.r, bad_col.g, bad_col.b, bad_col.a)
		end

		EasyChat.SetAddTextTypeHandle("Player", function(ply)
			local data = {}

			-- dont forget to reset color to white by default
			EasyChat.GUI.RichText:InsertColorChange(255, 255, 255, 255)
			table.insert(data, color_white)

			if not IsValid(ply) then
				global_insert_color_change(110, 247, 177)
				global_append_text("???")

				table.insert(data, Color(110, 247, 177))
				table.insert(data, "???")

				return data
			end

			if should_use_server_settings(ply) then
				local usergroup_prefix = EasyChat.Config.UserGroups[ply:GetUserGroup()]
				local tags_data = extract_tags_data(usergroup_prefix.Tag)
				for _, tag_data in ipairs(tags_data) do
					if is_color(tag_data) then
						EasyChat.GUI.RichText:InsertColorChange(tag_data.r, tag_data.g, tag_data.b, 255)
						table.insert(data, tag_data)
					elseif isstring(tag_data) then
						append_text(EasyChat.GUI.RichText, tag_data)
						table.insert(data, tag_data)
					end
				end

				append_text(EasyChat.GUI.RichText, " ")
				table.insert(data, " ")

				if EC_HUD_CUSTOM:GetBool() then
					EasyChat.ChatHUD:PushPartComponent("stop")

					if #usergroup_prefix.Tag > 0 then
						EasyChat.ChatHUD:AppendText(usergroup_prefix.Tag .. " ")
						EasyChat.ChatHUD:PushPartComponent("stop")
					end

					if #usergroup_prefix.EmoteName > 0 then
						local tag = ("<emote=%s"):format(usergroup_prefix.EmoteName)

						if usergroup_prefix.EmoteSize ~= -1 then
							tag = ("%s,%s"):format(tag, usergroup_prefix.EmoteSize)
						end

						if #usergroup_prefix.EmoteProvider > 0 then
							-- add a comma here for proper markup parsing
							if usergroup_prefix.EmoteSize == -1 then
								tag = ("%s,"):format(tag)
							end

							tag = ("%s,%s"):format(tag, usergroup_prefix.EmoteProvider)
						end

						tag = ("%s> "):format(tag)
						EasyChat.ChatHUD:AppendText(tag)
					end
				end
			end

			local ply_title = EasyChat.Config.Titles[ply:SteamID()]
			if ply_title then
				local tags_data = extract_tags_data(ply_title)
				for _, tag_data in ipairs(tags_data) do
					if is_color(tag_data) then
						EasyChat.GUI.RichText:InsertColorChange(tag_data.r, tag_data.g, tag_data.b, 255)
						table.insert(data, tag_data)
					elseif isstring(tag_data) then
						append_text(EasyChat.GUI.RichText, tag_data)
						table.insert(data, tag_data)
					end
				end

				append_text(EasyChat.GUI.RichText, " ")
				table.insert(data, " ")

				if EC_HUD_CUSTOM:GetBool() then
					EasyChat.ChatHUD:PushPartComponent("stop")
					EasyChat.ChatHUD:AppendText(ply_title .. " ")
					EasyChat.ChatHUD:PushPartComponent("stop")
				end
			end

			local team_color = EC_PLAYER_COLOR:GetBool() and team.GetColor(ply:Team()) or color_white
			global_insert_color_change(team_color.r, team_color.g, team_color.b, 255)
			table.insert(data, team_color)

			local stripped_ply_nick = EasyChat.GetProperNick(ply)
			if EC_PLAYER_PASTEL:GetBool() then
				local pastel_color = EasyChat.PastelizeNick(stripped_ply_nick)
				global_insert_color_change(pastel_color.r, pastel_color.g, pastel_color.b, 255)
				table.insert(data, pastel_color)
			end

			EasyChat.GUI.RichText:InsertClickableTextStart(("ECPlayerActions: %s|%s")
				:format(ply:SteamID(), stripped_ply_nick))

			local lp = LocalPlayer()
			if IsValid(lp) and lp == ply and EC_USE_ME:GetBool() then
				global_append_text("me")
				table.insert(data, "me")
			else
				local nick = EasyChat.Config.AllowTagsInNames and ply:Nick() or stripped_ply_nick
				local nick_data = global_append_nick(nick)
				table.Add(data, nick_data)
			end

			EasyChat.GUI.RichText:InsertClickableTextEnd()

			return data
		end)

		local history_file_handles = {}
		local HISTORY_DIRECTORY = "easychat/history"
		function EasyChat.SaveToHistory(name, content)
			if not name or not content then return end
			if EasyChat.IsStringEmpty(content) then return end

			if not file.Exists(HISTORY_DIRECTORY, "DATA") then
				file.CreateDir(HISTORY_DIRECTORY)
			end

			local file_name = ("%s/%s_history.txt"):format(HISTORY_DIRECTORY, name:lower())
			local file_handles = history_file_handles[name]
			if not file_handles then
				file_handles = {
					input = file.Open(file_name, "w", "DATA"),
					output = file.Open(file_name, "r", "DATA"),
				}
				history_file_handles[name] = file_handles
			end

			-- another process is using the file, discard
			if not file_handles.input or not file_handles.output then return end

			file_handles.input:Seek(0)
			file_handles.output:Seek(0)

			local pre_content = file_handles.output:Size() >= 10000
				and "...\n" .. (file_handles.output:Read(10000 - #content) or "")
				or file_handles.output:Read(10000)

			file_handles.input:Write(pre_content and pre_content .. content or content)
			file_handles.input:Flush()
		end

		function EasyChat.ReadFromHistory(name)
			if not name then return "" end

			local file_name = ("%s/%s_history.txt"):format(HISTORY_DIRECTORY, name:lower())
			if not file.Exists(file_name, "DATA") then return "" end

			local history_file = file.Open(file_name, "r", "DATA")

			-- another process is using the file, return an empty string
			if not history_file then return "" end

			local contents = history_file:Read(10000)
			history_file:Close()

			return contents or ""
		end

		function EasyChat.AddText(richtext, ...)
			append_text(richtext, "\n")
			if not EasyChat.UseDermaSkin then
				richtext:InsertColorChange(255, 255, 255, 255)
			end

			if EC_TIMESTAMPS:GetBool() then
				if EC_TIMESTAMPS_12:GetBool() then
					append_text(richtext, os.date("%I:%M %p") .. " - ")
				else
					append_text(richtext, os.date("%H:%M") .. " - ")
				end
			end

			local args = {...}
			for _, arg in ipairs(args) do
				if isstring(arg) then
					append_text_url(richtext, arg)
				elseif type(arg) == "Player" then
					if not IsValid(arg) then
						richtext:InsertColorChange(110, 247, 177)
						append_text(richtext, "???")
					else
						local team_color = EC_PLAYER_COLOR:GetBool() and team.GetColor(arg:Team()) or color_white
						richtext:InsertColorChange(team_color.r, team_color.g, team_color.b, 255)

						local nick = EasyChat.GetProperNick(arg)
						if EC_PLAYER_PASTEL:GetBool() then
							local pastel_color = EasyChat.PastelizeNick(nick)
							richtext:InsertColorChange(pastel_color.r, pastel_color.g, pastel_color.b, 255)
						end

						local lp = LocalPlayer()
						if IsValid(lp) and lp == arg and EC_USE_ME:GetBool() then
							append_text(richtext, "me")
						else
							append_text(richtext, nick)
						end
					end
				elseif is_color(arg) then
					richtext:InsertColorChange(arg.r, arg.g, arg.b, isnumber(arg.a) and arg.a or 255)
				else
					append_text(richtext, tostring(arg))
				end
			end

			save_text(richtext)
		end

		function EasyChat.GlobalAddText(...)
			-- somehow too early?
			if not EasyChat.GUI or not EasyChat.ChatHUD then
				EasyChat.Print(true, "attempting to AddText without a GUI??!!")
				return { ... }
			end

			local data = {}

			if EC_HUD_CUSTOM:GetBool() then
				EasyChat.ChatHUD:NewLine()
			end

			append_text(EasyChat.GUI.RichText, "\n")
			global_insert_color_change(255, 255, 255, 255)
			table.insert(data, color_white)

			if EC_ENABLE:GetBool() then
				local timestamp = (EC_TIMESTAMPS_12:GetBool() and os.date("%I:%M %p") or os.date("%H:%M")) .. " - "
				if EC_TIMESTAMPS:GetBool() then
					append_text(EasyChat.GUI.RichText, timestamp)
				end

				if EC_HUD_TIMESTAMPS:GetBool() then
					chathud_append_text(timestamp)
					table.insert(data, timestamp)
				end
			end

			local args = {...}
			for _, arg in ipairs(args) do
				local callback = ec_addtext_handles[type(arg)]
				if callback then
					local succ, ret = xpcall(callback, function(err)
						ErrorNoHalt(debug.traceback(err))
					end, arg)
					if succ and ret then
						if is_color(ret) or isstring(ret) then
							table.insert(data, ret)
						elseif istable(ret) then
							table.Add(data, ret)
						end
					end
				else
					local str = tostring(arg)
					table.Add(data, global_append_text(str))
				end
			end

			if EC_HUD_CUSTOM:GetBool() then
				EasyChat.ChatHUD:PushPartComponent("stop")
				EasyChat.ChatHUD:InvalidateLayout()
			end

			save_text(EasyChat.GUI.RichText)

			if EC_TICK_SOUND:GetBool() then
				chat.PlaySound()
			end

			return data
		end

		do
			chat.old_AddText = chat.old_AddText or chat.AddText
			chat.old_GetChatBoxPos = chat.old_GetChatBoxPos or chat.GetChatBoxPos
			chat.old_GetChatBoxSize = chat.old_GetChatBoxSize or chat.GetChatBoxSize
			chat.old_Open = chat.old_Open or chat.Open
			chat.old_Close = chat.old_Close or chat.Close

			chat.AddText = function(...)
				local processed_args = EasyChat.GlobalAddText(...)
				chat.old_AddText(unpack(processed_args))
			end

			function chat.GetChatBoxPos()
				if EasyChat.GUI and IsValid(EasyChat.GUI.ChatBox) then
					local x, y, _, _ = EasyChat.GUI.ChatBox:GetBounds()
					return x, y
				else
					return chat.old_GetChatBoxPos()
				end
			end

			function chat.GetChatBoxSize()
				if EasyChat.GUI and IsValid(EasyChat.GUI.ChatBox) then
					local _, _, w, h = EasyChat.GUI.ChatBox:GetBounds()
					return w, h
				else
					return chat.old_GetChatBoxSize()
				end
			end

			function chat.Open(input)
				local is_team = input ~= 1
				open_chatbox(is_team)
			end

			-- lets not have third-party addons decide wether we should save
			-- user data or not
			chat.Close = function() close_chatbox() end
		end

		do
			local chatbox_frame = vgui.Create("ECChatBox")
			local cx, cy, cw, ch = load_chatbox_bounds()
			chatbox_frame:SetSize(cw, ch)
			chatbox_frame:SetPos(cx, cy)
			chatbox_frame.BtnClose.DoClick = close_chatbox

			function chatbox_frame.Tabs:OnActiveTabChanged(old_tab, new_tab)
				-- we don't want to type in another tab
				local focused_panel = old_tab.FocusOn
				if IsValid(focused_panel) then
					focused_panel:KillFocus()
				end

				local panel_to_focus = new_tab.FocusOn
				if IsValid(panel_to_focus) then
					panel_to_focus:RequestFocus()
				end

				safe_hook_run("ECTabChanged", old_tab.Name, new_tab.Name)
			end

			function EasyChat.RemoveTab(name)
				local old_tab_data = ec_tabs[name]
				if old_tab_data then
					local old_panel, old_tab = old_tab_data.Panel, old_tab_data.Tab
					if IsValid(old_panel) then old_panel:Remove() end
					if IsValid(old_tab) then old_tab:Remove() end

					-- we need this as the panel doesnt update itself otherwise
					for i, item in pairs(EasyChat.GUI.TabControl.Items or {}) do
						if not IsValid(item.Tab) or not IsValid(item.Panel) then
							table.remove(EasyChat.GUI.TabControl.Items, i)
						end
					end

					ec_tabs[name] = nil
				end
			end

			function EasyChat.AddTab(name, panel, icon)
				if EasyChat.Config.Tabs[name] == false then
					panel:Hide()
					return
				end

				-- in case we get overriden
				EasyChat.RemoveTab(name)

				local tab = chatbox_frame.Tabs:AddSheet(name, panel, icon)
				tab.Tab.Name = name
				tab.Tab:SetFont("EasyChatFont")
				tab.Tab:SetTextColor(color_white)
				tab.Tab.GetPanel = function() return panel end

				ec_tabs[name] = tab
				panel:Dock(FILL)

				if not EasyChat.UseDermaSkin then
					function panel:Paint(w, h)
						surface.SetDrawColor(EasyChat.TabColor)
						surface.DrawRect(0, 0, w, h)
						surface.SetDrawColor(EasyChat.TabOutlineColor)
						surface.DrawOutlinedRect(0, 0, w, h)
					end

					function tab.Tab:Paint(w, h)
						if self == chatbox_frame.Tabs:GetActiveTab() then
							self.Flashed = false
							surface.SetDrawColor(EasyChat.TabColor)
						else
							if self.Flashed then
								local sin = math.sin(CurTime() * 3)
								surface.SetDrawColor(
									math.abs(sin * 244),
									math.abs(sin * 3 * 167),
									math.abs(sin * 3 * 66),
									255
								)
							else
								surface.SetDrawColor(NO_COLOR)
							end
						end

						surface.DrawRect(0, 0, w, h)
						if self == chatbox_frame.Tabs:GetActiveTab() then
							surface.SetDrawColor(EasyChat.TextColor)
							surface.DisableClipping(true)
							surface.DrawRect(0, -2, w, 2)
							surface.DisableClipping(false)

							surface.SetDrawColor(EasyChat.TabOutlineColor)
							surface.DrawLine(0, 0, 0, h)
							surface.DrawLine(w - 1, 0, w - 1, h)
						elseif self:IsHovered() then
							surface.DisableClipping(true)
							surface.SetDrawColor(EasyChat.TextColor)
							surface.DrawOutlinedRect(0, -2, w, h + 4)
							surface.DisableClipping(false)
						end
					end
				end
			end

			function EasyChat.OpenTab(name)
				chatbox_frame.Tabs:SwitchToName(name)
			end

			function EasyChat.GetTab(name)
				if ec_tabs[name] then
					return ec_tabs[name]
				end

				return nil
			end

			function EasyChat.GetTabs()
				return ec_tabs
			end

			function EasyChat.GetActiveTab()
				local active = chatbox_frame.Tabs:GetActiveTab()
				return ec_tabs[active.Name]
			end

			function EasyChat.SetFocusForOn(name, panel)
				if ec_tabs[name] then
					ec_tabs[name].Tab.FocusOn = panel
				end
			end

			function EasyChat.FlashTab(name)
				if ec_tabs[name] then
					ec_tabs[name].Tab.Flashed = true
				end
			end

			local global_tab = vgui.Create("ECChatTab")
			EasyChat.AddTab("Global", global_tab, "icon16/comments.png")
			EasyChat.SetFocusForOn("Global", global_tab.TextEntry)

			if not EasyChat.UseDermaSkin then
				global_tab.RichText:InsertColorChange(255, 255, 255, 255)
			end

			global_tab.RichText.HistoryName = "global"
			if EC_HISTORY:GetBool() then
				local history = EasyChat.ReadFromHistory("global")
				if not EasyChat.IsStringEmpty(history) then
					if EasyChat.UseDermaSkin then
						local new_col = global_tab.RichText:GetSkin().text_normal
						global_tab.RichText:InsertColorChange(new_col.r, new_col.g, new_col.b, new_col.a)
					end

					global_tab.RichText:AppendText(history)
					local historynotice = "\n^^^^^ Last Session History ^^^^^\n\n"
					global_tab.RichText:AppendText(historynotice)
				end
			end

			-- Only the neccesary elements --
			EasyChat.GUI = {
				ChatBox = chatbox_frame,
				TextEntry = global_tab.TextEntry,
				RichText = global_tab.RichText,
				TabControl = chatbox_frame.Tabs
			}

			close_chatbox(true)
		end

		local ctrl_shortcuts = {}
		local alt_shortcuts = {}

		local invalid_shortcut_keys = {
			[KEY_ENTER] = true, [KEY_PAD_ENTER] = true,
			[KEY_ESCAPE] = true, [KEY_TAB] = true
		}
		local function is_valid_shortcut_key(key)
			return not invalid_shortcut_keys[key]
		end

		function EasyChat.RegisterCTRLShortcut(key, callback)
			if is_valid_shortcut_key(key) then
				ctrl_shortcuts[key] = callback
			end
		end

		function EasyChat.RegisterALTShortcut(key, callback)
			if is_valid_shortcut_key(key) then
				alt_shortcuts[key] = callback
			end
		end

		--[[
			/!\ Not used for the main chat text entry
			Its because the chat text entry is a DHTML
			panel that does not fire OnKeyCode* callbacks
		]]--
		function EasyChat.UseRegisteredShortcuts(text_entry, key)
			local pos = text_entry:GetCaretPos()
			local first = text_entry:GetText():sub(1, pos + 1)
			local last = text_entry:GetText():sub(pos + 2, #text_entry:GetText())

			if (input.IsKeyDown(KEY_LCONTROL) or input.IsKeyDown(KEY_RCONTROL)) and ctrl_shortcuts[key] then
				local retrieved, new_caret_pos = ctrl_shortcuts[key](text_entry, text_entry:GetText(), pos, first, last)
				if retrieved then
					text_entry:SetText(retrieved)
					if isnumber(new_caret_pos) then
						text_entry:SetCaretPos(new_caret_pos)
					end
				end
			elseif (input.IsKeyDown(KEY_LALT) or input.IsKeyDown(KEY_RALT)) and alt_shortcuts[key] then
				local retrieved, new_caret_pos = alt_shortcuts[key](text_entry, text_entry:GetText(), pos, first, last)
				if retrieved then
					text_entry:SetText(retrieved)
					if isnumber(new_caret_pos) then
						text_entry:SetCaretPos(new_caret_pos)
					end
				end
			end
		end

		--[[
			/!\ Not used for the main chat text entry
			Its because the chat text entry is a DHTML
			panel that does not fire OnKeyCode* callbacks
		]]--
		function EasyChat.SetupHistory(text_entry, key)
			if key == KEY_ENTER or key == KEY_PAD_ENTER then
				text_entry:AddHistory(text_entry:GetText())
				text_entry.HistoryPos = 0
			end

			if key == KEY_ESCAPE then
				text_entry.HistoryPos = 0
			end

			if not text_entry.HistoryPos then return end

			if key == KEY_UP then
				text_entry.HistoryPos = text_entry.HistoryPos - 1
				text_entry:UpdateFromHistory()
			elseif key == KEY_DOWN then
				text_entry.HistoryPos = text_entry.HistoryPos + 1
				text_entry:UpdateFromHistory()
			end
		end

		local function nick_completion(text)
			if EC_GM_COMPLETE:GetBool() then return end
			if not EC_NICK_COMPLETE:GetBool() then return end

			local words = text:Split(" ")
			local last_word = words[#words]

			local prioritize_nicks = EC_NICK_PRIORITIZE:GetBool()
			local max_perc = 0
			local res
			for _, ply in ipairs(player.GetAll()) do
				local nick = EasyChat.GetProperNick(ply)
				local match = nick:lower():match(last_word:lower():PatternSafe())
				if match and not text:EndsWith(nick) then
					local perc = #match / #nick
					local consider_match = (perc > 0.5 or #match >= 3)
					if prioritize_nicks then consider_match = true end
					if perc == 1 then consider_match = false end -- we dont want to complete things that already are
					if consider_match and perc > max_perc then
						max_perc = perc
						res = nick
					end
				end
			end

			if res then
				words[#words] = res
				return table.concat(words, " ")
			end
		end

		local completion_blacklist = {
			chatsounds_autocomplete = true
		}
		local function get_completion(text, use_blacklist)
			if EC_NICK_PRIORITIZE:GetBool() then
				local ply_nick = nick_completion(text)
				if ply_nick then return ply_nick end
			end

			if not use_blacklist then
				local gm = EC_GM_COMPLETE:GetBool() and gmod.GetGamemode() or nil
				return hook.Call("OnChatTab", gm, text)
			else
				local callbacks = hook.GetTable().OnChatTab
				if callbacks then
					local completion
					for callback_key, callback in pairs(callbacks) do
						if not completion_blacklist[callback_key] then
							if isstring(callback_key) then
								completion = callback(text) or completion
							elseif IsValid(callback_key) then
								completion = callback(callback_key, text) or completion
							end
						end
					end

					if completion then return completion end
				end

				if EC_GM_COMPLETE:GetBool() then
					local gm = gmod.GetGamemode()
					if gm.OnChatTab then return gm:OnChatTab(text) end
				end
			end
		end

		local function update_chat_mode()
			if input.IsKeyDown(KEY_LCONTROL) or input.IsKeyDown(KEY_RCONTROL) then
				local next_mode = EasyChat.Mode - 1
				EasyChat.Mode = next_mode < 0 and EasyChat.ModeCount or next_mode
			else
				local next_mode = EasyChat.Mode + 1
				EasyChat.Mode = next_mode > EasyChat.ModeCount and 0 or next_mode
			end
		end

		function EasyChat.GUI.TextEntry:OnTab()
			if self:GetText() == "" then
				update_chat_mode()
				return
			end

			if EC_PEEK_COMPLETION:GetBool() and self.TabCompletion then
				if self.TabbedOnce then
					local completion = get_completion(self:GetText())
					if completion then self:SetText(completion) end
				else
					self.TabbedOnce = true
					self:SetText(self.TabCompletion)
				end
			else
				local completion = get_completion(self:GetText())
				if completion then self:SetText(completion) end
			end

			timer.Simple(0, function()
				self:RequestFocus()
				self:SetCaretPos(#self:GetText())
			end)
		end

		function EasyChat.GUI.TextEntry:OnEnter()
			if input.IsKeyDown(KEY_LSHIFT) or input.IsKeyDown(KEY_RSHIFT) then return end

			local msg = EasyChat.ExtendedStringTrim(self:GetText())
			self:SetText(msg)

			if uploading and msg:match(UPLOADING_TEXT) and not queued_upload then
				local should_send = safe_hook_run("ECShouldSendMessage", msg)
				if should_send == false then return end

				queued_upload = { Message = msg, Mode = EasyChat.GetCurrentMode() }
				close_chatbox()
				return
			end

			if msg ~= "" then
				local should_send = safe_hook_run("ECShouldSendMessage", msg)
				if should_send == false then return end

				local cur_mode = EasyChat.GetCurrentMode()
				cur_mode.Callback(msg)
			end

			close_chatbox()
		end

		function EasyChat.GUI.TextEntry:OnImagePaste(name, base64)
			if uploading then return end

			local caret_pos = self:GetCaretPos()
			local str = self:GetText()
			local str_start, str_end = str:sub(1, caret_pos), str:sub(caret_pos + 1)
			self:SetText(("%s%s%s"):format(str_start, UPLOADING_TEXT, str_end))
			uploading = true

			EasyChat.UploadToImgur(base64, function(url)
				if not url then
					local cur_text = EasyChat.ExtendedStringTrim(self:GetText())
					if cur_text:match(UPLOADING_TEXT) then
						self:SetText(cur_text:Replace(UPLOADING_TEXT, ""))
					end

					notification.AddLegacy("Image upload failed, check your console", NOTIFY_ERROR, 3)
					surface.PlaySound("buttons/button11.wav")
				else
					if queued_upload then
						local msg = queued_upload.Message:Replace(UPLOADING_TEXT, url)
						queued_upload.Mode.Callback(msg)
						queued_upload = nil
					else
						local cur_text = EasyChat.ExtendedStringTrim(self:GetText())
						if cur_text:match(UPLOADING_TEXT) then
							self:SetText(cur_text:Replace(UPLOADING_TEXT, url))
						end
					end
				end

				uploading = false
			end)
		end

		function EasyChat.GUI.TextEntry:OnValueChange(text)
			hook.Run("ChatTextChanged", text)

			-- this needs to be reset here for peeking to work properly
			self.TabbedOnce = false

			if not EC_PEEK_COMPLETION:GetBool() then return end

			if EasyChat.IsStringEmpty(text) then
				self.TabCompletion = nil
				self:SetCompletionText(nil)
				return
			end

			local completion = get_completion(text, true)
			self.TabCompletion = completion
			self:SetCompletionText(completion)
		end

		local function handle_player_actions(steam_id, ply_name)
			if steam_id == "BOT" then return end

			local steam_id64 = util.SteamIDTo64(steam_id)
			local ply_menu = DermaMenu()
			ply_menu:AddOption("Set Title", function()
				local frame = EasyChat.AskForInput("Set Title", function(title)
					local succ, err = EasyChat.Config:WritePlayerTitle(steam_id, title)
					if not succ then
						notification.AddLegacy(err, NOTIFY_ERROR, 3)
						surface.PlaySound("buttons/button11.wav")
					end
				end, false)

				frame:SetTall(200)

				local mk
				local ply_title = EasyChat.Config.Titles[steam_id]
				if ply_title then
					mk = ec_markup.Parse(ply_title)
					frame.TextEntry:SetText(ply_title)
				end

				frame.TextEntry.OnKeyCodeTyped = function(self, key_code)
					if key_code == KEY_ENTER or key_code == KEY_PAD_ENTER then
						self:OnEnter()
						return
					end

					timer.Create("ECSetPlayerTitle", 0.25, 1, function()
						-- if the frame is closed this can error
						if not IsValid(self) then return end
						mk = ec_markup.Parse(self:GetText())
					end)
				end

				local canvas = frame:Add("DPanel")
				canvas:Dock(BOTTOM)
				canvas:DockMargin(0, 7, 0, 7)
				canvas:SetTall(100)
				canvas.Paint = function(_, w, h)
					surface.SetDrawColor(color_white)
					surface.DrawOutlinedRect(0, 0, w, h)

					if mk then
						mk:Draw(w / 2 - mk:GetWide() / 2, h / 2 - mk:GetTall() / 2)
					end
				end
			end):SetImage("icon16/shield.png")

			ply_menu:AddOption("Remove Title", function()
				local succ, err = EasyChat.Config:DeletePlayerTitle(steam_id)
				if not succ then
					notification.AddLegacy(err, NOTIFY_ERROR, 3)
					surface.PlaySound("buttons/button11.wav")
				end
			end):SetImage("icon16/shield.png")

			local ply = player.GetBySteamID(steam_id)
			if IsValid(ply) then
				ply_menu:AddOption("Set Name", function()
					local frame = EasyChat.AskForInput("Set Name", function(name)
						local succ, err = EasyChat.Config:WritePlayerName(ply, name)
						if not succ then
							notification.AddLegacy(err, NOTIFY_ERROR, 3)
							surface.PlaySound("buttons/button11.wav")
						end
					end, false)
					frame.TextEntry:SetText(ply:Nick())
				end):SetImage("icon16/shield.png")
			end

			ply_menu:AddSpacer()

			ply_menu:AddOption("Open Steam Profile", function() EasyChat.OpenURL("https://steamcommunity.com/profiles/" .. steam_id64) end)
			ply_menu:AddOption("Copy Name", function()
				SetClipboardText(ply_name)
				notification.AddLegacy("Copied player name", NOTIFY_GENERIC, 3)
			end)

			ply_menu:AddOption("Copy SteamID", function()
				SetClipboardText(steam_id)
				notification.AddLegacy("Copied player SteamID", NOTIFY_GENERIC, 3)
			end)

			ply_menu:AddOption("Copy SteamID64", function()
				SetClipboardText(steam_id64)
				notification.AddLegacy("Copied player SteamID64", NOTIFY_GENERIC, 3)
			end)

			ply_menu:AddSpacer()

			ply_menu:AddOption("Cancel", function() ply_menu:Remove() end)
			ply_menu:Open()
		end

		local function handle_steam_id(steam_id)
			local id_menu = DermaMenu()
			local steam_id64 = util.SteamIDTo64(steam_id)
			id_menu:AddOption("Open Steam Profile", function() EasyChat.OpenURL("https://steamcommunity.com/profiles/" .. steam_id64) end)
			id_menu:AddOption("Copy SteamID", function() SetClipboardText(steam_id) end)
			id_menu:AddOption("Copy SteamID64", function() SetClipboardText(steam_id64) end)

			id_menu:AddSpacer()

			id_menu:AddOption("Cancel", function() id_menu:Remove() end)
			id_menu:Open()
		end

		local clickable_callback_id = 0
		local clickable_callbacks = {}
		function EasyChat.GUI.RichText:ActionSignal(name, value)
			if name ~= "TextClicked" then return end

			local interaction_id = tonumber(value:match("^CustomInteraction: (%d+)"))
			if interaction_id and clickable_callbacks[interaction_id] then
				clickable_callbacks[interaction_id]()
				return
			end

			local steam_id, ply_name = value:match("^ECPlayerActions%: (STEAM_%d%:%d%:%d+)|(.+)")
			if steam_id and ply_name then
				if steam_id == "NULL" or not steam_id:match("STEAM_%d%:%d%:%d+") then return end
				handle_player_actions(steam_id, ply_name)
				return
			end

			local steam_id = value:match("^STEAM_%d%:%d%:%d+")
			if steam_id then
				handle_steam_id(steam_id)
				return
			end

			EasyChat.OpenURL(value)
		end

		function EasyChat.GUI.RichText:AppendClickableText(text, callback)
			self:InsertClickableTextStart(("CustomInteraction: %d"):format(clickable_callback_id))
			append_text(self, text)
			self:InsertClickableTextEnd()

			clickable_callbacks[clickable_callback_id] = callback
			clickable_callback_id = clickable_callback_id + 1
		end

		local invalid_chat_keys = {
			[KEY_LCONTROL] = true, [KEY_LALT] = true,
			[KEY_RCONTROL] = true, [KEY_RALT] = true,
		}
		local function is_chat_key_pressed(key_code)
			if invalid_chat_keys[key_code] then return false end
			-- above 0 so we dont include KEY_NONE/KEY_FIRSt, under 67 because above are control keys
			if key_code > 0 and key_code <= 67 then return true end

			return false
		end

		function EasyChat.GUI.ChatBox:OnKeyCodePressed(key_code)
			if not EasyChat.IsOpened() then return end

			local tab = EasyChat.GUI.TabControl:GetActiveTab()
			if tab.FocusOn and not tab.FocusOn:HasFocus() then
				if is_chat_key_pressed(key_code) then
					local key_name = input.GetKeyName(key_code)
					if key_name == "ENTER" or key_name == "TAB" then
						key_name = ""
					end

					local cur_text = tab.FocusOn:GetText()
					tab.FocusOn:RequestFocus()
					tab.FocusOn:SetText(cur_text .. key_name)
					tab.FocusOn:SetCaretPos(#tab.FocusOn:GetText())
				end
			end
		end

		hook.Add("OnChatTab", TAG, function(text)
			if EC_NICK_PRIORITIZE:GetBool() then return end
			return nick_completion(text)
		end)

		local chat_mode_keys = { KEY_1, KEY_2, KEY_3, KEY_4, KEY_5, KEY_6 }
		local function key_to_chat_mode()
			for i, chat_mode_key in ipairs(chat_mode_keys) do
				if input.IsKeyDown(chat_mode_key) then
					local mode = i - 1
					if mode < 0 then return 0 end
					if mode > EasyChat.ModeCount then return EasyChat.ModeCount end
					return mode
				end
			end

			return -1
		end

		hook.Add("PlayerBindPress", TAG, function(ply, bind, pressed)
			if not pressed then return end

			if bind == "messagemode" then
				open_chatbox(false, key_to_chat_mode())
				return true
			elseif bind == "messagemode2" then
				open_chatbox(true)
				return true
			end
		end)

		hook.Add("PreRender", TAG, function()
			if not input.IsKeyDown(KEY_ESCAPE) then return end

			-- handle settings menu if opened, stop there for now
			if IsValid(EasyChat.Settings) and EasyChat.Settings:IsVisible() then
				EasyChat.Settings:SetVisible(false)
				return
			end

			if EasyChat.IsOpened() then
				close_chatbox()
				gui.HideGameUI()
			end
		end)

		hook.Add("GUIMousePressed", TAG, function(mouse_code)
			if not EC_OUT_CLICK_CLOSE:GetBool() then return end
			if mouse_code ~= MOUSE_LEFT then return end
			if not EasyChat.IsOpened() then return end
			close_chatbox()
		end)

		-- we do that here so its available from modules
		EasyChat.Settings = vgui.Create("ECSettingsMenu")
		EasyChat.Settings:SetVisible(false)

		function EasyChat.OpenSettings()
			local settings = EasyChat.Settings
			if not IsValid(settings) then return end

			settings:SetVisible(true)
			settings:MakePopup()

			local x, y, w, _ = EasyChat.GUI.ChatBox:GetBounds()
			if EasyChat.IsOnRightSide() then
				settings:SetPos(x - settings:GetWide() - 5, y)
			else
				settings:SetPos(x + w + 5, y)
			end

			safe_hook_run("ECSettingsOpened")
		end

		-- load modules
		do
			safe_hook_run("ECPreLoadModules")
			if not EC_NO_MODULES:GetBool() then load_modules() end
			safe_hook_run("ECPostLoadModules")
		end

		-- process the user tabs preferences
		do
			local tabs_data = load_chatbox_tabs_data() or {}
			local tabs = {}
			local processed_tab = {}
			for _, tab_data in ipairs(tabs_data) do
				local tab = EasyChat.GetTab(tab_data.Name)
				if tab then
					table.insert(tabs, tab.Tab)

					if tab_data.Hidden then
						tab.Tab:Hide()
					end

					processed_tab[tab_data.Name] = true
				end
			end

			if #EasyChat.GUI.ChatBox.Scroller.Panels > #tabs then
				for _, tab in ipairs(EasyChat.GUI.ChatBox.Scroller.Panels) do
					if not processed_tab[tab.Name] then
						table.insert(tabs, tab)
					end
				end
			end

			EasyChat.GUI.ChatBox.Scroller.Panels = tabs
		end

		local chat_text_types = {
			none = true, -- fallback
			-- darkrp = true -- darkrp compat most likely? Note: prints twice
			-- namechange = true, -- annoying
			-- servermsg = true, -- annoying
			-- teamchange = true, -- annoying
			-- chat = true, -- deprecated
			-- joinleave = true, -- we handle it ourselves
		}
		hook.Add("ChatText", TAG, function(index, name, text, type)
			if not chat_text_types[type] then return end

			chat.AddText(color_white, text)
		end)

		local chathud_call = false
		hook.Add("HUDShouldDraw", TAG, function(hud_element)
			if hud_element ~= "CHudChat" then return end
			if chathud_call then return end
			if EC_HUD_CUSTOM:GetBool() then return false end
		end)

		local function chathud_get_bounds(x, y, w, h)
			local c_x, c_y, c_w =
				EC_HUD_POS_X:GetInt(),
				EC_HUD_POS_Y:GetInt(),
				EC_HUD_WIDTH:GetInt()

			if c_w > 250 then
				w = math.min(c_w, ScrW() - 30)
			elseif ScrW() < 1600 then -- ant screens
				w = 250
			end

			if c_x > 0 then
				x = c_x
				if x + w > ScrW() then
					local diff = (x + w) - ScrW()
					x = x - diff - 30
				end
			end

			if c_y > 0 then
				y = c_y - h
				if y + h > ScrH() then
					local diff = (y + h) - ScrH()
					y = y - diff - 30
				end
			end

			return x, y, w, h
		end

		local chathud = EasyChat.ChatHUD
		local function chathud_screen_resolution_changed()
			local x, y, w, h = EasyChat.GetDefaultBounds()
			x, y, w, h = chathud_get_bounds(x, y, w, h)

			chathud.Pos = { X = x, Y = y }
			chathud.Size = { W = w, H = h }

			-- this is because 16 is way too small on 1440p and above
			if ScrH() < 1080 then
				chathud:UpdateFontSize(17)
			elseif ScrH() == 1080 then
				chathud:UpdateFontSize(18)
			else
				chathud:UpdateFontSize(20)
			end

			chathud:InvalidateLayout()
		end

		local chathud_bounds_cvar = { EC_HUD_WIDTH, EC_HUD_POS_X, EC_HUD_POS_Y }
		for _, cvar in ipairs(chathud_bounds_cvar) do
			local name = cvar:GetName()
			cvars.RemoveChangeCallback(name, name)
			cvars.AddChangeCallback(name, chathud_screen_resolution_changed, name)
		end

		local function screen_resolution_changed(old_scrw, old_scrh)
			local old_scrw, old_scrh =
				old_scrw == 0 and ScrW() or old_scrw,
				old_scrh == 0 and ScrH() or old_scrh

			chathud_screen_resolution_changed()

			local chatbox_frame = EasyChat.GUI.ChatBox
			if not IsValid(chatbox_frame) then return end

			local x, y, w, h = chatbox_frame:GetBounds()
			local scrw, scrh = ScrW(), ScrH()
			local coef_x, coef_y = scrw / old_scrw, scrh / old_scrh

			-- scale position and size to the new res
			x, y, w, h = x * coef_x, y * coef_y, w * coef_x, h * coef_y

			-- unfuck position and size
			if w >= scrw then w = scrh - 30 end
			if h >= scrw then h = scrh - 30 end
			if y + h >= scrw then y = scrh - h end
			if x + w >= scrw then x = scrh - w end

			chatbox_frame:SetPos(x, y)
			chatbox_frame:SetSize(w, h)
		end

		hook.Add("Think", TAG, function()
			if not chathud then return end

			if EC_HUD_FOLLOW:GetBool() then
				local x, y, w, h = EasyChat.GUI.ChatBox:GetBounds()
				x, y = x + 10, y - EasyChat.GUI.TextEntry:GetTall() -- fix slightly off pos

				local new_x, new_y, new_w, new_h = hook.Run("ECHUDBoundsUpdate", x, y, w, h)
				x, y, w, h = new_x or x, new_y or y, new_w or w, new_h or h

				chathud.Pos = { X = x, Y = y }
				chathud.Size = { W = w, H = h }
			else
				local x, y, w, h = EasyChat.GetDefaultBounds()
				x, y, w, h = chathud_get_bounds(x, y, w, h)

				local new_x, new_y, new_w, new_h = hook.Run("ECHUDBoundsUpdate", x, y, w, h)
				x, y, w, h = new_x or x, new_y or y, new_w or w, new_h or h

				chathud.Pos = { X = x, Y = y }
				chathud.Size = { W = w, H = h }
			end
		end)

		local old_scrw, old_scrh = 0, 0
		hook.Add("HUDPaint", TAG, function()
			local scrw, scrh = ScrW(), ScrH()

			-- this is because the "OnScreenSizeChanged" is kinda broken and unreliable
			if scrh ~= old_scrh or scrw ~= old_scrw then
				screen_resolution_changed(old_scrw, old_scrh)
				old_scrw, old_scrh = scrw, scrh
			end

			-- dont show if we have follow on, and the gui is opened
			if EC_HUD_FOLLOW:GetBool() and EasyChat.IsOpened() then return end

			chathud_call = true
			local should_draw = hook.Run("HUDShouldDraw", "CHudChat") ~= false
			chathud_call = false

			if EC_HUD_CUSTOM:GetBool() and should_draw then
				chathud:Draw()
			end
		end)

		-- for getting rid of chathud related annoying stuff
		hook.Add("OnPlayerChat", TAG, function(ply, text)
			if EC_HUD_SH_CLEAR:GetBool() and text == "sh" or text:match("%ssh%s") then
				chathud:StopComponents()
			end
		end)

		if jit.arch == "x64" and not cookie.GetString("ECChromiumWarn") then
			-- warn related to chromium regression
			EasyChat.AddText(EasyChat.GUI.RichText, color_red, "IF YOU ARE HAVING TROUBLES TO TYPE SOME CHARACTERS PLEASE TYPE", color_white, " easychat_legacy_entry 1 ",
			color_red, "IN YOUR CONSOLE. THE ISSUE IS DUE TO A REGRESSION IN CHROMIUM. MORE INFO HERE: https://github.com/Facepunch/garrysmod-issues/issues/4414\n"
			.. "IF YOU STILL HAVE ISSUES PLEASE DO REPORT THEM HERE: https://github.com/Earu/EasyChat/issues")
			cookie.Set("ECChromiumWarn", "1")
		end

		hook.Add("ECFactoryReset", TAG, function()
			cookie.Delete("ECChromiumWarn")
			cookie.Delete("ECShowDonateButton")
		end)

		safe_hook_run("ECInitialized")
	end

	net.Receive(NET_BROADCAST_MSG, function()
		local ply = net.ReadEntity()
		local msg = net.ReadString()
		local is_dead = net.ReadBool()
		local is_team = net.ReadBool()
		local is_local = net.ReadBool()

		-- so we never have the two together
		if is_local and is_team then
			is_team = false
		end

		local source_lang, target_lang =
			EC_TRANSLATE_INC_SRC_LANG:GetString(),
			EC_TRANSLATE_INC_TARGET_LANG:GetString()

		if EC_TRANSLATE_INC_MSG:GetBool() and source_lang ~= target_lang and ply ~= LocalPlayer() then
			EasyChat.Translator:Translate(msg, source_lang, target_lang, function(success, _, translation)
				-- dont use the gamemode default function here as it always returns true
				local suppress = hook.Call("OnPlayerChat", nil, ply, msg, is_team, is_dead, is_local)
				if not suppress then
					-- call the gamemode function if we're not suppressed otherwise it wont display
					GAMEMODE:OnPlayerChat(ply, msg, is_team, is_dead, is_local)
					if msg ~= translation then
						chat.AddText(ply, ("▲ %s ▲"):format(translation))
					end
				end
			end)
		else
			hook.Run("OnPlayerChat", ply, msg, is_team, is_dead, is_local)
		end
	end)

	net.Receive(NET_ADD_TEXT, function()
		local args = net.ReadTable()
		chat.AddText(unpack(args))
	end)

	function EasyChat.AddNameTags(ply, msg_components)
		msg_components = msg_components or {}

		if EC_ENABLE:GetBool() then
			if IsValid(ply) then
				if should_use_server_settings(ply) then
					-- dont do anything here, we want to process this more deeply so
					-- usergroup prefixes can be fancy (rainbow, etc...)
				elseif EC_TEAMS:GetBool() then
					if EC_TEAMS_COLOR:GetBool() then
						local team_color = team.GetColor(ply:Team())
						table.insert(msg_components, team_color)
					end
					table.insert(msg_components, "[" .. team.GetName(ply:Team()) .. "] - ")
				end
			end
		end

		return msg_components
	end

	function EasyChat.AddDeadTag(msg_components)
		msg_components = msg_components or {}

		table.insert(msg_components, Color(240, 80, 80))
		table.insert(msg_components, "*DEAD* ")

		return msg_components
	end

	function EasyChat.AddLocalTag(msg_components)
		msg_components = msg_components or {}

		table.insert(msg_components, Color(120, 210, 255))
		table.insert(msg_components, "(Local) ")

		return msg_components
	end

	function EasyChat.AddTeamTag(msg_components)
		msg_components = msg_components or {}

		table.insert(msg_components, Color(120, 120, 240))
		table.insert(msg_components, "(Team) ")

		return msg_components
	end

	hook.Add("Initialize", TAG, function()
		if EC_ENABLE:GetBool() then
			EasyChat.Init()
		end

		-- we're making this the "default" behavior if people introduce hooks that change this
		-- it shouldnt prevent it (ex: custom networking with different limits)
		function GAMEMODE:ECShouldSendMessage(msg)
			if #msg > EC_MAX_CHARS:GetInt() then
				surface.PlaySound("buttons/button11.wav")
				EasyChat.GUI.TextEntry:TriggerBlink("TOO BIG")
				return false
			end

			return true
		end

		-- this is for the best
		function GAMEMODE:OnPlayerChat(ply, msg, is_team, is_dead, is_local)
			local msg_components = {}

			-- reset color to white
			table.insert(msg_components, color_white)

			if is_dead then
				EasyChat.AddDeadTag(msg_components)
			end

			if is_local == true then
				EasyChat.AddLocalTag(msg_components)
			end

			if is_team then
				EasyChat.AddTeamTag(msg_components)
			end

			EasyChat.AddNameTags(ply, msg_components)

			if IsValid(ply) then
				table.insert(msg_components, ply)
			else
				table.insert(msg_components, Color(110, 247, 177))
				table.insert(msg_components, "???") -- console or weird stuff
			end

			table.insert(msg_components, color_white)

			if EasyChat.Config.AllowTagsInMessages then
				table.insert(msg_components, ": " .. msg)
			else
				local stripped_msg = ec_markup and ec_markup.Parse(msg):GetText() or msg
				table.insert(msg_components, ": " .. stripped_msg)
			end

			chat.AddText(unpack(msg_components))

			return true
		end

		safe_hook_run("ECPostInitialized")
	end)
end

function EasyChat.Destroy()
	-- dont fuck destroying if your addon is bad
	safe_hook_run("ECPreDestroy")

	if CLIENT then
		-- call closing before destroying in-case the chatbox is opened
		chat.Close()

		hook.Remove("PreRender", TAG)
		hook.Remove("Think", TAG)
		hook.Remove("PlayerBindPress", TAG)
		hook.Remove("HUDShouldDraw", TAG)

		if chat.old_AddText then
			chat.AddText = chat.old_AddText
			chat.GetChatBoxPos = chat.old_GetChatBoxPos
			chat.GetChatBoxSize = chat.old_GetChatBoxSize
			chat.Open = chat.old_Open
			chat.Close = chat.old_Close
		end

		EasyChat.ModeCount = 0
		EasyChat.Mode = 0
		EasyChat.Modes = { [0] = default_chat_mode }

		if EasyChat.GUI and IsValid(EasyChat.GUI.ChatBox) then
			EasyChat.GUI.ChatBox:Remove()
		end

		if IsValid(EasyChat.Settings) then
			EasyChat.Settings:Remove()
		end

		if EasyChat.ChatHUD then
			EasyChat.ChatHUD:Clear()
		end
	end

	safe_hook_run("ECPostDestroy")
end

function EasyChat.Reload()
	EasyChat.Destroy()
	EasyChat.Init()

	if SERVER then
		for _, v in ipairs(player.GetAll()) do
			v:SendLua([[EasyChat.Reload()]])
		end

		EasyChat.Config:Send(player.GetAll(), true)
	end
end

concommand.Add("easychat_reload", EasyChat.Reload)
