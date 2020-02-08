local EASYCHAT_ADMIN = "EASY_CHAT_MODULE_ADMIN"

if SERVER then
	util.AddNetworkString(EASYCHAT_ADMIN)

	net.Receive(EASYCHAT_ADMIN, function(_, ply)
		if not ply:IsAdmin() then return end

		local msg = net.ReadString()
		msg = msg:Trim()
		if msg == "" then return end

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
	local PLY_COL = Color(255, 127, 127)
	local EC_HISTORY = GetConVar("easychat_history")

	local nick_cache = {}
	local function cache_nick(ply, maxwidth)
		local nick, team_color = ply:Nick(), team.GetColor(ply:Team())
		local cache = nick_cache[nick]
		if cache and cache.DefaultColor == team_color then
			return cache
		end

		local mk = ec_markup.AdvancedParse(nick, {
			default_font = "EasyChatFont",
			default_color = team_color,
			nick = true,
			no_shadow = true,
			maxwidth = maxwidth
		})
		nick_cache[nick] = mk

		return mk
	end

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
				local black_color = Color(0, 0, 0)
				self.TextEntry.Paint = function(self, w, h)
					surface.SetDrawColor(color_white)
					surface.DrawRect(0, 0, w, h)

					self:DrawTextEntryText(black_color, EasyChat.OutlayColor, black_color)
				end

				self.AdminList.Paint = function(self, w, h)
					surface.SetDrawColor(EasyChat.OutlayColor)
					surface.DrawRect(0, 0, w, h)
					surface.SetDrawColor(EasyChat.TabOutlineColor)
					surface.DrawOutlinedRect(0, 0, w, h)

					local cur_y = 20
					for _, ply in ipairs(player.GetAll()) do
						if ply:IsAdmin() then
							local mk = cache_nick(ply, self:GetWide() - 20)
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
							local mk = cache_nick(ply, self:GetWide() - 20)
							mk:Draw(10, cur_y)
							cur_y = cur_y + mk:GetTall() + 5
						end
					end
				end
			end

			self.RichText = self:Add("RichText")
			self.RichText.HistoryName = "admin"
			if not EasyChat.UseDermaSkin then
				self.RichText:InsertColorChange(255, 255, 255, 255)
			end
			self.RichText.PerformLayout = function(self)
				self:SetFontInternal("EasyChatFont")
				if not EasyChat.UseDermaSkin then
					self:SetFGColor(EasyChat.TextColor)
				end
			end
			self.RichText.ActionSignal = function(self, name, value)
				if name == "TextClicked" then
					EasyChat.OpenURL(value)
				end
			end
			self.RichText:Dock(FILL)
			self.RichText:DockMargin(0, 0, 0, 5)

			local lastkey = KEY_ENTER
			self.TextEntry.OnKeyCodeTyped = function(self, code)
				EasyChat.SetupHistory(self, code)
				EasyChat.UseRegisteredShortcuts(self, lastkey, code)

				if code == KEY_ESCAPE then
					chat.Close()
					gui.HideGameUI()
				elseif code == KEY_ENTER or code == KEY_PAD_ENTER then
					self:SetText(self:GetText():Replace("╚​", ""))
					if self:GetText():Trim() ~= "" then
						frame:SendMessage(self:GetText():sub(1, 3000))
					end
				end

				lastkey = code
			end

			if EC_HISTORY:GetBool() then
				local history = EasyChat.ReadFromHistory("admin")
				if history:Trim() == "" then
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

	net.Receive(EASYCHAT_ADMIN, function()
		local sender = net.ReadEntity()
		local msg = net.ReadString()
		if not IsValid(sender) then return end

		EasyChat.AddText(admintab.RichText, team.GetColor(sender:Team()), sender, color_white, ": " .. msg)
		if not IsValid(EasyChat.GUI.ChatBox) then -- maybe this fix gmod crashes??
			admintab:Notify(sender, msg)
		else
			local activetabname = EasyChat.GetActiveTab().Tab.Name
			if activetabname ~= "Admin" then
				admintab:Notify(sender, msg)
			end
		end
	end)

	hook.Add("ECTabChanged", "EasyChatModuleDMTab", function(_, tab)
		if tab == "Admin" then
			admintab.NewMessages = 0
			admintab.RichText:GotoTextEnd()
			if not LocalPlayer():IsAdmin() then
				EasyChat.AddText(self.RichText, "You cannot see the content of this channel because you are not an admin")
			end
		end
	end)

	EasyChat.AddMode("Admin", function(text)
		admintab:SendMessage(text)
	end)

	EasyChat.AddTab("Admin", admintab)
	EasyChat.SetFocusForOn("Admin", admintab.TextEntry)
end

return "Admin Chat"
