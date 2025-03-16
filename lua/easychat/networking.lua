
local PLY = FindMetaTable("Player")
local TAG = "EasyChat"

local NET_BROADCAST_MSG = "EASY_CHAT_BROADCAST_MSG"
local NET_SEND_MSG = "EASY_CHAT_RECEIVE_MSG"
local NET_ADD_TEXT = "EASY_CHAT_ADD_TEXT"
local NET_SYNC_BLOCKED = "EASY_CHAT_SYNC_BLOCKED"

local COLOR_PRINT_CHAT_TIME = Color(0, 161, 255)
local COLOR_PRINT_CHAT_NICK = Color(222, 222, 255)
local COLOR_PRINT_CHAT_MSG = Color(255, 255, 255)

local native = true
function EasyChat.IsCallingNativeHooks()
	return native
end

if SERVER then
	local msgc_native = _G._MsgC or _G.MsgC -- epoe compat

	util.AddNetworkString(NET_SEND_MSG)
	util.AddNetworkString(NET_BROADCAST_MSG)
	util.AddNetworkString(NET_ADD_TEXT)
	util.AddNetworkString(NET_SYNC_BLOCKED)

	function EasyChat.PlayerAddText(ply, ...)
		if not istable(ply) and not IsValid(ply) then return end

		net.Start(NET_ADD_TEXT)
		net.WriteTable({ ... })
		net.Send(ply)
	end

	function EasyChat.Warn(ply, msg)
		EasyChat.PlayerAddText(ply, COLOR_RED, "[WARN] " ..  msg)
	end

	local function print_chat_msg(ply, msg, is_team, is_dead)
		local print_args = {}

		table.insert(print_args, COLOR_PRINT_CHAT_TIME)
		table.insert(print_args, os.date("!%H:%M:%S "))

		if is_team then
			table.insert(print_args, COLOR_TEAM)
			table.insert(print_args, "(Team) ")
		end

		if is_dead then
			table.insert(print_args, COLOR_DEAD)
			table.insert(print_args, "*DEAD* ")
		end

		local stripped_ply_nick = ply:Nick()
		if #stripped_ply_nick > 20 then
			stripped_ply_nick = stripped_ply_nick:sub(1, 20) .. "..."
		end

		table.insert(print_args, COLOR_PRINT_CHAT_NICK)
		table.insert(print_args, stripped_ply_nick)

		table.insert(print_args, COLOR_PRINT_CHAT_MSG)
		table.insert(print_args, (": %s\n"):format(msg))

		msgc_native(unpack(print_args))
	end

	function EasyChat.SendGlobalMessage(ply, str, is_team, is_local, skip_player_say)
		local msg
		if not skip_player_say then
			native = true
			local result = hook.Run("PlayerSay", ply, str, is_team, is_local)
			native = false

			if result == true then return -- kill the message
			elseif result == false then -- let the message pass
			elseif type(result) == "string" then -- replace the message
				msg = result
			end
		else
			msg = str
		end

		msg = EasyChat.ExtendedStringTrim(msg)
		if #msg == 0 then return end

		-- transform text after PlayerSay
		local datapack = { msg, is_team, is_local }
		if EasyChat.SafeHookRun("PlayerSayPostTransform", ply, datapack, is_team, is_local) == false then return end

		msg, is_team, is_local = unpack(datapack)

		msg = EasyChat.ExtendedStringTrim(msg)
		if #msg == 0 then return end

		-- compact with gameevent
		hook.Run("player_say", { 
			priority = 1, 
			userid = IsValid(ply) and ply:UserID() or 0,
			text = msg,
			teamonly = is_team and 1 or 0,
		})

		local filter = {}
		local broken_count = 1
		local function add_to_filter(ply_to_add)
			local id = ply_to_add:AccountID()
			if not id then
				filter[broken_count] = ply_to_add
				broken_count = broken_count + 1
			else
				filter[id] = ply_to_add
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

		local is_dead = not ply:Alive()
		net.Start(NET_BROADCAST_MSG)
		net.WriteUInt(ply:UserID(), 16)
		net.WriteString(ply:RichNick())
		net.WriteString(msg)
		net.WriteBool(is_dead)
		net.WriteBool(is_team)
		net.WriteBool(is_local)
		net.Send(filter)

		if game.IsDedicated() and not is_local then
			-- shows in server console
			print_chat_msg(ply, msg, is_team, is_dead)
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
		if ply:IsAdmin() then return false end

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

	local EC_MAX_CHARS = GetConVar("easychat_max_chars")
	function EasyChat.ReceiveGlobalMessage(ply, msg, is_team, is_local)
		-- we sub the message len clientside if we receive something bigger here
		-- it HAS to be malicious
		if #msg > EC_MAX_CHARS:GetInt() then
			EasyChat.SafeHookRun("ECBlockedMessage", ply, msg, is_team, is_local, "too big")
			EasyChat.Warn(ply, ("NOT SENT (TOO BIG): %s..."):format(msg:sub(1, 100)))
			return false
		end

		-- anti-spam
		if spam_watch(ply, msg) then
			EasyChat.SafeHookRun("ECBlockedMessage", ply, msg, is_team, is_local, "spam")
			EasyChat.Warn(ply, ("NOT SENT (SPAM): %s..."):format(msg:sub(1, 100)))
			return false
		end

		-- trim the message to remove any oddities so its clean to process for hooks etc...
		msg = EasyChat.ExtendedStringTrim(msg)

		-- Transform text before PlayerSay
		local datapack = { msg, is_team, is_local }
		if EasyChat.SafeHookRun("PlayerSayTransform", ply, datapack, is_team, is_local) == false then return false end

		local skip_player_say = datapack.SkipPlayerSay
		msg, is_team, is_local = unpack(datapack, 1, 3)

		EasyChat.SendGlobalMessage(ply, msg, is_team, is_local, skip_player_say)
	end

	local is_valid = _G.IsValid
	local blocked_players = EasyChat.BlockedPlayers or {}
	EasyChat.BlockedPlayers = blocked_players
	function EasyChat.IsBlockedPlayer(ply, steam_id)
		if not is_valid(ply) or not steam_id then return false end

		local lookup = blocked_players[ply]
		if not lookup then return false end
		if not lookup[steam_id] then return false end

		return true
	end

	net.Receive(NET_SEND_MSG, function(_, ply)
		local msg = net.ReadString()
		local is_team = net.ReadBool()
		local is_local = net.ReadBool()

		EasyChat.ReceiveGlobalMessage(ply, msg, is_team, is_local)
	end)

	net.Receive(NET_SYNC_BLOCKED, function(_, ply)
		local partial = net.ReadBool()
		if not partial then
			local lookup = {}
			local blocked_steam_ids = net.ReadTable()
			for _, steam_id in pairs(blocked_steam_ids) do
				lookup[steam_id] = true
			end

			EasyChat.BlockedPlayers[ply] = lookup
		else
			local blocked_steam_ids = EasyChat.BlockedPlayers[ply] or {}
			local steam_id = net.ReadString()
			local blocked = net.ReadBool()
			blocked_steam_ids[steam_id] = blocked or nil
			EasyChat.BlockedPlayers[ply] = blocked_steam_ids
		end
	end)

	function EasyChat.PlayerCanSeePlayersChat(_, _, listener, speaker, is_local)
		if is_local then
			if not IsValid(listener) or not IsValid(speaker) then
				return false
			end

			if is_local and listener:GetPos():Distance(speaker:GetPos()) > speaker:GetInfoNum("easychat_local_msg_distance", 150) then
				return false
			end
		end

		if IsValid(listener) and IsValid(speaker) and EasyChat.IsBlockedPlayer(listener, speaker:SteamID()) then
			return false
		end
	end

	local get_steam_id = FindMetaTable("Player").SteamID
	local is_ply_blocked = EasyChat.IsBlockedPlayer
	function EasyChat.PlayerCanHearPlayersVoice(listener, talker)
		if is_ply_blocked(listener, get_steam_id(talker)) then return false end
	end

	hook.Add("PlayerCanSeePlayersChat", TAG, EasyChat.PlayerCanSeePlayersChat)
	hook.Add("PlayerCanHearPlayersVoice", TAG, EasyChat.PlayerCanHearPlayersVoice)
	hook.Add("PlayerDisconnected", TAG, function(ply)
		spam_watch_lookup[ply] = nil
		EasyChat.BlockedPlayers[ply] = nil
	end)
end

if CLIENT then
	local BLOCKED_PLAYERS_PATH = "easychat/blocked_players.json"
	local BLOCKED_STRINGS_PATH = "easychat/BLOCKED_STRINGS.json"

	-- translation
	local EC_TRANSLATE_INC_MSG = CreateConVar("easychat_translate_inc_msg", "0", FCVAR_ARCHIVE, "Translates incoming chat messages")
	local EC_TRANSLATE_INC_SRC_LANG = CreateConVar("easychat_translate_inc_source_lang", "auto", FCVAR_ARCHIVE, "Language used in incoming chat messages")
	local EC_TRANSLATE_INC_TARGET_LANG = CreateConVar("easychat_translate_inc_target_lang", "en", FCVAR_ARCHIVE, "Language to translate incoming chat messages to")
	local EC_TRANSLATE_OUT_MSG = CreateConVar("easychat_translate_out_msg", "0", FCVAR_ARCHIVE, "Translates your chat messages")
	local EC_TRANSLATE_OUT_SRC_LANG = CreateConVar("easychat_translate_out_source_lang", "auto", FCVAR_ARCHIVE, "Language used in your chat messages")
	local EC_TRANSLATE_OUT_TARGET_LANG = CreateConVar("easychat_translate_out_target_lang", "en", FCVAR_ARCHIVE, "Language to translate your chat messages to")

	function user_id_to_ply(user_id)
		for _, ply in ipairs(player.GetAll()) do
			if ply:UserID() == user_id then
				return ply
			end
		end

		return false
	end

	local BLOCKED_STRINGS = file.Read(BLOCKED_STRINGS_PATH, "DATA") or ""
	EasyChat.BlockedStrings = util.JSONToTable(BLOCKED_STRINGS) or {}

	function EasyChat.BlockString(word, is_pattern)
		table.insert(EasyChat.BlockedStrings, {
			Content = word,
			IsPattern = is_pattern or false
		})

		file.Write(BLOCKED_STRINGS_PATH, util.TableToJSON(EasyChat.BlockedStrings))
	end

	function EasyChat.UnblockString(id)
		table.remove(EasyChat.BlockedStrings, id)
		file.Write(BLOCKED_STRINGS_PATH, util.TableToJSON(EasyChat.BlockedStrings))
	end

	-- Censorship depends on steam language
	-- shortest racial slur from every language from steam api in 2021
	local racial_slur_testers = util.Base64Decode("bmlnZ2VyCmhvbW8KYmliYQpwaWNoa3UKbmVncgpsZXNiYQpwZApqaWQKz4DOv8+Nz4PPhM63CmphcMOzCmNoZWNjCuyVoOyekAptYXJpY2EKY2lwCmZ1ZmEKbXVpc3QKZmF4YQpvw6cK0LPQtdC5CsSRxKk="):Split("\n")
	local is_steam_filtering_chat = nil

	function EasyChat.IsSteamFilteringChat()
		if is_steam_filtering_chat ~= nil then return is_steam_filtering_chat end

		-- we can only loosen restrictions so this should catch most cases
		-- BUG: We cannot catch custom filtered words, but the player then likely has filtering on regardless
		for filter_mode = TEXT_FILTER_UNKNOWN, TEXT_FILTER_NAME do
			for _, racial_slur_test in pairs(racial_slur_testers) do
				local filtered = util.FilterText(racial_slur_test, filter_mode)

				if filtered ~= racial_slur_test then
					is_steam_filtering_chat = true

					return true
				end
			end
		end

		is_steam_filtering_chat = false

		return false
	end

	local broken_filtering = nil

	function EasyChat.IsFilteringBroken()
		-- Automatically becomes fixed in easychat if ever fixed in GMod (or in steam?)
		if broken_filtering ~= nil then return broken_filtering end
		local broken = "\xe2\x96\x88"
		local broken_result = util.FilterText(broken, TEXT_FILTER_UNKNOWN)
		broken_filtering = broken ~= broken_result

		return broken_filtering
	end

	function EasyChat.FilterString(str)
		local original_str = str
		local base_str = ec_markup.GetText(str)
		if EasyChat.IsFilteringBroken() and EasyChat.IsSteamFilteringChat() then
			--TODO: Alternative (better) approach:
			--      Redo in Lua all that is being accidentally filtered
			--      and check if string matches util.FilterText result

			str = util.FilterText(base_str) -- respect the Steam filter settings
		end

		for _, blocked_str in ipairs(EasyChat.BlockedStrings) do
			local content = blocked_str.Content
			if not blocked_str.IsPattern then
				content = blocked_str.Content:PatternSafe()
			end

			str = str:gsub(content, function(match)
				return ("*"):rep(#match)
			end)
		end

		if base_str ~= str then
			return str
		end

		return original_str
	end

	function EasyChat.ReceiveGlobalMessage(ply, msg, is_dead, is_team, is_local)
		if EasyChat.IsBlockedPlayer(ply) then return end

		-- so we never have the two together
		if is_local and is_team then
			is_team = false
		end

		local only_local = GetConVar("easychat_only_local")
		if only_local and only_local:GetBool() and not is_local then return end

		msg = EasyChat.FilterString(msg)

		local source_lang, target_lang =
			EC_TRANSLATE_INC_SRC_LANG:GetString(),
			EC_TRANSLATE_INC_TARGET_LANG:GetString()

		if EC_TRANSLATE_INC_MSG:GetBool() and source_lang ~= target_lang and ply ~= LocalPlayer() then
			EasyChat.Translator:Translate(msg, source_lang, target_lang, function(success, _, translation)
				local datapack = { msg }
				if EasyChat.SafeHookRun("OnPlayerChatTransform", ply, datapack, is_team, is_local) == false then return end

				msg = datapack[1]
				if not msg then return end

				-- dont use the gamemode default function here as it always returns true
				local suppress = hook.Call("OnPlayerChat", nil, ply, msg, is_team, is_dead, is_local)
				if not suppress then
					-- call the gamemode function if we're not suppressed otherwise it wont display
					GAMEMODE:OnPlayerChat(ply, msg, is_team, is_dead, is_local)
					if translation and msg ~= translation then
						chat.AddText(ply, ("▲ %s ▲"):format(translation))
					end

					-- compact with gameevent
					hook.Run("player_say", { 
						priority = 1, 
						userid = IsValid(ply) and ply:UserID() or 0,
						text = msg,
						teamonly = is_team and 1 or 0,
					})
				end
			end)
		else
			hook.Run("OnPlayerChat", ply, msg, is_team, is_dead, is_local)
			
			-- compact with gameevent
			hook.Run("player_say", { 
				priority = 1, 
				userid = IsValid(ply) and ply:UserID() or 0,
				text = msg,
				teamonly = is_team and 1 or 0,
			})
		end
	end

	local MAX_RETRIES = 40
	local RETRY_DELAY = 0.25
	local DISCONNECTED_COLOR = Color(110, 247, 177)
	net.Receive(NET_BROADCAST_MSG, function()
		local user_id = net.ReadUInt(16)
		local user_name = net.ReadString()
		local msg = net.ReadString()
		local is_dead = net.ReadBool()
		local is_team = net.ReadBool()
		local is_local = net.ReadBool()

		local function receive(retries)
			retries = retries or 0

			local ply = user_id_to_ply(user_id)
			if not IsValid(ply) then
				if retries > MAX_RETRIES then
					chat.AddText(
						DISCONNECTED_COLOR,
						"[DISCONNECTED] ",
						COLOR_PRINT_CHAT_MSG,
						user_name,
						COLOR_PRINT_CHAT_MSG,
						(": %s"):format(msg)
					)

					return
				end

				timer.Simple(RETRY_DELAY, function()
					receive(retries + 1)
				end)

				return
			end

			EasyChat.ReceiveGlobalMessage(ply, msg, is_dead, is_team, is_local)
		end

		receive()
	end)

	net.Receive(NET_ADD_TEXT, function()
		local args = net.ReadTable()
		chat.AddText(unpack(args))
	end)

	function EasyChat.SendGlobalMessage(msg, is_team, is_local, no_translate)
		if msg:find("\0", 1, true) then
			ErrorNoHalt("Null byte on chat message, unhandled!")
		end

		msg = EasyChat.MacroProcessor:ProcessString(msg)

		local ply = LocalPlayer()

		-- transform text before PlayerSay
		local datapack = { msg }
		if EasyChat.SafeHookRun("PlayerSayTransform", ply, datapack, is_team, is_local) == false then return false end

		msg = EasyChat.ExtendedStringTrim(datapack[1])
		if #msg == 0 then return false end

		--  this isn't in the specs but it is now :|
		native = false
		local result = EasyChat.SafeHookRun("PlayerSay", ply, msg, is_team, is_local)
		native = true

		if result == true then -- kill the message
			return false
		elseif result == false then -- let the message pass
		elseif type(result) == "string" then -- Replace the message
			msg = EasyChat.ExtendedStringTrim(result)
		end

		if #msg == 0 then return false end

		-- Transform text after PlayerSay
		datapack = { msg }
		if EasyChat.SafeHookRun("PlayerSayPostTransform", ply, datapack, is_team, is_local) == false then return false end

		msg = EasyChat.ExtendedStringTrim(datapack[1])
		if #msg == 0 then return false end

		local result = EasyChat.SafeHookRun("SendChatMessage", msg, is_team, is_local)
		if result == false then return false end

		local source_lang, target_lang =
			EC_TRANSLATE_OUT_SRC_LANG:GetString(),
			EC_TRANSLATE_OUT_TARGET_LANG:GetString()

		if not no_translate and EC_TRANSLATE_OUT_MSG:GetBool() and source_lang ~= target_lang then
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

	function EasyChat.LoadBlockedPlayers()
		local BLOCKED_PLAYERS = file.Read(BLOCKED_PLAYERS_PATH, "DATA") or ""
		EasyChat.BlockedPlayers = util.JSONToTable(BLOCKED_PLAYERS) or {}

		local lookup = {}

		if GetConVar("easychat_sync_steam_blocks"):GetBool() then
			for _, ply in ipairs(player.GetAll()) do
				if ply:GetFriendStatus() == "blocked" then
					table.insert(lookup, ply:SteamID())
				end
			end
		end

		for steam_id, _ in pairs(EasyChat.BlockedPlayers) do
			table.insert(lookup, steam_id)
		end

		EasyChat.RunOnNextFrame(function()
			net.Start(NET_SYNC_BLOCKED)
			net.WriteBool(false)
			net.WriteTable(lookup)
			net.SendToServer()
		end)
	end

	hook.Add("Initialize", "EasyChatBlockListInit", EasyChat.LoadBlockedPlayers)

	function EasyChat.BlockPlayer(steam_id)
		EasyChat.BlockedPlayers[steam_id] = true
		file.Write(BLOCKED_PLAYERS_PATH, util.TableToJSON(EasyChat.BlockedPlayers))
		notification.AddLegacy("Blocked user: " .. steam_id, NOTIFY_GENERIC, 5)

		net.Start(NET_SYNC_BLOCKED)
		net.WriteBool(true)
		net.WriteString(steam_id)
		net.WriteBool(true)
		net.SendToServer()

		EasyChat.SafeHookRun("ECBlockedPlayer", steam_id)
	end

	function EasyChat.UnblockPlayer(steam_id)
		EasyChat.BlockedPlayers[steam_id] = nil
		file.Write(BLOCKED_PLAYERS_PATH, util.TableToJSON(EasyChat.BlockedPlayers))
		notification.AddLegacy("Unblocked user: " .. steam_id, NOTIFY_UNDO, 5)

		net.Start(NET_SYNC_BLOCKED)
		net.WriteBool(true)
		net.WriteString(steam_id)
		net.WriteBool(false)
		net.SendToServer()

		EasyChat.SafeHookRun("ECUnblockedPlayer")
	end

	function EasyChat.IsBlockedPlayer(ply)
		if not IsValid(ply) then return false end
		if not ply:IsPlayer() then return false end

		if GetConVar("easychat_sync_steam_blocks"):GetBool() then
			local steam_blocked = (ply:GetFriendStatus() or "") == "blocked"
			if steam_blocked then return true end
		end

		local steam_id = ply:SteamID() or ""
		if LocalPlayer():SteamID() == steam_id then return false end

		return EasyChat.BlockedPlayers[steam_id] and true or false
	end

	-- sync up data for players joining, we dont want a funny steam blocked person to avoid blocking
	gameevent.Listen("player_spawn")
	hook.Add("player_spawn", TAG, function(data)
		if not GetConVar("easychat_sync_steam_blocks"):GetBool() then return end

		timer.Simple(10, function()
			local ply = Player(data.userid)
			if not IsValid(ply) then return end
			if ply:GetFriendStatus() ~= "blocked" then return end

			net.Start(NET_SYNC_BLOCKED)
			net.WriteBool(true)
			net.WriteString(ply:SteamID())
			net.WriteBool(true)
			net.SendToServer()
		end)
	end)
end

PLY.old_IsTyping = PLY.old_IsTyping or PLY.IsTyping
function PLY:IsTyping()
	if self:ECIsEnabled() then
		return self:GetNWBool("ec_is_typing", false)
	else
		return self:old_IsTyping()
	end
end

local function say_override(ply, msg, is_team, is_local)
	if not msg then return end

	msg = EasyChat.ExtendedStringTrim(msg)
	if #msg == 0 then return end

	if SERVER then
		if not IsValid(ply) then
			RunConsoleCommand(is_team and "say_team" or "say", msg)
			return
		end

		EasyChat.ReceiveGlobalMessage(ply, msg, is_team or false, is_local or false)
	end

	if CLIENT then
		if ply ~= LocalPlayer() then return end

		local should_send = EasyChat.SafeHookRun("ECShouldSendMessage", msg)
		if should_send == false then return end

		EasyChat.SendGlobalMessage(msg, is_team or false, is_local or false)
	end
end

PLY.old_Say = PLY.old_Say or PLY.Say -- in case we need the old version
function PLY:Say(msg, is_team, is_local)
	say_override(self, msg, is_team, is_local)
end

function Say(msg, is_team, is_local)
	if CLIENT then
		say_override(LocalPlayer(), msg, is_team, is_local)
	end

	if SERVER then
		say_override(nil, msg, is_team, is_local)
	end
end
