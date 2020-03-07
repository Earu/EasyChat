local EASYCHAT_AUTO_COMPLETION = "EASY_CHAT_MODULE_CMDS_AUTO_COMPLETION"

if SERVER then
	if aowl then
		util.AddNetworkString(EASYCHAT_AUTO_COMPLETION)

		net.Receive(EASYCHAT_AUTO_COMPLETION, function(_, ply)
			local cmds_str = ""
			for cmd_name in pairs(aowl.cmds) do
				cmds_str = ("%s,%s"):format(cmds_str, cmd_name)
			end

			timer.Simple(0, function()
				net.Start(EASYCHAT_AUTO_COMPLETION)
				net.WriteString(cmds_str)
				net.Send(ply)
			end)
		end)
	end
end

if CLIENT then
	local EC_CMDS_SUGGESTIONS = CreateConVar("easychat_cmd_suggestions", "1", FCVAR_ARCHIVE, "Shows suggestions for commands")
	EasyChat.RegisterConvar(EC_CMDS_SUGGESTIONS, "Displays command suggestions")

	local black_color = Color(0, 0, 0, 200)
	local option_font = "EasyChatFont"
	local hook_name = "EasyChatModuleCmdsAutoComplete"

	local cmds = {
		Lookup = {},
		Prefix = "",
		Initialized = false,
	}

	local function initialize(prefix, lookup)
		cmds.Prefix = prefix
		cmds.Lookup = lookup
		cmds.Initialized = true
		cmds.ActiveOptionsIndex = 1
		cmds.ActiveOptions = {}
		cmds.ActiveOptionsCount = 0
	end

	local function stop_auto_completion()
		hook.Remove("HUDPaint", hook_name)
		cmds.ActiveOptions = {}
		cmds.ActiveOptionsCount = 0
	end

	if ulx and ULib then
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

		initialize("!", generate_ulx_cmds_lookup())
	elseif aowl then
		net.Receive(EASYCHAT_AUTO_COMPLETION, function()
			local aowl_cmds = {}
			local cmds_str = net.ReadString()
			for cmd_name, _ in pairs(aowl.cmds) do
				aowl_cmds[cmd_name] = {}
			end

			local srv_cmds = cmds_str:Split(",")
			for _, cmd_name in ipairs(srv_cmds) do
				aowl_cmds[cmd_name] = {}
			end

			for chat_cmd, _ in pairs(list.Get("ChatCommands")) do
				aowl_cmds[chat_cmd] = {}
			end

			initialize("[!|/|%.]", aowl_cmds)
		end)

		hook.Add("StartChat", hook_name, function()
			net.Start(EASYCHAT_AUTO_COMPLETION)
			net.SendToServer()
			hook.Remove("StartChat", hook_name)
		end)
	end

	hook.Add("ChatTextChanged", hook_name, function(text)
		if not EC_CMDS_SUGGESTIONS:GetBool() then return end

		if not cmds.Initialized then return end
		cmds.ActiveOptionsIndex = 1

		local prefix = text:match(("^%s"):format(cmds.Prefix))
		if not prefix then
			stop_auto_completion()
			return
		end

		local args = text:sub(2):Split(" ")
		-- if we dont have a command dont proceed anyway
		if not args[1] then
			stop_auto_completion()
			return
		end

		local cmd = args[1]:lower():PatternSafe()
		table.remove(args, 1) -- remove the command from the args

		local options_count = 0
		local options = {}
		for cmd_name, cmd_args in pairs(cmds.Lookup) do
			if cmd_name:match(cmd) then
				options[("%s%s"):format(prefix, cmd_name)] = cmd_args
				options_count = options_count + 1
			end
		end

		if options_count == 0 then
			stop_auto_completion()
			return
		end

		table.sort(options)
		cmds.ActiveOptions = options
		cmds.ActiveOptionsCount = options_count

		-- only keep options that will fit on the screen
		local chat_x, chat_y = chat.GetChatBoxPos()
		local chat_w, _ = chat.GetChatBoxSize()
		local above_screen_height = false
		local option_h = draw.GetFontHeight(option_font) + 10 -- account for wordbox padding
		local i = 1
		for option, _ in pairs(options) do
			local pos_y = chat_y + ((i + 1) * option_h)
			if pos_y > ScrH() then
				options[option] = nil
				above_screen_height = true
				options_count = options_count - 1
			end
			i = i + 1
		end

		local pos_x = chat_x + chat_w + 2

		-- account for the panel that shows people that can "hear" you
		local cur_mode = EasyChat.GetCurrentMode()
		local localui_panel = EasyChat.GUI.LocalPanel
		if cur_mode and cur_mode.Name == "Local" and IsValid(localui_panel) then
			pos_x = pos_x + localui_panel:GetWide()
		end

		hook.Add("HUDPaint", hook_name, function()
			if not EasyChat.IsOpened() then
				stop_auto_completion()
				return
			end

			local i = 0
			for option, option_args in pairs(options) do
				local pos_y = chat_y + (i * option_h)
				draw.WordBox(4, pos_x, pos_y, option, option_font, black_color, color_white)

				for arg_index, arg in ipairs(option_args) do
					draw.WordBox(4, pos_x + (arg_index * 130), pos_y, arg, option_font, black_color, color_white)
				end

				i = i + 1
			end

			if above_screen_height then
				draw.WordBox(4, pos_x, chat_y + (i * option_h), "...", option_font, black_color, color_white)
			end
		end)
	end)

	hook.Add("OnChatTab", hook_name, function(text)
		if not EC_CMDS_SUGGESTIONS:GetBool() then return end
		if cmds.ActiveOptionsCount == 0 then return end
		if text:match(" ") then return end

		local i = 1
		for option, _ in pairs(cmds.ActiveOptions) do
			if i == cmds.ActiveOptionsIndex then
				cmds.ActiveOptionsIndex = cmds.ActiveOptionsIndex + 1
				if cmds.ActiveOptionsIndex > cmds.ActiveOptionsCount then
					cmds.ActiveOptionsIndex = 1
				end

				return option
			end

			i = i + 1
		end
	end)

	hook.Add("FinishChat", hook_name, stop_auto_completion)
end

return "Commands Auto-Completion"
