local EasyChat = _G.EasyChat or {}

local netprintmsg      = "EASY_CHAT_PRINT_MSG"
local netbroadcastmsgs = "EASY_CHAT_BROADCAST_MSG"
local netreceivemsg    = "EASY_CHAT_RECEIVE_MSG"
local tag = "EasyChat"

EasyChat.LoadModules = function()
	local path = "easychat/modules/"

	for _,file_name in pairs((file.Find(path.."*.lua","LUA"))) do
		AddCSLuaFile(path..file_name)
		include(path..file_name)
		print("[EasyChatModule]: shared "..file_name.." loaded!")
	end

	if SERVER then
		for _,file_name in pairs((file.Find(path.."server/*.lua","LUA"))) do
			include(path.."server/"..file_name)
			print("[EasyChatModule]: server "..file_name.." loaded!")
		end

		for _,file_name in pairs((file.Find(path.."client/*.lua","LUA"))) do
			AddCSLuaFile(path.."client/"..file_name)
		end
	end

	if CLIENT then
		for _,file_name in pairs((file.Find(path.."client/*.lua","LUA"))) do
			include(path.."client/"..file_name)
			print("[EasyChatModule]: client "..file_name.." loaded!")
		end
	end

end

if SERVER then

	util.AddNetworkString(netprintmsg)
	util.AddNetworkString(netreceivemsg)
	util.AddNetworkString(netbroadcastmsgs)

	net.Receive(netreceivemsg,function(_,ply)
		local str = net.ReadString()
		local msg = gamemode.Call("PlayerSay", ply, str, false)
		if string.Trim(msg) == "" then return end
		net.Start(netbroadcastmsgs)
		net.WriteEntity(ply)
		net.WriteString(msg)
		net.WriteBool(IsValid(ply) and (not ply:Alive()) or false)
		net.Broadcast()
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
	CreateConVar("easychat_timestamps","0",FCVAR_ARCHIVE,"Display timestamp in front of messages or not")
	CreateConVar("easychat_teams","0",FCVAR_ARCHIVE,"Display team in front of messages or not")
	CreateConVar("easychat_teams_colored","0",FCVAR_ARCHIVE,"Display team with its relative color")
	CreateConVar("easychat_players_colored","1",FCVAR_ARCHIVE,"Display player with its relative team color")

	cvars.AddChangeCallback("easychat_font",function(name,old,new)
		surface.CreateFont("EasyChatFont",{
			font      = new,
			extended  = true,
			size      = 16,
			weight    = 500,
			shadow    = true,
			additive  = true,
		})

		surface.CreateFont("EasyChatHUDFont",{
			font      = new,
			extended  = true,
			size      = 18,
			weight    = 500,
		})

		surface.CreateFont("EasyChatHUDShadow",{
			font      = new,
			extended  = true,
			size      = 18,-- + (linux_offset * 3),
			weight    = 500,
			--outline = true,
			blursize  = 2,
		})
	end)

	local linux_offset = system.IsLinux() and 1 or 0
	local font = GetConVar("easychat_font"):GetString()

	surface.CreateFont("EasyChatFont",{
		font      = font,
		extended  = true,
		size      = 16,
		weight    = 500,
		shadow    = true,
		additive  = true,
	})

	surface.CreateFont("EasyChatHUDFont",{
		font      = font,
		extended  = true,
		size      = 18,
		weight    = 500,
	})

	surface.CreateFont("EasyChatHUDShadow",{
		font      = font,
		extended  = true,
		size      = 18,-- + (linux_offset * 3),
		weight    = 500,
		--outline = true,
		blursize  = 2,
	})

	local coljson = file.Read("easychat/colors.txt","DATA")
	if coljson then
		local cols = util.JSONToTable(coljson)
		EasyChat.OutlayColor        = Color(cols.outlay.r,cols.outlay.g,cols.outlay.b,cols.outlay.a)
		EasyChat.OutlayOutlineColor = Color(cols.outlayoutline.r,cols.outlayoutline.g,cols.outlayoutline.b,cols.outlayoutline.a)
		EasyChat.TabOutlineColor    = Color(cols.taboutline.r,cols.taboutline.g,cols.taboutline.b,cols.taboutline.a)
		EasyChat.TabColor           = Color(cols.tab.r,cols.tab.g,cols.tab.b,cols.tab.a)
	else
		EasyChat.OutlayColor		= Color(65,65,65,150)
		EasyChat.OutlayOutlineColor = Color(145,145,145,255)
		EasyChat.TabOutlineColor    = Color(175,175,175,255)
		EasyChat.TabColor           = Color(39,40,34,255)
	end

	EasyChat.TextColor = Color(255,255,255,255) --stays like that til someone can make it happen

	EasyChat.IsOpened = function()
		return EasyChat.ChatBox and EasyChat.ChatBox:IsVisible()
	end

	EasyChat.LinkPatterns = {
		"https?://[^%s%\"]+",
		"ftp://[^%s%\"]+",
		"steam://[^%s%\"]+",
		"www%.[^%s%\"]+", -- must always be last
	}

	EasyChat.Open = function()
		EasyChat.ChatBox:Show()
		EasyChat.ChatBox:MakePopup()
		EasyChat.TextEntry:RequestFocus()
		if GetConVar("easychat_global_on_open"):GetBool() then
			EasyChat.TabControl:SetActiveTab(EasyChat.TabControl.Items[1].Tab)
		end
		gamemode.Call( "StartChat" )
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
		end
	end

	EasyChat.IsURL = function(str)
		for index,pattern in ipairs(EasyChat.LinkPatterns) do
			if string.match(str,pattern) then
				if index == #EasyChat.LinkPatterns then
					return true, true
				else
					return true, false
				end
			end
		end

		return false,false
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

		do
			-- overrides
			EasyChat.old_chat_AddText = EasyChat.old_chat_AddText or chat.AddText

			chat.AddText = function(...)
				EasyChat.InsertColorChange(255,255,255,255) --we do job of devs that forget to set it back to white
				local args = { ... }
				for _,arg in pairs(args) do
					if type(arg) == "table" then
						EasyChat.InsertColorChange(arg.r,arg.g,arg.b,arg.a or 255)
					elseif type(arg) == "number" then
						EasyChat.AppendText(tostring(arg))
					elseif type(arg) == "string" then
						local isurl,_ = EasyChat.IsURL(arg)
						if isurl then
							local poses = EasyChat.GetURLPoses(arg)
							for k,pos in pairs(poses) do
								EasyChat.AppendText(string.sub(arg,k == 1 and 1 or (poses[k-1].End + 1),(pos.Start - 1)))

								local url = string.gsub(string.sub(arg,pos.Start,pos.End),"^%s:","")
								local _,www = EasyChat.IsURL(url)
								EasyChat.RichText:InsertClickableTextStart(www and "http://"..url or url)
								EasyChat.AppendText(url)
								EasyChat.RichText:InsertClickableTextEnd()

								EasyChat.AppendText(string.sub(arg,(pos.End + 1),poses[k+1] and (poses[k+1].Start - 1) or string.len(arg)))
							end
						else
							EasyChat.AppendText(arg)
						end
					elseif arg:IsPlayer() then
						if GetConVar("easychat_timestamps"):GetBool() then
							EasyChat.AppendText("["..os.date("%H:%M:%S").."]")
						end
						if GetConVar("easychat_teams"):GetBool() then
							if GetConVar("easychat_teams_colored"):GetBool() then
								local tcol = team.GetColor(arg:Team())
								EasyChat.InsertColorChange(tcol.r,tcol.g,tcol.b,tcol.a)
							end
							EasyChat.AppendText("["..team.GetName(arg:Team()).."]")
						end
						local col = GetConVar("easychat_players_colored"):GetBool() and team.GetColor(arg:Team()) or Color(255,255,255,255)
						EasyChat.InsertColorChange(col.r,col.g,col.b,col.a)
						EasyChat.AppendText(arg:GetName())
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

			frame.Paint = function(self,wide,tall)
				surface.SetDrawColor(EasyChat.OutlayColor)
				surface.DrawRect(0, 0, wide, tall)
				surface.SetDrawColor(EasyChat.OutlayOutlineColor)
				surface.DrawOutlinedRect(0, 0, wide, tall)
			end

			frame.btnClose:SetZPos(10)

			frame.btnClose.DoClick = function()
				EasyChat.Close()
			end

			frame.btnClose.Paint = function(self,w,h)
				local wide, tall = w, 18
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

			frame.btnMaxim:Hide()
			frame.btnMinim:Hide()

			------ To make dms and stuff later ------
			local tabs = frame:Add("DPropertySheet")
			tabs:SetSize(cw-16,ch-20)
			tabs:SetPos(8,13)
			tabs.Paint = function(self,w,h)
				surface.SetDrawColor(0,0,0,0)
				surface.DrawRect(0, 0, w, h)
			end

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

			------ Global chat ----
			local maintab = vgui.Create("DPanel")
			local main = tabs:AddSheet("Global", maintab)
			main.Tab:SetFont("EasyChatFont")
			main.Tab:SetFont("EasyChatFont")
			main.Tab.Paint = function(self,w,h)
				local wide,tall = w, h
				if self == EasyChat.TabControl:GetActiveTab() then
					surface.SetDrawColor(EasyChat.OutlayColor)
				else
					surface.SetDrawColor(EasyChat.TabColor)
				end
				surface.DrawRect(0,0, wide, tall)
				surface.SetDrawColor(EasyChat.TabOutlineColor)
				surface.DrawLine(0,0,wide,0)
				surface.DrawLine(0,0,0,tall)
				surface.DrawLine(wide-1,0,wide-1,tall)
			end
			maintab:Dock(FILL)
			maintab.Paint = function(self,w,h)
				surface.SetDrawColor(EasyChat.TabColor)
				surface.DrawRect(0, 0, w,h)
				surface.SetDrawColor(EasyChat.TabOutlineColor)
				surface.DrawOutlinedRect(0, 0, w,h)
			end

			local richt = maintab:Add("RichText")
			richt:Dock(FILL)
			richt:SetContentAlignment(2)
			richt.PerformLayout = function(self)
				self:SetFontInternal("EasyChatFont")
				self:SetFGColor(EasyChat.TextColor)
			end

			local tentry = maintab:Add("DTextEntry")
			tentry:Dock(BOTTOM)
			tentry:SetHistoryEnabled(true)
			tentry.HistoryPos = 0
			tentry:SetUpdateOnType(true)

			----- Chat HUD -----
			local cshadow = vgui.Create("RichText")
			cshadow:SetVerticalScrollbarEnabled(false)
			cshadow:SetContentAlignment(2)
			cshadow:SetSelectable(false)
			cshadow:ParentToHUD() -- do not touch this
			cshadow:SetPaintedManually(true)
			cshadow:InsertColorChange(25,50,100,255)
			cshadow.PerformLayout = function(self)
				self:SetFontInternal("EasyChatHUDShadow")
				self:SetFGColor(50,50,50)
				self:InsertFade( 8, 2 )
			end

			cshadow.Paint = function(self,w,h)
				surface.SetDrawColor(0,0,0,0)
				surface.DrawRect(0,0,w,h)
			end

			cshadow.Think = function(self)
				local x,y,w,h
				if GetConVar("easychat_hud_follow"):GetBool() then
					x,y,w,h = frame:GetBounds()
				else
					x,y,w,h = 25,25,cw,ch
				end
				self:SetPos(x,y)
				self:SetSize(w,h)
			end

			local chud = vgui.Create("RichText")
			chud:SetVerticalScrollbarEnabled(false)
			chud:SetContentAlignment(2)
			chud:SetSelectable(false)
			chud:ParentToHUD() -- let this be
			chud:SetPaintedManually(true)
			chud.PerformLayout = function(self)
				self:SetFontInternal("EasyChatHUDFont")
				self:SetFGColor(EasyChat.TextColor)
				self:InsertFade( 8, 2 )
			end

			chud.Paint = function(self,w,h)
				for i = 1, 10 do
					EasyChat.HUDShadow:PaintManual()
				end
			end

			chud.Think = function(self)
				local x,y,w,h
				if GetConVar("easychat_hud_follow") and GetConVar("easychat_hud_follow"):GetBool() then
					x,y,w,h = frame:GetBounds()
				else
					x,y,w,h = 25,25,cw,ch
				end
				self:SetPos(x,y)
				self:SetSize(w,h)
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

		EasyChat.AddTab = function(name,panel)
			local tab = EasyChat.TabControl:AddSheet(name,panel)
			tab.Tab:SetFont("EasyChatFont")
			tab.Tab.Paint = function(self,w,h)
				local wide,tall = w, h
				if self == EasyChat.TabControl:GetActiveTab() then
					surface.SetDrawColor(EasyChat.OutlayColor)
				else
					surface.SetDrawColor(EasyChat.TabColor)
				end
				surface.DrawRect(0,0, wide, tall)
				surface.SetDrawColor(EasyChat.TabOutlineColor)
				surface.DrawLine(0,0,wide,0)
				surface.DrawLine(0,0,0,tall)
				surface.DrawLine(wide-1,0,wide-1,tall)
			end
			panel:Dock(FILL)
			panel.Paint = function(self,w,h)
				surface.SetDrawColor(EasyChat.TabColor)
				surface.DrawRect(0, 0, w,h)
				surface.SetDrawColor(EasyChat.TabOutlineColor)
				surface.DrawOutlinedRect(0, 0, w,h)
			end
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

		EasyChat.TextEntry.OnKeyCodeTyped = function( self, code )
			if code == KEY_ESCAPE then
				EasyChat.Close()
				gui.HideGameUI()
			elseif code == KEY_ENTER then
				if string.Trim( self:GetText() ) ~= "" then
					net.Start(netreceivemsg)
					net.WriteString(string.sub(self:GetText(),1,3000))
					net.SendToServer()
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

			if code == KEY_TAB then
				local a = gamemode.Call("OnChatTab", self:GetText())
				self:SetText(a)
				timer.Simple(0, function() self:RequestFocus() self:SetCaretPos(#self:GetText()) end)
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

		hook.Add( "PlayerBindPress", tag, function( ply, bind, pressed )
			if bind == "messagemode" then
				EasyChat.Open()
			elseif bind == "messagemode2" then
				EasyChat.Open()
			else
				return
			end

			return true
		end)

		hook.Add( "HUDShouldDraw", tag, function( name ) -- hudchat is still yet to make
			if name == "CHudChat" then
				return false
			end
		end)

		hook.Add( "ChatText", tag, function( index, name, text, type )
			if type == "none" then
				EasyChat.InsertColorChange(244,66,66,255)
				EasyChat.AppendText( "Info" )
				EasyChat.InsertColorChange(175,175,175,255)
				EasyChat.AppendText( " ⮞⮞ " )
				EasyChat.InsertColorChange(255,255,255,255)
				EasyChat.AppendText( text.."\n" )
			end
		end)

		EasyChat.LoadModules()

		do
			local ResetColors = function()
				EasyChat.OutlayColor        = Color(65,65,65,240)
				EasyChat.OutlayOutlineColor = Color(130,130,130,255)
				EasyChat.TabOutlineColor    = Color(175,175,175,255)
				EasyChat.TabColor     		= Color(39,40,34,255)
				EasyChat.TextColor          = Color(255,255,255,255)
				file.Delete("easychat/colors.txt")
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
			apply.Paint = function(self,w,h)
				surface.SetDrawColor(EasyChat.OutlayColor)
				surface.DrawRect(0,0,w,h)
				surface.SetDrawColor(EasyChat.TabOutlineColor)
				surface.DrawOutlinedRect(0,0,w,h)
			end

			local resetc = panel:Add("DButton")
			resetc:SetPos(15,150)
			resetc:SetText("Reset Colors")
			resetc:SetTextColor(EasyChat.TextColor)
			resetc:SetSize(100,25)
			resetc.Paint = function(self,w,h)
				surface.SetDrawColor(EasyChat.OutlayColor)
				surface.DrawRect(0,0,w,h)
				surface.SetDrawColor(EasyChat.TabOutlineColor)
				surface.DrawOutlinedRect(0,0,w,h)
			end

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

			local fontentry = panel:Add("DTextEntry")
			fontentry:SetPos(15,190)
			fontentry:SetSize(100,25)
			fontentry:SetText("font name here")

			local fontapply = panel:Add("DButton")
			fontapply:SetPos(15,225)
			fontapply:SetSize(100,25)
			fontapply:SetText("Apply Font")
			fontapply:SetTextColor(EasyChat.TextColor)
			fontapply.Paint = function(self,w,h)
				surface.SetDrawColor(EasyChat.OutlayColor)
				surface.DrawRect(0,0,w,h)
				surface.SetDrawColor(EasyChat.TabOutlineColor)
				surface.DrawOutlinedRect(0,0,w,h)
			end
			fontapply.DoClick = function()
				LocalPlayer():ConCommand("easychat_font "..fontentry:GetValue())
			end

			local fontreset = panel:Add("DButton")
			fontreset:SetPos(15,260)
			fontreset:SetSize(100,25)
			fontreset:SetText("Reset Font")
			fontreset:SetTextColor(EasyChat.TextColor)
			fontreset.Paint = function(self,w,h)
				surface.SetDrawColor(EasyChat.OutlayColor)
				surface.DrawRect(0,0,w,h)
				surface.SetDrawColor(EasyChat.TabOutlineColor)
				surface.DrawOutlinedRect(0,0,w,h)
			end
			fontreset.DoClick = function()
				LocalPlayer():ConCommand("easychat_font Roboto")
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
			reseto.Paint = function(self,w,h)
				surface.SetDrawColor(EasyChat.OutlayColor)
				surface.DrawRect(0,0,w,h)
				surface.SetDrawColor(EasyChat.TabOutlineColor)
				surface.DrawOutlinedRect(0,0,w,h)
			end

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
			reset.Paint = function(self,w,h)
				surface.SetDrawColor(EasyChat.OutlayColor)
				surface.DrawRect(0,0,w,h)
				surface.SetDrawColor(EasyChat.TabOutlineColor)
				surface.DrawOutlinedRect(0,0,w,h)
			end

			reset.DoClick = function()
				LocalPlayer():ConCommand("easychat_timestamps 0")
				LocalPlayer():ConCommand("easychat_teams 0")
				LocalPlayer():ConCommand("easychat_teams_colored 0")
				LocalPlayer():ConCommand("easychat_global_on_open 1")
				LocalPlayer():ConCommand("easychat_players_colored 1")
				LocalPlayer():ConCommand("easychat_hud_follow 1")
				ResetColors()
			end

			local reload = panel:Add("DButton")
			reload:SetPos(170,235)
			reload:SetText("Restart")
			reload:SetTextColor(EasyChat.TextColor)
			reload:SetSize(100,25)
			reload.Paint = function(self,w,h)
				surface.SetDrawColor(EasyChat.OutlayColor)
				surface.DrawRect(0,0,w,h)
				surface.SetDrawColor(EasyChat.TabOutlineColor)
				surface.DrawOutlinedRect(0,0,w,h)
			end

			reload.DoClick = function()
				LocalPlayer():ConCommand("easychat_reload")
			end

		end

	end

	net.Receive(netprintmsg, function()
		local msg = net.ReadString()
		EasyChat.AppendText(msg.."\n")
	end)

	net.Receive(netbroadcastmsgs,function()
		local ply  = net.ReadEntity()
		local msg  = net.ReadString()
		local dead = net.ReadBool()

		gamemode.Call("OnPlayerChat", ply, msg, false,dead)
	end)

	hook.Add("Initialize", tag, EasyChat.Init)

	EasyChat.CloseWithESC = function()
		if (gui.IsGameUIVisible()) and (IsValid(EasyChat.ChatBox) and EasyChat.ChatBox:IsVisible()) then
			if input.IsKeyDown(KEY_ESCAPE) then
				EasyChat.TextEntry:SetText("")
				gui.HideGameUI()
				EasyChat.Close()
			end
		end
	end

	hook.Add("PreRender", tag, EasyChat.CloseWithESC)

end

EasyChat.Destroy = function()
	if CLIENT then
		hook.Remove("HUDPaint",tag)
		hook.Remove("PlayerBindPress",tag)
		hook.Remove("HUDShouldDraw",tag)
		hook.Remove("ChatText", tag)

		if EasyChat.old_chat_AddText then
			chat.AddText = EasyChat.old_chat_AddText
			FindMetaTable("Player").PrintMessage = EasyChat.old_Player_PrintMessage
		end

		if EasyChat.IsOpened() then
			EasyChat.ChatBox:Close()
		end
		EasyChat.ChatHUD:Remove()
	end

	if SERVER then
		_G.PrintMessage = EasyChat.old_PrintMessage
		FindMetaTable("Player").PrintMessage = EasyChat.old_Player_PrintMessage
	end
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

if _G.EasyChat then
	EasyChat.Destroy()
end

_G.EasyChat = EasyChat

if me then
	EasyChat.Init()
end
