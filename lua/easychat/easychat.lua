local EasyChat = _G.EasyChat or {}
_G.EasyChat = EasyChat

local string   = _G.string
local net	   = _G.net
local print    = _G._print or _G.print --epoe compat
local util	   = _G.util
local player   = _G.player
local PLY	   = FindMetaTable("Player")
local pairs    = _G.pairs
local ipairs   = _G.ipairs

local NET_BROADCAST_MSG 	  = "EASY_CHAT_BROADCAST_MSG"
local NET_SEND_MSG    		  = "EASY_CHAT_RECEIVE_MSG"
local NET_SEND_LOCAL_MSG      = "EASY_CHAT_LOCAL_MSG"
local NET_BROADCAST_LOCAL_MSG = "EASY_CHAT_LOCAL_SEND"
local NET_SET_TYPING	      = "EASY_CHAT_START_CHAT"
local TAG              		  = "EasyChat"
local LoadModules,GetModules  = include("easychat/autoloader.lua")

EasyChat.GetModules = GetModules -- maybe useful for modules?

PLY.ECIsEnabled = function(self)
	return self:GetInfoNum("easychat_enable",0) == 1
end

PLY.old_IsTyping = PLY.old_IsTyping or PLY.IsTyping
PLY.IsTyping = function(self)
	if self:ECIsEnabled() then
		return self:GetNWBool("ec_is_typing",false)
	else
		return self:old_IsTyping()
	end
end

if SERVER then

	util.AddNetworkString(NET_SEND_MSG)
	util.AddNetworkString(NET_BROADCAST_MSG)
	util.AddNetworkString(NET_SEND_LOCAL_MSG)
	util.AddNetworkString(NET_BROADCAST_LOCAL_MSG)
	util.AddNetworkString(NET_SET_TYPING)

	net.Receive(NET_SEND_MSG,function(len,ply)
		local str = net.ReadString()
		local isteam = net.ReadBool()
		local msg = gamemode.Call("PlayerSay",ply,str,isteam)

		if type(msg) ~= "string" or string.Trim(msg) == "" then return end

		net.Start(NET_BROADCAST_MSG)
		net.WriteEntity(ply)
		net.WriteString(msg)
		net.WriteBool(IsValid(ply) and (not ply:Alive()) or false)
		net.WriteBool(isteam)

		if isteam then
			net.Send(team.GetPlayers(ply:Team()))
		else
			net.Broadcast()
			print((string.gsub(ply:Nick(),"<.->",""))..": "..msg) --shows in server console
		end

	end)

	net.Receive(NET_SEND_LOCAL_MSG,function(len,ply)
		local msg = net.ReadString()

		if type(msg) ~= "string" or string.Trim(msg) == "" then return end

		net.Start(NET_BROADCAST_LOCAL_MSG)
		net.WriteEntity(ply)
		net.WriteString(msg)
		net.WriteBool(IsValid(ply) and (not ply:Alive()) or false)

		local receivers = {}
		for _,v in ipairs(player.GetAll()) do
			if IsValid(v) and v:GetPos():Distance(ply:GetPos()) <= ply:GetInfoNum("easychat_local_msg_distance",150) then
				table.insert(receivers,v)
			end
		end

		net.Send(receivers)
	end)

	net.Receive(NET_SET_TYPING,function(len,ply)
		local bool = net.ReadBool()
		ply:SetNWBool("ec_is_typing",bool)

		if bool then
			hook.Run("ECOpened",ply)
		else
			hook.Run("ECClosed",ply)
		end
	end)

	EasyChat.Init = function()
		hook.Run("ECPreLoadModules")
		LoadModules()
		hook.Run("ECPostLoadModules")
		hook.Run("ECInitialized")
	end

	hook.Add('Initialize', TAG, EasyChat.Init)
end

if CLIENT then
	local MAX_CHARS   = 3000
	local JSON_COLS   = file.Read("easychat/colors.txt","DATA")

	local EC_GLOBAL_ON_OPEN = CreateConVar("easychat_global_on_open","1",FCVAR_ARCHIVE,"Set the chat to always open global chat tab on open")
	local EC_FONT 			= CreateConVar("easychat_font",(system.IsWindows() and "Verdana" or "Tahoma"),FCVAR_ARCHIVE,"Set the font to use for the chat")
	local EC_FONT_SIZE 		= CreateConVar("easychat_font_size","15",FCVAR_ARCHIVE,"Set the font size for chatbox")
	local EC_TIMESTAMPS		= CreateConVar("easychat_timestamps","0",FCVAR_ARCHIVE,"Display timestamp in front of messages or not")
	local EC_TEAMS 			= CreateConVar("easychat_teams","0",FCVAR_ARCHIVE,"Display team in front of messages or not")
	local EC_TEAMS_COLOR 	= CreateConVar("easychat_teams_colored","0",FCVAR_ARCHIVE,"Display team with its relative color")
	local EC_PLAYER_COLOR 	= CreateConVar("easychat_players_colored","1",FCVAR_ARCHIVE,"Display player with its relative team color")
	local EC_ENABLE 		= CreateConVar("easychat_enable","1",{FCVAR_ARCHIVE,FCVAR_USERINFO},"Use easychat or not")
	local EC_ENABLEBROWSER	= CreateConVar("easychat_enablebrowser","1",{FCVAR_ARCHIVE,FCVAR_USERINFO},"Use easychat browser or not")
	local EC_DERMASKIN 		= CreateConVar("easychat_use_dermaskin","0",{FCVAR_ARCHIVE,FCVAR_USERINFO},"Use dermaskin look or not")
	local EC_LOCAL_MSG_DIST = CreateConVar("easychat_local_msg_distance","300",FCVAR_ARCHIVE,"Set the maximum distance for users to receive local messages")
	local EC_NO_MODULES 	= CreateConVar("easychat_no_modules","0",FCVAR_ARCHIVE,"Should easychat load modules or not")
	local EC_HUD_FOLLOW 	= CreateConVar("easychat_hud_follow","0",FCVAR_ARCHIVE,"Set the chat hud to follow the chatbox")
	local EC_TICK_SOUND		= CreateConVar("easychat_tick_sound","1",FCVAR_ARCHIVE,"Should a tick sound be played on new messages or not")

	EasyChat.UseDermaSkin = EC_DERMASKIN:GetBool()

	cvars.AddChangeCallback("easychat_enable", function(name,old,new)
		if EC_ENABLE:GetBool() then
			EasyChat.Init()
		else
			EasyChat.Destroy()
			net.Start(NET_SET_TYPING)	-- this is useful if a user disable easychat with console mode
			net.WriteBool(true)
			net.SendToServer()
		end
	end)

	cvars.AddChangeCallback("easychat_use_dermaskin",function(name,old,new)
		EasyChat.UseDermaSkin = EC_DERMASKIN:GetBool()
		LocalPlayer():ConCommand("easychat_reload")
	end)

	EasyChat.FontName = EC_FONT:GetString()
	EasyChat.FontSize = EC_FONT_SIZE:GetInt()

	local UpdateChatBoxFont = function(fontname,size)
		EasyChat.FontName = fontname
		EasyChat.FontSize = size
		surface.CreateFont("EasyChatFont",{
			font      = fontname,
			extended  = true,
			size      = size,
			weight    = 500,
			shadow	  = false,
			additive  = false,
		})
	end

	UpdateChatBoxFont(EasyChat.FontName,EasyChat.FontSize)

	cvars.AddChangeCallback("easychat_font",function(name,old,new)
		UpdateChatBoxFont(new,EasyChat.FontSize)
	end)

	cvars.AddChangeCallback("easychat_font_size",function(name,old,new)
		UpdateChatBoxFont(EasyChat.FontName,tonumber(new))
	end)

	if JSON_COLS then
		local colors = util.JSONToTable(JSON_COLS)
		EasyChat.OutlayColor        = colors.outlay
		EasyChat.OutlayOutlineColor = colors.outlayoutline
		EasyChat.TabOutlineColor    = colors.taboutline
		EasyChat.TabColor           = colors.tab
	else
        EasyChat.OutlayColor        = Color(62,62,62,173)
        EasyChat.OutlayOutlineColor = Color(104,104,104,103)
        EasyChat.TabOutlineColor    = Color(5,5,5,123)
        EasyChat.TabColor     		= Color(36,36,36,255)
	end

	EasyChat.TextColor = Color(255,255,255,255)
	EasyChat.Mode	   = 0
	EasyChat.Modes     = {}
	EasyChat.ChatHUD   = include("easychat/client/chathud.lua")
	EasyChat.ModeCount = 0

	local ECTabs 	  = {}
	local LocalPlayer = _G.LocalPlayer
	local surface 	  = _G.surface
	local IsValid	  = _G.IsValid
	local table		  = _G.table
	local file		  = _G.file
	local input		  = _G.input

	--after easychat var declarations [necessary]
	include("easychat/client/chatbox_panel.lua")
	include("easychat/client/browser_panel.lua")
	include("easychat/client/chat_tab.lua")
	include("easychat/client/settings_tab.lua")
	include("easychat/client/default_tags.lua")

	local ECConvars = {}
	EasyChat.RegisterConvar = function(convar,desc)
		table.insert(ECConvars,{
			Convar = convar,
			Description = desc,
		})
	end

	EasyChat.GetRegisteredConvars = function()
		return ECConvars
	end

	EasyChat.AddMode = function(name,callback)
		table.insert(EasyChat.Modes,{Name = name,Callback = callback})
		EasyChat.ModeCount = #EasyChat.Modes
	end

	EasyChat.IsOpened = function()
		return EasyChat.GUI and IsValid(EasyChat.GUI.ChatBox) and EasyChat.GUI.ChatBox:IsVisible()
	end

	local ECNextNotif = 0
	local ECOpen = function(isteam)
		local ok = hook.Run("ECShouldOpen")
		if ok == false then return end

		ok = hook.Run('StartChat', isteam)
		if ok == true then return end

		EasyChat.GUI.ChatBox:Show()
		EasyChat.GUI.ChatBox:MakePopup()
		EasyChat.Mode = isteam and 1 or 0

		if EC_GLOBAL_ON_OPEN:GetBool() then
			EasyChat.GUI.TabControl:SetActiveTab(EasyChat.GUI.TabControl.Items[1].Tab)
			EasyChat.GUI.TextEntry:RequestFocus()
		end

		if ECNextNotif <= CurTime() then
			ECNextNotif = CurTime() + 40
			for k,v in pairs(ECTabs) do
				if v.NotificationCount and v.NotificationCount > 0 then
					chat.AddText("EC",Color(175,175,175)," ⮞ ",Color(255, 127, 127),v.NotificationCount,Color(255,255,255)," new notifications from "..k)
				end
			end
		end

		hook.Run("ECOpened",LocalPlayer())

		net.Start(NET_SET_TYPING)
		net.WriteBool(true)
		net.SendToServer()
	end

	local SavePosSize = function()
		local x,y,w,h = EasyChat.GUI.ChatBox:GetBounds()
		local tab = {
			w = w,
			h = h,
			x = x,
			y = y,
		}
		local json = util.TableToJSON(tab,true)
		file.CreateDir("easychat")
		file.Write("easychat/possize.txt",json)
	end

	local LoadPosSize = function()
		local w,h = 550,320
		local x,y = 25,(ScrH() - 150)
		local json = file.Read("easychat/possize.txt","DATA")

		if not json then return x,y,w,h end
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
			return tab.x,tab.y,tab.w,tab.h
		else
			return x,y,w,h
		end
	end

	local ECClose = function()
		if EasyChat.IsOpened() then
			EasyChat.GUI.ChatBox:SetMouseInputEnabled(false)
			EasyChat.GUI.ChatBox:SetKeyboardInputEnabled(false)
			gui.EnableScreenClicker(false)
			EasyChat.GUI.TextEntry:SetText("")
			chat.old_Close()
			gamemode.Call("ChatTextChanged","")
			gamemode.Call("FinishChat")
			SavePosSize()
			EasyChat.GUI.ChatBox:Hide()
			hook.Run("ECClosed",LocalPlayer())
			net.Start(NET_SET_TYPING)
			net.WriteBool(false)
			net.SendToServer()
		end
	end

	EasyChat.IsURL = function(str)
		local LinkPatterns = {
			"https?://[^%s%\"]+",
			"ftp://[^%s%\"]+",
			"steam://[^%s%\"]+",
		}
		for index,pattern in ipairs(LinkPatterns) do
			if string.match(str,pattern) then
				return true
			end
		end
		return false
	end

	EasyChat.OpenURL = function(url)
		if not EC_ENABLEBROWSER:GetBool() then gui.OpenURL(url) return end
		local ok = hook.Run("ECOpenURL",url)
		if ok == false then return end
		local browser = vgui.Create("ECBrowser")
		browser:MakePopup()
		browser:OpenURL(url or "www.google.com")
	end

	local ECAddTextHandles = {}
	EasyChat.SetAddTextTypeHandle = function(type,callback)
		ECAddTextHandles[type] = callback
	end

	EasyChat.GetSetAddTextTypeHandle = function(type)
		return ECAddTextHandles[type]
	end

	EasyChat.Init = function()
		ECConvars 		 = {} -- reset for reload
		ECAddTextHandles = {}

		EasyChat.RegisterConvar(EC_GLOBAL_ON_OPEN,"Open chatbox in global tab")
		EasyChat.RegisterConvar(EC_TIMESTAMPS,"Display timestamps")
		EasyChat.RegisterConvar(EC_TEAMS,"Display teams")
		EasyChat.RegisterConvar(EC_TEAMS_COLOR,"Color the team tags")
		EasyChat.RegisterConvar(EC_PLAYER_COLOR,"Color players in their team color")
		EasyChat.RegisterConvar(EC_HUD_FOLLOW,"Chathud follows chatbox")
		EasyChat.RegisterConvar(EC_TICK_SOUND,"Tick sound on new messages")

		EasyChat.AddMode("Team",function(text)
			net.Start(NET_SEND_MSG)
			net.WriteString(string.sub(text,1,MAX_CHARS))
			net.WriteBool(true)
			net.SendToServer()
		end)

		EasyChat.AddMode("Local",function(text)
			net.Start(NET_SEND_LOCAL_MSG)
			net.WriteString(string.sub(text,1,MAX_CHARS))
			net.SendToServer()
		end)

		EasyChat.AddMode("Console",function(text)
			LocalPlayer():ConCommand(text)
		end)

		EasyChat.SetAddTextTypeHandle("table",function(col)
			EasyChat.InsertColorChange(col.r,col.g,col.b,col.a or 255)
		end)

		EasyChat.SetAddTextTypeHandle("string",function(str)
			if EasyChat.IsURL(str) then
				local words = string.Explode(" ",str)
				for k,v in ipairs(words) do
					if k > 1 then
						EasyChat.AppendText(" ")
					end
					if EasyChat.IsURL(v) then
						local url = string.gsub(v,"^%s:","")
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

		EasyChat.SetAddTextTypeHandle("Player",function(ply)
			local col = EC_PLAYER_COLOR:GetBool() and team.GetColor(ply:Team()) or Color(255,255,255)
			EasyChat.InsertColorChange(col.r,col.g,col.b,255)
			EasyChat.AppendTaggedText(ply:Nick())
		end)

		do
			EasyChat.ChatHUD.Init()

			chat.old_AddText 		= chat.old_AddText 		  or chat.AddText
			chat.old_GetChatBoxPos  = chat.old_GetChatBoxPos  or chat.GetChatBoxPos
			chat.old_GetChatBoxSize = chat.old_GetChatBoxSize or chat.GetChatBoxSize
			chat.old_Open			= chat.old_Open			  or chat.Open
			chat.old_Close			= chat.old_Close		  or chat.Close

			chat.AddText = function(...)
				EasyChat.AppendText("\n")
				EasyChat.ChatHUD.AddTagStop()
				EasyChat.InsertColorChange(255,255,255,255)

				if EC_ENABLE:GetBool() then
					if EC_TIMESTAMPS:GetBool() then
						EasyChat.AppendText(os.date("%H:%M").." - ")
					end
				end

				local args = { ... }
				for _,arg in ipairs(args) do
					local callback = ECAddTextHandles[type(arg)]
					if callback then
						pcall(callback,arg)
					else
						local str = tostring(arg)
						EasyChat.AppendText(str)
					end
				end
				chat.old_AddText(...)
				if EC_TICK_SOUND:GetBool() then
					chat.PlaySound()
				end
			end

			chat.GetChatBoxPos = function()
				if EasyChat.GUI and IsValid(EasyChat.GUI.ChatBox) then
					local x,y,_,_ = EasyChat.GUI.ChatBox:GetBounds()
					return x,y
				else
					return chat.old_GetChatBoxPos()
				end
			end

			chat.GetChatBoxSize = function()
				if EasyChat.GUI and IsValid(EasyChat.GUI.ChatBox) then
					local _,_,w,h = EasyChat.GUI.ChatBox:GetBounds()
					return w,h
				else
					return chat.old_GetChatBoxSize()
				end
			end

			chat.Open = function(input)
				local isteam = input == 0
				ECOpen(isteam)
				--chat.old_Open(input)
			end

			chat.Close = function()
				ECClose()
			end

		end

		do
			local frame = vgui.Create("ECChatBox")
			local cx,cy,cw,ch = LoadPosSize()
			frame:SetSize(cw,ch)
			frame:SetPos(cx,cy)
			frame.BtnClose.DoClick = function()
				ECClose()
			end

			EasyChat.AddTab = function(name,panel)
				local tab = frame.Tabs:AddSheet(name,panel)
				tab.Tab.Name = name
				tab.Tab:SetFont("EasyChatFont")
				tab.Tab:SetTextColor(Color(255,255,255))
				ECTabs[name] = tab
				panel:Dock(FILL)
				if not EasyChat.UseDermaSkin then
					panel.Paint = function(self,w,h)
						surface.SetDrawColor(EasyChat.TabColor)
						surface.DrawRect(0, 0, w,h)
						surface.SetDrawColor(EasyChat.TabOutlineColor)
						surface.DrawOutlinedRect(0, 0, w,h)
					end
					tab.Tab.Paint = function(self,w,h)
						if self == frame.Tabs:GetActiveTab() then
							self.Flashed = false
							tab.NotificationCount = 0
							surface.SetDrawColor(EasyChat.TabColor)
						else
							if self.Flashed then
								surface.SetDrawColor( math.abs(math.sin(CurTime()*3)*244),math.abs(math.sin(CurTime()*3)*167), math.abs(math.sin(CurTime()*3)*66),255)
							else
								surface.SetDrawColor(EasyChat.OutlayColor)
							end
						end
						surface.DrawRect(0,0,w,h)
						if self == frame.Tabs:GetActiveTab() then
							surface.SetDrawColor(EasyChat.TabOutlineColor)
						else
							surface.SetDrawColor(EasyChat.OutlayOutlineColor)
						end
						surface.DrawLine(0,0,w,0)
						surface.DrawLine(0,0,0,h)
						surface.DrawLine(w-1,0,w-1,h)
					end
				end
			end

			EasyChat.GetTab = function(name)
				if ECTabs[name] then
					return ECTabs[name]
				else
					return nil
				end
			end

			EasyChat.GetActiveTab = function()
				local active = frame.Tabs:GetActiveTab()
				return ECTabs[active.Name]
			end

			EasyChat.SetFocusForOn = function(name,panel)
				if ECTabs[name] then
					ECTabs[name].Tab.FocusOn = panel
				end
			end

			EasyChat.FlashTab = function(name)
				if ECTabs[name] then
					ECTabs[name].Tab.Flashed = true
					ECTabs[name].NotificationCount = ECTabs[name].NotificationCount and ECTabs[name].NotificationCount + 1 or 1
				end
			end

			local maintab = vgui.Create("ECChatTab")
			EasyChat.AddTab("Global",maintab)
			EasyChat.SetFocusForOn("Global",maintab.TextEntry)

			-- Only the neccesary elements --
			EasyChat.GUI = {
				ChatBox 	= frame,
				TextEntry 	= maintab.TextEntry,
				RichText 	= maintab.RichText,
				TabControl 	= frame.Tabs,
			}

			ECClose()
		end

		EasyChat.InsertColorChange = function(r,g,b,a)
			EasyChat.GUI.RichText:InsertColorChange(r,g,b,a)
			EasyChat.ChatHUD.InsertColorChange(r,g,b,a)
		end

		EasyChat.AppendText = function(text)
			EasyChat.GUI.RichText:AppendText(text)
			EasyChat.ChatHUD.AppendText(text)
		end

		EasyChat.AppendTaggedText = function(str)
			local pattern = "<(.-)=(.-)>"
			local parts = string.Explode(pattern,str,true)
			local index = 1
			for tag,values in string.gmatch(str,pattern) do
				EasyChat.AppendText(parts[index])
				index = index + 1
				if tag == "color" then
					local r,g,b
					string.gsub(values,"(%d+),(%d+),(%d+)",function(sr,sg,sb)
						r = tonumber(sr)
						g = tonumber(sg)
						b = tonumber(sb)
						return ""
					end)
					if r and g and b then
						EasyChat.InsertColorChange(r,g,b,255)
					end
				end
			end
			EasyChat.AppendText(parts[#parts])
			EasyChat.InsertColorChange(255,255,255,255)
		end

		local CTRLShortcuts = {}
		local ALTShortcuts  = {}

		local IsValidShortcutKey = function(key)
			local notvalids = {
				KEY_ENTER 	  = true,
				KEY_PAD_ENTER = true,
				KEY_ESCAPE    = true,
				KEY_TAB       = true,
			}
			if notvalids[key] then
				return false
			else
				return true
			end
		end

		local IsBaseShortcutKey = function(key)
			local valids = {
				KEY_LCONTROL = true,
				KEY_LALT 	 = true,
				KEY_RCONTROL = true,
				KEY_RALT 	 = true,
			}
			if valids[key] then
				return true
			else
				return false
			end
		end

		EasyChat.RegisterCTRLShortcut = function(key,callback)
			if IsValidShortcutKey(key) then
				CTRLShortcuts[key] = callback
			end
		end

		EasyChat.RegisterALTShortcut = function(key,callback)
			if not IsValidShortcutKey(key) then
				ALTShortcuts[key] = callback
			end
		end

		EasyChat.UseRegisteredShortcuts = function(textentry,lastkey,key)
			if IsBaseShortcutKey(lastkey) then
				local pos = textentry:GetCaretPos()
				local first = string.sub(textentry:GetText(),1,pos+1)
				local last = string.sub(textentry:GetText(),pos+2,#textentry:GetText())

				if CTRLShortcuts[key] then
					local retrieved = CTRLShortcuts[key](textentry,textentry:GetText(),pos,first,last)
					if retrieved then
						textentry:SetText(retrieved)
					end
				elseif ALTShortcuts[key] then
					local retrieved = ALTShortcuts[key](textentry,textentry:GetText(),pos,first,last)
					if retrieved then
						textentry:SetText(retrieved)
					end
				end
			end
		end

		EasyChat.SetupHistory = function(textentry,key)
			if key == KEY_ENTER or key == KEY_PAD_ENTER then
				textentry:AddHistory(textentry:GetText())
				textentry.HistoryPos = 0
			end
			if key == KEY_ESCAPE then
				textentry.HistoryPos = 0
			end

			if not textentry.HistoryPos then return end
			if key == KEY_UP then
				textentry.HistoryPos = textentry.HistoryPos - 1
				textentry:UpdateFromHistory()
			elseif key == KEY_DOWN then
				textentry.HistoryPos = textentry.HistoryPos + 1
				textentry:UpdateFromHistory()
			end
		end

		local lastkey = KEY_ENTER
		EasyChat.GUI.TextEntry.OnKeyCodeTyped = function(self,code)
			EasyChat.SetupHistory(self,code)
			EasyChat.UseRegisteredShortcuts(self,lastkey,code)

			if code == KEY_ESCAPE then
				ECClose()
				gui.HideGameUI()
			elseif code == KEY_ENTER or code == KEY_PAD_ENTER then
				self:SetText(string.Replace(self:GetText(),"╚​",""))
				if string.Trim(self:GetText()) ~= "" then
					if EasyChat.Mode == 0 then
						net.Start(NET_SEND_MSG)
						net.WriteString(string.sub(self:GetText(),1,MAX_CHARS))
						net.WriteBool(false)
						net.SendToServer()
					else
						local mode = EasyChat.Modes[EasyChat.Mode]
						mode.Callback(self:GetText())
					end
				end
				ECClose()
			end

			lastkey = code

			if code == KEY_TAB then
				if self:GetText() ~= "" then
					local a = gamemode.Call("OnChatTab",self:GetText())
					self:SetText(a)
					timer.Simple(0,function()
						self:RequestFocus()
						self:SetCaretPos(#self:GetText())
					end)
				else
					local modeplus = EasyChat.Mode + 1
					EasyChat.Mode = modeplus > EasyChat.ModeCount and 0 or modeplus
				end
				return true
			end
		end

		EasyChat.GUI.TextEntry.OnValueChange = function(self,text)
			gamemode.Call("ChatTextChanged",text)
		end

		EasyChat.GUI.RichText.ActionSignal = function(self,name,value)
			if name == "TextClicked" then
				EasyChat.OpenURL(value)
			end
		end

		hook.Add("PlayerBindPress", TAG, function(ply, bind, status)
			if bind == "messagemode" then
				ECOpen(false)
				return true
			elseif bind == "messagemode2" then
				ECOpen(true)
				return true
			end
		end)

		if not EC_NO_MODULES:GetBool() then
			hook.Run("ECPreLoadModules")
			LoadModules()
			hook.Run("ECPostLoadModules")
		end

		local settings = vgui.Create("ECSettingsTab")
		EasyChat.AddTab("Settings",settings)

		hook.Add("ChatText",TAG, function(index,name,text,type)
			local types = {
				none = true,         -- fallback
				darkrp = true,       --darkrp compat most likely?
				--namechange = true, -- annoying
				--servermsg = true,  -- annoying
				--teamchange = true, -- annoying
				--chat = true,       -- deprecated
			}
			if types[type] then
				chat.AddText(text)
			end
		end)

		local IsChatKeyPressed = function()
			local nonvalids = {
				KEY_LCONTROL,
				KEY_LALT,
				KEY_RCONTROL,
				KEY_RALT,
			}
			local letters = {
				KEY_A,KEY_B,KEY_C,KEY_D,KEY_E,
				KEY_F,KEY_G,KEY_H,KEY_I,KEY_J,
				KEY_K,KEY_L,KEY_M,KEY_N,KEY_O,
				KEY_P,KEY_Q,KEY_R,KEY_S,KEY_T,
				KEY_U,KEY_V,KEY_W,KEY_X,KEY_Y,
				KEY_Z,KEY_ENTER,KEY_TAB,KEY_SPACE,
				KEY_BACKSPACE,
			}

			for _,key in ipairs(nonvalids) do
				if input.IsKeyDown(key) then
					return false
				end
			end

			for _,key in ipairs(letters) do
				if input.IsKeyDown(key) then
					local k = input.GetKeyName(key)
					return true,((k ~= "TAB" and k ~= "ENTER") and k or "")
				end
			end
			return false
		end

		hook.Add("HUDShouldDraw",TAG,function(hudelement)
			if EasyChat.ChatHUD.DuringShouldDraw then return end
			if hudelement == "CHudChat" then
				return false
			end
		end)

		hook.Add("PreRender",TAG,function()
			if EasyChat.IsOpened() then
				if input.IsKeyDown(KEY_ESCAPE) then
					EasyChat.GUI.TextEntry:SetText("")
					ECClose()
				end
				local tab = EasyChat.GUI.TabControl:GetActiveTab()
				if tab.FocusOn and not tab.FocusOn:HasFocus() then
					local pressed,key = IsChatKeyPressed()
					if pressed then
						tab.FocusOn:RequestFocus()
						tab.FocusOn:SetText(key)
						tab.FocusOn:SetCaretPos(#tab.FocusOn:GetText())
					end
				end
			end
		end)

		hook.Add("Think",TAG,function()
			if not IsValid(EasyChat.GUI.ChatBox) or not EasyChat.ChatHUD or (EasyChat.ChatHUD and not IsValid(EasyChat.ChatHUD.Frame)) then return end
			if not EC_HUD_FOLLOW:GetBool() then
					EasyChat.ChatHUD.Frame:SetVisible(true)
					EasyChat.ChatHUD.Frame:SetPos(25,ScrH() - 150)
					EasyChat.ChatHUD.Frame:SetSize(550,320)
			else
				local x,y,w,h = EasyChat.GUI.ChatBox:GetBounds()
				EasyChat.ChatHUD.Frame:SetPos(x,y + h)
				EasyChat.ChatHUD.Frame:SetSize(w,h)
			end
		end)

		hook.Run("ECInitialized")

	end

	net.Receive(NET_BROADCAST_MSG,function()
		local ply  = net.ReadEntity()
		local msg  = net.ReadString()
		local dead = net.ReadBool()
		local isteam = net.ReadBool()

		gamemode.Call("OnPlayerChat",ply,msg,isteam,dead,false)
	end)

	net.Receive(NET_BROADCAST_LOCAL_MSG,function()
		local ply  = net.ReadEntity()
		local msg  = net.ReadString()
		local dead = net.ReadBool()

		gamemode.Call("OnPlayerChat",ply,msg,false,dead,true)
	end)

	hook.Add("Initialize", TAG, function()
		if EC_ENABLE:GetBool() then
			EasyChat.Init()
		end

		GAMEMODE.OnPlayerChat = function(self,ply,msg,isteam,isdead,islocal) -- this is for the best
			local tab = {}
			table.insert(tab,Color(255,255,255)) -- we don't want previous colors to be used again

			if EC_ENABLE:GetBool() then
				if IsValid(ply) and EC_TEAMS:GetBool() then
					if EC_TEAMS_COLOR:GetBool() then
						local tcol = team.GetColor(ply:Team())
						table.insert(tab,tcol)
					end
					table.insert(tab,"["..team.GetName(ply:Team()).."] - ")
				end
			end

			if isdead then
				table.insert(tab,Color(240,80,80))
				table.insert(tab,"*DEAD* " )
			end

			if islocal == true then
				table.insert(tab,Color(120,210,255))
				table.insert(tab,"(Local) ")
			end

			if isteam then
				table.insert(tab,Color(120,120,240))
				table.insert(tab,"(Team) ")
			end

			if IsValid(ply)  then
				table.insert(tab,ply)
			else
				table.insert(tab,Color(110,247,177))
				table.insert(tab,"???") -- console or weird stuff
			end

			table.insert(tab,Color(255,255,255))
			table.insert(tab,": "..msg)

			chat.AddText(unpack(tab))

			return true
		end

		hook.Run("ECPostInitialize")
	end)

end

EasyChat.Destroy = function()

	if CLIENT then
		hook.Remove("PreRender",TAG)
		hook.Remove("Think",TAG)
		hook.Remove("PlayerBindPress", TAG)
		hook.Remove("HUDShouldDraw",TAG)

		if chat.old_AddText then
			chat.AddText 		= chat.old_AddText
			chat.GetChatBoxPos  = chat.old_GetChatBoxPos
			chat.GetChatBoxSize = chat.old_GetChatBoxSize
			chat.Open 			= chat.old_Open
			chat.Close			= chat.old_Close
		end

		EasyChat.ModeCount = 0
		EasyChat.Mode = 0
		EasyChat.Modes = {}

		if EasyChat.GUI and IsValid(EasyChat.GUI.ChatBox) then
			EasyChat.GUI.ChatBox:Remove()
		end

		if EasyChat.ChatHUD and IsValid(EasyChat.ChatHUD.Frame) then
			EasyChat.ChatHUD.Frame:Remove()
		end

	end

	hook.Run("ECDestroyed")

end

concommand.Add("easychat_reload",function()
	EasyChat.Destroy()
	EasyChat.Init()
	if SERVER then
		for _,v in ipairs(player.GetAll()) do
			v:SendLua([[EasyChat.Destroy() EasyChat.Init()]])
		end
	end
end)
