if _G.EasyChat then
	EasyChat.Destroy()
end

local EasyChat = _G.EasyChat or {}
_G.EasyChat = EasyChat

local netbroadcastmsgs = "EASY_CHAT_BROADCAST_MSG"
local netreceivemsg    = "EASY_CHAT_RECEIVE_MSG"
local netlocalmsg      = "EASY_CHAT_LOCAL_MSG"
local netlocalsend     = "EASY_CHAT_LOCAL_SEND"
local tag              = "EasyChat"

AddCSLuaFile("easychat/chathud.lua") -- yo dont forget that

----- this is neccesary in case loader file gets removed ----
EasyChat.LoadModules = function() end
AddCSLuaFile("easychat/autoloader.lua")
local Loader = CompileFile("easychat/autoloader.lua")
pcall(Loader)
-------------------------------------------------------------

if SERVER then

	util.AddNetworkString(netreceivemsg)
	util.AddNetworkString(netbroadcastmsgs)
	util.AddNetworkString(netlocalmsg)
	util.AddNetworkString(netlocalsend)

	net.Receive(netreceivemsg,function(len,ply)
		local str = net.ReadString()
		local msg = gamemode.Call("PlayerSay", ply, str, false)
		if type(msg) ~= "string" or string.Trim(msg) == "" then return end
		net.Start(netbroadcastmsgs)
		net.WriteEntity(ply)
		net.WriteString(msg)
		net.WriteBool(IsValid(ply) and (not ply:Alive()) or false)
		net.Broadcast()
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

	include("easychat/chathud.lua")

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

	local font = ec_font:GetString()
	local font_size = ec_font_size:GetInt()

	local UpdateChatBoxFont = function(fontname,size)
		surface.CreateFont("EasyChatFont",{
			font      = fontname,
			extended  = true,
			size      = size,
			weight    = 500,
		})
	end

	UpdateChatBoxFont(font,font_size)

	cvars.AddChangeCallback("easychat_font",function(name,old,new)
		UpdateChatBoxFont(new,font_size)
	end)

	cvars.AddChangeCallback("easychat_font_size",function(name,old,new)
		UpdateChatBoxFont(font,tonumber(new))
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

	EasyChat.AddMode = function(name,callback)
		table.insert(EasyChat.Modes,{Name = name,Callback = callback})
		EasyChat.ModeCount = #EasyChat.Modes
	end

	EasyChat.IsOpened = function()
		return EasyChat.GUI and IsValid(EasyChat.GUI.ChatBox) and EasyChat.GUI.ChatBox:IsVisible()
	end

	EasyChat.NextNotify = 0

	EasyChat.Open = function()
		EasyChat.GUI.ChatBox:Show()
		EasyChat.GUI.ChatBox:MakePopup()
		EasyChat.Mode = 0
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
			return 25,ScrH()-370,527,315
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

	EasyChat.Init = function()
		hook.Remove("Initialize", tag)

		EasyChat.AddMode("Local",function(text)
			net.Start(netlocalmsg)
			net.WriteString(text)
			net.SendToServer()
		end)

		EasyChat.AddMode("Console",function(text)
			LocalPlayer():ConCommand(text)
		end)

		do
			EasyChat.ChatHUD.Init()

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
				if ok ~= false then
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
			------ Main frame -----
			local frame = vgui.Create("DFrame")
			local cx,cy,cw,ch = LoadPosSize()
			frame:SetSize(cw,ch)
			frame:SetPos(cx,cy)
			frame:ShowCloseButton(true)
			frame:SetDraggable(true)
			frame:SetSizable(true)
			frame:SetDeleteOnClose(false)
			frame:SetTitle("")

			frame.btnClose:Hide()
			frame.btnMaxim:Hide()
			frame.btnMinim:Hide()

			local closebtn = frame:Add("DButton")
			closebtn:SetSize(45,18)
			closebtn:SetZPos(10)
			if not EasyChat.UseDermaSkin then
				closebtn:SetTextColor(Color(200,20,20))
			end
			closebtn:SetFont("DermaDefaultBold")
			closebtn:SetText("X")
			closebtn.DoClick = function()
				EasyChat.Close()
			end
			closebtn.Think = function(self)
				local x,y,w,h = frame:GetBounds()
				self:SetPos(w-self:GetWide()-6,-2)
			end

			local maximbtn = frame:Add("DButton")
			maximbtn:SetSize(35,23)
			maximbtn:SetZPos(10)
			if not EasyChat.UseDermaSkin then
				maximbtn:SetTextColor(Color(125,125,125))
			end
			maximbtn:SetFont("DermaLarge")
			maximbtn:SetText("▭")
			maximbtn.IsFullScreen = false
			maximbtn.DoClick = function(self)
				if not self.IsFullScreen then
					local a,b,c,d = frame:GetBounds()
					self.Before = {
						x = a,
						y = b,
						w = c,
						h = d,
					}
					frame:SetSize(ScrW(),ScrH())
					frame:SetPos(0,0)
					self.IsFullScreen = true
				else
					frame:SetPos(self.Before.x,self.Before.y)
					frame:SetSize(self.Before.w,self.Before.h)
					self.IsFullScreen = false
				end
			end
			maximbtn.Think = function(self)
				local x,y,w,h = frame:GetBounds()
				self:SetPos(w-self:GetWide()-50,-7)
			end

			------ To make dms and stuff later ------
			local tabs = frame:Add("DPropertySheet")
			tabs:SetPos(6,6)

			tabs.old_performlayout = tabs.PerformLayout
			tabs.PerformLayout = function(self)
				self.old_performlayout(self)
				self.tabScroller:SetTall(20)
			end

			tabs.Think = function(self)
				local x,y,w,h = frame:GetBounds()
				tabs:SetSize(w-13,h-11)
			end

			local scroller = tabs.tabScroller
			scroller:SetParent(tabs)
			scroller:Dock(TOP)
			scroller:SetSize(0,20)
			scroller.m_iOverlap = -2

			EasyChat.AddTab = function(name,panel)
				local tab = tabs:AddSheet(name,panel)
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
						local wide,tall = w, h
						if self == tabs:GetActiveTab() then
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
						surface.DrawRect(0,0, wide, tall)
						surface.SetDrawColor(EasyChat.TabOutlineColor)
						surface.DrawLine(0,0,wide,0)
						surface.DrawLine(0,0,0,tall)
						surface.DrawLine(wide-1,0,wide-1,tall)
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

			------ Global chat ----
			local maintab = vgui.Create("DPanel")
			EasyChat.AddTab("Global",maintab)

			local richt = maintab:Add("RichText")
			richt:SetVerticalScrollbarEnabled(true)
			richt.Think = function(self)
				local x,y,w,h = frame:GetBounds()
				self:SetSize(w-15,h-50)
			end
			richt.PerformLayout = function(self)
				self:SetFontInternal("EasyChatFont")
				self:SetFGColor(EasyChat.UseDermaSkin and EasyChat.TextColor or Color(0,0,0,255))
			end

			local dbutton = maintab:Add("DButton")
			dbutton:SetTextColor(EasyChat.TextColor)
			dbutton:SetText("Say")
			dbutton:SetSize(65,20)
			dbutton:SetZPos(10)
			dbutton.Think = function(self)
				local x,y,w,h = maintab:GetBounds()
				self:SetPos(0,h-self:GetTall())
				if EasyChat.Mode == 0 then
					self:SetText("Say")
				else
					self:SetText(EasyChat.Modes[EasyChat.Mode].Name)
				end
			end
			dbutton.DoClick = function()
				local modeplus = EasyChat.Mode + 1
				EasyChat.Mode = modeplus > EasyChat.ModeCount and 0 or modeplus
			end

			local tentry = maintab:Add("DTextEntry")
			tentry.Think = function(self)
				local x,y,w,h = maintab:GetBounds()
				self:SetSize(w-dbutton:GetWide(),20)
				self:SetPos(dbutton:GetWide(),h-20)
			end
			tentry:SetHistoryEnabled(true)
			tentry.HistoryPos = 0
			tentry:SetUpdateOnType(true)
			tentry:SetZPos(10)

			EasyChat.SetFocusForOn("Global",tentry)

			if not EasyChat.UseDermaSkin then
				frame.Paint = function(self,w,h)
					surface.SetDrawColor(EasyChat.OutlayColor)
					surface.DrawRect(0,0,w,h)
					surface.SetDrawColor(EasyChat.OutlayOutlineColor)
					surface.DrawOutlinedRect(0,0,w,h)
				end

				closebtn.Paint = function(self,w,h)
					draw.RoundedBoxEx(3,0,0,w,h,EasyChat.OutlayOutlineColor,false,true,false,true)
					draw.RoundedBoxEx(3,1,1,w-2,h-2,Color(246,40,40),false,true,false,true)
					surface.SetDrawColor(EasyChat.OutlayOutlineColor)
					surface.DrawLine(0,2,w,2)
				end

				maximbtn.Paint = function(self,w,h)
					draw.RoundedBoxEx(3,0,0,w,h,EasyChat.OutlayOutlineColor,true,false,true,false)
					draw.RoundedBoxEx(3,1,1,w-2,h-2,Color(225,225,225),true,false,true,false)
					surface.SetDrawColor(EasyChat.OutlayOutlineColor)
					surface.DrawLine(0,7,w,7)
				end


				tabs.Paint = function(self,w,h)
					surface.SetDrawColor(0,0,0,0)
					surface.DrawRect(0, 0, w, h)
				end

				dbutton.Paint = function(self,w,h)
					surface.SetDrawColor(EasyChat.OutlayColor)
					surface.DrawRect(0,0,w,h)
					surface.SetDrawColor(EasyChat.TabOutlineColor)
					surface.DrawOutlinedRect(0,0,w,h)
				end
			end

			-- Only the neccesary elements --
			EasyChat.GUI = {
				ChatBox = frame,
				TextEntry = tentry,
				RichText = richt,
				TabControl = tabs,
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
				gui.OpenURL(value)
			end
		end

		hook.Add("StartChat",tag,function(team)
			EasyChat.Open()
			return true
		end)

		if not ec_no_modules:GetBool() then
			EasyChat.LoadModules()
		end

		do

			local ResetColors = function()
				EasyChat.OutlayColor        = Color(62,62,62,173)
				EasyChat.OutlayOutlineColor = Color(104,104,104,103)
				EasyChat.TabOutlineColor    = Color(74,72,72,255)
				EasyChat.TabColor     		= Color(43,43,43,255)
				local tab = {
					outlay = EasyChat.OutlayColor,
					outlayoutline = EasyChat.OutlayOutlineColor,
					tab = EasyChat.TabColor,
					taboutline = EasyChat.TabOutlineColor,
				}
				local json = util.TableToJSON(tab,true)
				file.Write("easychat/colors.txt",json)
			end

			local panel = vgui.Create("DScrollPanel")
			EasyChat.AddTab("Settings",panel)

			local checkboxes = {}

			local olcol = panel:Add("DCheckBoxLabel")
			olcol:SetText("Outlay Color")
			olcol:SetPos(15,15)
			table.insert(checkboxes,olcol)

			local ololcol = panel:Add("DCheckBoxLabel")
			ololcol:SetText("Outlay Outline Color")
			ololcol:SetPos(15,40)
			table.insert(checkboxes,ololcol)

			local tabcol = panel:Add("DCheckBoxLabel")
			tabcol:SetText("Tab Color")
			tabcol:SetPos(15,65)
			table.insert(checkboxes,tabcol)

			local tabolcol = panel:Add("DCheckBoxLabel")
			tabolcol:SetText("Tab Outline Color")
			tabolcol:SetPos(15,90)
			table.insert(checkboxes,tabolcol)

			local mixer = panel:Add("DColorMixer")
			mixer:Dock(RIGHT)
			mixer:DockMargin(0,15,15,0)

			local apply = panel:Add("DButton")
			apply:SetPos(15,115)
			apply:SetText("Apply Color")
			apply:SetTextColor(EasyChat.TextColor)
			apply:SetSize(100,25)

			local resetc = panel:Add("DButton")
			resetc:SetPos(15,150)
			resetc:SetText("Reset Colors")
			resetc:SetTextColor(EasyChat.TextColor)
			resetc:SetSize(100,25)

			apply.DoClick = function()
				for k,v in pairs(checkboxes) do
					if v:GetChecked() then
						if v:GetText() == "Outlay Color" then
							EasyChat.OutlayColor = mixer:GetColor()
						elseif v:GetText() == "Outlay Outline Color" then
							EasyChat.OutlayOutlineColor = mixer:GetColor()
						elseif v:GetText() == "Tab Color" then
							EasyChat.TabColor = mixer:GetColor()
						elseif v:GetText() == "Tab Outline Color" then
							EasyChat.TabOutlineColor = mixer:GetColor()
						end
					end
				end
				local tab = {
					outlay = EasyChat.OutlayColor,
					outlayoutline = EasyChat.OutlayOutlineColor,
					tab = EasyChat.TabColor,
					taboutline = EasyChat.TabOutlineColor,
				}
				local json = util.TableToJSON(tab,true)
				file.Write("easychat/colors.txt",json)
			end

			resetc.DoClick = ResetColors

			if EasyChat.UseDermaSkin then
				olcol:SetVisible(false)
				ololcol:SetVisible(false)
				tabcol:SetVisible(false)
				tabolcol:SetVisible(false)
				mixer:SetVisible(false)
				apply:SetVisible(false)
				resetc:SetVisible(false)
			end

			local fontentry = panel:Add("DTextEntry")
			fontentry:SetPos(15,190)
			fontentry:SetSize(100,25)
			fontentry:SetText("font name here")

			local fontapply = panel:Add("DButton")
			fontapply:SetPos(15,225)
			fontapply:SetSize(100,25)
			fontapply:SetText("Apply Font")
			fontapply:SetTextColor(EasyChat.TextColor)

			fontapply.DoClick = function()
				LocalPlayer():ConCommand("easychat_font "..fontentry:GetValue())
			end

			local lfontsize = panel:Add("DLabel")
			lfontsize:SetPos(15,260)
			lfontsize:SetSize(100,10)
			lfontsize:SetText("Font size")

			local fontsize = panel:Add("DNumberWang")
			fontsize:SetPos(15,270)
			fontsize:SetSize(100,25)
			fontsize:SetMin(0)
			fontsize:SetMax(40)
			fontsize:SetValue(font_size)
			fontsize.OnValueChanged = function(self,val)
				LocalPlayer():ConCommand("easychat_font_size "..val)
			end
			cvars.AddChangeCallback("easychat_font_size",function(name,old,new)
				fontsize:SetValue(tonumber(new))
			end)

			local fontreset = panel:Add("DButton")
			fontreset:SetPos(15,345)
			fontreset:SetSize(100,25)
			fontreset:SetText("Reset Font")
			fontreset:SetTextColor(EasyChat.TextColor)

			fontreset.DoClick = function()
				LocalPlayer():ConCommand("easychat_font Roboto")
				LocalPlayer():ConCommand("easychat_font_size 17")
			end

			local hfollow = panel:Add("DCheckBoxLabel")
			hfollow:SetText("HUD follows chatbox")
			hfollow:SetPos(170,15)
			hfollow:SetChecked(ec_hud_follow:GetBool())
			hfollow.OnChange = function(self,val)
				LocalPlayer():ConCommand("easychat_hud_follow "..(val and 1 or 0))
			end
			cvars.AddChangeCallback("easychat_hud_follow",function(name,old,new)
				hfollow:SetChecked(old == "0")
			end)

			local tstamps = panel:Add("DCheckBoxLabel")
			tstamps:SetText("Display timestamps")
			tstamps:SetPos(170,40)
			tstamps:SetChecked(ec_timestamps:GetBool())
			tstamps.OnChange = function(self,val)
				LocalPlayer():ConCommand("easychat_timestamps "..(val and 1 or 0))
			end
			cvars.AddChangeCallback("easychat_timestamps",function(name,old,new)
				tstamps:SetChecked(old == "0")
			end)

			local teams = panel:Add("DCheckBoxLabel")
			teams:SetText("Display team tags")
			teams:SetPos(170,65)
			teams:SetChecked(ec_teams:GetBool())
			teams.OnChange = function(self,val)
				LocalPlayer():ConCommand("easychat_teams "..(val and 1 or 0))
			end
			cvars.AddChangeCallback("easychat_teams",function(name,old,new)
				teams:SetChecked(old == "0")
			end)

			local teamsc = panel:Add("DCheckBoxLabel")
			teamsc:SetText("Color team tags")
			teamsc:SetPos(170,90)
			teamsc:SetChecked(ec_teams_color:GetBool())
			teamsc.OnChange = function(self,val)
				LocalPlayer():ConCommand("easychat_teams_colored "..(val and 1 or 0))
			end
			cvars.AddChangeCallback("easychat_teams_colored",function(name,old,new)
				teamsc:SetChecked(old == "0")
			end)

			local plc = panel:Add("DCheckBoxLabel")
			plc:SetText("Color players")
			plc:SetPos(170,115)
			plc:SetChecked(ec_player_color:GetBool())
			plc.OnChange = function(self,val)
				LocalPlayer():ConCommand("easychat_players_colored "..(val and 1 or 0))
			end
			cvars.AddChangeCallback("easychat_players_colored",function(name,old,new)
				plc:SetChecked(old == "0")
			end)

			local global = panel:Add("DCheckBoxLabel")
			global:SetText("Global tab on open")
			global:SetPos(170,140)
			global:SetChecked(ec_global_on_open:GetBool())
			global.OnChange = function(self,val)
				LocalPlayer():ConCommand("easychat_global_on_open "..(val and 1 or 0))
			end
			cvars.AddChangeCallback("easychat_global_on_open",function(name,old,new)
				global:SetChecked(old == "0")
			end)

			local reseto = panel:Add("DButton")
			reseto:SetPos(170,165)
			reseto:SetText("Reset Options")
			reseto:SetTextColor(EasyChat.TextColor)
			reseto:SetSize(100,25)

			reseto.DoClick = function()
				LocalPlayer():ConCommand("easychat_timestamps 0")
				LocalPlayer():ConCommand("easychat_teams 0")
				LocalPlayer():ConCommand("easychat_teams_colored 0")
				LocalPlayer():ConCommand("easychat_global_on_open 1")
				LocalPlayer():ConCommand("easychat_players_colored 1")
			end

			local reset = panel:Add("DButton")
			reset:SetPos(170,200)
			reset:SetText("Reset Everything")
			reset:SetTextColor(EasyChat.TextColor)
			reset:SetSize(100,25)

			reset.DoClick = function()
				LocalPlayer():ConCommand("easychat_timestamps 0")
				LocalPlayer():ConCommand("easychat_teams 0")
				LocalPlayer():ConCommand("easychat_teams_colored 0")
				LocalPlayer():ConCommand("easychat_global_on_open 1")
				LocalPlayer():ConCommand("easychat_players_colored 1")
				LocalPlayer():ConCommand("easychat_font HL2MPTypeDeath")
				LocalPlayer():ConCommand("easychat_font_size 17")

				ResetColors()
			end

			-- yes im doing that here cuz im lazy --
			concommand.Add("easychat_reset_settings",reset.DoClick)
			----------------------------------------

			local reload = panel:Add("DButton")
			reload:SetPos(170,235)
			reload:SetText("Restart")
			reload:SetTextColor(EasyChat.TextColor)
			reload:SetSize(100,25)

			reload.DoClick = function()
				LocalPlayer():ConCommand("easychat_reload")
			end

			local useds = panel:Add("DButton")
			useds:SetPos(170,270)
			useds:SetText(EasyChat.UseDermaSkin and "Use custom skin" or "Use dermaskin")
			useds:SetTextColor(EasyChat.TextColor)
			useds:SetSize(100,25)

			useds.DoClick = function()
				LocalPlayer():ConCommand("easychat_use_dermaskin "..(EasyChat.UseDermaSkin and 0 or 1))
			end

			if not EasyChat.UseDermaSkin then

				local paint = function(self,w,h)
					surface.SetDrawColor(EasyChat.OutlayColor)
					surface.DrawRect(0,0,w,h)
					surface.SetDrawColor(EasyChat.TabOutlineColor)
					surface.DrawOutlinedRect(0,0,w,h)
				end

				useds.Paint     = paint
				apply.Paint     = paint
				resetc.Paint    = paint
				fontapply.Paint = paint
				fontreset.Paint = paint
				reseto.Paint    = paint
				reset.Paint     = paint
				reload.Paint    = paint

			end

		end

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
			if not IsValid(EasyChat.GUI.ChatBox) or not IsValid(EasyChat.ChatHUD.Frame) then return end
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
		AddTags(ply)
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

		if IsValid(EasyChat.GUI.ChatBox) then
			EasyChat.GUI.ChatBox:Remove()
		end

		if IsValid(EasyChat.ChatHUD) then
			EasyChat.ChatHUD:Remove()
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
