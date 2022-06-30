local TAG = "EasyChat"
local NET_SEND_CONFIG = "EASY_CHAT_SEND_SERVER_CONFIG"
local NET_WRITE_USER_GROUP = "EASY_CHAT_SERVER_CONFIG_WRITE_USER_GROUP"
local NET_DEL_USER_GROUP = "EASY_CHAT_SERVER_CONFIG_DEL_USER_GROUP"
local NET_WRITE_TAB = "EASY_CHAT_SERVER_CONFIG_WRITE_TAB"
local NET_WRITE_PLY_TITLE = "EASY_CHAT_SERVER_CONFIG_WRITE_PLY_TITLE"
local NET_DEL_PLY_TITLE = "EASY_CHAT_SERVER_CONFIG_DEL_PLY_TITLE"
local NET_WRITE_SETTING_OVERRIDE = "EASY_CHAT_SERVER_SETTING_WRITE_OVERRIDE"
local NET_WRITE_TAGS_IN_NAMES = "EASY_CHAT_TAGS_IN_NAMES"
local NET_WRITE_TAGS_IN_MESSAGES = "EASY_CHAT_TAGS_IN_MESSAGES"
local NET_WRITE_PLY_NAME = "EASY_CHAT_WRITE_PLY_NAME"
local NET_MODULE_IGNORE_LIST = "EASY_CHAT_MODULE_IGNORE_LIST"

local default_config = {
	OverrideClientSettings = true,
	AllowTagsInNames = true,
	AllowTagsInMessages = true,
	UserGroups = {
		--[[["players"] = {
			EmoteName = "user",
			EmoteSize = 16,
			EmoteProvider = silkicons,
			Tag = "[<hscan>Plebian<stop>]"
		}]]
	},
	Titles = {
		--["STEAM_0:0:80006525"] = "EasyChat Dev"
	},
	Tabs = {
		--["Lua"] = false
	}
}

if SERVER then
	local config = default_config
	EasyChat.Config = config

	concommand.Add("easychat_purge_config", function()
		config.OverrideClientSettings = true
		config.AllowTagsInNames = true
		config.AllowTagsInMessages = true
		config.UserGroups = {}
		config.Titles = {}
		config.Tabs = {}

		config:Save()
		config:Send(player.GetAll(), true)

		EasyChat.Print("Purged server config")
	end, nil, "Purges the server's EasyChat config")

	util.AddNetworkString(NET_SEND_CONFIG)
	util.AddNetworkString(NET_WRITE_USER_GROUP)
	util.AddNetworkString(NET_DEL_USER_GROUP)
	util.AddNetworkString(NET_WRITE_TAB)
	util.AddNetworkString(NET_WRITE_PLY_TITLE)
	util.AddNetworkString(NET_DEL_PLY_TITLE)
	util.AddNetworkString(NET_WRITE_SETTING_OVERRIDE)
	util.AddNetworkString(NET_WRITE_TAGS_IN_NAMES)
	util.AddNetworkString(NET_WRITE_TAGS_IN_MESSAGES)
	util.AddNetworkString(NET_WRITE_PLY_NAME)
	util.AddNetworkString(NET_MODULE_IGNORE_LIST)

	local CONFIG_PATH = "easychat/server_config.json"
	function config:Save()
		if not file.Exists("easychat", "DATA") then
			file.CreateDir("easychat")
		end

		-- util.TableToJSON ignores functions so its fine
		file.Write(CONFIG_PATH, util.TableToJSON(self, true))
		EasyChat.SafeHookRun("ECServerConfigUpdate", self)
	end

	-- make this as user proof as possible
	function config:Load()
		if file.Exists(CONFIG_PATH, "DATA") then
			local json = file.Read(CONFIG_PATH, "DATA")
			local config_data = util.JSONToTable(json) or {}
			for k, v in pairs(config_data) do
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

	local already_sent = {}
	local function clear_cache()
		for ply, _ in pairs(already_sent) do
			if not IsValid(ply) then
				already_sent[ply] = nil
			end
		end
	end

	function config:Send(ply, force_send)
		if not force_send and already_sent[ply] then return end

		local config_copy = table.Copy(config)
		for k, v in pairs(config_copy) do
			if isfunction(config_copy[k]) then
				config_copy[k] = nil
			end
		end

		local data = util.Compress(util.TableToJSON(config_copy))
		local data_len = #data
		EasyChat.RunOnNextFrame(function()
			net.Start(NET_SEND_CONFIG)
			net.WriteDouble(data_len)
			net.WriteData(data, data_len)
			net.Send(ply)
		end)

		if not force_send then
			already_sent[ply] = true
			clear_cache()
		end
	end

	config:Load()

	local MODULE_IGNORE_LIST_PATH = "easychat/module_ignore_list.txt"
	net.Receive(NET_SEND_CONFIG, function(_, ply)
		config:Send(ply, false)

		if ply:IsAdmin() and file.Exists(MODULE_IGNORE_LIST_PATH, "DATA") then
			EasyChat.RunOnNextFrame(function()
				local file_contents = file.Read(MODULE_IGNORE_LIST_PATH, "DATA")
				local paths = ("\r?\n"):Explode(file_contents, true)
				net.Start(NET_MODULE_IGNORE_LIST)
				net.WriteTable(paths)
				net.Send(ply)
			end)
		end
	end)

	local function restricted_receive(net_string, callback)
		net.Receive(net_string, function(len, ply)
			if not ply:IsAdmin() then return end

			callback(len, ply)
		end)
	end

	restricted_receive(NET_WRITE_USER_GROUP, function(_, ply)
		local user_group = net.ReadString()
		local tag = net.ReadString()
		local emote_name = net.ReadString()
		local emote_size = net.ReadInt(32)
		local emote_provider = net.ReadString()

		config.UserGroups[user_group] = {
			Tag = tag,
			EmoteName = emote_name,
			EmoteSize = emote_size,
			EmoteProvider = emote_provider,
		}

		config:Save()
		config:Send(player.GetAll(), true)
		EasyChat.Print(("%s changed the usergroup prefix for: %s"):format(ply, user_group))
	end)

	restricted_receive(NET_DEL_USER_GROUP, function(_, ply)
		local user_group = net.ReadString()
		config.UserGroups[user_group] = nil

		config:Save()
		config:Send(player.GetAll(), true)
		EasyChat.Print(("%s deleted the usergroup prefix for: %s"):format(ply, user_group))
	end)

	restricted_receive(NET_WRITE_TAB, function(_, ply)
		local tab_name = net.ReadString()
		local is_allowed = net.ReadBool()
		config.Tabs[tab_name] = is_allowed

		config:Save()
		config:Send(player.GetAll(), true)
		EasyChat.Print(("%s changed tab \"%s\" restrictions to: %s"):format(ply, tab_name, is_allowed and "allowed" or "restricted"))
	end)

	restricted_receive(NET_WRITE_PLY_TITLE, function(_, ply)
		local steam_id = net.ReadString()
		local title = net.ReadString()
		config.Titles[steam_id] = title

		config:Save()
		config:Send(player.GetAll(), true)

		local target = player.GetBySteamID(steam_id)
		EasyChat.Print(("%s changed title for: %s (%s)"):format(ply, IsValid(target) and target or steam_id, title))
	end)

	restricted_receive(NET_DEL_PLY_TITLE, function(_, ply)
		local steam_id = net.ReadString()
		config.Titles[steam_id] = nil

		config:Save()
		config:Send(player.GetAll(), true)

		local target = player.GetBySteamID(steam_id)
		EasyChat.Print(("%s removed title for: %s"):format(ply, IsValid(target) and target or steam_id))
	end)

	restricted_receive(NET_WRITE_SETTING_OVERRIDE, function(_, ply)
		local should_override = net.ReadBool()
		config.OverrideClientSettings = should_override
		config:Save()
		config:Send(player.GetAll(), true)
		EasyChat.Print(("%s changed settings override to: %s"):format(ply, should_override))
	end)

	restricted_receive(NET_WRITE_TAGS_IN_NAMES, function(_, ply)
		local allow_tags = net.ReadBool()
		config.AllowTagsInNames = allow_tags
		config:Save()
		config:Send(player.GetAll(), true)
		EasyChat.Print(("%s changed usage of tags in player names to: %s"):format(ply, allow_tags))
	end)

	restricted_receive(NET_WRITE_TAGS_IN_MESSAGES, function(_, ply)
		local allow_tags = net.ReadBool()
		config.AllowTagsInMessages = allow_tags
		config:Save()
		config:Send(player.GetAll(), true)
		EasyChat.Print(("%s changed usage of tags in messages to: %s"):format(ply, allow_tags))
	end)

	restricted_receive(NET_WRITE_PLY_NAME, function(_, ply)
		local target_ply = net.ReadEntity()
		local name = net.ReadString()
		if not IsValid(target_ply) then return end

		EasyChat.SafeHookRun("ECPlayerNameChange", ply, target_ply, target_ply:RichNick(), name)
	end)

	restricted_receive(NET_MODULE_IGNORE_LIST, function(_, ply)
		local ignore_paths = net.ReadTable()
		if file.Exists(MODULE_IGNORE_LIST_PATH, "DATA") then
			file.Delete(MODULE_IGNORE_LIST_PATH)
		end

		file.Write(MODULE_IGNORE_LIST_PATH, table.concat(ignore_paths, "\n"))

		EasyChat.Print(("%s changed the module ignore list, a restart is required"):format(ply))
		EasyChat.Warn(ply, "EasyChat's module ignore list updated. A restart is required.")
		EasyChat.RunOnNextFrame(function()
			net.Start(NET_MODULE_IGNORE_LIST)
			net.WriteTable(ignore_paths)
			net.Broadcast()
		end)
	end)
end

if CLIENT then
	local ADMIN_WARN = "You need to be an admin to do that"

	local config = default_config
	config.ModuleIgnoreList = {}
	EasyChat.Config = config

	hook.Add("InitPostEntity", TAG, function()
		net.Start(NET_SEND_CONFIG)
		net.SendToServer()
	end)

	local function process_tabs_config()
		local newly_allowed_tabs = {}

		-- nil if EasyChat is disabled maybe?
		if EasyChat.GetTab then
			for tab_name, is_allowed in pairs(EasyChat.Config.Tabs) do
				local tab_data = EasyChat.GetTab(tab_name)
				if tab_data and not is_allowed then
					EasyChat.RemoveTab(tab_name)
				elseif not tab_data and is_allowed then
					table.insert(newly_allowed_tabs, tab_name)
				end
			end
		end

		if #newly_allowed_tabs > 0 then
			local msg = ("Chat tabs (%s) got unrestricted. Reload the chatbox to get access to them.")
				:format(table.concat(newly_allowed_tabs, ", "))
			EasyChat.Warn(msg)
		end
	end

	net.Receive(NET_SEND_CONFIG, function()
		local data_len = net.ReadDouble()
		local data = net.ReadData(data_len)
		if #data < data_len then
			EasyChat.Warn("EasyChat's server config is TOO BIG, tell the admin(s) / owner(s).")
			return
		end

		local config_data = util.JSONToTable(util.Decompress(data))
		if not config_data then return end

		for k, v in pairs(config_data) do
			EasyChat.Config[k] = v
		end

		process_tabs_config()
		EasyChat.SafeHookRun("ECServerConfigUpdate", EasyChat.Config)
	end)

	net.Receive(NET_MODULE_IGNORE_LIST, function()
		local paths = net.ReadTable()
		EasyChat.Config.ModuleIgnoreList = paths
		EasyChat.SafeHookRun("ECServerConfigUpdate", EasyChat.Config)
	end)

	function config:WriteUserGroup(user_group, tag, emote_name, emote_size, emote_provider)
		if not LocalPlayer():IsAdmin() then return false, ADMIN_WARN end

		user_group = (user_group or ""):Trim()
		tag = (tag or ""):Trim()
		emote_name = (emote_name or ""):Trim()
		emote_size = tonumber(emote_size) or -1
		emote_provider = (emote_provider or ""):Trim()
		if #user_group == 0 then return false, "No usergroup specified" end

		net.Start(NET_WRITE_USER_GROUP)
		net.WriteString(user_group)
		net.WriteString(tag)
		net.WriteString(emote_name)
		net.WriteInt(emote_size, 32)
		net.WriteString(emote_provider)
		net.SendToServer()

		return true
	end

	function config:DeleteUserGroup(user_group)
		if not LocalPlayer():IsAdmin() then return false, ADMIN_WARN end

		user_group = (user_group or ""):Trim()
		if #user_group == 0 then return false, "No usergroup specified" end

		net.Start(NET_DEL_USER_GROUP)
		net.WriteString(user_group)
		net.SendToServer()

		return true
	end

	function config:WriteTab(tab_name, allowed)
		if not LocalPlayer():IsAdmin() then return false, ADMIN_WARN end

		tab_name = (tab_name or ""):Trim()
		if #tab_name == 0 then return false, "No tab specified" end

		net.Start(NET_WRITE_TAB)
		net.WriteString(tab_name)
		net.WriteBool(allowed)
		net.SendToServer()

		return true
	end

	function config:WritePlayerTitle(steam_id, title)
		if not LocalPlayer():IsAdmin() then return false, ADMIN_WARN end

		steam_id = (steam_id or ""):Trim()
		if #steam_id == 0 then return false, "Invalid SteamID" end

		title = (title or ""):Trim()
		if #title == 0 then return false, "No title specified" end

		net.Start(NET_WRITE_PLY_TITLE)
		net.WriteString(steam_id)
		net.WriteString(title)
		net.SendToServer()

		return true
	end

	function config:DeletePlayerTitle(steam_id)
		if not LocalPlayer():IsAdmin() then return false, ADMIN_WARN end

		steam_id = (steam_id or ""):Trim()
		if #steam_id == 0 then return false, "Invalid SteamID" end

		net.Start(NET_DEL_PLY_TITLE)
		net.WriteString(steam_id)
		net.SendToServer()

		return true
	end

	function config:WriteSettingOverride(should_override)
		if not LocalPlayer():IsAdmin() then return false, ADMIN_WARN end

		net.Start(NET_WRITE_SETTING_OVERRIDE)
		net.WriteBool(should_override or false)
		net.SendToServer()

		return true
	end

	function config:WriteTagsInNames(allow)
		if not LocalPlayer():IsAdmin() then return false, ADMIN_WARN end

		net.Start(NET_WRITE_TAGS_IN_NAMES)
		net.WriteBool(allow or false)
		net.SendToServer()

		return true
	end

	function config:WriteTagsInMessages(allow)
		if not LocalPlayer():IsAdmin() then return false, ADMIN_WARN end

		net.Start(NET_WRITE_TAGS_IN_MESSAGES)
		net.WriteBool(allow or false)
		net.SendToServer()

		return true
	end

	function config:WritePlayerName(ply, name)
		if not LocalPlayer():IsAdmin() then return false, ADMIN_WARN end
		if not IsValid(ply) then return false, "Invalid Player" end
		if #name > 32 then return false, "Name Too Long" end

		net.Start(NET_WRITE_PLY_NAME)
		net.WriteEntity(ply)
		net.WriteString(name)
		net.SendToServer()

		return true
	end

	function config:WriteModuleIgnoreList(paths)
		if not LocalPlayer():IsAdmin() then return false, ADMIN_WARN end

		net.Start(NET_MODULE_IGNORE_LIST)
		net.WriteTable(paths)
		net.SendToServer()

		return true
	end
end