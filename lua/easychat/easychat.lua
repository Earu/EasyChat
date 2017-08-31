if _G.EasyChat then
	EasyChat.Destroy()
end

local EasyChat = _G.EasyChat or {}
_G.EasyChat = EasyChat

local print = _G._print or _G.print

local netbroadcastmsgs = "EASY_CHAT_BROADCAST_MSG"
local netreceivemsg    = "EASY_CHAT_RECEIVE_MSG"
local netlocalmsg      = "EASY_CHAT_LOCAL_MSG"
local netlocalsend     = "EASY_CHAT_LOCAL_SEND"
local tag              = "EasyChat"

include("easychat/autoloader.lua")

if SERVER then

	util.AddNetworkString(netreceivemsg)
	util.AddNetworkString(netbroadcastmsgs)
	util.AddNetworkString(netlocalmsg)
	util.AddNetworkString(netlocalsend)

	net.Receive(netreceivemsg,function(len,ply)
		local str = net.ReadString()
		local isteam = net.ReadBool()
		local msg = gamemode.Call("PlayerSay",ply,str,isteam)
		if type(msg) ~= "string" or string.Trim(msg) == "" then return end
		net.Start(netbroadcastmsgs)
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

	net.Receive(netlocalmsg,function(len,ply)
		local msg = net.ReadString()
		if type(msg) ~= "string" or string.Trim(msg) == "" then return end
		net.Start(netlocalsend)
		net.WriteEntity(ply)
		net.WriteString(msg)
		net.WriteBool(IsValid(ply) and (not ply:Alive()) or false)
		local receivers = {}
		for k,v in pairs(player.GetAll()) do
			if IsValid(v) and v:GetPos():Distance(ply:GetPos()) <= ply:GetInfoNum("easychat_local_msg_distance",150) then
				table.insert(receivers,v)
			end
		end
		net.Send(receivers)
	end)

	EasyChat.Init = function()
		EasyChat.LoadModules()
	end

	hook.Add("Initialize", tag, EasyChat.Init)
end

if CLIENT then

	local ec_global_on_open = CreateConVar("easychat_global_on_open","1",FCVAR_ARCHIVE,"Set the chat to always open global chat tab on open")
	local ec_font 			= CreateConVar("easychat_font","HL2MPTypeDeath",FCVAR_ARCHIVE,"Set the font to use for the chat")
	local ec_font_size 		= CreateConVar("easychat_font_size","17",FCVAR_ARCHIVE,"Set the font size for chatbox")
	local ec_timestamps		= CreateConVar("easychat_timestamps","0",FCVAR_ARCHIVE,"Display timestamp in front of messages or not")
	local ec_teams 			= CreateConVar("easychat_teams","0",FCVAR_ARCHIVE,"Display team in front of messages or not")
	local ec_teams_color 	= CreateConVar("easychat_teams_colored","0",FCVAR_ARCHIVE,"Display team with its relative color")
	local ec_player_color 	= CreateConVar("easychat_players_colored","1",FCVAR_ARCHIVE,"Display player with its relative team color")
	local ec_enable 		= CreateConVar("easychat_enable","1",FCVAR_ARCHIVE,"Use easychat or not")
	local ec_dermaskin 		= CreateConVar("easychat_use_dermaskin","0",FCVAR_ARCHIVE,"Use dermaskin look or not")
	local ec_local_msg_dist = CreateConVar("easychat_local_msg_distance","300",FCVAR_ARCHIVE,"Set the maximum distance for users to receive local messages")
	local ec_no_modules 	= CreateConVar("easychat_no_modules","0",FCVAR_ARCHIVE,"Should easychat load modules or not")
	local ec_hud_follow 	= CreateConVar("easychat_hud_follow","0",FCVAR_ARCHIVE,"Set the chat hud to follow the chatbox")

	EasyChat.UseDermaSkin = ec_dermaskin:GetBool()

	cvars.AddChangeCallback("easychat_enable",function(name,old,new)
		if ec_enable:GetBool() then
			EasyChat.Init()
		else
			EasyChat.Destroy()
		end
	end)

	cvars.AddChangeCallback("easychat_use_dermaskin",function(name,old,new)
		EasyChat.UseDermaSkin = ec_dermaskin:GetBool()
		LocalPlayer():ConCommand("easychat_reload")
	end)

	EasyChat.FontName = ec_font:GetString()
	EasyChat.FontSize = ec_font_size:GetInt()

	local UpdateChatBoxFont = function(fontname,size)
		surface.CreateFont("EasyChatFont",{
			font      = fontname,
			extended  = true,
			size      = size,
			weight    = 500,
		})
	end

	UpdateChatBoxFont(EasyChat.FontName,EasyChat.FontSize)

	cvars.AddChangeCallback("easychat_font",function(name,old,new)
		UpdateChatBoxFont(new,EasyChat.FontSize)
	end)

	cvars.AddChangeCallback("easychat_font_size",function(name,old,new)
		UpdateChatBoxFont(EasyChat.FontName,tonumber(new))
	end)

	local coljson = file.Read("easychat/colors.txt","DATA")
	if coljson then
		local cols = util.JSONToTable(coljson)
		EasyChat.OutlayColor        = Color(cols.outlay.r,cols.outlay.g,cols.outlay.b,cols.outlay.a)
		EasyChat.OutlayOutlineColor = Color(cols.outlayoutline.r,cols.outlayoutline.g,cols.outlayoutline.b,cols.outlayoutline.a)
		EasyChat.TabOutlineColor    = Color(cols.taboutline.r,cols.taboutline.g,cols.taboutline.b,cols.taboutline.a)
		EasyChat.TabColor           = Color(cols.tab.r,cols.tab.g,cols.tab.b,cols.tab.a)
	else
		EasyChat.OutlayColor        = Color(62,62,62,173)
		EasyChat.OutlayOutlineColor = Color(104,104,104,103)
		EasyChat.TabOutlineColor    = Color(74,72,72,255)
		EasyChat.TabColor     		= Color(43,43,43,255)
	end

	EasyChat.TextColor = Color(255,255,255,255)
	EasyChat.ModeCount = 0
	EasyChat.Mode = 0
	EasyChat.Modes = {}
	EasyChat.Tabs = {}

	--after easychat var declarations [necessary]
	include("easychat/client/chathud.lua")
	include("easychat/client/chatbox_panel.lua")
	include("easychat/client/browser_panel.lua")
	include("easychat/client/chat_tab.lua")
	include("easychat/client/settings_tab.lua")

	EasyChat.AddMode = function(name,callback)
		table.insert(EasyChat.Modes,{Name = name,Callback = callback})
		EasyChat.ModeCount = #EasyChat.Modes
	end

	EasyChat.IsOpened = function()
		return EasyChat.GUI and IsValid(EasyChat.GUI.ChatBox) and EasyChat.GUI.ChatBox:IsVisible()
	end

	EasyChat.NextNotify = 0

	EasyChat.Open = function(isteam)
		EasyChat.GUI.ChatBox:Show()
		EasyChat.GUI.ChatBox:MakePopup()
		EasyChat.Mode = isteam and 1 or 0
		if ec_global_on_open:GetBool() then
			EasyChat.GUI.TabControl:SetActiveTab(EasyChat.GUI.TabControl.Items[1].Tab)
			EasyChat.GUI.TextEntry:RequestFocus()
		end
		if EasyChat.NextNotify <= CurTime() then
			EasyChat.NextNotify = CurTime() + 40
			for k,v in pairs(EasyChat.Tabs) do
				if v.NotificationCount and v.NotificationCount > 0 then
					chat.AddText("EC",Color(175,175,175)," ⮞ ",Color(255, 127, 127),v.NotificationCount,Color(255,255,255)," new notifications from "..k)
				end
			end
		end
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
		local w,h = chat.GetChatBoxSize()
		local json = file.Read("easychat/possize.txt","DATA")
		if not json then return 25,25,w,h*1.5 end
		local tab = util.JSONToTable(json)
		if tab then
			if tab.x >= ScrW() then
				tab.x = 25
			end
			if tab.y >= ScrH() then
				tab.y = 25
			end
			if tab.w >= ScrW() then
				tab.w = w
			end
			if tab.h >= ScrH() then
				tab.h = h
			end
			return tab.x,tab.y,tab.w,tab.h
		else
			return 25,ScrH()-370,550,320
		end
	end

	EasyChat.Close = function()
		if EasyChat.IsOpened() then
			EasyChat.GUI.ChatBox:SetMouseInputEnabled( false )
			EasyChat.GUI.ChatBox:SetKeyboardInputEnabled( false )
			gui.EnableScreenClicker( false )
			EasyChat.GUI.TextEntry:SetText( "" )
			gamemode.Call( "ChatTextChanged", "" )
			gamemode.Call( "FinishChat" )
			SavePosSize()
			EasyChat.GUI.ChatBox:Hide()
			chat.Close()
		end
	end

	EasyChat.IsURL = function(str)
		local LinkPatterns = {
			"https?://[^%s%\"]+",
			"ftp://[^%s%\"]+",
			"steam://[^%s%\"]+",
		}
		for index,pattern in pairs(LinkPatterns) do
			if string.match(str,pattern) then
				return true
			end
		end
		return false
	end

	EasyChat.OpenURL = function(url)
		local browser = vgui.Create("ECBrowser")
		browser:MakePopup()
		browser:OpenURL(url or "www.google.com")
	end

	EasyChat.Init = function()
		hook.Remove("Initialize", tag)

		EasyChat.AddMode("Team",function(text)
			net.Start(netreceivemsg)
			net.WriteString(text)
			net.WriteBool(true)
			net.SendToServer()
		end)

		EasyChat.AddMode("Local",function(text)
			net.Start(netlocalmsg)
			net.WriteString(text)
			net.SendToServer()
		end)

		EasyChat.AddMode("Console",function(text)
			LocalPlayer():ConCommand(text)
		end)

		do
            if EasyChat.ChatHUD then
			    EasyChat.ChatHUD.Init()
            end

			EasyChat.old_chat_AddText = EasyChat.old_chat_AddText or chat.AddText
			EasyChat.old_chat_GetChatBoxPos = EasyChat.old_chat_GetChatBoxPos or chat.GetChatBoxPos
			EasyChat.old_chat_GetChatBoxSize = EasyChat.old_chat_GetChatBoxSize or chat.GetChatBoxSize

			chat.AddText = function(...)
				local args = { ... }
				for _,arg in pairs(args) do
					if type(arg) == "table" then
						EasyChat.InsertColorChange(arg.r,arg.g,arg.b,arg.a or 255)
					elseif type(arg) == "string" then
						if EasyChat.IsURL(arg) then
							local words = string.Explode(" ",arg)
							for k,v in pairs(words) do
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
							EasyChat.AppendText(arg)
						end
					elseif arg:IsPlayer() then
						local col = ec_player_color:GetBool() and team.GetColor(arg:Team()) or Color(255,255,255)
						EasyChat.InsertColorChange(col.r,col.g,col.b,255)
						EasyChat.AppendTaggedText(arg:Nick())
					else
						local str = tostring(arg)
						EasyChat.AppendText(str)
					end
				end
				EasyChat.InsertColorChange(255,255,255,255)
				EasyChat.AppendText("\n")
				local ok = hook.Run("ChatHudAddText","")
				if ok ~= false and EasyChat.ChatHUD then
					EasyChat.ChatHUD.AddText("\n\n")
				end
				EasyChat.old_chat_AddText(...)
			end

			chat.GetChatBoxPos = function()
				if EasyChat.GUI and IsValid(EasyChat.GUI.ChatBox) then
					local x,y,_,_ = EasyChat.GUI.ChatBox:GetBounds()
					return x,y
				else
					return EasyChat.old_chat_GetChatBoxPos()
				end
			end

			chat.GetChatBoxSize = function()
				if EasyChat.GUI and IsValid(EasyChat.GUI.ChatBox) then
					local _,_,w,h = EasyChat.GUI.ChatBox:GetBounds()
					return w,h
				else
					return EasyChat.old_chat_GetChatBoxSize()
				end
			end

		end

		do
			local frame = vgui.Create("ECChatBox")
			local cx,cy,cw,ch = LoadPosSize()
			frame:SetSize(cw,ch)
			frame:SetPos(cx,cy)

			EasyChat.AddTab = function(name,panel)
				local tab = frame.Tabs:AddSheet(name,panel)
				tab.Tab:SetFont("EasyChatFont")
				tab.Tab:SetTextColor(Color(255,255,255))
				EasyChat.Tabs[name] = tab
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
							surface.SetDrawColor(EasyChat.OutlayColor)
						else
							if self.Flashed then
								surface.SetDrawColor( math.abs(math.sin(CurTime()*3)*244),math.abs(math.sin(CurTime()*3)*167), math.abs(math.sin(CurTime()*3)*66),255)
							else
								surface.SetDrawColor(EasyChat.TabColor)
							end
						end
						surface.DrawRect(0,0,w,h)
						surface.SetDrawColor(EasyChat.TabOutlineColor)
						surface.DrawLine(0,0,w,0)
						surface.DrawLine(0,0,0,h)
						surface.DrawLine(w-1,0,w-1,h)
					end
				end
			end

			EasyChat.SetFocusForOn = function(name,panel)
				if EasyChat.Tabs[name] then
					EasyChat.Tabs[name].Tab.FocusOn = panel
				end
			end

			EasyChat.FlashTab = function(name)
				if EasyChat.Tabs[name] then
					EasyChat.Tabs[name].Tab.Flashed = true
					EasyChat.Tabs[name].NotificationCount = EasyChat.Tabs[name].NotificationCount and EasyChat.Tabs[name].NotificationCount + 1 or 1
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

			EasyChat.Close()
		end

		EasyChat.InsertColorChange = function(r,g,b,a)
			EasyChat.GUI.RichText:InsertColorChange(r,g,b,a)
			if EasyChat.ChatHUD then
				EasyChat.ChatHUD.InsertColorChange(r,g,b,a)
			end
		end

		EasyChat.AppendText = function(text)
			EasyChat.GUI.RichText:AppendText(text)
			if EasyChat.ChatHUD then
				EasyChat.ChatHUD.AppendText(text)
			end
		end

		EasyChat.AppendTaggedText = function(str)
			local pattern = "<(.-)=(.-)>"
			local parts = string.Explode(pattern,str,true)
			local index = 1
			for tag,values in string.gmatch(str,pattern) do
				EasyChat.AppendText(parts[index])
				index = index + 1
				if tag == "color" then -- maybe more tags to support but heh
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

		EasyChat.CTRLShortcuts = {}
		EasyChat.ALTShortcuts  = {}

		EasyChat.AddCTRLShortcut = function(key,callback)
			if key == KEY_ENTER or key == KEY_PAD_ENTER or key == KEY_ESCAPE or key == KEY_TAB then return end
			EasyChat.CTRLShortcuts[key] = callback
		end

		EasyChat.AddALTShortcut = function(key,callback)
			if key == KEY_ENTER or key == KEY_PAD_ENTER or key == KEY_ESCAPE or key == KEY_TAB then return end
			EasyChat.ALTShortcuts[key] = callback
		end

		EasyChat.UseRegisteredShortcuts = function(textentry,last_key,key)
			if last_key == KEY_LCONTROL or last_key == KEY_LALT or last_key == KEY_RCONTROL or last_key == KEY_RALT then
				local pos = textentry:GetCaretPos()
				local first = string.sub(textentry:GetText(),1,pos+1)
				local last = string.sub(textentry:GetText(),pos+1,string.len(textentry:GetText()))

				if EasyChat.CTRLShortcuts[key] then
					local retrieved = EasyChat.CTRLShortcuts[key](textentry,textentry:GetText(),pos,first,last)
					if retrieved then
						textentry:SetText(retrieved)
					end
				elseif EasyChat.ALTShortcuts[key] then
					local retrieved = EasyChat.ALTShortcuts[key](textentry,textentry:GetText(),pos,first,last)
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
			if not textentry.HistoryPos then return end
			if key == KEY_UP then
				textentry.HistoryPos = textentry.HistoryPos - 1
				textentry:UpdateFromHistory()
			elseif key == KEY_DOWN then
				textentry.HistoryPos = textentry.HistoryPos + 1
				textentry:UpdateFromHistory()
			end
		end

		local last_key = KEY_ENTER
		EasyChat.GUI.TextEntry.OnKeyCodeTyped = function( self, code )
			EasyChat.SetupHistory(self,code)
			EasyChat.UseRegisteredShortcuts(self,last_key,code)

			if code == KEY_ESCAPE then
				EasyChat.Close()
			elseif code == KEY_ENTER or code == KEY_PAD_ENTER then
				self:SetText(string.Replace(self:GetText(),"╚​",""))
				if string.Trim(self:GetText()) ~= "" then
					if EasyChat.Mode == 0 then
						net.Start(netreceivemsg)
						net.WriteString(string.sub(self:GetText(),1,3000))
						net.WriteBool(false)
						net.SendToServer()
					else
						local mode = EasyChat.Modes[EasyChat.Mode]
						mode.Callback(self:GetText())
					end
				end
				EasyChat.Close()
			end

			last_key = code

			if code == KEY_TAB then
				if self:GetText() ~= "" then
					local a = gamemode.Call("OnChatTab", self:GetText())
					self:SetText(a)
					timer.Simple(0, function() self:RequestFocus() self:SetCaretPos(#self:GetText()) end)
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

		hook.Add("StartChat",tag,function(isteam)
			EasyChat.Open(isteam)
			return true
		end)

		if not ec_no_modules:GetBool() then
			EasyChat.LoadModules()
		end

		local settings = vgui.Create("ECSettingsTab")
		EasyChat.AddTab("Settings",settings)

		hook.Add("ChatText",tag, function(index,name,text,type)
			if type == "none" then
				chat.AddText(text)
			end
		end)

		local IsChatKeyPressed = function()
			local letters = {
				KEY_A,KEY_B,KEY_C,KEY_D,KEY_E,
				KEY_F,KEY_G,KEY_H,KEY_I,KEY_J,
				KEY_K,KEY_L,KEY_M,KEY_N,KEY_O,
				KEY_P,KEY_Q,KEY_R,KEY_S,KEY_T,
				KEY_U,KEY_V,KEY_W,KEY_X,KEY_Y,
				KEY_Z,KEY_ENTER,KEY_TAB,
			}
			for _,key in pairs(letters) do
				if input.IsKeyDown(key) then
					local k = input.GetKeyName(key)
					return true,((k ~= "TAB" and k ~= "ENTER") and k or "")
				end
			end
			return false
		end

		hook.Add("HUDShouldDraw",tag,function(hudelement)
			if hudelement == "CHudChat" then
				return false
			end
		end)

		hook.Add("PreRender",tag,function()
			if EasyChat.IsOpened() then
				if input.IsKeyDown(KEY_ESCAPE) then
					EasyChat.GUI.TextEntry:SetText("")
					EasyChat.Close()
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

		hook.Add("Think",tag,function()
			if not IsValid(EasyChat.GUI.ChatBox) or not EasyChat.ChatHUD or (EasyChat.ChatHUD and not IsValid(EasyChat.ChatHUD.Frame)) then return end
			if not ec_hud_follow:GetBool() then
					EasyChat.ChatHUD.Frame:SetVisible(true)
					EasyChat.ChatHUD.Frame:SetPos(25,ScrH() - 370)
					EasyChat.ChatHUD.Frame:SetSize(527,315)
			else
				local x,y,w,h = EasyChat.GUI.ChatBox:GetBounds()
				EasyChat.ChatHUD.Frame:SetPos(x,y)
				EasyChat.ChatHUD.Frame:SetSize(w,h)
			end
		end)

		hook.Run("EasyChatOnInit")

	end

	local AddTags = function(ply)
		if not ec_enable:GetBool() then return end
		if ec_timestamps:GetBool() then
			EasyChat.AppendText(os.date("%H:%M:%S").." - ")
		end
		if ec_teams:GetBool() then
			if ec_teams_color:GetBool() then
				local tcol = team.GetColor(ply:Team())
				EasyChat.InsertColorChange(tcol.r,tcol.g,tcol.b,tcol.a)
			end
			EasyChat.AppendText("["..team.GetName(ply:Team()).."] - ")
		end
	end

	net.Receive(netbroadcastmsgs,function()
		local ply  = net.ReadEntity()
		local msg  = net.ReadString()
		local dead = net.ReadBool()
		local isteam = net.ReadBool()
		AddTags(ply)
		if isteam then
			EasyChat.AppendText("(Team)")
		end
		gamemode.Call("OnPlayerChat",ply,msg,false,dead)
	end)

	net.Receive(netlocalsend,function()
		local ply  = net.ReadEntity()
		local msg  = net.ReadString()
		local dead = net.ReadBool()
		AddTags(ply)
		EasyChat.AppendText("(Local)")
		gamemode.Call("OnPlayerChat",ply,msg,false,dead)
	end)

	hook.Add("Initialize",tag,function()
		if ec_enable:GetBool() then
			EasyChat.Init()
		end
	end)

end

EasyChat.Destroy = function()

	if CLIENT then
		hook.Remove("HUDPaint",tag)
		hook.Remove("StartChat",tag)
		hook.Remove("HUDShouldDraw",tag)
		hook.Remove("ChatText",tag)
		hook.Remove("PreRender",tag)
		hook.Remove("Think",tag)
		hook.Remove("HUDShouldDraw",tag)

		if EasyChat.old_chat_AddText then
			chat.AddText = EasyChat.old_chat_AddText
			chat.GetChatBoxPos = EasyChat.old_chat_GetChatBoxPos
			chat.GetChatBoxSize = EasyChat.old_chat_GetChatBoxSize
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

	hook.Run("EasyChatOnDestroy")

end

concommand.Add("easychat_reload",function()
	EasyChat.Destroy()
	EasyChat.Init()
	if SERVER then
		for k,v in pairs(player.GetAll()) do
			v:SendLua([[EasyChat.Destroy() EasyChat.Init()]])
		end
	end
end)

if me then
	EasyChat.Init()
end
