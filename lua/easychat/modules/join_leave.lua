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

		net.Start(NET_SPAWN_LEAVE)
		net.WriteBool(true)
		net.WriteString(ply:Nick())
		net.WriteInt(ply:Team(), 32)
		net.WriteString(ply:SteamID())
		net.Broadcast()
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
	local green_color = Color(100, 230, 100)
	local red_color = Color(230, 100, 100)
	local gray_color = Color(200, 200, 200)
	local white_color = Color(255, 255, 255)

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
		local ply_col = team.GetColor(team_id)
		if EC_PLAYER_PASTEL:GetBool() then
			ply_col = EasyChat.PastelizeNick(name)
		end

		if is_join then
			chat.AddText(green_color, " ● ", ply_col, name, gray_color, " (" .. network_id .. ") ", white_color, "has ", green_color, "spawned")
		else
			chat.AddText(red_color, " ● ", ply_col, name, gray_color, " (" .. network_id .. ") ", white_color, "has ", red_color, "left", white_color, " the server", red_color, " (" .. reason .. ")")
		end
	end)

	net.Receive(NET_FRIEND_JOIN, function()
		local name = net.ReadString()
		local network_id = net.ReadString()

		if not friend_ids[network_id] then return end
		chat.AddText(green_color, " ● Friend joining ", white_color, name, gray_color, " (" .. network_id .. ")")
	end)
end

return "JoinLeave Notifications"
