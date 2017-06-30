if _G.EasyChat then
	EasyChat.Destroy()
end

local EasyChat = _G.EasyChat or {}
_G.EasyChat = EasyChat

local netprintmsg      = "EASY_CHAT_PRINT_MSG"
local netbroadcastmsgs = "EASY_CHAT_BROADCAST_MSG"
local netreceivemsg    = "EASY_CHAT_RECEIVE_MSG"
local netlocalmsg      = "EASY_CHAT_LOCAL_MSG"
local netlocalsend     = "EASY_CHAT_LOCAL_SEND"
local tag              = "EasyChat"

EasyChat.Modules = {} --this is to prevent errors if loader gets removed
EasyChat.LoadModules = function() end

AddCSLuaFile("easychat/autoloader.lua")
local Loader = CompileFile("easychat/autoloader.lua")
pcall(Loader)

if SERVER then

	util.AddNetworkString(netprintmsg)
	util.AddNetworkString(netreceivemsg)
	util.AddNetworkString(netbroadcastmsgs)
	util.AddNetworkString(netlocalmsg)
	util.AddNetworkString(netlocalsend)

	net.Receive(netreceivemsg,function(len,ply)
		local str = net.ReadString()
		local msg = gamemode.Call("PlayerSay", ply, str, false)
		if string.Trim(msg) == "" then return end
		net.Start(netbroadcastmsgs)
		net.WriteEntity(ply)
		net.WriteString(msg)
		net.WriteBool(IsValid(ply) and (not ply:Alive()) or false)
		net.Broadcast()
	end)

	net.Receive(netlocalmsg,function(len,ply)
		local msg = net.ReadString()
		if string.Trim(msg) == "" then return end
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

		do -- overrides
			EasyChat.old_PrintMessage = EasyChat.old_PrintMessage or _G.PrintMessage
			_G.PrintMessage = function(enum,text)
				if enum == HUD_PRINTTALK then
					net.Start(netprintmsg)
					net.WriteString(text)
					net.Broadcast()
				end
				EasyChat.old_PrintMessage(enum,text)
			end

			local meta = FindMetaTable("Player")
			EasyChat.old_Player_PrintMessage = EasyChat.old_Player_PrintMessage or meta.PrintMessage
			meta.PrintMessage = function(self,enum,text)
				if enum == HUD_PRINTTALK then
					net.Start(netprintmsg)
					net.WriteString(text)
					net.Send(self)
				end
				EasyChat.old_Player_PrintMessage(self,enum,text)
			end
		end

		EasyChat.LoadModules()
	end

	hook.Add("Initialize", tag, EasyChat.Init)
end

if CLIENT then

	CreateConVar("easychat_hud_follow","0",FCVAR_ARCHIVE,"Set the chat hud to follow the chatbox")
	CreateConVar("easychat_global_on_open","1",FCVAR_ARCHIVE,"Set the chat to always open global chat tab on open")
	CreateConVar("easychat_font","Roboto",FCVAR_ARCHIVE,"Set the font to use for the chat")
	CreateConVar("easychat_font_size","17",FCVAR_ARCHIVE,"Set the font size for chatbox")
	CreateConVar("easychat_hud_font_size","19",FCVAR_ARCHIVE,"Set the font size for chathud")
	CreateConVar("easychat_timestamps","0",FCVAR_ARCHIVE,"Display timestamp in front of messages or not")
	CreateConVar("easychat_teams","0",FCVAR_ARCHIVE,"Display team in front of messages or not")
	CreateConVar("easychat_teams_colored","0",FCVAR_ARCHIVE,"Display team with its relative color")
	CreateConVar("easychat_players_colored","1",FCVAR_ARCHIVE,"Display player with its relative team color")
	CreateConVar("easychat_enable","1",FCVAR_ARCHIVE,"Use easychat or not")
	CreateConVar("easychat_use_dermaskin","0",FCVAR_ARCHIVE,"Use dermaskin look or not")
	CreateConVar("easychat_local_msg_distance","300",FCVAR_ARCHIVE,"Set the maximum distance for users to receive local messages")
	CreateConVar("easychat_no_modules","0",FCVAR_ARCHIVE,"Should easychat load modules or not")

	EasyChat.UseDermaSkin = GetConVar("easychat_use_dermaskin"):GetBool()

	cvars.AddChangeCallback("easychat_enable",function(name,old,new)
		if GetConVar("easychat_enable"):GetBool() then
			EasyChat.Init()
		else
			EasyChat.Destroy()
		end
	end)

	cvars.AddChangeCallback("easychat_use_dermaskin",function(name,old,new)
		EasyChat.UseDermaSkin = GetConVar("easychat_use_dermaskin"):GetBool()
		LocalPlayer():ConCommand("easychat_reload")
	end)

	local linux_offset = system.IsLinux() and 1 or 0
	local font = GetConVar("easychat_font"):GetString()
	local font_size = GetConVar("easychat_font_size"):GetInt()
	local font_hud_size = GetConVar("easychat_hud_font_size"):GetInt()

	surface.CreateFont("EasyChatFont",{
		font      = font,
		extended  = true,
		size      = font_size,
		weight    = 500,
		shadow    = true,
		additive  = true,
	})

	surface.CreateFont("EasyChatHUDFont",{
		font      = font,
		extended  = true,
		size      = font_hud_size,
		weight    = 500,
	})

	surface.CreateFont("EasyChatHUDShadow",{
		font      = font,
		extended  = true,
		size      = font_hud_size,-- + (linux_offset * 3),
		weight    = 500,
		blursize  = 2,
	})

	cvars.AddChangeCallback("easychat_font",function(name,old,new)
		surface.CreateFont("EasyChatFont",{
			font      = new,
			extended  = true,
			size      = font_size,
			weight    = 500,
			shadow    = true,
			additive  = true,
		})

		surface.CreateFont("EasyChatHUDFont",{
			font      = new,
			extended  = true,
			size      = font_hud_size,
			weight    = 500,
		})

		surface.CreateFont("EasyChatHUDShadow",{
			font      = new,
			extended  = true,
			size      = font_hud_size,-- + (linux_offset * 3),
			weight    = 500,
			blursize  = 2,
		})
	end)

	cvars.AddChangeCallback("easychat_font_size",function(name,old,new)
		surface.CreateFont("EasyChatFont",{
			font      = font,
			extended  = true,
			size      = tonumber(new),
			weight    = 500,
			shadow    = true,
			additive  = true,
		})
	end)

	cvars.AddChangeCallback("easychat_hud_font_size",function(name,old,new)
		surface.CreateFont("EasyChatHUDFont",{
			font      = font,
			extended  = true,
			size      = tonumber(new),
			weight    = 500,
		})

		surface.CreateFont("EasyChatHUDShadow",{
			font      = font,
			extended  = true,
			size      = tonumber(new),-- + (linux_offset * 3),
			weight    = 500,
			blursize  = 2,
		})
	end)

	local coljson = file.Read("easychat/colors.txt","DATA")
	if coljson then
		local cols = util.JSONToTable(coljson)
		EasyChat.OutlayColor        = Color(cols.outlay.r,cols.outlay.g,cols.outlay.b,cols.outlay.a)
		EasyChat.OutlayOutlineColor = Color(cols.outlayoutline.r,cols.outlayoutline.g,cols.outlayoutline.b,cols.outlayoutline.a)
		EasyChat.TabOutlineColor    = Color(cols.taboutline.r,cols.taboutline.g,cols.taboutline.b,cols.taboutline.a)
		EasyChat.TabColor           = Color(cols.tab.r,cols.tab.g,cols.tab.b,cols.tab.a)
	else
		EasyChat.OutlayColor        = Color(49,49,49,208)
		EasyChat.OutlayOutlineColor = Color(0,0,0,255)
		EasyChat.TabOutlineColor    = Color(0,0,0,255)
		EasyChat.TabColor     		= Color(39,40,34,255)
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
		return EasyChat.ChatBox and EasyChat.ChatBox:IsVisible()
	end

	EasyChat.LinkPatterns = {
		"https?://[^%s%\"]+",
		"ftp://[^%s%\"]+",
		"steam://[^%s%\"]+",
	}

	EasyChat.Open = function()
		EasyChat.ChatBox:Show()
		EasyChat.ChatBox:MakePopup()
		EasyChat.Mode = 0
		if GetConVar("easychat_global_on_open"):GetBool() then
			EasyChat.TabControl:SetActiveTab(EasyChat.TabControl.Items[1].Tab)
			EasyChat.TextEntry:RequestFocus()
		end
		for k,v in pairs(EasyChat.Tabs) do
			if v.NotificationCount and v.NotificationCount > 0 then
				chat.AddText("EC",Color(175,175,175)," ⮞ ",Color(244, 167, 66),v.NotificationCount,Color(255,255,255)," new notifications from "..k)
				v.NotificationCount = 0
			end
		end
	end

	EasyChat.Close = function()
		if EasyChat.IsOpened() then
			EasyChat.ChatBox:SetMouseInputEnabled( false )
			EasyChat.ChatBox:SetKeyboardInputEnabled( false )
			gui.EnableScreenClicker( false )
			EasyChat.TextEntry:SetText( "" )
			gamemode.Call( "ChatTextChanged", "" )
			gamemode.Call( "FinishChat" )
			EasyChat.SavePosSize()
			EasyChat.ChatBox:Hide()
			chat.Close()
		end
	end

	EasyChat.IsURL = function(str)
		for index,pattern in ipairs(EasyChat.LinkPatterns) do
			if string.match(str,pattern) then
				if index == #EasyChat.LinkPatterns then
					return true
				end
			end
		end

		return false
	end

	EasyChat.GetURLPoses = function(str,added,poses)
		local poses = poses or {}
		local added = added or {}
		local redo  = false
		for _, pattern in ipairs(EasyChat.LinkPatterns) do
			local startp,endp,_ = string.find(str,pattern)
			if startp and not added[startp] and added[startp] ~= endp then
				table.insert(poses,{Start = startp,End = endp})
				added[startp] = endp
				redo = true
			end
		end
		if redo then
			EasyChat.GetURLPoses(str,added,poses)
		end
		return poses
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
			-- overrides
			EasyChat.old_chat_AddText = EasyChat.old_chat_AddText or chat.AddText

			chat.AddText = function(...)
				EasyChat.InsertColorChange(255,255,255,255) --we do job of devs that forget to set it back to white
				local args = { ... }
				for _,arg in pairs(args) do
					if type(arg) == "table" then
						EasyChat.InsertColorChange(arg.r,arg.g,arg.b,arg.a or 255)
					elseif type(arg) == "string" then
						local isurl = EasyChat.IsURL(arg)
						if isurl then
							local poses = EasyChat.GetURLPoses(arg)
							for k,pos in pairs(poses) do
								EasyChat.AppendText(string.sub(arg,k == 1 and 1 or (poses[k-1].End + 1),(pos.Start - 1)))

								local url = string.gsub(string.sub(arg,pos.Start,pos.End),"^%s:","")
								EasyChat.RichText:InsertClickableTextStart(url)
								EasyChat.AppendText(url)
								EasyChat.RichText:InsertClickableTextEnd()

								EasyChat.AppendText(string.sub(arg,(pos.End + 1),poses[k+1] and (poses[k+1].Start - 1) or string.len(arg)))
							end
						else
							EasyChat.AppendText(arg)
						end
					elseif arg:IsPlayer() then
						local col = GetConVar("easychat_players_colored"):GetBool() and team.GetColor(arg:Team()) or Color(255,255,255)
						EasyChat.InsertColorChange(col.r,col.g,col.b,255)
						EasyChat.AppendText(arg:GetName())
					else
						EasyChat.AppendText(tostring(arg))
					end
				end
				EasyChat.AppendText("\n")
				EasyChat.old_chat_AddText(...)
			end

			local meta = FindMetaTable("Player")
			EasyChat.old_Player_PrintMessage = EasyChat.old_Player_PrintMessage or meta.PrintMessage
			meta.PrintMessage = function(self,enum,text)
				if enum == HUD_PRINTTALK then
					EasyChat.AppendText(text.."\n")
				end
				EasyChat.old_Player_PrintMessage(self,enum,text)
			end
		end

		EasyChat.SavePosSize = function()
			local x,y,w,h = EasyChat.ChatBox:GetBounds()
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

		EasyChat.LoadPosSize = function()
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
				return 25,25,w,h*1.5
			end
		end

		do
			------ Main frame -----
			local frame = vgui.Create("DFrame")
			local cx,cy,cw,ch = EasyChat.LoadPosSize()
			frame:SetSize(cw,ch)
			frame:SetPos(cx,cy)
			frame:ShowCloseButton(true)
			frame:SetDraggable(true)
			frame:SetSizable(true)
			frame:SetDeleteOnClose(false)
			frame:SetTitle("")

			frame.btnClose:SetZPos(10)

			frame.btnClose.DoClick = function()
				EasyChat.Close()
			end

			frame.btnMaxim:Hide()
			frame.btnMinim:Hide()

			------ To make dms and stuff later ------
			local tabs = frame:Add("DPropertySheet")
			tabs:SetSize(cw-16,ch-20)
			tabs:SetPos(8,13)

			tabs.old_performlayout = tabs.PerformLayout
			tabs.PerformLayout = function(self)
				self.old_performlayout(self)
				self.tabScroller:SetTall(20)
			end

			tabs.Think = function(self)
				local x,y,w,h = frame:GetBounds()
				tabs:SetSize(w-16,h-20)
			end

			local scroller = tabs.tabScroller
			scroller:SetParent(tabs)
			scroller:Dock(TOP)
			scroller:SetSize(0,20)
			scroller.m_iOverlap = -2

			EasyChat.AddTab = function(name,panel)
				local tab = tabs:AddSheet(name,panel)
				tab.Tab:SetFont("EasyChatFont")
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
			richt.Think = function(self)
				local x,y,w,h = maintab:GetBounds()
				richt:SetSize(w,h-20)
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

			----- Chat HUD -----
			local cshadow = vgui.Create("RichText")
			cshadow:SetVerticalScrollbarEnabled(false)
			cshadow:SetSelectable(false)
			cshadow.PerformLayout = function(self)
				self:SetFontInternal("EasyChatHUDShadow")
				self:SetFGColor(50,50,50)
				self:InsertFade( 16, 2 )
			end
			cshadow:ParentToHUD() -- do not touch this
			cshadow:SetPaintedManually(true)
			cshadow:InsertColorChange(25,50,100,255)

			cshadow.Paint = function(self,w,h)
				surface.SetDrawColor(0,0,0,0)
				surface.DrawRect(0,0,w,h)
			end

			cshadow.Think = function(self)
				local x,y,w,h
				if GetConVar("easychat_hud_follow"):GetBool() then
					x,y,w,h = richt:GetBounds()
				else
					x,y = chat.GetChatBoxPos()
					w,h = chat.GetChatBoxSize()
				end
				self:SetPos(x,y)
				self:SetSize(w,h)
			end

			local chud = vgui.Create("RichText")
			chud:SetVerticalScrollbarEnabled(false)
			chud:SetSelectable(false)
			chud.PerformLayout = function(self)
				self:SetFontInternal("EasyChatHUDFont")
				self:SetFGColor(EasyChat.TextColor)
				self:InsertFade( 16, 2 )
			end
			chud:ParentToHUD() -- let this be
			chud:SetPaintedManually(true)

			chud.Paint = function(self,w,h)
				for i = 1, 10 do
					EasyChat.HUDShadow:PaintManual()
				end
			end

			chud.Think = function(self)
				local x,y,w,h
				if GetConVar("easychat_hud_follow") and GetConVar("easychat_hud_follow"):GetBool() then
					x,y,w,h = richt:GetBounds()
				else
					x,y = chat.GetChatBoxPos()
					w,h = chat.GetChatBoxSize()
				end
				self:SetPos(x,y)
				self:SetSize(w,h)
			end

			if not EasyChat.UseDermaSkin then
				frame.Paint = function(self,wide,tall)
					surface.SetDrawColor(EasyChat.OutlayColor)
					surface.DrawRect(0, 0, wide, tall)
					surface.SetDrawColor(EasyChat.OutlayOutlineColor)
					surface.DrawOutlinedRect(0, 0, wide, tall)
				end

				frame.btnClose.Paint = function(self,w,h)
					local wide, tall = w, 20
					surface.SetDrawColor(246,40,40)
					surface.DrawRect(0,5,wide,tall)
					surface.SetDrawColor(200,20,20)
					surface.DrawOutlinedRect(0,5,wide,tall)
					surface.SetTextColor(200,20,20)
					surface.SetFont("DermaDefaultBold")
					local x,y = surface.GetTextSize("X")
					surface.SetTextPos(wide/2-x/2,tall/2-y/2+5)
					surface.DrawText("X")
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
			EasyChat.ChatBox    = frame
			EasyChat.ChatHUD    = chud
			EasyChat.MainTab    = main
			EasyChat.HUDShadow  = cshadow
			EasyChat.TextEntry  = tentry
			EasyChat.RichText   = richt
			EasyChat.TabControl = tabs

			EasyChat.Close()
		end

		EasyChat.InsertColorChange = function(r,g,b,a)
			EasyChat.RichText:InsertColorChange(r,g,b,a)
			EasyChat.ChatHUD:InsertColorChange(r,g,b,a)
		end

		EasyChat.AppendText = function(text)
			EasyChat.RichText:AppendText(text)
			EasyChat.ChatHUD:AppendText(text)
			EasyChat.HUDShadow:AppendText(text)
		end

		local last_key = KEY_ENTER
		EasyChat.TextEntry.OnKeyCodeTyped = function( self, code )
			if code == KEY_ESCAPE then
				EasyChat.Close()
			elseif code == KEY_ENTER or code == KEY_PAD_ENTER then
				if string.Trim( self:GetText() ) ~= "" and string.Trim( self:GetText() ) ~= "╚​" then
					if EasyChat.Mode == 0 then
						net.Start(netreceivemsg)
						net.WriteString(string.sub(self:GetText(),1,3000))
						net.SendToServer()
					else
						local mode = EasyChat.Modes[EasyChat.Mode]
						mode.Callback(self:GetText())
					end
				end

				self:AddHistory(self:GetText())
				self.HistoryPos = 0
				EasyChat.Close()
			end

			if code == KEY_UP then
				self.HistoryPos = self.HistoryPos - 1
				self:UpdateFromHistory()
			elseif code == KEY_DOWN then
				self.HistoryPos = self.HistoryPos + 1
				self:UpdateFromHistory()
			end

			if last_key == KEY_LCONTROL then --shortcut zone
				local pos = self:GetCaretPos()
				local first = string.sub(self:GetText(),1,pos+1)
				local last = string.sub(self:GetText(),pos+1,string.len(self:GetText()))

				if code == KEY_BACKSPACE then
					local args = string.Explode(" ",first)
					self:SetText(table.concat(args," ",1,#args-1)..last)
					self:SetCaretPos(pos-string.len(args[#args]))
				end
				if code == KEY_DELETE then
					local args = string.Explode(" ",last)
					self:SetText(first..table.concat(args," ",2,#args))
					self:SetCaretPos(pos)
				end
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

		EasyChat.TextEntry.OnValueChange = function(self,text)
			gamemode.Call("ChatTextChanged",text)
		end

		EasyChat.RichText.ActionSignal = function(self,name,value)
			if name == "TextClicked" then
				gui.OpenURL(value)
			end
		end

		hook.Add("HUDPaint", tag, function()
			EasyChat.ChatHUD:PaintManual()
		end)

		hook.Add( "HUDShouldDraw", tag, function( name ) -- hudchat is still yet to make
			if name == "CHudChat" then
				return false
			end
		end)

		hook.Add( "StartChat",tag,function(team)
			EasyChat.Open()
			return true
		end)

		if not GetConVar("easychat_no_modules"):GetBool() then
			EasyChat.LoadModules()
		end

		do

			local ResetColors = function()
				EasyChat.OutlayColor        = Color(49,49,49,208)
				EasyChat.OutlayOutlineColor = Color(0,0,0,255)
				EasyChat.TabOutlineColor    = Color(0,0,0,255)
				EasyChat.TabColor     		= Color(39,40,34,255)
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
				fontsize:SetValue(GetConVar("easychat_font_size"):GetInt())
			end)

			local lhfontsize = panel:Add("DLabel")
			lhfontsize:SetPos(15,300)
			lhfontsize:SetSize(100,10)
			lhfontsize:SetText("HUD font size")

			local hfontsize = panel:Add("DNumberWang")
			hfontsize:SetPos(15,310)
			hfontsize:SetSize(100,25)
			hfontsize:SetMin(0)
			hfontsize:SetMax(40)
			hfontsize:SetValue(font_hud_size)
			hfontsize.OnValueChanged = function(self,val)
				LocalPlayer():ConCommand("easychat_hud_font_size "..val)
			end
			cvars.AddChangeCallback("easychat_hud_font_size",function(name,old,new)
				hfontsize:SetValue(GetConVar("easychat_hud_font_size"):GetInt())
			end)

			local fontreset = panel:Add("DButton")
			fontreset:SetPos(15,345)
			fontreset:SetSize(100,25)
			fontreset:SetText("Reset Font")
			fontreset:SetTextColor(EasyChat.TextColor)

			fontreset.DoClick = function()
				LocalPlayer():ConCommand("easychat_font Roboto")
				LocalPlayer():ConCommand("easychat_font_size 17")
				LocalPlayer():ConCommand("easychat_hud_font_size 19")
			end

			local chud = panel:Add("DCheckBoxLabel")
			chud:SetText("ChatHUD follows chatbox")
			chud:SetPos(170,15)
			chud:SetValue(GetConVar("easychat_hud_follow"):GetBool())
			chud.OnChange = function(self,val)
				LocalPlayer():ConCommand("easychat_hud_follow "..(val and 1 or 0))
			end
			cvars.AddChangeCallback("easychat_hud_follow",function(name,old,new)
				chud:SetValue(GetConVar("easychat_hud_follow"):GetBool())
			end)

			local tstamps = panel:Add("DCheckBoxLabel")
			tstamps:SetText("Display timestamps")
			tstamps:SetPos(170,40)
			tstamps:SetValue(GetConVar("easychat_timestamps"):GetBool())
			tstamps.OnChange = function(self,val)
				LocalPlayer():ConCommand("easychat_timestamps "..(val and 1 or 0))
			end
			cvars.AddChangeCallback("easychat_hud_follow",function(name,old,new)
				tstamps:SetValue(GetConVar("easychat_timestamps"):GetBool())
			end)

			local teams = panel:Add("DCheckBoxLabel")
			teams:SetText("Display team tags")
			teams:SetPos(170,65)
			teams:SetValue(GetConVar("easychat_teams"):GetBool())
			teams.OnChange = function(self,val)
				LocalPlayer():ConCommand("easychat_teams "..(val and 1 or 0))
			end
			cvars.AddChangeCallback("easychat_teams",function(name,old,new)
				teams:SetValue(GetConVar("easychat_teams"):GetBool())
			end)

			local teamsc = panel:Add("DCheckBoxLabel")
			teamsc:SetText("Color team tags")
			teamsc:SetPos(170,90)
			teamsc:SetValue(GetConVar("easychat_teams_colored"):GetBool())
			teamsc.OnChange = function(self,val)
				LocalPlayer():ConCommand("easychat_teams_colored "..(val and 1 or 0))
			end
			cvars.AddChangeCallback("easychat_teams_colored",function(name,old,new)
				teamsc:SetValue(GetConVar("easychat_teams_colored"):GetBool())
			end)

			local plc = panel:Add("DCheckBoxLabel")
			plc:SetText("Color players")
			plc:SetPos(170,115)
			plc:SetValue(GetConVar("easychat_players_colored"):GetBool())
			plc.OnChange = function(self,val)
				LocalPlayer():ConCommand("easychat_players_colored "..(val and 1 or 0))
			end
			cvars.AddChangeCallback("easychat_players_colored",function(name,old,new)
				plc:SetValue(GetConVar("easychat_players_colored"):GetBool())
			end)

			local global = panel:Add("DCheckBoxLabel")
			global:SetText("Global tab on open")
			global:SetPos(170,140)
			global:SetValue(GetConVar("easychat_global_on_open"):GetBool())
			global.OnChange = function(self,val)
				LocalPlayer():ConCommand("easychat_global_on_open "..(val and 1 or 0))
			end
			cvars.AddChangeCallback("easychat_global_on_open",function(name,old,new)
				global:SetValue(GetConVar("easychat_global_on_open"):GetBool())
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
				LocalPlayer():ConCommand("easychat_hud_follow 1")
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
				LocalPlayer():ConCommand("easychat_hud_follow 1")
				LocalPlayer():ConCommand("easychat_font Roboto")
				LocalPlayer():ConCommand("easychat_font_size 17")
				LocalPlayer():ConCommand("easychat_hud_font_size 19")
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

		EasyChat.AddTags = function()
			if GetConVar("easychat_timestamps"):GetBool() then
				EasyChat.AppendText(os.date("%H:%M:%S").."-")
			end
			if GetConVar("easychat_teams"):GetBool() then
				if GetConVar("easychat_teams_colored"):GetBool() then
					local tcol = team.GetColor(ply:Team())
					EasyChat.InsertColorChange(tcol.r,tcol.g,tcol.b,tcol.a)
				end
				EasyChat.AppendText("["..team.GetName(ply:Team()).."]")
			end
		end


		hook.Run("EasyChatOnInit")

	end

	net.Receive(netprintmsg, function()
		local msg = net.ReadString()
		EasyChat.AppendText(msg.."\n")
	end)

	net.Receive(netbroadcastmsgs,function()
		local ply  = net.ReadEntity()
		local msg  = net.ReadString()
		local dead = net.ReadBool()
		EasyChat.AddTags()
		gamemode.Call("OnPlayerChat", ply, msg,false,dead)
	end)

	net.Receive(netlocalsend,function()
		local ply  = net.ReadEntity()
		local msg  = net.ReadString()
		local dead = net.ReadBool()
		EasyChat.AddTags()
		EasyChat.InsertColorChange(255,255,255,255)
		EasyChat.AppendText("(Local) ")
		gamemode.Call("OnPlayerChat", ply, msg,false,dead)
	end)

	hook.Add("Initialize",tag,function()
		if GetConVar("easychat_enable"):GetBool() then
			EasyChat.Init()
		end
	end)

	hook.Add( "ChatText", tag, function( index, name, text, type )
		if type == "none" then
			EasyChat.AppendText( text.."\n" )
		end
	end)

	EasyChat.IsChatKeyPressed = function()
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

	EasyChat.KeyChecker = function()
		if EasyChat.IsOpened() then
			if input.IsKeyDown(KEY_ESCAPE) then
				EasyChat.TextEntry:SetText("")
				EasyChat.Close()
			end
			local tab = EasyChat.TabControl:GetActiveTab()
			if tab.FocusOn and not tab.FocusOn:HasFocus() then
				local pressed,key = EasyChat.IsChatKeyPressed()
				if pressed then
					tab.FocusOn:RequestFocus()
					tab.FocusOn:SetText(key)
					tab.FocusOn:SetCaretPos(#tab.FocusOn:GetText())
				end
			end
		end
	end

	hook.Add("PreRender", tag, EasyChat.KeyChecker)

end

EasyChat.Destroy = function()
	if CLIENT then
		hook.Remove("HUDPaint",tag)
		hook.Remove("StartChat",tag)
		hook.Remove("HUDShouldDraw",tag)
		hook.Remove("ChatText", tag)
		--hook.Remove("PreRender", tag)

		if EasyChat.old_chat_AddText then
			chat.AddText = EasyChat.old_chat_AddText
			FindMetaTable("Player").PrintMessage = EasyChat.old_Player_PrintMessage
		end

		EasyChat.ModeCount = 0
		EasyChat.Mode = 0
		EasyChat.Modes = {}

		if EasyChat.IsOpened() then
			EasyChat.ChatBox:Remove()
		end

		EasyChat.ChatHUD:Remove()
		EasyChat.HUDShadow:Remove()

	end

	if SERVER then
		_G.PrintMessage = EasyChat.old_PrintMessage
		FindMetaTable("Player").PrintMessage = EasyChat.old_Player_PrintMessage
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
