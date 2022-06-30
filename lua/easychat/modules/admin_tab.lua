local EASYCHAT_ADMIN = "EASY_CHAT_MODULE_ADMIN"

if SERVER then
	util.AddNetworkString(EASYCHAT_ADMIN)

	net.Receive(EASYCHAT_ADMIN, function(_, ply)
		if not ply:IsAdmin() then return end

		local msg = net.ReadString()
		msg = EasyChat.ExtendedStringTrim(msg)
		if #msg == 0 then return end

		local admins = {}
		for _, p in ipairs(player.GetAll()) do
			if p:IsAdmin() then
				table.insert(admins, p)
			end
		end

		net.Start(EASYCHAT_ADMIN)
		net.WriteEntity(ply)
		net.WriteString(msg)
		net.Send(admins)
	end)
end

if CLIENT then
	local color_white = color_white

	local EC_HISTORY = GetConVar("easychat_history")
	local EC_TICK_SOUND = GetConVar("easychat_tick_sound")

	local ADMIN_TAB = {
		NewMessages = 0,
		Init = function(self)
			local frame = self

			self.AdminList = self:Add("DListView")
			self.AdminList:SetWide(100)
			self.AdminList:Dock(LEFT)
			self.AdminList:AddColumn("Admins")

			self.TextEntry = self:Add("DTextEntry")
			self.TextEntry:SetTall(20)
			self.TextEntry:Dock(BOTTOM)
			self.TextEntry:SetHistoryEnabled(true)
			self.TextEntry.HistoryPos = 0
			self.TextEntry:SetUpdateOnType(true)

			if not EasyChat.UseDermaSkin then
				local selection_color = Color(255, 0, 0, 127)
				self.TextEntry.Paint = function(self, w, h)
					local border_color = EasyChat.TabOutlineColor.a == 0
						and EasyChat.OutlayColor or EasyChat.TabOutlineColor
					surface.SetDrawColor(border_color)
					surface.DrawLine(0, 0, w, 0)

					self:DrawTextEntryText(EasyChat.TextColor, selection_color, EasyChat.TextColor)
				end

				self.AdminList.Paint = function(self, w, h)
					surface.SetDrawColor(EasyChat.OutlayColor)
					surface.DrawRect(0, 0, w, h)
					surface.SetDrawColor(EasyChat.TabOutlineColor)
					surface.DrawOutlinedRect(0, 0, w, h)

					local cur_y = 20
					for _, ply in ipairs(player.GetAll()) do
						if ply:IsAdmin() then
							local mk = ec_markup.CachePlayer("AdminTab", ply, function()
								return ec_markup.AdvancedParse(ply:RichNick(), {
									default_font = "EasyChatFont",
									default_color = team.GetColor(ply:Team()),
									nick = true,
									no_shadow = true,
									maxwidth = self:GetWide() - 20
								})
							end)
							mk:Draw(10, cur_y)
							cur_y = cur_y + mk:GetTall() + 5
						end
					end
				end

				local header = self.AdminList.Columns[1].Header
				header:SetTextColor(Color(255, 255, 255))
				header.Paint = function(self, w, h)
					surface.SetDrawColor(EasyChat.TabColor)
					surface.DrawRect(0, 0, w, h)
					surface.SetDrawColor(EasyChat.OutlayColor)
					surface.DrawLine(w - 1, 0, w - 1, h)
					surface.SetDrawColor(EasyChat.TabOutlineColor)
					surface.DrawOutlinedRect(0, 0, w, h)
				end
			else
				local old_Paint = self.AdminList.Paint
				self.AdminList.Paint = function(self, w, h)
					old_Paint(self, w, h)
					local cur_y = 20
					for _, ply in ipairs(player.GetAll()) do
						if ply:IsAdmin() then
							local mk = ec_markup.CachePlayer("AdminTab", ply, function()
								return ec_markup.AdvancedParse(ply:RichNick(), {
									default_font = "EasyChatFont",
									default_color = team.GetColor(ply:Team()),
									nick = true,
									no_shadow = true,
									maxwidth = self:GetWide() - 20
								})
							end)
							mk:Draw(10, cur_y)
							cur_y = cur_y + mk:GetTall() + 5
						end
					end
				end
			end

			self.RichText = self:Add("RichTextLegacy")
			self.RichText.HistoryName = "admin"

			if not EasyChat.UseDermaSkin then
				self.RichText:InsertColorChange(255, 255, 255, 255)
			end

			self.RichText.PerformLayout = function(self)
				self:SetFontInternal("EasyChatFont")
				self:SetUnderlineFont("EasyChatFont")
				if not EasyChat.UseDermaSkin then
					self:SetFGColor(EasyChat.TextColor)
				end
			end

			self.RichText.ActionSignal = EasyChat.GUI.RichText.ActionSignal
			self.RichText:Dock(FILL)
			self.RichText:DockMargin(0, 0, 0, 5)

			self.TextEntry.OnKeyCodeTyped = function(self, code)
				EasyChat.SetupHistory(self, code)
				EasyChat.UseRegisteredShortcuts(self, code)

				if code == KEY_ESCAPE then
					chat.Close()
					gui.HideGameUI()
				elseif code == KEY_ENTER or code == KEY_PAD_ENTER then
					local text = EasyChat.ExtendedStringTrim(self:GetText())
					self:SetText(text)
					if #text > 0 then
						frame:SendMessage(text:sub(1, 3000))
					end
				end
			end

			if EC_HISTORY:GetBool() then
				local history = EasyChat.ReadFromHistory("admin")
				if EasyChat.IsStringEmpty(history) then
					EasyChat.AddText(self.RichText, "Welcome to the admin chat!")
				else
					self.RichText:AppendText(history) -- so we do not log twice
					self.RichText:AppendText("\n^^^^^ Last Session History ^^^^^\n\n")
					self.RichText:GotoTextEnd()
				end
			else
				EasyChat.AddText(self.RichText, "Welcome to the admin chat!")
			end
		end,
		Notify = function(self, ply, message)
			if ply ~= LocalPlayer() then
				self.NewMessages = self.NewMessages + 1
				EasyChat.FlashTab("Admin")
			end
			_G.chat.AddText(color_white, "[Admin Chat | ", Color(255, 127, 127), ply, color_white, "] " .. message)
		end,
		SendMessage = function(self, msg)
			net.Start(EASYCHAT_ADMIN)
			net.WriteString(msg)
			net.SendToServer()
			self.TextEntry:SetText("")
		end,
		PaintOver = function(self, w, h)
			surface.SetDrawColor(EasyChat.TabOutlineColor)
			surface.DrawOutlinedRect(0, 0, w, h)
		end
	}

	vgui.Register("ECAdminTab", ADMIN_TAB, "DPanel")
	local admintab = vgui.Create("ECAdminTab")

	local function handle_message()
		local sender = net.ReadEntity()
		local msg = net.ReadString()

		if not IsValid(admintab) then return end
		if not IsValid(sender) then return end
		if EasyChat.IsBlockedPlayer(sender) then return end

		EasyChat.AddText(admintab.RichText, sender, color_white, ": " .. msg)

		if EC_TICK_SOUND:GetBool() then
			chat.PlaySound()
		end

		if not EasyChat.IsOpened() then
			admintab:Notify(sender, msg)
		else
			local active_tab_name = EasyChat.GetActiveTab().Tab.Name
			if active_tab_name ~= "Admin" then
				admintab:Notify(sender, msg)
			end
		end
	end

	net.Receive(EASYCHAT_ADMIN, handle_message)

	-- handle fadmin admin chat
	net.Receive("FAdmin_ReceiveAdminMessage", handle_message)

	hook.Add("ECTabChanged", "EasyChatModuleDMTab", function(_, tab)
		if tab == "Admin" then
			admintab.NewMessages = 0
			admintab.RichText:GotoTextEnd()
			if not LocalPlayer():IsAdmin() then
				EasyChat.AddText(admintab.RichText, "You cannot see the content of this channel because you are not an admin")
			end
		end
	end)

	EasyChat.AddMode("Admin", function(text)
		admintab:SendMessage(text)
	end)

	EasyChat.AddTab("Admin", admintab, "icon16/vcard.png")
	EasyChat.SetFocusForOn("Admin", admintab.TextEntry)

	hook.Add("ECOpened", "EasyChatModuleDMTab", function()
		local tab_data = EasyChat.GetTab("Admin")
		if tab_data and IsValid(tab_data.Tab) and IsValid(LocalPlayer()) then
			tab_data.Tab:SetVisible(LocalPlayer():IsAdmin())
		end
	end)
end

return "Admin Chat"