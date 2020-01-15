local EasyChat = _G.EasyChat or {}
_G.EasyChat = EasyChat

local print  = _G._print or _G.print --epoe compat

local NET_BROADCAST_MSG = "EASY_CHAT_BROADCAST_MSG"
local NET_SEND_MSG      = "EASY_CHAT_RECEIVE_MSG"
local NET_SET_TYPING    = "EASY_CHAT_START_CHAT"

local PLY = FindMetaTable("Player")
local TAG = "EasyChat"

local load_modules, get_modules = include("easychat/autoloader.lua")
EasyChat.GetModules = get_modules -- maybe useful for modules?

function PLY:ECIsEnabled()
	return self:GetInfoNum("easychat_enable", 0) == 1
end

PLY.old_IsTyping = PLY.old_IsTyping or PLY.IsTyping
function PLY:IsTyping()
	if self:ECIsEnabled() then
		return self:GetNWBool("ec_is_typing", false)
	else
		return self:old_IsTyping()
	end
end

if SERVER then
	util.AddNetworkString(NET_SEND_MSG)
	util.AddNetworkString(NET_BROADCAST_MSG)
	util.AddNetworkString(NET_SET_TYPING)

	net.Receive(NET_SEND_MSG, function(len, ply)
		local str = net.ReadString()
		local is_team = net.ReadBool()
		local is_local = net.ReadBool()
		local msg = gamemode.Call("PlayerSay", ply, str, is_team)

		if type(msg) ~= "string" or msg:Trim() == "" then return end

		local filter = {}
		local broken_count = 1
		local add_to_filter = function(ply)
			local id = ply:AccountID()
			if not id then
				filter[broken_count] = ply
				broken_count = broken_count + 1
			else
				filter[id] = ply
			end
		end

		add_to_filter(ply)
		for _, listener in ipairs(player.GetAll()) do
			if listener ~= ply then
				local can_see = gamemode.Call("PlayerCanSeePlayersChat", msg, is_team, listener, ply, is_local)
				if can_see == true then -- can be another type than a bool
					add_to_filter(listener)
				elseif can_see == false then -- can be nil so need to check for false
					filter[listener:AccountID() or 0] = nil
				end
			end
		end

		filter = table.ClearKeys(filter)

		net.Start(NET_BROADCAST_MSG)
		net.WriteEntity(ply)
		net.WriteString(msg)
		net.WriteBool(IsValid(ply) and (not ply:Alive()) or false)
		net.WriteBool(is_team)
		net.WriteBool(is_local)
		net.Send(filter)

		print(ply:Nick():gsub("<.->", "") .. ": " .. msg) -- shows in server console
	end)

	net.Receive(NET_SET_TYPING, function(len, ply)
		local is_opened = net.ReadBool()
		ply:SetNWBool("ec_is_typing", is_opened)
		hook.Run(is_opened and "ECOpened" or "ECClosed", ply)
	end)

	function EasyChat.Init()
		hook.Run("ECPreLoadModules")
		load_modules()
		hook.Run("ECPostLoadModules")
		hook.Run("ECInitialized")
	end

	function EasyChat.PlayerCanSeePlayersChat(_, _, listener, speaker, is_local)
		if is_local then
			if not IsValid(listener) or not IsValid(speaker) then
				return false
			end
			if is_local and listener:GetPos():Distance(speaker:GetPos()) > speaker:GetInfoNum("easychat_local_msg_distance", 150) then
				return false
			end
		end
	end

	hook.Add("Initialize", TAG, EasyChat.Init)
	hook.Add("PlayerCanSeePlayersChat", TAG, EasyChat.PlayerCanSeePlayersChat)
end

if CLIENT then
	local MAX_CHARS = 3000
	local JSON_COLS = file.Read("easychat/colors.txt", "DATA")

	local EC_GLOBAL_ON_OPEN = CreateConVar("easychat_global_on_open", "1", FCVAR_ARCHIVE, "Set the chat to always open global chat tab on open")
	local EC_FONT           = CreateConVar("easychat_font", "Roboto", FCVAR_ARCHIVE, "Set the font to use for the chat")
	local EC_FONT_SIZE      = CreateConVar("easychat_font_size", "15", FCVAR_ARCHIVE, "Set the font size for chatbox")
	local EC_TIMESTAMPS     = CreateConVar("easychat_timestamps", "0", FCVAR_ARCHIVE, "Display timestamp in front of messages or not")
	local EC_TEAMS          = CreateConVar("easychat_teams", "0", FCVAR_ARCHIVE, "Display team in front of messages or not")
	local EC_TEAMS_COLOR    = CreateConVar("easychat_teams_colored", "0", FCVAR_ARCHIVE, "Display team with its relative color")
	local EC_PLAYER_COLOR   = CreateConVar("easychat_players_colored", "1", FCVAR_ARCHIVE, "Display player with its relative team color")
	local EC_ENABLE         = CreateConVar("easychat_enable", "1", {FCVAR_ARCHIVE, FCVAR_USERINFO}, "Use easychat or not")
	local EC_ENABLEBROWSER  = CreateConVar("easychat_enablebrowser", "0", {FCVAR_ARCHIVE, FCVAR_USERINFO}, "Use easychat browser or not")
	local EC_DERMASKIN      = CreateConVar("easychat_use_dermaskin", "0", {FCVAR_ARCHIVE, FCVAR_USERINFO}, "Use dermaskin look or not")
	local EC_LOCAL_MSG_DIST = CreateConVar("easychat_local_msg_distance", "300", FCVAR_ARCHIVE, "Set the maximum distance for users to receive local messages")
	local EC_NO_MODULES     = CreateConVar("easychat_no_modules", "0", FCVAR_ARCHIVE, "Should easychat load modules or not")
	local EC_HUD_FOLLOW     = CreateConVar("easychat_hud_follow", "0", FCVAR_ARCHIVE, "Set the chat hud to follow the chatbox")
	local EC_TICK_SOUND     = CreateConVar("easychat_tick_sound", "1", FCVAR_ARCHIVE, "Should a tick sound be played on new messages or not")
	local EC_HUD_TTL        = CreateConVar("easychat_hud_ttl", "16", FCVAR_ARCHIVE, "How long messages stay before vanishing")
	local EC_TIMESTAMPS_12  = CreateConVar("easychat_timestamps_12", "0", FCVAR_ARCHIVE, "Display timestamps in 12 hours mode or not")
	local EC_HISTORY        = CreateConVar("easychat_history", "1", FCVAR_ARCHIVE, "Should the history be shown")
	local EC_USE_ME         = CreateConVar("easychat_use_me", "0", FCVAR_ARCHIVE, 'Should the chat display your name or "me"')
	local EC_HUD_SMOOTH     = CreateClientConVar("easychat_hud_smooth", "1", true, false, "Enables chat smoothing")
	local EC_PLAYER_PASTEL  = CreateClientConVar("easychat_pastel", "0", true, false, "Should players have pastelized colors instead of their team color")

	EasyChat.UseDermaSkin = EC_DERMASKIN:GetBool()

	cvars.AddChangeCallback("easychat_enable", function(name, old, new)
		if EC_ENABLE:GetBool() then
			EasyChat.Init()
		else
			EasyChat.Destroy()
			net.Start(NET_SET_TYPING) -- this is useful if a user disable easychat with console mode
			net.WriteBool(true)
			net.SendToServer()
		end
	end)

	cvars.AddChangeCallback("easychat_use_dermaskin", function(name, old, new)
		EasyChat.UseDermaSkin = EC_DERMASKIN:GetBool()
		LocalPlayer():ConCommand("easychat_reload")
	end)

	EasyChat.FontName = EC_FONT:GetString()
	EasyChat.FontSize = EC_FONT_SIZE:GetInt()

	local function UpdateChatBoxFont(fontname, size)
		EasyChat.FontName = fontname
		EasyChat.FontSize = size
		surface.CreateFont("EasyChatFont",{
			font = fontname,
			extended = true,
			size = size,
			weight = 530,
			shadow = false,
			additive = false
		})
	end

	UpdateChatBoxFont(EasyChat.FontName, EasyChat.FontSize)

	cvars.AddChangeCallback("easychat_font", function(name, old, new)
		UpdateChatBoxFont(new, EasyChat.FontSize)
	end)

	cvars.AddChangeCallback("easychat_font_size", function(name, old, new)
		UpdateChatBoxFont(EasyChat.FontName, tonumber(new))
	end)

	if JSON_COLS then
		local colors = util.JSONToTable(JSON_COLS)
		EasyChat.OutlayColor = colors.outlay
		EasyChat.OutlayOutlineColor = colors.outlayoutline
		EasyChat.TabOutlineColor = colors.taboutline
		EasyChat.TabColor = colors.tab
	else
		EasyChat.OutlayColor = Color(62, 62, 62, 255)
		EasyChat.OutlayOutlineColor = Color(0, 0, 0, 0)
		EasyChat.TabOutlineColor = Color(0, 0, 0, 0)
		EasyChat.TabColor = Color(36, 36, 36, 255)
	end

	EasyChat.TextColor = Color(255, 255, 255, 255)
	EasyChat.Mode = 0
	EasyChat.Modes = {}
	EasyChat.Expressions = include("easychat/client/expressions.lua")
	EasyChat.ChatHUD = include("easychat/client/chathud.lua")
	EasyChat.ModeCount = 0

	include("easychat/client/markup.lua")

	local ec_tabs = {}
	local ec_convars = {}

	-- after easychat var declarations [necessary]
	include("easychat/client/chatbox_panel.lua")
	include("easychat/client/browser_panel.lua")
	include("easychat/client/chat_tab.lua")
	include("easychat/client/settings_tab.lua")
	include("easychat/client/chathud_font_editor_panel.lua")

	function EasyChat.RegisterConvar(convar, desc)
		table.insert(ec_convars, {
			Convar = convar,
			Description = desc
		})
	end

	function EasyChat.GetRegisteredConvars()
		return ec_convars
	end

	function EasyChat.AddMode(name, callback)
		table.insert(EasyChat.Modes, { Name = name, Callback = callback })
		EasyChat.ModeCount = #EasyChat.Modes
	end

	function EasyChat.IsOpened()
		return EasyChat.GUI and IsValid(EasyChat.GUI.ChatBox) and EasyChat.GUI.ChatBox:IsVisible()
	end

	function EasyChat.GetDefaultBounds()
		local coef_w, coef_h = (ScrW() / 2560), (ScrH() / 1440)
		return 50 * coef_w, ScrH() - (320 + (coef_h * 250)), 550, 320
	end

	local function open_chatbox(is_team)
		local ok = hook.Run("ECShouldOpen")
		if ok == false then return end

		ok = hook.Run("StartChat", is_team)
		if ok == true then return end

		EasyChat.GUI.ChatBox:Show()
		EasyChat.GUI.ChatBox:MakePopup()
		EasyChat.Mode = is_team and 1 or 0

		if EC_GLOBAL_ON_OPEN:GetBool() then
			EasyChat.GUI.TabControl:SetActiveTab(EasyChat.GUI.TabControl.Items[1].Tab)
			EasyChat.GUI.TextEntry:RequestFocus()
		end

		EasyChat.GUI.TextEntry:SetText("")

		hook.Run("ECOpened", LocalPlayer())

		net.Start(NET_SET_TYPING)
		net.WriteBool(true)
		net.SendToServer()
	end

	local function save_chatbox_bounds()
		local x, y, w, h = EasyChat.GUI.ChatBox:GetBounds()
		local tab = {
			w = w,
			h = h,
			x = x,
			y = y
		}

		local json = util.TableToJSON(tab, true)
		file.CreateDir("easychat")
		file.Write("easychat/possize.txt", json)
	end

	local function load_chatbox_bounds()
		local x, y, w, h = EasyChat.GetDefaultBounds()
		local json = file.Read("easychat/possize.txt", "DATA")
		if not json then return x, y, w, h end

		local tab = util.JSONToTable(json)
		if tab then
			if tab.x >= ScrW() then
				tab.x = x
			end
			if tab.y >= ScrH() then
				tab.y = y
			end
			if tab.w >= ScrW() then
				tab.w = w
			end
			if tab.h >= ScrH() then
				tab.h = h
			end
			return tab.x, tab.y, tab.w, tab.h
		else
			return x, y, w, h
		end
	end

	local function close_chatbox()
		if EasyChat.IsOpened() then
			EasyChat.GUI.ChatBox:SetMouseInputEnabled(false)
			EasyChat.GUI.ChatBox:SetKeyboardInputEnabled(false)
			gui.EnableScreenClicker(false)
			EasyChat.GUI.TextEntry:SetText("")
			chat.old_Close()
			gamemode.Call("ChatTextChanged", "")
			gamemode.Call("FinishChat")
			save_chatbox_bounds()
			EasyChat.GUI.ChatBox:Hide()
			hook.Run("ECClosed", LocalPlayer())
			net.Start(NET_SET_TYPING)
			net.WriteBool(false)
			net.SendToServer()
		end
	end

	function EasyChat.IsURL(str)
		local patterns = {
			'https?://[^%s%"]+',
			'ftp://[^%s%"]+',
			'steam://[^%s%"]+',
		}

		for index, pattern in ipairs(patterns) do
			if str:match(pattern) then
				return true
			end
		end

		return false
	end

	function EasyChat.OpenURL(url)
		if not EC_ENABLEBROWSER:GetBool() then
			gui.OpenURL(url)
			return
		end

		local ok = hook.Run("ECOpenURL", url)
		if ok == false then return end

		local browser = vgui.Create("ECBrowser")
		browser:MakePopup()
		browser:OpenURL(url or "www.google.com")
	end

	local ec_addtext_handles = {}
	function EasyChat.SetAddTextTypeHandle(type, callback)
		ec_addtext_handles[type] = callback
	end

	function EasyChat.GetSetAddTextTypeHandle(type)
		return ec_addtext_handles[type]
	end

	function EasyChat.Init()
		-- reset for reload
		EasyChat.TextColor = Color(255, 255, 255, 255)
		EasyChat.Mode = 0
		EasyChat.Modes = {}
		EasyChat.Expressions = include("easychat/client/expressions.lua")
		EasyChat.ChatHUD = include("easychat/client/chathud.lua")
		EasyChat.ModeCount = 0

		include("easychat/client/markup.lua")

		ec_convars = {}
		ec_addtext_handles = {}

		EasyChat.RegisterConvar(EC_GLOBAL_ON_OPEN, "Open chatbox in global tab")
		EasyChat.RegisterConvar(EC_HISTORY, "Enable history")
		EasyChat.RegisterConvar(EC_TIMESTAMPS, "Display timestamps")
		EasyChat.RegisterConvar(EC_TIMESTAMPS_12, "12 hours mode timestamps")
		EasyChat.RegisterConvar(EC_TEAMS, "Display teams")
		EasyChat.RegisterConvar(EC_TEAMS_COLOR, "Color the team tags")
		EasyChat.RegisterConvar(EC_PLAYER_COLOR, "Color players in their team color")
		EasyChat.RegisterConvar(EC_HUD_FOLLOW, "Chathud follows chatbox")
		EasyChat.RegisterConvar(EC_TICK_SOUND, "Tick sound on new messages")
		EasyChat.RegisterConvar(EC_HUD_SMOOTH, "Smooth chathud")

		EasyChat.AddMode("Team", function(text)
			net.Start(NET_SEND_MSG)
			net.WriteString(text:sub(1, MAX_CHARS))
			net.WriteBool(true)
			net.WriteBool(false)
			net.SendToServer()
		end)

		EasyChat.AddMode("Local", function(text)
			net.Start(NET_SEND_MSG)
			net.WriteString(text:sub(1, MAX_CHARS))
			net.WriteBool(false)
			net.WriteBool(true)
			net.SendToServer()
		end)

		EasyChat.AddMode("Console", function(text)
			LocalPlayer():ConCommand(text)
		end)

		EasyChat.SetAddTextTypeHandle("table", function(col)
			EasyChat.InsertColorChange(col.r or 255, col.g or 255, col.b or 255, col.a or 255)
		end)

		EasyChat.SetAddTextTypeHandle("string", function(str)
			if EasyChat.IsURL(str) then
				local words = (" "):Explode(str)
				for k, v in ipairs(words) do
					if k > 1 then
						EasyChat.AppendText(" ")
					end
					if EasyChat.IsURL(v) then
						local url = v:gsub("^%s:", "")
						EasyChat.GUI.RichText:InsertClickableTextStart(url)
						EasyChat.AppendText(url)
						EasyChat.GUI.RichText:InsertClickableTextEnd()
					else
						EasyChat.AppendText(v)
					end
				end
			else
				EasyChat.AppendText(str)
			end
		end)

		local function string_hash(text)
			local counter = 1
			local len = string.len(text)
			for i = 1, len, 3 do
				counter =
					math.fmod(counter * 8161, 4294967279) + -- 2^32 - 17: Prime!
					(text:byte(i) * 16776193) +
					((text:byte(i + 1) or (len - i + 256)) * 8372226) +
					((text:byte(i + 2) or (len - i + 256)) * 3932164)
			end

			return math.fmod(counter, 4294967291) -- 2^32 - 5: Prime (and different from the prime in the loop)
		end

		local function pastelize_nick(nick, small_seed)
			local hue = string_hash(nick) + (small_seed or 0)
			local saturation, value = hue % 3 == 0, hue % 127 == 0
			return HSVToColor(hue % 180 * 2, saturation and 0.3 or 0.6, value and 0.6 or 1)
		end

		EasyChat.SetAddTextTypeHandle("Player", function(ply)
			local team_color = EC_PLAYER_COLOR:GetBool() and team.GetColor(ply:Team()) or Color(255, 255, 255)
			EasyChat.InsertColorChange(team_color.r, team_color.g, team_color.b, 255)

			if EC_PLAYER_PASTEL:GetBool() and ec_markup then
				local nick = ec_markup.Parse(ply:Nick(), nil, true):GetText()
				local pastel_color = pastelize_nick(nick)
				EasyChat.InsertColorChange(pastel_color.r, pastel_color.g, pastel_color.b, 255)
			end

			local lp = LocalPlayer()
			if IsValid(lp) and lp == ply and EC_USE_ME:GetBool() then
				EasyChat.AppendText("me")
			else
				EasyChat.AppendNick(ply:Nick())
			end
		end)

		function EasyChat.SaveToHistory(name, content)
			if not name or not content then return end
			if content:Trim() == "" then return end

			if not file.Exists("easychat", "DATA") then
				file.CreateDir("easychat")
			end

			local filename = "easychat/" .. name:lower() .. "_history.txt"
			if not file.Exists(filename, "DATA") then
				file.Write(filename, content)
			else
				file.Append(filename, content)
			end
		end

		function EasyChat.ReadFromHistory(name)
			if not name then return "" end

			local filename = "easychat/" .. name:lower() .. "_history.txt"
			if not file.Exists(filename, "DATA") then
				return ""
			end

			return file.Read(filename, "DATA")
		end

		local function append_text(richtext, txt)
			if richtext.HistoryName then
				richtext.Log = richtext.Log and richtext.Log .. txt or txt
			end

			richtext:AppendText(txt)
		end

		local function save_text(richtext)
			if not richtext.HistoryName then return end

			EasyChat.SaveToHistory(richtext.HistoryName, richtext.Log)
			richtext.Log = ""
		end

		function EasyChat.AddText(tab, richtext, ...)
			append_text(richtext, "\n")

			if EC_TIMESTAMPS:GetBool() then
				if EC_TIMESTAMPS_12:GetBool() then
					append_text(richtext, os.date("%I:%M %p") .. " - ")
				else
					append_text(richtext, os.date("%H:%M") .. " - ")
				end
			end

			local args = {...}
			for _, arg in ipairs(args) do
				if type(arg) == "string" then
					if not EasyChat.UseDermaSkin then
						richtext:InsertColorChange(255, 255, 255, 255)
					end

					if EasyChat.IsURL(arg) then
						local words = (" "):Explode(arg)
						for k, v in ipairs(words) do
							if k > 1 then
								append_text(richtext, " ")
							end

							if EasyChat.IsURL(v) then
								local url = v:gsub("^%s:", "")
								richtext:InsertClickableTextStart(url)
								append_text(richtext, url)
								richtext:InsertClickableTextEnd()
							else
								append_text(richtext, v)
							end
						end
					else
						append_text(richtext, arg)
					end
				elseif type(arg) == "Player" then
					append_text(richtext, (EC_USE_ME:GetBool() and arg == LocalPlayer()) and "me" or arg:Nick())
				elseif type(arg) == "table" then
					richtext:InsertColorChange(arg.r or 255, arg.g or 255, arg.b or 255, arg.a or 255)
				end
			end

			save_text(richtext)
		end

		do
			chat.old_AddText = chat.old_AddText or chat.AddText
			chat.old_GetChatBoxPos = chat.old_GetChatBoxPos or chat.GetChatBoxPos
			chat.old_GetChatBoxSize = chat.old_GetChatBoxSize or chat.GetChatBoxSize
			chat.old_Open = chat.old_Open or chat.Open
			chat.old_Close = chat.old_Close or chat.Close

			function chat.AddText(...)
				EasyChat.ChatHUD:NewLine()
				append_text(EasyChat.GUI.RichText, "\n")
				EasyChat.InsertColorChange(255, 255, 255, 255)

				if EC_ENABLE:GetBool() then
					if EC_TIMESTAMPS:GetBool() then
						if EC_TIMESTAMPS_12:GetBool() then
							EasyChat.AppendText(os.date("%I:%M %p") .. " - ")
						else
							EasyChat.AppendText(os.date("%H:%M") .. " - ")
						end
					end
				end

				local args = {...}
				for _, arg in ipairs(args) do
					local callback = ec_addtext_handles[type(arg)]
					if callback then
						pcall(callback, arg)
					else
						local str = tostring(arg)
						EasyChat.AppendText(str)
					end
				end

				EasyChat.ChatHUD:PushPartComponent("stop")
				EasyChat.ChatHUD:InvalidateLayout()

				chat.old_AddText(...)
				save_text(EasyChat.GUI.RichText)

				if EC_TICK_SOUND:GetBool() then
					chat.PlaySound()
				end
			end

			function chat.GetChatBoxPos()
				if EasyChat.GUI and IsValid(EasyChat.GUI.ChatBox) then
					local x, y, _, _ = EasyChat.GUI.ChatBox:GetBounds()
					return x, y
				else
					return chat.old_GetChatBoxPos()
				end
			end

			function chat.GetChatBoxSize()
				if EasyChat.GUI and IsValid(EasyChat.GUI.ChatBox) then
					local _, _, w, h = EasyChat.GUI.ChatBox:GetBounds()
					return w, h
				else
					return chat.old_GetChatBoxSize()
				end
			end

			function chat.Open(input)
				local is_team = input == 0
				open_chatbox(is_team)
				--chat.old_Open(input)
			end

			chat.Close = close_chatbox
		end

		do
			local chatbox_frame = vgui.Create("ECChatBox")
			local cx, cy, cw, ch = load_chatbox_bounds()
			chatbox_frame:SetSize(cw, ch)
			chatbox_frame:SetPos(cx, cy)
			chatbox_frame.BtnClose.DoClick = close_chatbox

			chatbox_frame.Tabs.OnActiveTabChanged = function(oldtab, newtab)
				hook.Run("ECTabChanged", oldtab.Name, newtab.Name)
			end

			function EasyChat.AddTab(name, panel)
				local tab = chatbox_frame.Tabs:AddSheet(name, panel)
				tab.Tab.Name = name
				tab.Tab:SetFont("EasyChatFont")
				tab.Tab:SetTextColor(Color(255, 255, 255))
				ec_tabs[name] = tab
				panel:Dock(FILL)

				if not EasyChat.UseDermaSkin then
					function panel:Paint(w, h)
						surface.SetDrawColor(EasyChat.TabColor)
						surface.DrawRect(0, 0, w, h)
						surface.SetDrawColor(EasyChat.TabOutlineColor)
						surface.DrawOutlinedRect(0, 0, w, h)
					end

					function tab.Tab:Paint(w, h)
						if self == chatbox_frame.Tabs:GetActiveTab() then
							self.Flashed = false
							surface.SetDrawColor(EasyChat.TabColor)
						else
							if self.Flashed then
								surface.SetDrawColor(
									math.abs(math.sin(CurTime() * 3) * 244),
									math.abs(math.sin(CurTime() * 3) * 167),
									math.abs(math.sin(CurTime() * 3) * 66),
									255
								)
							else
								surface.SetDrawColor(Color(0, 0, 0, 0))
							end
						end

						surface.DrawRect(0, 0, w, h)
						if self == chatbox_frame.Tabs:GetActiveTab() then
							surface.SetDrawColor(EasyChat.TextColor)
							surface.DisableClipping(true)
							surface.DrawRect(0, -2, w, 2)
							surface.DisableClipping(false)

							surface.SetDrawColor(EasyChat.TabOutlineColor)
							surface.DrawLine(0, 0, 0, h)
							surface.DrawLine(w - 1, 0, w - 1, h)
						end
					end
				end
			end

			function EasyChat.GetTab(name)
				if ec_tabs[name] then
					return ec_tabs[name]
				else
					return nil
				end
			end

			function EasyChat.GetActiveTab()
				local active = chatbox_frame.Tabs:GetActiveTab()
				return ec_tabs[active.Name]
			end

			function EasyChat.SetFocusForOn(name, panel)
				if ec_tabs[name] then
					ec_tabs[name].Tab.FocusOn = panel
				end
			end

			function EasyChat.FlashTab(name)
				if ec_tabs[name] then
					ec_tabs[name].Tab.Flashed = true
				end
			end

			local global_tab = vgui.Create("ECChatTab")
			EasyChat.AddTab("Global", global_tab)
			EasyChat.SetFocusForOn("Global", global_tab.TextEntry)

			if not EasyChat.UseDermaSkin then
				global_tab.RichText:InsertColorChange(255, 255, 255, 255)
			end

			global_tab.RichText.HistoryName = "global"
			if EC_HISTORY:GetBool() then
				local history = EasyChat.ReadFromHistory("global")
				if history:Trim() ~= "" then
					global_tab.RichText:AppendText(history)
					local historynotice = "\n^^^^^ Last Session History ^^^^^\n\n"
					global_tab.RichText:AppendText(historynotice)
					EasyChat.SaveToHistory("global", historynotice)
					global_tab.RichText:GotoTextEnd()
				end
			end

			-- Only the neccesary elements --
			EasyChat.GUI = {
				ChatBox = chatbox_frame,
				TextEntry = global_tab.TextEntry,
				RichText = global_tab.RichText,
				TabControl = chatbox_frame.Tabs
			}

			hook.Add("Think", TAG, function()
				local chathud = EasyChat.ChatHUD
				if not chathud then return end

				if EC_HUD_FOLLOW:GetBool() then
					local x, y, w, h = chatbox_frame:GetBounds()
					chathud.Pos = {X = x, Y = y}
					chathud.Size = {W = w, H = h}
				else
					local x, y, w, h = EasyChat.GetDefaultBounds()
					chathud.Pos = {X = x, Y = y}
					chathud.Size = {W = w, H = h}
				end
			end)

			close_chatbox()
		end

		function EasyChat.InsertColorChange(r, g, b, a)
			EasyChat.GUI.RichText:InsertColorChange(r, g, b, a)
			EasyChat.ChatHUD:InsertColorChange(r, g, b)
		end

		function EasyChat.AppendText(text)
			EasyChat.ChatHUD:AppendText(text)
			append_text(EasyChat.GUI.RichText, text)
		end

		function EasyChat.AppendNick(str)
			if not ec_markup then
				append_text(EasyChat.GUI.RichText, str)
			else
				-- use markup to get text and colors out of nicks
				local mk = ec_markup.Parse(str, nil, true)
				for _, line in ipairs(mk.Lines) do
					for _, component in ipairs(line.Components) do
						if component.Color then
							local c = component.Color
							EasyChat.GUI.RichText:InsertColorChange(c.r, c.g, c.b, 255)
						elseif component.Type == "text" then
							append_text(EasyChat.GUI.RichText, component.Content)
						end
					end
				end
			end

			EasyChat.GUI.RichText:InsertColorChange(255, 255, 255, 255)

			-- let the chathud do its own thing
			local chathud = EasyChat.ChatHUD
			chathud:AppendNick(str)
			chathud:PushPartComponent("stop")
		end

		local ctrl_shortcuts = {}
		local alt_shortcuts = {}

		local invalid_shortcut_keys = {
			KEY_ENTER = true,
			KEY_PAD_ENTER = true,
			KEY_ESCAPE = true,
			KEY_TAB = true
		}
		local function is_valid_shortcut_key(key)
			return invalid_shortcut_keys[key] and true or false
		end

		local valid_base_keys = {
			KEY_LCONTROL = true,
			KEY_LALT = true,
			KEY_RCONTROL = true,
			KEY_RALT = true
		}
		local function is_base_shortcut_key(key)
			return valid_base_keys[key] and true or false
		end

		function EasyChat.RegisterCTRLShortcut(key, callback)
			if is_valid_shortcut_key(key) then
				ctrl_shortcuts[key] = callback
			end
		end

		function EasyChat.RegisterALTShortcut(key, callback)
			if not is_valid_shortcut_key(key) then
				alt_shortcuts[key] = callback
			end
		end

		function EasyChat.UseRegisteredShortcuts(text_entry, last_key, key)
			if is_base_shortcut_key(last_key) then
				local pos = text_entry:GetCaretPos()
				local first = text_entry:GetText():sub(1, pos + 1)
				local last = text_entry:GetText():sub(pos + 2, #text_entry:GetText())

				if ctrl_shortcuts[key] then
					local retrieved = ctrl_shortcuts[key](text_entry, text_entry:GetText(), pos, first, last)
					if retrieved then
						text_entry:SetText(retrieved)
					end
				elseif alt_shortcuts[key] then
					local retrieved = alt_shortcuts[key](text_entry, text_entry:GetText(), pos, first, last)
					if retrieved then
						text_entry:SetText(retrieved)
					end
				end
			end
		end

		function EasyChat.SetupHistory(text_entry, key)
			if key == KEY_ENTER or key == KEY_PAD_ENTER then
				text_entry:AddHistory(text_entry:GetText())
				text_entry.HistoryPos = 0
			end

			if key == KEY_ESCAPE then
				text_entry.HistoryPos = 0
			end

			if not text_entry.HistoryPos then return end

			if key == KEY_UP then
				text_entry.HistoryPos = text_entry.HistoryPos - 1
				text_entry:UpdateFromHistory()
			elseif key == KEY_DOWN then
				text_entry.HistoryPos = text_entry.HistoryPos + 1
				text_entry:UpdateFromHistory()
			end
		end

		local last_key = KEY_ENTER
		function EasyChat.GUI.TextEntry:OnKeyCodeTyped(code)
			EasyChat.SetupHistory(self, code)
			EasyChat.UseRegisteredShortcuts(self, last_key, code)

			if code == KEY_ESCAPE then
				close_chatbox()
				gui.HideGameUI()
			elseif code == KEY_ENTER or code == KEY_PAD_ENTER then
				self:SetText(self:GetText():Replace("╚​", ""))
				if self:GetText():Trim() ~= "" then
					if EasyChat.Mode == 0 then
						net.Start(NET_SEND_MSG)
						net.WriteString(self:GetText():sub(1, MAX_CHARS))
						net.WriteBool(false)
						net.WriteBool(false)
						net.SendToServer()
					else
						local mode = EasyChat.Modes[EasyChat.Mode]
						mode.Callback(self:GetText())
					end
				end

				close_chatbox()
			end

			last_key = code

			if code == KEY_TAB then
				if self:GetText() ~= "" then
					local autocompletion_text = gamemode.Call("OnChatTab", self:GetText())
					self:SetText(autocompletion_text)
					timer.Simple(0, function()
						self:RequestFocus()
						self:SetCaretPos(#self:GetText())
					end)
				else
					local next_mode = EasyChat.Mode + 1
					EasyChat.Mode = next_mode > EasyChat.ModeCount and 0 or next_mode
				end

				return true
			end
		end

		function EasyChat.GUI.TextEntry:OnValueChange(text)
			gamemode.Call("ChatTextChanged", text)
		end

		function EasyChat.GUI.RichText:ActionSignal(name, value)
			if name == "TextClicked" then
				EasyChat.OpenURL(value)
			end
		end

		hook.Add("PlayerBindPress", TAG, function(ply, bind, pressed)
			if not pressed then return end

			if bind == "messagemode" then
				open_chatbox(false)
				return true
			elseif bind == "messagemode2" then
				open_chatbox(true)
				return true
			end
		end)

		if not EC_NO_MODULES:GetBool() then
			hook.Run("ECPreLoadModules")
			load_modules()
			hook.Run("ECPostLoadModules")
		end

		local settings = vgui.Create("ECSettingsTab")
		EasyChat.AddTab("Settings", settings)

		local chat_text_types = {
			none = true, -- fallback
			darkrp = true -- darkrp compat most likely?
			--namechange = true, -- annoying
			--servermsg = true,  -- annoying
			--teamchange = true, -- annoying
			--chat = true,       -- deprecated
		}
		hook.Add("ChatText", TAG, function(index, name, text, type)
			if chat_text_types[type] then
				chat.AddText(text)
			end
		end)

		local function is_chat_key_pressed()
			local invalid_keys = { KEY_LCONTROL, KEY_LALT, KEY_RCONTROL, KEY_RALT }
			local letters = {
				KEY_A, KEY_B, KEY_C, KEY_D, KEY_E, KEY_F, KEY_G, KEY_H, KEY_I,
				KEY_J, KEY_K, KEY_L, KEY_M, KEY_N, KEY_O, KEY_P, KEY_Q, KEY_R,
				KEY_S, KEY_T, KEY_U, KEY_V, KEY_W, KEY_X, KEY_Y, KEY_Z, KEY_ENTER,
				KEY_TAB, KEY_SPACE, KEY_BACKSPACE
			}

			for _, key in ipairs(invalid_keys) do
				if input.IsKeyDown(key) then
					return false
				end
			end

			for _, key in ipairs(letters) do
				if input.IsKeyDown(key) then
					local key_name = input.GetKeyName(key)
					return true, ((key_name ~= "TAB" and key_name ~= "ENTER") and key_name or "")
				end
			end

			return false
		end

		hook.Add("HUDShouldDraw", TAG, function(hud_element)
			if hud_element == "CHudChat" then
				return false
			end
		end)

		local chathud = EasyChat.ChatHUD
		local x, y, w, h = EasyChat.GetDefaultBounds()
		chathud.Pos = {X = x, Y = y}
		chathud.Size = {W = w, H = h}
		chathud:InvalidateLayout()

		hook.Add("HUDPaint", TAG, function()
			chathud:Draw()
		end)

		-- for getting rid of annoying stuff
		hook.Add("OnPlayerChat", TAG, function(ply, txt)
			if txt == "sh" or txt:match("%ssh%s") then
				chathud:StopComponents()
			end
		end)

		hook.Add("PreRender", TAG, function()
			if EasyChat.IsOpened() then
				if input.IsKeyDown(KEY_ESCAPE) then
					EasyChat.GUI.TextEntry:SetText("")
					close_chatbox()
					gui.HideGameUI()
				end

				local tab = EasyChat.GUI.TabControl:GetActiveTab()
				if tab.FocusOn and not tab.FocusOn:HasFocus() then
					local pressed, key = is_chat_key_pressed()
					if pressed then
						tab.FocusOn:RequestFocus()
						tab.FocusOn:SetText(key)
						tab.FocusOn:SetCaretPos(#tab.FocusOn:GetText())
					end
				end
			end
		end)

		hook.Run("ECInitialized")
	end

	net.Receive(NET_BROADCAST_MSG, function()
		local ply = net.ReadEntity()
		local msg = net.ReadString()
		local dead = net.ReadBool()
		local is_team = net.ReadBool()
		local is_local = net.ReadBool()

		-- so we never have the two together
		if is_local and is_team then
			is_team = false
		end

		gamemode.Call("OnPlayerChat", ply, msg, is_team, dead, is_local)
	end)

	hook.Add("Initialize", TAG, function()
		if EC_ENABLE:GetBool() then
			EasyChat.Init()
		end

		-- this is for the best
		function GAMEMODE:OnPlayerChat(ply, msg, is_team, is_dead, is_local)
			local msg_components = {}

			-- reset color to white
			table.insert(msg_components, Color(255, 255, 255))

			if EC_ENABLE:GetBool() then
				if IsValid(ply) and EC_TEAMS:GetBool() then
					if EC_TEAMS_COLOR:GetBool() then
						local team_color = team.GetColor(ply:Team())
						table.insert(msg_components, team_color)
					end
					table.insert(msg_components, "[" .. team.GetName(ply:Team()) .. "] - ")
				end
			end

			if is_dead then
				table.insert(msg_components, Color(240, 80, 80))
				table.insert(msg_components, "*DEAD* ")
			end

			if is_local == true then
				table.insert(msg_components, Color(120, 210, 255))
				table.insert(msg_components, "(Local) ")
			end

			if is_team then
				table.insert(msg_components, Color(120, 120, 240))
				table.insert(msg_components, "(Team) ")
			end

			if IsValid(ply) then
				table.insert(msg_components, ply)
			else
				table.insert(msg_components, Color(110, 247, 177))
				table.insert(msg_components, "???") -- console or weird stuff
			end

			table.insert(msg_components, Color(255, 255, 255))
			table.insert(msg_components, ": " .. msg)

			chat.AddText(unpack(msg_components))

			return true
		end

		hook.Run("ECPostInitialize")
	end)
end

function EasyChat.Destroy()
	hook.Run("ECPreDestroy")

	if CLIENT then
		hook.Remove("PreRender", TAG)
		hook.Remove("Think", TAG)
		hook.Remove("PlayerBindPress", TAG)
		hook.Remove("HUDShouldDraw", TAG)

		if chat.old_AddText then
			chat.AddText = chat.old_AddText
			chat.GetChatBoxPos = chat.old_GetChatBoxPos
			chat.GetChatBoxSize = chat.old_GetChatBoxSize
			chat.Open = chat.old_Open
			chat.Close = chat.old_Close
		end

		EasyChat.ModeCount = 0
		EasyChat.Mode = 0
		EasyChat.Modes = {}

		if EasyChat.GUI and IsValid(EasyChat.GUI.ChatBox) then
			EasyChat.GUI.ChatBox:Remove()
		end

		if EasyChat.ChatHUD then
			EasyChat.ChatHUD:Clear()
		end
	end

	hook.Run("ECDestroyed")
end

concommand.Add("easychat_reload", function()
	EasyChat.Destroy()
	EasyChat.Init()

	if SERVER then
		for _, v in ipairs(player.GetAll()) do
			v:SendLua([[EasyChat.Destroy() EasyChat.Init()]])
		end
	end
end)