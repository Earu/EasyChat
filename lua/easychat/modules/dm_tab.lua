local EASYCHAT_DM = "EASY_CHAT_MODULE_DM"
local EASYCHAT_DM_REMOVE = "EASY_CHAT_MODULE_DM_REMOVE"

if SERVER then
	util.AddNetworkString(EASYCHAT_DM)
	util.AddNetworkString(EASYCHAT_DM_REMOVE)

	net.Receive(EASYCHAT_DM, function(_, ply)
		local target = net.ReadEntity()
		local msg = net.ReadString()

		msg = EasyChat.ExtendedStringTrim(msg)
		if not IsValid(target) or #msg == 0 then return end

		net.Start(EASYCHAT_DM)
		net.WriteEntity(ply)
		net.WriteString(msg)
		net.Send(target)
	end)

	hook.Add("PlayerDisconnected", "EasyChatModuleDMTab", function(ply)
		net.Start(EASYCHAT_DM_REMOVE)
		net.WriteEntity(ply)
		net.Broadcast()
	end)
end

if CLIENT then
	local color_white = color_white

	local EC_HISTORY = GetConVar("easychat_history")
	local EC_TICK_SOUND = GetConVar("easychat_tick_sound")

	local DM_TAB = {
		Chats = {},
		ActiveChat = {
			Player = NULL,
			RichText = NULL,
			Name = "",
			NewMessages = 0,
			Line = NULL
		},
		Init = function(self)
			local frame = self

			self.DMList = self:Add("DListView")
			self.DMList:SetWide(100)
			self.DMList:Dock(LEFT)
			self.DMList:AddColumn("Chats")
			self.DMList.OnRowSelected = function(self, index, row)
				local ply = row.Player
				if IsValid(ply) then
					if IsValid(frame.ActiveChat.RichText) then
						frame.ActiveChat.RichText:Hide()
					end
					local chat = frame.Chats[ply]
					chat.RichText:Show()
					chat.NewMessages = 0
					frame.ActiveChat = chat
				else
					self:RemoveLine(index)
				end
			end

			self.TextEntry = self:Add("DTextEntry")
			self.TextEntry:SetTall(20)
			self.TextEntry:Dock(BOTTOM)
			self.TextEntry:SetHistoryEnabled(true)
			self.TextEntry.HistoryPos = 0
			self.TextEntry:SetUpdateOnType(true)
			self.TextEntry.OnKeyCodeTyped = function(self, code)
				EasyChat.SetupHistory(self, code)
				EasyChat.UseRegisteredShortcuts(self, code)

				if code == KEY_ESCAPE then
					chat.Close()
					gui.HideGameUI()
				elseif code == KEY_ENTER or code == KEY_PAD_ENTER then
					local text = EasyChat.ExtendedStringTrim(self:GetText())
					if #text > 0 then
						frame:SendMessage(text:sub(1, 3000))
					end
				end
			end

			if not EasyChat.UseDermaSkin then
				local selection_color = Color(255, 0, 0, 127)
				self.TextEntry.Paint = function(self, w, h)
					local border_color = EasyChat.TabOutlineColor.a == 0
						and EasyChat.OutlayColor or EasyChat.TabOutlineColor
					surface.SetDrawColor(border_color)
					surface.DrawLine(0, 0, w, 0)

					self:DrawTextEntryText(EasyChat.TextColor, selection_color, EasyChat.TextColor)
				end

				self.DMList.Paint = function(self, w, h)
					surface.SetDrawColor(EasyChat.OutlayColor)
					surface.DrawRect(0, 0, w, h)
					surface.SetDrawColor(EasyChat.TabOutlineColor)
					surface.DrawOutlinedRect(0, 0, w, h)
				end

				local header = self.DMList.Columns[1].Header
				header:SetTextColor(Color(255, 255, 255))
				header.Paint = function(self, w, h)
					surface.SetDrawColor(EasyChat.TabColor)
					surface.DrawRect(0, 0, w, h)
					surface.SetDrawColor(EasyChat.OutlayColor)
					surface.DrawLine(w - 1, 0, w - 1, h)
					surface.SetDrawColor(EasyChat.TabOutlineColor)
					surface.DrawOutlinedRect(0, 0, w, h)
				end
			end
		end,
		CreateChat = function(self, ply)
			if not IsValid(ply) then return end
			if self.Chats[ply] then return end

			local id64 = ply:SteamID64()
			local richtext = self:Add("RichTextLegacy")
			richtext.HistoryName = id64 -- so we save our chat history with that player

			if not EasyChat.UseDermaSkin then
				richtext:InsertColorChange(255, 255, 255, 255)
			end

			richtext.PerformLayout = function(self)
				self:SetFontInternal("EasyChatFont")
				self:SetUnderlineFont("EasyChatFont")
				if not EasyChat.UseDermaSkin then
					self:SetFGColor(EasyChat.TextColor)
				end
			end

			richtext.ActionSignal = EasyChat.GUI.RichText.ActionSignal
			richtext:Dock(FILL)
			richtext:DockMargin(0, 0, 0, 5)
			richtext:Hide()

			local chat = {
				Player = ply,
				Name = ply:Nick(),
				RichText = richtext,
				NewMessages = 0
			}

			local line = self.DMList:AddLine(chat.Name)
			if not EasyChat.UseDermaSkin then
				line.Columns[1]:SetTextColor(Color(255, 255, 255))
			end
			line.Player = ply
			chat.Line = line

			self.Chats[ply] = chat

			if not IsValid(self.ActiveChat.Player) then
				self.ActiveChat = chat
			end

			if EC_HISTORY:GetBool() then
				local history = EasyChat.ReadFromHistory(id64)
				if EasyChat.IsStringEmpty(history) then
					EasyChat.AddText(richtext, "This is the beginning of your conversation!\n\n")
				else
					richtext:AppendText(history) -- so we do not log twice
					richtext:AppendText("\n^^^^^ Last Session History ^^^^^\n\n")
				end
			else
				EasyChat.AddText(richtext, "This is the beginning of your conversation!\n\n")
			end

			return chat
		end,
		RemoveChat = function(self, ply)
			if not IsValid(ply) then return end
			if not self.Chats[ply] then	return end

			local chat = self.Chats[ply]
			chat.RichText:Remove()
			self.Chats[ply] = nil

			self.DMList:Clear()
			for _, chat in pairs(self.Chats) do
				local line = self.DMList:AddLine(chat.Player:RichNick())
				chat.Line = line
				line.Player = chat.Player
			end
		end,
		SendMessage = function(self, message)
			local i = self.DMList:GetSelectedLine()
			local line = self.DMList:GetLine(i)
			if not line then
				self.TextEntry:SetText("")
				return
			end

			local ply = line.Player
			if IsValid(ply) then
				local chat = self.Chats[ply]
				EasyChat.AddText(chat.RichText, LocalPlayer(), color_white, ": " .. message)
				net.Start(EASYCHAT_DM)
				net.WriteEntity(chat.Player)
				net.WriteString(message)
				net.SendToServer()
			else
				EasyChat.AddText(chat.RichText, "The player you are trying to message is not on the server anymore!")
			end

			self.TextEntry:SetText("")
		end,
		Notify = function(self, chat, message)
			chat.NewMessages = chat.NewMessages + 1
			EasyChat.FlashTab("DM")
			_G.chat.AddText(color_white, "[DM | ", chat.Player, color_white, "] " .. message)
		end,
		Think = function(self)
			for _, chat in pairs(self.Chats) do
				local line = chat.Line
				if not IsValid(chat.Player) then return end

				if chat.NewMessages > 0 then
					line:SetColumnText(1, chat.Player:RichNick() .. " (" .. chat.NewMessages .. ")")
				else
					line:SetColumnText(1, chat.Player:RichNick())
				end
			end
		end,
		PaintOver = function(self, w, h)
			surface.SetDrawColor(EasyChat.TabOutlineColor)
			surface.DrawOutlinedRect(0, 0, w, h)
		end
	}

	vgui.Register("ECDMTab", DM_TAB, "DPanel")
	local dmtab = vgui.Create("ECDMTab")

	net.Receive(EASYCHAT_DM, function()
		local sender = net.ReadEntity()
		local message = net.ReadString()
		if not IsValid(dmtab) then return end
		if not IsValid(sender) then return end
		if EasyChat.IsBlockedPlayer(sender) then return end

		local chat = dmtab.Chats[sender]
		if not chat then
			chat = dmtab:CreateChat(sender)
		end

		EasyChat.AddText(chat.RichText, sender, color_white, ": " .. message)

		if EC_TICK_SOUND:GetBool() then
			_G.chat.PlaySound()
		end

		if not EasyChat.IsOpened() then
			dmtab:Notify(chat, message)
		else
			local activetabname = EasyChat.GetActiveTab().Tab.Name
			if (activetabname == "DM" and dmtab.ActiveChat ~= chat) or activetabname ~= "DM" then
				dmtab:Notify(chat, message)
			end
		end
	end)

	net.Receive(EASYCHAT_DM_REMOVE, function()
		if not IsValid(dmtab) then return end
		local ply = net.ReadEntity()
		dmtab:RemoveChat(ply)
	end)

	hook.Add("EntityRemoved", "EasyChatModuleDMTab", function(ent)
		if not IsValid(dmtab) then return end
		if ent:IsPlayer() and ent ~= LocalPlayer() then
			dmtab:RemoveChat(ent)
		end
	end)

	hook.Add("ECTabChanged", "EasyChatModuleDMTab", function(_, tab)
		if not IsValid(dmtab) then return end
		if tab == "DM" then
			local chat = dmtab.ActiveChat
			if IsValid(chat.Player) and chat.NewMessages > 0 then
				chat.NewMessages = 0
				chat.RichText:GotoTextEnd()
			end
		end
	end)

	hook.Add("NetworkEntityCreated", "EasyChatModuleDMTab", function(ent)
		if not IsValid(dmtab) then return end
		if ent:IsPlayer() and ent ~= LocalPlayer() then
			dmtab:CreateChat(ent)
		end
	end)

	hook.Add("ECInitialized", "EasyChatModuleDMTab", function()
		if not IsValid(dmtab) then return end
		for _, ply in pairs(player.GetAll()) do
			if ply ~= LocalPlayer() then
				dmtab:CreateChat(ply)
			end
		end
	end)

	EasyChat.AddTab("DM", dmtab, "icon16/group.png")
	EasyChat.SetFocusForOn("DM", dmtab.TextEntry)
end

return "Direct Messages"