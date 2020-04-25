local TAG = "EasyChat"
local NET_SEND_CONFIG = "EASY_CHAT_SEND_SERVER_CONFIG"
local NET_USER_GROUP = "EASY_CHAT_WRITE_USER_GROUP"

local config = {}
EasyChat.Config = config

local default_config = {
	OverrideClientSettings = true,
	UserGroups = {
		--[[["players"] = {
			EmoteName = "image16/user.png",
			Tag = "[<hscan>Plebian<stop>]"
		}]]
	}
}

if SERVER then
	util.AddNetworkString(NET_SEND_CONFIG)

	local CONFIG_PATH = "easychat/config.json"
	function config:Save()
		if not file.Exists("easychat", "DATA") then
			file.CreateDir("easychat")
		end

		-- util.TableToJSON ignores functions so its fine
		file.Write(CONFIG_PATH, util.TableToJSON(self, true))
	end

	-- make this as user proof as possible
	function config:Load()
		if file.Exists(CONFIG_PATH, "DATA") then
			local json = file.Read(CONFIG_PATH, "DATA")
			local config = util.JSONToTable(json) or {}
			for k, v in pairs(config) do
				self[k] = v
			end
		end

		-- make sure every key/value of the default config exists
		for k, v in pairs(default_config) do
			if self[k] == nil then
				self[k] = v
			end
		end
	end

	local already_sent = setmetatable({}, { __mode = "k" })
	function config:Send(ply, force_send)
		if not force_send and already_sent[ply] then return end

		local config_copy = table.Copy(config)
		for k, v in pairs(config_copy) do
			if isfunction(config_copy[k]) then
				config_copy[k] = nil
			end
		end

		timer.Simple(0, function()
			net.Start(NET_SEND_CONFIG)
			net.WriteTable(config_copy)
			net.Send(ply)
		end)

		already_sent[ply] = true
	end

	config:Load()

	net.Receive(NET_SEND_CONFIG, function(_, ply)
		config:Send(ply, false)
	end)
end

if CLIENT then
	EasyChat.Config = default_config

	hook.Add("InitPostEntity", TAG, function()
		net.Start(NET_SEND_CONFIG)
		net.SendToServer()
	end)

	net.Receive(NET_SEND_CONFIG, function()
		local config = net.ReadTable()
		for k, v in pairs(config) do
			EasyChat.Config[k] = v
		end
	end)
end