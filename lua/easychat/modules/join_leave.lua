local TAG = "EasyChatModuleJoinLeave"

local NET_SPAWN_LEAVE = "EASY_CHAT_MODULE_JOIN_LEAVE"
local NET_FRIEND_JOIN = "EASY_CHAT_MODULE_JOIN_LEAVE_FRIEND"
local EC_JOIN_LEAVE = CreateConVar("easychat_joinleave_msg", "1", { FCVAR_REPLICATED, SERVER and FCVAR_ARCHIVE or nil }, "Enables or disables join/leave messages")

if SERVER then
	util.AddNetworkString(NET_SPAWN_LEAVE)
	util.AddNetworkString(NET_FRIEND_JOIN)

	gameevent.Listen("player_connect")
	gameevent.Listen("player_disconnect")

	hook.Add("PlayerInitialSpawn", TAG, function(ply)
		if not EC_JOIN_LEAVE:GetBool() then return end

		-- we have to do this because its too early for getting player nick etc...
		EasyChat.RunOnNextFrame(function()
			if not IsValid(ply) then return end -- we never know

			net.Start(NET_SPAWN_LEAVE)
			net.WriteBool(true)
			net.WriteString(ply:RichNick())
			net.WriteInt(ply:Team(), 32)
			net.WriteString(ply:SteamID())

			local last_seen = ply:GetPData("ECLastSeen", -1)
			local cur_time = os.time()
			if last_seen ~= -1 then
				local last_seen_time = tonumber(last_seen) or 0
				local time_diff = last_seen_time ~= 0 and (cur_time - last_seen_time) or 0

				net.WriteInt(time_diff, 32)
				net.WriteInt(cur_time, 32)
				net.WriteInt(last_seen_time, 32)
			else
				net.WriteInt(-1, 32)
			end

			net.Broadcast()

			-- we do it too so if the server crashes we dont lose "too much" data
			ply:SetPData("ECLastSeen", cur_time)
		end)
	end)

	hook.Add("PlayerDisconnected", TAG, function(ply)
		ply:SetPData("ECLastSeen", os.time())
	end)

	hook.Add("ShutDown", TAG, function()
		for _, ply in ipairs(player.GetHumans()) do
			ply:SetPData("ECLastSeen", os.time())
		end
	end)

	hook.Add("player_disconnect", TAG, function(data)
		if not EC_JOIN_LEAVE:GetBool() then return end

		net.Start(NET_SPAWN_LEAVE)
		net.WriteBool(false)
		net.WriteString(data.name)
		net.WriteString(data.reason)
		net.WriteString(data.networkid)
		net.Broadcast()
	end)

	hook.Add("player_connect", TAG, function(data)
		if not EC_JOIN_LEAVE:GetBool() then return end

		net.Start(NET_FRIEND_JOIN)
		net.WriteString(data.name)
		net.WriteString(data.networkid)
		net.Broadcast()
	end)
end

if CLIENT then
	local UNKNOWN_COLOR = Color(110, 247, 177)

	local green_color = Color(100, 230, 100)
	local red_color = Color(230, 100, 100)
	local cyan_color = Color(0, 255, 255)
	local teal_color = Color(0, 255, 150)
	local gray_color = Color(200, 200, 200)
	local white_color = Color(255, 255, 255)
	local black_color = Color(0, 0, 0)

	hook.Add("ChatText", TAG, function(_, _, _, mode)
		if not EC_JOIN_LEAVE:GetBool() then return end
		if mode == "joinleave" then return true end
	end)

	local FRIEND_CACHE_PATH = "easychat/friend_cache.txt"
	local friend_ids = {}
	for _, line in ipairs((file.Read(FRIEND_CACHE_PATH, "DATA") or ""):Split("\n")) do
		friend_ids[line:Trim()] = true
	end

	local function check_player_friendship(ply)
		if not IsValid(ply) then return end

		local steam_id = ply:SteamID()
		if not steam_id or steam_id == "NULL" or steam_id == "BOT" then return end

		if ply:GetFriendStatus() == "friend" then
			friend_ids[steam_id] = true
		else
			-- account for friend removal
			if friend_ids[steam_id] then
				friend_ids[steam_id] = nil
			end
		end
	end

	local function save_friend_cache()
		if not file.Exists("easychat", "DATA") then
			file.CreateDir("easychat")
		end

		local contents = table.concat(table.GetKeys(friend_ids), "\n")
		file.Write(FRIEND_CACHE_PATH, contents)
	end

	hook.Add("OnEntityCreated", TAG, function(ent)
		if not ent:IsPlayer() then return end
		if ent:IsBot() then return end

		timer.Simple(15, function()
			check_player_friendship(ent)
			save_friend_cache()
		end)
	end)

	for _, ply in ipairs(player.GetAll()) do
		check_player_friendship(ply)
	end
	save_friend_cache()

	local EC_PLAYER_PASTEL = GetConVar("easychat_pastel")
	net.Receive(NET_SPAWN_LEAVE, function()
		local is_join = net.ReadBool()
		local name = net.ReadString()
		local reason
		local team_id = 1

		if not is_join then
			reason = net.ReadString()
		else
			team_id = net.ReadInt(32)
		end

		local network_id = net.ReadString()
		local last_seen_diff = net.ReadInt(32)

		local last_seen_time, cur_seen_time
		local seen_date, formatted_diff
		if last_seen_diff ~= -1 then
			last_seen_time = net.ReadInt(32)
			cur_seen_time = net.ReadInt(32)

			if os.date("%D", last_seen_time) == os.date("%D", cur_seen_time) then
				seen_date = "today"
			elseif os.date("%D", last_seen_time) == os.date("%D", cur_seen_time - 86400) then
				seen_date = "yesterday"
			else
				seen_date = os.date("%D", last_seen_time)
			end

			formatted_diff = (" (%s ago)"):format(string.NiceTime(last_seen_diff))
		end

		local ply_col = team.GetColor(team_id)
		if EasyChat.IsStringEmpty(name, true) then
			name = "[NO NAME]"
			ply_col = UNKNOWN_COLOR
		else
			if EC_PLAYER_PASTEL:GetBool() then
				ply_col = EasyChat.PastelizeNick(name)
			end
		end

		local formatted_id = (" (%s) "):format(network_id)
		if is_join then
			chat.AddText(green_color, " ● ", ply_col, name, gray_color, formatted_id, white_color, "has ", green_color, "spawned")

			if last_seen_diff == -1 then
				chat.AddText(black_color, " ▸ ", white_color, "Joined for the ", cyan_color, "first time", white_color, "!")
			else
				chat.AddText(black_color, " ▸ ", white_color, "Last seen ", cyan_color, seen_date, white_color, " at ", teal_color, os.date("%H:%M", last_seen_time), gray_color, formatted_diff)
			end

			-- let me be special
			if network_id == "STEAM_0:0:80006525" then
				chat.AddText(black_color, " ▸ ", teal_color, "EasyChat", white_color, " Developer!")
			end
		else
			if reason == "Gave up connecting" then
				chat.AddText(red_color, " ● ", ply_col, name, gray_color, formatted_id, red_color, "gave up", white_color, " connecting")
			else
				chat.AddText(red_color, " ● ", ply_col, name, gray_color, formatted_id, white_color, "has ", red_color, "left", white_color, " the server", red_color, " (" .. reason .. ")")
			end
		end
	end)

	net.Receive(NET_FRIEND_JOIN, function()
		local name = net.ReadString()
		local network_id = net.ReadString()

		if not friend_ids[network_id] then return end
		if EasyChat.BlockedPlayers[network_id] then return end -- friends can block each others on steam
		if EasyChat.IsStringEmpty(name, true) then name = "[NO NAME]" end
		chat.AddText(green_color, " ● Friend joining ", white_color, name, gray_color, " (" .. network_id .. ")")
	end)
end

return "JoinLeave Notifications"
