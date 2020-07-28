local TAG = "EasyChatModuleJoinLeave"

local NET_SPAWN_LEAVE = "EASY_CHAT_MODULE_JOIN_LEAVE"
local EC_JOIN_LEAVE = CreateConVar("easychat_joinleave_msg", "1", { FCVAR_REPLICATED, SERVER and FCVAR_ARCHIVE or nil }, "Enables or disables join/leave messages")

if SERVER then
	util.AddNetworkString(NET_SPAWN_LEAVE)

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

		local networkid = net.ReadString()

		local ply_col = team.GetColor(team_id)
		if EC_PLAYER_PASTEL:GetBool() then
			ply_col = EasyChat.PastelizeNick(name)
		end

		if is_join then
			chat.AddText(green_color, " ● ", ply_col, name, gray_color, " (" .. networkid .. ") ", white_color, "has ", green_color, "spawned")
		else
			chat.AddText(red_color, " ● ", ply_col, name, gray_color, " (" .. networkid .. ") ", white_color, "has ", red_color, "left", white_color, " the server", red_color, " (" .. reason .. ")")
		end
	end)
end

return "JoinLeave Notifications"
