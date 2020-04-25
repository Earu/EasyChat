local TAG = "EasyChat"
local NET_SEND_CONFIG = "EASY_CHAT_SEND_SERVER_CONFIG"
local NET_WRITE_USER_GROUP = "EASY_CHAT_SERVER_CONFIG_WRITE_USER_GROUP"
local NET_DEL_USER_GROUP = "EASY_CHAT_SERVER_CONFIG_DEL_USER_GROUP"
local NET_WRITE_SETTING_OVERRIDE = "EASYCHAT_SERVER_SETTING_WRITE_OVERRIDE"

local default_config = {
	OverrideClientSettings = true,
	UserGroups = {
		--[[["players"] = {
			EmoteName = "user",
			Tag = "[<hscan>Plebian<stop>]"
		}]]
	}
}

if SERVER then
	local config = default_config
	EasyChat.Config = config

	util.AddNetworkString(NET_SEND_CONFIG)
	util.AddNetworkString(NET_WRITE_USER_GROUP)
	util.AddNetworkString(NET_DEL_USER_GROUP)
	util.AddNetworkString(NET_WRITE_SETTING_OVERRIDE)

	local CONFIG_PATH = "easychat/server_config.json"
	function config:Save()
		if not file.Exists("easychat", "DATA") then
			file.CreateDir("easychat")
		end

		-- util.TableToJSON ignores functions so its fine
		file.Write(CONFIG_PATH, util.TableToJSON(self, true))
		hook.Run("ECServerConfigUpdate", self)
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

		if not force_send then
			already_sent[ply] = true
		end
	end

	config:Load()

	net.Receive(NET_SEND_CONFIG, function(_, ply)
		config:Send(ply, false)
	end)

	net.Receive(NET_WRITE_USER_GROUP, function(_, ply)
		if not ply:IsAdmin() then return end

		local user_group = net.ReadString()
		local tag = net.ReadString()
		local emote_name = net.ReadString()

		config.UserGroups[user_group] = {
			Tag = tag,
			EmoteName = emote_name,
		}

		config:Save()
		config:Send(player.GetAll(), true)
	end)

	net.Receive(NET_DEL_USER_GROUP, function(_, ply)
		if not ply:IsAdmin() then return end

		local user_group = net.ReadString()
		config.UserGroups[user_group] = nil

		config:Save()
		config:Send(player.GetAll(), true)
	end)

	net.Receive(NET_WRITE_SETTING_OVERRIDE, function(_, ply)
		if not ply:IsAdmin() then return end

		config.OverrideClientSettings = net.ReadBool()
		config:Save()
		config:Send(player.GetAll(), true)
	end)
end

if CLIENT then
	local config = default_config
	EasyChat.Config = config

	hook.Add("InitPostEntity", TAG, function()
		net.Start(NET_SEND_CONFIG)
		net.SendToServer()
	end)

	net.Receive(NET_SEND_CONFIG, function()
		local config = net.ReadTable()
		for k, v in pairs(config) do
			EasyChat.Config[k] = v
		end

		hook.Run("ECServerConfigUpdate", EasyChat.Config)
	end)

	function config:WriteUserGroup(user_group, tag, emote_name)
		if not LocalPlayer():IsAdmin() then return end

		net.Start(NET_WRITE_USER_GROUP)
		net.WriteString(user_group)
		net.WriteString(tag)
		net.WriteString(emote_name)
		net.SendToServer()
	end

	function config:DeleteUserGroup(user_group)
		if not LocalPlayer():IsAdmin() then return end

		net.Start(NET_DEL_USER_GROUP)
		net.WriteString(user_group)
		net.SendToServer()
	end

	function config:WriteSettingOverride(should_override)
		if not LocalPlayer():IsAdmin() then return end

		net.Start(NET_WRITE_SETTING_OVERRIDE)
		net.WriteBool(should_override)
		net.SendToServer()
	end
end