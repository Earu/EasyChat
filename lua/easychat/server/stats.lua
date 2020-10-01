local EC_STATS = CreateConVar("easychat_stats", "1", FCVAR_ARCHIVE, "Analytical anonymous stats")

local TAG = "EasyChatStats"
local function compute_perc_enabled()
	local perc = 0
	local plys = player.GetAll()

	for _, ply in ipairs(plys) do
		if ply:GetInfoNum("easychat_enabled", 1) then
			perc = perc + 1
		end
	end

	return (perc / #plys) * 100
end

local function send_stats(msg_per_hour)
	if not EC_STATS:GetBool() then return true end
	if not game.IsDedicated() then return true end -- we dont care about singleplayer

	return HTTP({
		url = "http://3kv.in:9006/stats/submit",
		method = "POST",
		body = util.TableToJSON({
			MessagePerHour = msg_per_hour,
			PercentageEnabled = compute_perc_enabled(),
			PlayersConnected = player.GetCount(),
			Gamemode = gmod.GetGamemode().Name,
			FromWorkshop = EasyChat.IsWorkshopInstall(),
		}),
		type = "application/json",
	})
end

local current_msg_count = 0
hook.Add("PlayerSay", TAG, function()
	current_msg_count = current_msg_count + 1
end)

local retry_timer = TAG .. "Retry"
local function trigger_send()
	if not send_stats(current_msg_count) then
		local retries = 0
		timer.Create(retry_timer, 5, 3, function() -- retries 3 times then give up
			if send_stats(current_msg_count) then
				current_msg_count = 0
				timer.Remove(retry_timer)
			else
				retries = retries + 1
				if retries >= 3 then
					current_msg_count = 0 -- make sure to reset msg count
				end
			end
		end)
	else
		current_msg_count = 0
	end
end

timer.Create(TAG, 3600, 0, trigger_send)