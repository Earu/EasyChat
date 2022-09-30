local EASYCHAT_AUTO_COMPLETION = "EASY_CHAT_MODULE_CMDS_AUTO_COMPLETION"

if SERVER and istable(_G.aowl) then
	util.AddNetworkString(EASYCHAT_AUTO_COMPLETION)

	net.Receive(EASYCHAT_AUTO_COMPLETION, function(_, ply)
		local cmds_str = ""
		if istable(_G.aowl.cmds) then
			for cmd_name in pairs(aowl.cmds) do
				cmds_str = ("%s,%s"):format(cmds_str, cmd_name)
			end
		elseif istable(_G.aowl.Commands) then
			for cmd_name in pairs(aowl.Commands) do
				cmds_str = ("%s,%s"):format(cmds_str, cmd_name)
			end
		elseif istable(_G.aowl.commands) then
			for cmd_name in pairs(aowl.commands) do
				cmds_str = ("%s,%s"):format(cmds_str, cmd_name)
			end
		end

		EasyChat.RunOnNextFrame(function()
			net.Start(EASYCHAT_AUTO_COMPLETION)
			net.WriteString(cmds_str)
			net.Send(ply)
		end)
	end)
end

if CLIENT then
	local EC_CMDS_SUGGESTIONS = CreateConVar("easychat_cmd_suggestions", "1", FCVAR_ARCHIVE, "Shows suggestions for commands")
	EasyChat.RegisterConvar(EC_CMDS_SUGGESTIONS, "Displays command suggestions")

	local color_white = color_white
	local black_color = Color(0, 0, 0, 200)
	local option_font = "EasyChatFont"
	local hook_name = "EasyChatModuleCmdsAutoComplete"

	EasyChat.CmdSuggestions = {
		Handlers = {},
		Priorities = {}
	}

	function EasyChat.CmdSuggestions:AddSuggestionHandler(identifier, prefix, lookup, priority)
		priority = priority or 0
		self.Handlers[identifier] = {
			Lookup = lookup,
			Prefix = prefix,
			ActiveOptions = {},
			ActiveOptionsCount = 0,
		}

		self.Priorities[identifier] = priority
	end

	local function stop_auto_completion()
		hook.Remove("HUDPaint", hook_name)
		for _, cmds in pairs(EasyChat.CmdSuggestions.Handlers) do
			cmds.ActiveOptions = {}
			cmds.ActiveOptionsCount = 0
		end
	end

	if istable(_G.ulx) and istable(_G.ULib) then
		local categories = ulx.cmdsByCategory
		local ulx_args_lookup = {
			[ULib.cmds.NumArg] = "Number",
			[ULib.cmds.BoolArg] = "1/0",
			[ULib.cmds.PlayersArg] = "Players",
			[ULib.cmds.PlayerArg] = "Player",
			[ULib.cmds.StringArg] = "Text",
		}

		local function generate_ulx_cmds_lookup()
			local ulx_cmds = {}
			for _, category in pairs(categories) do
				for _, cmd_table in ipairs(category) do
					local cmd_name = cmd_table.cmd:gsub("^ulx%s", "")
					local args = {}
					for _, arg in ipairs(cmd_table.args) do
						local ulx_arg_type = ulx_args_lookup[arg.type]
						if ulx_arg_type then
							local display_arg = ("<%s>"):format(ulx_arg_type)
							table.insert(args, display_arg)
						end
					end

					ulx_cmds[cmd_name] = args
				end
			end

			return ulx_cmds
		end

		EasyChat.CmdSuggestions:AddSuggestionHandler("ULX", "!", generate_ulx_cmds_lookup(), 9999)
	elseif istable(_G.FAdmin) then
		hook.Remove("ChatTextChanged", "FAdmin_Chat_autocomplete")
		hook.Remove("HUDPaint", "FAdmin_Chat_autocomplete")
		hook.Remove("OnChatTab", "FAdmin_Chat_autocompletRemove")

		local fadmin_cmds = {}
		for cmd_name, cmd in pairs(FAdmin.Commands.List) do
			fadmin_cmds[cmd_name] = cmd.ExtraArgs or {}
		end

		EasyChat.CmdSuggestions:AddSuggestionHandler("FAdmin", "/", fadmin_cmds)
	elseif istable(_G.sam) and istable(_G.sam.command) then
		local function generate_sam_cmds_lookup()
			local sam_cmds = {}
			for _, cmd in pairs(sam.command:get_commands()) do
				local cmd_args = {}
				for _, arg in pairs(cmd.args) do
					table.insert(cmd_args, arg.name)
				end

				sam_cmds[cmd.name] = cmd_args
				for _, alias in pairs(cmd.aliases) do
					sam_cmds[cmd.name] = cmd_args
				end
			end

			return sam_cmds
		end

		EasyChat.CmdSuggestions:AddSuggestionHandler("sam", "[!%~]", generate_sam_cmds_lookup())
	elseif istable(_G.aowl) then
		net.Receive(EASYCHAT_AUTO_COMPLETION, function()
			local aowl_cmds = {}
			local cmds_str = net.ReadString()
			if aowl.cmds then
				for cmd_name in pairs(aowl.cmds) do
					aowl_cmds[cmd_name] = {}
				end
			elseif aowl.Commands then
				for cmd_name in pairs(aowl.Commands) do
					aowl_cmds[cmd_name] = {}
				end
			elseif aowl.commands then
				for cmd_name in pairs(aowl.commands) do
					aowl_cmds[cmd_name] = {}
				end
			end

			local srv_cmds = cmds_str:Split(",")
			for _, cmd_name in ipairs(srv_cmds) do
				aowl_cmds[cmd_name] = {}
			end

			EasyChat.CmdSuggestions:AddSuggestionHandler("aowl", aowl.Prefix or aowl.prefix or "[!/%.]", aowl_cmds)
		end)

		hook.Add("StartChat", hook_name, function()
			net.Start(EASYCHAT_AUTO_COMPLETION)
			net.SendToServer()
			hook.Remove("StartChat", hook_name)
		end)
	elseif istable(_G.Mercury) and istable(_G.Mercury.Commands) and istable(_G.Mercury.Commands.CommandTable) then
		local mercury_cmds = {}
		for cmd_name in pairs(Mercury.Commands.CommandTable) do
			mercury_cmds[cmd_name] = {}
		end

		EasyChat.CmdSuggestions:AddSuggestionHandler("Mercury", "[!/@]", mercury_cmds)
	end

	local ChatCommands = list.Get("ChatCommands")
	if not table.IsEmpty(ChatCommands) then
		local commands = {}
		for chat_cmd in pairs(ChatCommands) do
			commands[chat_cmd] = {}
		end

		EasyChat.CmdSuggestions:AddSuggestionHandler("ChatCommands", "[!/\\%.]", commands, -1)
	end

	if gmod.GetGamemode().Name == "DarkRP" and _G.DarkRP and _G.DarkRP.chatCommands then
		local commands = {}
		for chat_cmd, _ in pairs(_G.DarkRP.chatCommands) do
			commands[chat_cmd] = {}
		end

		EasyChat.CmdSuggestions:AddSuggestionHandler("DarkRP", "/", commands, -1)
	end

	local active_options_index = 0
	hook.Add("ChatTextChanged", hook_name, function(text)
		if not EC_CMDS_SUGGESTIONS:GetBool() then return end

		local all_options = {}
		local all_options_count = 0

		for identifier in SortedPairsByValue(EasyChat.CmdSuggestions.Priorities) do
			local cmds = EasyChat.CmdSuggestions.Handlers[identifier]

			local prefix = text:match(("^%s"):format(cmds.Prefix))
			if not prefix then
				continue
			end

			local args = text:sub(2):Split(" ")
			-- if we dont have a command dont proceed anyway
			if not args[1] then
				continue
			end

			local cmd = args[1]:lower():PatternSafe()
			table.remove(args, 1) -- remove the command from the args

			local options_count = 0
			local options = {}
			for cmd_name, cmd_args in pairs(cmds.Lookup) do
				if cmd_name:lower():match(cmd) then
					options[("%s%s"):format(prefix, cmd_name)] = cmd_args
					options_count = options_count + 1
				end
			end

			if options_count == 0 then
				cmds.ActiveOptions = options
				cmds.ActiveOptionsCount = options_count
				continue
			end

			table.sort(options)
			cmds.ActiveOptions = options
			cmds.ActiveOptionsCount = options_count

			all_options = table.Merge(all_options, options)
			all_options_count = all_options_count + options_count
		end

		table.sort(all_options)

		if all_options_count == 0 then
			stop_auto_completion()
			return
		end

		active_options_index = 1

		local pos_x = 0

		hook.Add("HUDPaint", hook_name, function()
			if not EasyChat.IsOpened() then
				stop_auto_completion()
				return
			end

			-- only keep options that will fit on the screen
			local chat_x, chat_y = chat.GetChatBoxPos()
			local chat_w = chat.GetChatBoxSize()
			local above_screen_height = false
			local option_h = draw.GetFontHeight(option_font) + 10 -- account for wordbox padding
			local i = 1
			for option in SortedPairs(all_options) do
				local pos_y = chat_y + ((i + 1) * option_h)
				if pos_y > ScrH() then
					all_options[option] = nil
					above_screen_height = true
					all_options_count = all_options_count - 1
				end
				i = i + 1
			end

			local should_left_side = EasyChat.IsOnRightSide()

			-- account for the panel that shows people that can "hear" you
			local cur_mode = EasyChat.GetCurrentMode()
			local localui_panel = EasyChat.GUI.LocalPanel
			local is_local_mode = cur_mode and cur_mode.Name == "Local" and IsValid(localui_panel)

			local j = 0
			local max_w = 0
			for option, option_args in SortedPairs(all_options) do
				local pos_y = chat_y + (j * option_h)
				local option_w = draw.WordBox(4, pos_x, pos_y, option, option_font, black_color, color_white)
				if option_w and option_w > max_w then max_w = option_w end

				for arg_index, arg in ipairs(option_args) do
					local arg_w = draw.WordBox(4, pos_x + (arg_index * 130), pos_y, arg, option_font, black_color, color_white)
					if arg_w and (arg_index * 130) + arg_w > max_w then max_w = (arg_index * 130) + arg_w end
				end

				j = j + 1
			end

			if above_screen_height then
				draw.WordBox(4, pos_x, chat_y + (i * option_h), "...", option_font, black_color, color_white)
			end

			if should_left_side then
				pos_x = chat_x - max_w - 2
				if is_local_mode then
					pos_x = pos_x - 5 - localui_panel:GetWide()
				end
			else
				pos_x = chat_x + chat_w + 2
				if is_local_mode then
					pos_x = pos_x + 5 + localui_panel:GetWide()
				end
			end
		end)
	end)

	hook.Add("OnChatTab", hook_name, function(text)
		if not EC_CMDS_SUGGESTIONS:GetBool() then return end

		local all_options = {}
		local all_options_count = 0

		for identifier in SortedPairsByValue(EasyChat.CmdSuggestions.Priorities) do
			local cmds = EasyChat.CmdSuggestions.Handlers[identifier]
			if cmds.ActiveOptionsCount == 0 then continue end
			if not cmds.ActiveOptions then continue end
			if text:match(" ") then continue end

			all_options = table.Merge(all_options, cmds.ActiveOptions)
			all_options_count = all_options_count + cmds.ActiveOptionsCount
		end

		table.sort(all_options)

		local i = 1
		for option in SortedPairs(all_options) do
			if i == active_options_index then
				active_options_index = active_options_index + 1
				if active_options_index > all_options_count then
					active_options_index = 1
				end

				return option
			end

			i = i + 1
		end
	end)

	hook.Add("ECPostLoadModules", hook_name, function()
		ChatCommands = list.Get("ChatCommands")
		if not table.IsEmpty(ChatCommands) then
			local commands = {}
			for chat_cmd in pairs(ChatCommands) do
				commands[chat_cmd] = {}
			end

			EasyChat.CmdSuggestions:AddSuggestionHandler("ChatCommands", "[!/\\%.]", commands, -1)
		end
	end)

	hook.Add("FinishChat", hook_name, stop_auto_completion)
	hook.Add("ECTabChanged", hook_name, stop_auto_completion)
	hook.Add("ECFactoryReset", hook_name, function() EC_CMDS_SUGGESTIONS:SetString(EC_CMDS_SUGGESTIONS:GetDefault()) end)
end

return "Commands Auto-Completion"
