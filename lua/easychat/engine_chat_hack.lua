local TAG = "EasyChatEngineChatHack"

-- if a server has slog or sourcenet, use them to route say commands to our networking
-- https://github.com/Heyter/gbins/tree/master/slog/src
-- https://github.com/danielga/gm_sourcenet
if SERVER then
	local function has_bin(name)
		if util.IsBinaryModuleInstalled then
			return util.IsBinaryModuleInstalled(name)
		end

		local arch = system.IsWindows() and "win" or (system.IsOSX() and "osx" or "linux")
		return #file.Find("lua/bin/gmsv_" .. name:PatternSafe() .. "_" .. arch .. "*.dll", "MOD") > 0
	end

	local has_slog = has_bin("slog")
	local has_sourcenet = has_bin("sourcenet")
	if has_slog then
		has_slog = pcall(require, "slog")
	end

	if not has_slog and has_sourcenet then
		has_sourcenet = pcall(require, "sourcenet")
		if has_sourcenet then
			local FilterIncomingMessage = function(...) end
			if file.Exists("sourcenet/incoming.lua", "LUA") then
				include("sourcenet/incoming.lua")
				FilterIncomingMessage = _G.FilterIncomingMessage
			else
				EasyChat.Print("Your sourcenet installation is corrupted! Missing lua files!")
			end

			local cache = {}
			local function steamid_from_addr(addr)
				local cached = cache[addr]
				if cached then return cached end

				for _, ply in pairs(player.GetHumans()) do
					if ply:IPAddress() == addr then
						local steam_id = ply:SteamID()
						cache[addr] = steam_id
						return steam_id
					end
				end

				return nil
			end

			FilterIncomingMessage(net_StringCmd, function(net_chan, read, write)
				local cmd = read:ReadString()
				local steam_id = steamid_from_addr(net_chan:GetAddress():ToString())
				if not steam_id then return end

				if hook.Call("ExecuteStringCommand", nil, steam_id, cmd) == true then return end
				write:WriteUInt(net_StringCmd, NET_MESSAGE_BITS)
				write:WriteString(cmd)
			end)
		end
	end

	if not has_slog and not has_sourcenet then
		MsgC(Color(255, 155, 0), "[EasyChat] [WARN]\n"
			.. "-------------------------------\n"
			.. "Could not find a proper installation of slog or sourcenet, "
			.. "chat console commands will use the engine networking as a result.\n"
			.. "If you care about console commands please install either of these two:\n"
			.. "- https://github.com/danielga/gm_sourcenet\n"
			.. "- https://github.com/Heyter/gbins/tree/master/slog/src\n"
			.. "-------------------------------\n"
			.. "YOU CAN IGNORE THIS WARNING SAFELY")
	end

	local say_cmds = {
		["^say%s+"] = function(ply, msg)
			EasyChat.ReceiveGlobalMessage(ply, msg, false, false)
		end,
		["^say%_team%s+"] = function(ply, msg)
			EasyChat.ReceiveGlobalMessage(ply, msg, true, false)
		end,
	}

	hook.Add("ExecuteStringCommand", TAG, function(steam_id, command)
		for say_cmd_pattern, say_cmd_callback in pairs(say_cmds) do
			if command:match(say_cmd_pattern) then
				local ply = player.GetBySteamID(steam_id)
				if not IsValid(ply) then return end

				local msg = command
					:gsub(say_cmd_pattern, "") -- remove the command
					:gsub("\"", "") -- remove quotes added by RunConsoleCommand

				say_cmd_callback(ply, msg)

				return true
			end
		end
	end)
end

-- this is inspired off
-- https://github.com/meepen/gmodchatmod
if CLIENT then
	local EC_ENABLED = GetConVar("easychat_enable")
	local EC_SKIP_STARTUP_MSG = GetConVar("easychat_skip_startup_msg")
	local MSG_BLOCK_TIME = 5 -- how many seconds after InitPostEntity do we still block messages

	local color_white = color_white

	local engine_panel
	local is_chat_opened = false
	local function hack_msg_send()
		local parent_panel = engine_panel:GetParent()
		local label = parent_panel:GetChildren()[1]
		--engine_panel:SetKeyboardInputEnabled(false) -- lets not do that lol

		local text_entry = parent_panel:Add("TextEntryLegacy")
		text_entry:SetZPos(9999999)
		text_entry:SetFocusTopLevel(true)
		text_entry:SetFont("ChatFont")
		text_entry:SetTextColor(color_white)
		text_entry:SetUpdateOnType(true)
		_G.EC_CHAT_HACK = text_entry

		local selection_color = Color(255, 0, 0, 127)
		function text_entry:Paint()
			self:DrawTextEntryText(EasyChat.TextColor, selection_color, EasyChat.TextColor)
		end

		hook.Add("Think", text_entry, function(self)
			if engine_panel:HasFocus() then
				engine_panel:KillFocus()
				self:RequestFocus()
			end

			self:SetPos(engine_panel:GetPos())
			self:SetSize(engine_panel:GetSize())

			local should_show = is_chat_opened and not EC_ENABLED:GetBool()
			self:SetVisible(should_show)

			if should_show and input.IsKeyDown(KEY_ESCAPE) then
				self:SetText("")
				hook.Run("ChatTextChanged", "")
				chat.Close()
			end
		end)

		function text_entry:OnValueChange(text)
			hook.Run("ChatTextChanged", text)
		end

		function text_entry:OnTab()
			local text = self:GetText()
			if #text == 0 then return end

			local completion = hook.Run("OnChatTab", text)
			if completion then self:SetText(completion) end

			EasyChat.RunOnNextFrame(function()
				self:SetCaretPos(#self:GetText())
				engine_panel:KillFocus()
				self:RequestFocus()
			end)
		end

		function text_entry:OnKeyCodeTyped(key_code)
			EasyChat.SetupHistory(self, key_code)

			if key_code == KEY_TAB then
				self:OnTab()
				return true
			end

			if key_code == KEY_ESCAPE then
				self:SetText("")
				hook.Run("ChatTextChanged", "")
				chat.Close()
				return true
			end

			if key_code == KEY_ENTER or key_code == KEY_PAD_ENTER then
				local msg = self:GetText()
				if not EasyChat.IsStringEmpty(msg) then
					msg = EasyChat.ExtendedStringTrim(self:GetText())

					local should_send = EasyChat.SafeHookRun("ECShouldSendMessage", msg)
					if should_send == false then return end

					local is_team = label:GetText():lower():match("team")
					EasyChat.SendGlobalMessage(msg, is_team, false)
				end

				self:SetText("")
				hook.Run("ChatTextChanged", "")
				chat.Close()
				return true
			end
		end
	end

	hook.Add("StartChat", TAG, function(is_team)
		is_chat_opened = true

		if EC_ENABLED:GetBool() then return end
		if IsValid(engine_panel) then return end

		hook.Add("Think", TAG, function()
			if IsValid(vgui.GetKeyboardFocus()) then
				engine_panel = vgui.GetKeyboardFocus()
				hack_msg_send()
				hook.Remove("Think", TAG)
			end
		end)
	end)

	hook.Add("FinishChat", TAG, function()
		is_chat_opened = false
	end)

	local STACK_OFFSET = 4 -- we start at 4 to ignore all the calls from the internals of easychat
	local function is_easychat_calling()
		local data = debug.getinfo(STACK_OFFSET)
		if data then
			local ret = data.source:match("^@lua/easychat") ~= nil or data.source:match("^@addons/easychat/lua/easychat") ~= nil
			if ret then return true end

			if data.source:match("^@addons") then
				local chunks = data.source:Split("/")
				return chunks[1] == "@addons" and chunks[3] == "lua" and chunks[4] == "easychat"
			end
		end

		return false
	end

	chat.old_EC_HackAddText = chat.old_EC_HackAddText or chat.AddText
	chat.AddText = function(...)
		local calling = is_easychat_calling()
		if EC_SKIP_STARTUP_MSG:GetBool() and not calling then
			if EasyChat and EasyChat.SkippedAnnoyingMessages then
				chat.old_EC_HackAddText(...)
			else
				MsgC("\n", ...)
				return "EC_SKIP_MESSAGE"
			end
		else
			chat.old_EC_HackAddText(...)
		end
	end

	hook.Add("InitPostEntity", TAG, function()
		timer.Simple(MSG_BLOCK_TIME, function()
			EasyChat.SkippedAnnoyingMessages = true
		end)

		hook.Remove("InitPostEntity", TAG)
	end)
end
