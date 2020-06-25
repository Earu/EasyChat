local NET_LUA_CLIENTS = "EASY_CHAT_MODULE_LUA_CLIENTS"
local NET_LUA_SV = "EASY_CHAT_MODULE_LUA_SV"
local NET_LUA_SEND_CODE = "EASY_CHAT_MODULE_LUA_SEND_CODE"

--[[----------------------------------------------------
	LuaDev Compat + Fallbacks
]]------------------------------------------------------
local lua = {}
if CLIENT then
	if _G.luadev then
		lua = _G.luadev
	else
		function lua.RunOnClient(code, target, _)
			if isentity(target) and target:IsPlayer() then
				net.Start(NET_LUA_SV)
				net.WriteString(code)
				net.WriteString("client")
				net.WriteEntity(target)
				net.SendToServer()
			end
		end

		function lua.RunOnClients(code, _)
			net.Start(NET_LUA_SV)
			net.WriteString(code)
			net.WriteString("clients")
			net.SendToServer()
		end

		function lua.RunOnSelf(code, _)
			net.Start(NET_LUA_SV)
			net.WriteString(code)
			net.WriteString("self")
			net.SendToServer()
		end

		function lua.RunOnShared(code, _)
			net.Start(NET_LUA_SV)
			net.WriteString(code)
			net.WriteString("shared")
			net.SendToServer()
		end

		function lua.RunOnServer(code, _)
			net.Start(NET_LUA_SV)
			net.WriteString(code)
			net.WriteString("server")
			net.SendToServer()
		end

		net.Receive(NET_LUA_CLIENTS, function()
			local code = net.ReadString()
			local ply = net.ReadEntity()
			if not IsValid(ply) then return end

			CompileString(code, ply:Nick())()
		end)
	end
end

if SERVER then
	-- add luacheck to clients
	for _, file_name in ipairs(file.Find("lua/includes/modules/luacheck*", "GAME")) do
		AddCSLuaFile("includes/modules/" .. file_name)
	end

	util.AddNetworkString(NET_LUA_CLIENTS)
	util.AddNetworkString(NET_LUA_SV)
	util.AddNetworkString(NET_LUA_SEND_CODE)

	local execution_callbacks = {
		["server"] = function(ply, code)
			CompileString(code, ply:Nick())()
		end,
		["client"] = function(ply, target, code)
			net.Start(NET_LUA_CLIENTS)
			net.WriteString(code)
			net.WriteEntity(ply)
			net.Send(target)
		end,
		["clients"] = function(ply, code)
			net.Start(NET_LUA_CLIENTS)
			net.WriteString(code)
			net.WriteEntity(ply)
			net.Broadcast()
		end,
		["shared"] = function(ply, code)
			CompileString(code, ply:Nick())()
			net.Start(NET_LUA_CLIENTS)
			net.WriteString(code)
			net.WriteEntity(ply)
			net.Broadcast()
		end,
		["self"] = function(ply, code)
			net.Start(NET_LUA_CLIENTS)
			net.WriteString(code)
			net.WriteEntity(ply)
			net.Send(ply)
		end
	}

	net.Receive(NET_LUA_SV, function(_, ply)
		if not IsValid(ply) then return end

		local code = net.ReadString()
		local mode = net.ReadString()
		if not ply:IsSuperAdmin() then return end

		local callback = execution_callbacks[mode]
		if callback then
			if mode == "client" then
				local target = net.ReadEntity()
				mode = tostring(target)
				callback(ply, target, code)
			else
				callback(ply, code)
			end

			EasyChat.Print(("%s running code on %s"):format(ply, mode))
		end
	end)

	net.Receive(NET_LUA_SEND_CODE, function(_, ply)
		local url = net.ReadString()
		local target = net.ReadEntity()

		timer.Simple(0, function()
			net.Start(NET_LUA_SEND_CODE)
			net.WriteString(url)
			net.WriteEntity(ply)
			net.Send(target)
		end)
	end)
end

--[[----------------------------------------------------
	Actual Lua Tab Code
]]------------------------------------------------------
if CLIENT then
	require("luacheck")

	local blue_color = Color(0, 122, 204)
	local green_color = Color(141, 210, 138)
	local red_color = Color(255, 0, 0)
	local orange_color = Color(255, 165, 0)
	local gray_color = Color(75, 75, 75)
	local last_session_path = "easychat/lua_tab/last_session"

	local lua_callbacks = {
		["self"] = function(self, code)
			lua.RunOnSelf(code, LocalPlayer())
		end,
		["clients"] = function(self, code)
			lua.RunOnClients(code, LocalPlayer())
		end,
		["shared"] = function(self, code)
			lua.RunOnShared(code, LocalPlayer())
		end,
		["server"] = function(self, code)
			lua.RunOnServer(code, LocalPlayer())
		end,
		["javascript"] = function(self, code)

		end,
	}

	local LUA_TAB = {
		LastAction = {
			Script = "",
			Type = "",
			Time = ""
		},
		Env = "self",
		Init = function(self)
			local frame = self

			self.MenuBar = self:Add("DMenuBar")
			self.MenuBar:Dock(NODOCK)
			self.MenuBar:DockPadding(5, 0, 0, 0)
			self.MenuBar.Paint = function(self, w, h)
				surface.SetDrawColor(EasyChat.TabColor)
				surface.DrawRect(0, 0, w, h)
			end

			local options = {}

			self.MenuFile = self.MenuBar:AddMenu("File")
			table.insert(options, self.MenuFile:AddOption("New (Ctrl + N)", function() self:NewTab() end))
			table.insert(options, self.MenuFile:AddOption("Close Current (Ctrl + W)", function() self:CloseCurrentTab() end))

			-- table.insert(options, self.MenuFile:AddOption("Load File (Ctrl + O)"))
			-- table.insert(options, self.MenuFile:AddOption("Save (Ctrl + S)"))
			-- table.insert(options, self.MenuFile:AddOption("Save As... (Ctrl + Shift + S)"))
			-- self.MenuFile:AddSpacer()
			-- table.insert(options, self.MenuFile:AddOption("Settings"))

			self.MenuEdit = self.MenuBar:AddMenu("Edit")
			table.insert(options, self.MenuEdit:AddOption("Rename Current (F2)", function() self:RenameCurrentTab() end))

			self.MenuTools = self.MenuBar:AddMenu("Tools")
			table.insert(options, self.MenuTools:AddOption("Upload to Pastebin", function() self:UploadCodeToPastebin() end))
			table.insert(options, self.MenuTools:AddOption("Load Code from URL", function() self:LoadCodeFromURL() end))
			table.insert(options, self.MenuTools:AddOption("Send Code", function()
				timer.Simple(0, function() self:SendCode() end)
			end))

			local function build_env_icon(mat_path)
				local img = vgui.Create("DImage")
				img:SetMaterial(Material(mat_path))

				return img
			end

			self.EnvSelector = self.MenuBar:Add("DComboBox")
			self.EnvSelector:SetSize(100, 20)
			self.EnvSelector:SetPos(200, 5)
			self.EnvSelector:SetSortItems(false)
			self.EnvSelector:SetTextColor(color_white)

			local function build_env_choices()
				self.EnvSelector:Clear()

				self.EnvSelector:AddChoice("self", nil, true, "icon16/cog_go.png")
				self.EnvSelector:AddChoice("clients", nil, false, "icon16/user.png")
				self.EnvSelector:AddChoice("shared", nil, false, "icon16/world.png")
				self.EnvSelector:AddChoice("server", nil, false, "icon16/server.png")
				self.EnvSelector:AddChoice("javascript", nil, false, "icon16/script_code.png")

				for _, ply in ipairs(player.GetAll()) do
					if ply ~= LocalPlayer() then
						self.EnvSelector:AddChoice(EasyChat.GetProperNick(ply), ply, false)
					end
				end

				self.EnvSelector.OnSelect = function(_, id, value)
					local data = self.EnvSelector:GetOptionData(id)
					self.Env = data or value
				end
			end

			build_env_choices()

			self.RunButton = self.MenuBar:Add("DButton")
			self.RunButton:SetText("")
			self.RunButton:SetTextColor(color_white)
			self.RunButton:SetSize(40, 10)
			self.RunButton:SetPos(300, 5)
			self.RunButton.DoClick = function() self:RunCode() end

			local function menu_paint(self, w, h)
				surface.SetDrawColor(gray_color)
				surface.DrawRect(0, 0, w, h)
			end

			local function option_paint(self, w, h)
				if self:IsHovered() then
					surface.SetDrawColor(color_white)
					surface.DrawOutlinedRect(0, 0, w, h)
				end
			end

			local function menu_button_paint(self, w, h)
				if self:IsHovered() then
					surface.SetDrawColor(gray_color)
					surface.DrawRect(0, 0, w, h)
				end
			end

			local function combo_box_paint(_, w, h)
				surface.SetDrawColor(color_white)
				surface.DrawOutlinedRect(0, 0, w, h)
			end

			local drop_triangle = {
				{ x = 10, y = 3 },
				{ x = 5, y = 12 },
				{ x = 0, y = 3 },
			}
			local function drop_button_paint()
				surface.SetDrawColor(color_white)
				draw.NoTexture()
				surface.DrawPoly(drop_triangle)
			end

			self.MenuFile.Paint = menu_paint
			self.MenuEdit.Paint = menu_paint
			self.MenuTools.Paint = menu_paint
			self.EnvSelector.Paint = menu_paint

			local old_player_count = player.GetCount()
			self.EnvSelector.Think = function(self)
				local player_count = player.GetCount()
				if old_player_count ~= player_count then
					build_env_choices()
					old_player_count = player_count
					return
				end

				if self:IsMenuOpen() then
					if not self.Menu.CustomPainted then
						self.Menu.Paint = menu_paint
						for i=1, self.Menu:ChildCount() do
							local option = self.Menu:GetChild(i)
							option:SetTextColor(color_white)
							option.Paint = option_paint
						end
						self.Menu.CustomPainted = true
					end
				end
			end

			for _, option in ipairs(options) do
				option:SetTextColor(color_white)
				option.Paint = option_paint
			end

			-- menu bar buttons changes
			for _, panel in pairs(self.MenuBar:GetChildren()) do
				if panel.ClassName == "DButton" then
					panel:SetTextColor(color_white)
					panel:SetSize(50, 25)
					panel.Paint = menu_button_paint
				end
			end

			local run_triangle = {
				{ x = 10, y = 15 },
				{ x = 10, y = 5 },
				{ x = 20, y = 10 }
			}
			self.RunButton.Paint = function(self, w_, h)
				surface.SetDrawColor(gray_color)
				if self:IsHovered() then
					surface.DrawRect(0, 0, 30, h - 5)
				else
					surface.DrawOutlinedRect(0, 0, 30, h - 5)
				end

				surface.SetDrawColor(green_color)
				draw.NoTexture()
				surface.DrawPoly(run_triangle)
			end

			self.CodeTabs = self:Add("DPropertySheet")
			self.CodeTabs:SetPos(0, 35)
			self.CodeTabs:SetPadding(0)
			self.CodeTabs:SetFadeTime(0)
			self.CodeTabs.Paint = function(_, w, h)
				surface.DisableClipping(true)
				surface.SetDrawColor(EasyChat.TabColor)
				surface.DrawRect(0, -10, w, h + 20)
				surface.DisableClipping(false)
			end
			self.CodeTabs.tabScroller.Paint = function() end
			self.CodeTabs.OnActiveTabChanged = function(_, _, new_tab)
				new_tab.m_pPanel:RequestFocus()
				self:AnalyzeTab(new_tab, new_tab.m_pPanel)
			end

			if not EasyChat.CanUseCEFFeatures() then
				self.Warn = self:Add("DLabel")
				self.Warn:SetWrap(true)
				self.Warn:Dock(TOP)
				self.Warn:DockMargin(5, 5, 5, 5)
				self.Warn:SetTall(75)
				self.Warn:SetTextColor(color_white)
				self.Warn:SetText([[You cannot use the lua tab on a non-chromium branch, please switch to x86-64.
				You can change your Garry's Mod branch in your steam library.]])
			end

			self.LblRunStatus = self:Add("DLabel")
			self.LblRunStatus:SetTextColor(color_white)
			self.LblRunStatus:Dock(BOTTOM)
			self.LblRunStatus:SetSize(self:GetWide(), 25)
			self.LblRunStatus:SetText(("%sReady"):format((" "):rep(3)))
			self.LblRunStatus.Paint = function(_, w, h)
				surface.SetDrawColor(blue_color)
				surface.DrawRect(0, 0, w, h)
			end

			self.ThemeSelector = self:Add("DComboBox")
			self.ThemeSelector:AddChoice("vs-dark", nil, true)
			self.ThemeSelector:SetTextColor(color_white)
			self.ThemeSelector:SetWide(100)
			self.ThemeSelector.DropButton.Paint = drop_button_paint
			self.ThemeSelector.Paint = combo_box_paint

			self.ThemeSelector.OnSelect = function(_, _, theme_name)
				local tabs = self.CodeTabs:GetItems()
				for _, tab in pairs(tabs) do
					tab.Panel:QueueJavascript([[gmodinterface.SetTheme("]] .. theme_name .. [[");]])
				end

				cookie.Set("ECLuaTabTheme", theme_name)
			end

			self.LangSelector = self:Add("DComboBox")
			self.LangSelector:SetTextColor(color_white)
			self.LangSelector:SetWide(100)
			self.LangSelector.DropButton.Paint = drop_button_paint
			self.LangSelector.Paint = combo_box_paint

			self.LangSelector.OnSelect = function(_, _, lang)
				local active_tab = self.CodeTabs:GetActiveTab()
				if not IsValid(active_tab) then return end

				local editor = active_tab.m_pPanel
				if lang == "glua" then
					self:AnalyzeTab(active_tab, editor)
				else
					editor:QueueJavascript([[gmodinterface.SubmitLuaReport({ events: []});]])
					self.ErrorList.List:Clear()
					self.ErrorList:SetLabel("Error List")
				end

				editor:QueueJavascript([[gmodinterface.SetLanguage("]] .. lang .. [[");]])
				active_tab.Lang = lang
			end

			self.ErrorList = self:Add("DCollapsibleCategory")
			self.ErrorList:Dock(BOTTOM)
			self.ErrorList:SetSize(self:GetWide(), 50)
			self.ErrorList:SetLabel("Error List")
			self.ErrorList.Paint = function(self, w, h)
				surface.SetDrawColor(blue_color)
				surface.DrawRect(0, 0, w, 25)
			end

			-- hack to always keep the expanded state at the same height
			local old_ErrorListPerformLayout = self.ErrorList.PerformLayout
			self.ErrorList.PerformLayout = function(self)
				old_ErrorListPerformLayout(self)
				if self:GetExpanded() then
					self:SetTall(150)
				end
			end

			local error_list = vgui.Create("DListView")
			error_list:SetMultiSelect(false)
			error_list.Paint = function(self, w, h)
				surface.SetDrawColor(EasyChat.TabColor)
				surface.DrawRect(0, 0, w, h)
			end

			-- hack to paint the scrollbar
			local old_error_list_scrollbar_appear = error_list.OnScrollbarAppear
			error_list.OnScrollbarAppear = function(self)
				old_error_list_scrollbar_appear(self)
				self.VBar:SetHideButtons(true)
				self.VBar.Paint = function(self, w, h)
					surface.SetDrawColor(gray_color)
					surface.DrawLine(0, 0, 0, h)
				end

				local grip_color = table.Copy(gray_color)
				grip_color.a = 150
				self.VBar.btnGrip.Paint = function(self, w, h)
					surface.SetDrawColor(grip_color)
					surface.DrawRect(0, 0, w, h)
				end
			end

			local line_column = error_list:AddColumn("Line")
			line_column:SetFixedWidth(50)
			line_column.Header:SetTextColor(color_white)
			line_column.Header.Paint = function(self, w, h)
				surface.SetDrawColor(EasyChat.TabColor)
				surface.DrawRect(0, 0, w, h)

				surface.SetDrawColor(gray_color)
				surface.DrawLine(0, h - 1, w, h - 1)
				surface.DrawLine(w - 1, 0, w - 1, h)
			end

			local code_column = error_list:AddColumn("Code")
			code_column:SetFixedWidth(50)
			code_column.Header:SetTextColor(color_white)
			code_column.Header.Paint = function(self, w, h)
				surface.SetDrawColor(EasyChat.TabColor)
				surface.DrawRect(0, 0, w, h)

				surface.SetDrawColor(gray_color)
				surface.DrawLine(0, h - 1, w, h - 1)
				surface.DrawLine(w - 1, 0, w - 1, h)
			end

			local desc_column = error_list:AddColumn("Description")
			desc_column.Header:SetTextColor(color_white)
			desc_column.Header.Paint = function(self, w, h)
				surface.SetDrawColor(EasyChat.TabColor)
				surface.DrawRect(0, 0, w, h)

				surface.SetDrawColor(gray_color)
				surface.DrawLine(0, h - 1, w, h - 1)
			end

			self.ErrorList:SetContents(error_list)
			self.ErrorList:SetExpanded(EasyChat.CanUseCEFFeatures())
			self.ErrorList.List = error_list
			self.ErrorList.Header:SetFont("DermaDefault")

			if not cookie.GetString("ECLuaTabTheme") then
				cookie.Set("ECLuaTabTheme", "vs-dark")
			end
		end,
		Shortcuts = {
			{
				Trigger = { KEY_LCONTROL, KEY_N },
				Callback = function(self) self:NewTab() end,
			},
			{
				Trigger = { KEY_LCONTROL, KEY_W },
				Callback = function(self) self:CloseCurrentTab() end,
			},
			{
				Trigger = { KEY_LCONTROL, KEY_R },
				Callback = function(self) self:RunCode() end,
			},
			{
				Trigger = { KEY_F2 },
				Callback = function(self) self:RenameCurrentTab() end,
				Cooldown = 0.5,
			}
		},
		Think = function(self)
			if not EasyChat.IsOpened() then return end
			local tab = EasyChat.GetActiveTab()
			if tab.Panel ~= self then return end

			for _, shortcut in ipairs(self.Shortcuts) do
				if CurTime() >= (shortcut.Next or 0) then
					local should_trigger = true
					for _, key in ipairs(shortcut.Trigger) do
						if not input.IsKeyDown(key) then
							should_trigger = false
							break
						end
					end

					if should_trigger then
						shortcut.Callback(self)
						shortcut.Next = CurTime() + (shortcut.Cooldown or 0.1)
					end
				end
			end
		end,
		PerformLayout = function(self, w, h)
			self.MenuBar:SetSize(w, 25)
			self.CodeTabs:SetSize(w, h - (60 + self.ErrorList:GetTall()))

			local x, y, w, _ = self.LblRunStatus:GetBounds()
			self.ThemeSelector:SetPos(x + w - self.ThemeSelector:GetWide() - 5, y + 1)
			self.LangSelector:SetPos(x + w - self.ThemeSelector:GetWide() - 10 - self.LangSelector:GetWide(), y + 1)
		end,
		RenameCurrentTab = function(self)
			local tab = self.CodeTabs:GetActiveTab()
			if IsValid(tab) then tab:DoDoubleClick() end
		end,
		RunCode = function(self)
			local code = self:GetCode():Trim()
			if #code == 0 then return end

			-- otherwise too big for net messages
			if not _G.luadev and #code > 63000 then
				local err_msg = "Code too big, consider installing luadev and an actual editor"
				EasyChat.Print(true, err_msg)
				notification.AddLegacy(err_msg, NOTIFY_ERROR, 5)
				surface.PlaySound("buttons/button11.wav")
				return
			end

			if isentity(self.Env) then
				lua.RunOnClient(code, self.Env, LocalPlayer())
				self:RegisterAction(self.Env)
				return
			end

			if self.Env == "javascript" then
				local active_tab = self.CodeTabs:GetActiveTab()
				if IsValid(active_tab) then
					active_tab.m_pPanel:QueueJavascript(code:JavascriptSafe())
					self:RegisterAction(self.Env)
				end

				return
			end

			if lua_callbacks[self.Env] then
				lua_callbacks[self.Env](self, code)
				self:RegisterAction(self.Env)
			end
		end,
		CloseCurrentTab = function(self)
			if #self.CodeTabs:GetItems() > 1 then
				local tab = self.CodeTabs:GetActiveTab()
				self.CodeTabs:CloseTab(tab, true)

				-- get new tab
				tab = self.CodeTabs:GetActiveTab()
				tab.m_pPanel:RequestFocus()
			end
		end,
		--[[ServerDump = util.JSONToTable(file.Read("server_global_dump.json", "DATA")),
		IsOKServerIndex = function(self, indexing)
			local lookup = self.ServerDump
			for _, index in ipairs(indexing) do
				local value = lookup[index]
				if not value then
					return false
				else
					if value ~= true then
						-- continue indexing at a greater depth
						lookup = value
					else
						return true
					end
				end
			end

			return false
		end,]]--
		AnalyzeTab = function(self, tab, editor)
			timer.Create("EasyChatLuaCheck", 1, 1, function()
				if not IsValid(tab) or not IsValid(editor) then return end -- this can happen upon reload / disabling
				if not tab.Code or tab.Code:Trim() == "" then return end
				if tab ~= self.CodeTabs:GetActiveTab() then return end
				if tab.Lang ~= "glua" then return end

				-- luacheck can sometime error out
				local succ, ret = pcall(function()
					local report = luacheck.get_report(tab.Code)
					return luacheck.filter.filter({ report })
				end)

				local events = succ and ret[1] or {}
				local js_objects = {}
				local error_list = self.ErrorList.List
				error_list:Clear()
				for _, event in ipairs(events) do
					local code = tostring(event.code)
					--local ignore = (code == "113" or code == "143") and self:IsOKServerIndex(event.indexing)
					--if not ignore then
						local is_error = code[1] == "0"
						local msg = luacheck.get_message(event)
						local line, start_column, end_column = event.line, event.column, event.end_column + 1

						local js_object = ([[{ message: `%s`, isError: %s, line: %d, startColumn: %d, endColumn: %d, luacheckCode: `%s` }]]):format(msg, tostring(is_error), line, start_column, end_column, code)
						table.insert(js_objects, js_object)

						local line_panel = error_list:AddLine(line + 1, code, msg)
						line_panel.Paint = function(self, w, h)
							if not self:IsHovered() then return end
							surface.SetDrawColor(is_error and red_color or orange_color)
							surface.DrawOutlinedRect(0, 0, w, h)
						end
						line_panel.OnSelect = function(self)
							editor:QueueJavascript([[gmodinterface.GotoLine(]] .. line .. [[);]])
						end

						--PrintTable(line_panel:GetTable())
						for _, column in pairs(line_panel.Columns) do
							column:SetTextColor(is_error and red_color or orange_color)
						end
					--end
				end

				local error_count = #events
				error_list:GetParent():SetLabel(error_count > 0 and ("Error List (%d)"):format(error_count) or "Error List")
				error_list:InvalidateParent(true)
				editor:QueueJavascript([[gmodinterface.SubmitLuaReport({ events: [ ]] .. table.concat(js_objects, ",")  .. [[ ]});]])
			end)
		end,
		NewTab = function(self, code)
			if not EasyChat.CanUseCEFFeatures() then return end

			code = code or ""

			local editor = vgui.Create("DHTML")
			local tab_name = ("Untitled%s"):format((" "):rep(20))
			local sheet = self.CodeTabs:AddSheet(tab_name, editor)
			local tab = sheet.Tab
			tab.Code = code
			tab.Name = tab_name:Trim()
			tab.Lang = "glua"
			self.LblRunStatus:SetText(("%sLoading..."):format((" "):rep(3)))

			editor:AddFunction("gmodinterface", "OnCode", function(new_code)
				tab.Code = new_code
				self:AnalyzeTab(tab, editor)
			end)

			editor:AddFunction("gmodinterface", "OnThemesLoaded", function(themes)
				self.ThemeSelector:Clear()
				for _, theme_name in pairs(themes) do
					if cookie.GetString("ECLuaTabTheme") == theme_name then
						self.ThemeSelector:AddChoice(theme_name, nil, true)
						editor:QueueJavascript([[gmodinterface.SetCode("]] .. theme_name .. [[");]])
					else
						self.ThemeSelector:AddChoice(theme_name)
					end
				end
			end)

			editor:AddFunction("gmodinterface", "OnLanguages", function(languages)
				self.LangSelector:Clear()
				self.LangSelector:AddChoice("glua", nil, true)

				for _, lang in pairs(languages) do
					self.LangSelector:AddChoice(lang)
				end
			end)

			editor:AddFunction("gmodinterface", "OnReady", function()
				self.LblRunStatus:SetText(("%sReady"):format((" "):rep(3)))
				local safe_code = code:JavascriptSafe()
				editor:QueueJavascript([[gmodinterface.SetCode(`]] .. safe_code .. [[`);]])
				--editor:QueueJavascript([[gmodinterface.SetTheme(`chromedevtools`);]])

				if tab == self.CodeTabs:GetActiveTab() then
					editor:RequestFocus()
					self:AnalyzeTab(tab, editor)
				end
			end)

			local url = "metastruct.github.io/gmod-monaco"
			editor:OpenURL(url)

			self.CodeTabs:SetActiveTab(tab)
			local tab_w = tab:GetWide()
			tab:SetTextColor(color_white)

			local close_btn = tab:Add("DButton")
			close_btn:SetPos(tab_w - 20, 0)
			close_btn:SetSize(20, 20)
			close_btn:SetText("x")
			close_btn:SetTextColor(color_white)
			close_btn.Paint = function() end
			close_btn.DoClick = function()
				if #self.CodeTabs:GetItems() > 1 then
					self.CodeTabs:CloseTab(tab, true)
				end
			end

			tab.DoDoubleClick = function(self)
				EasyChat.AskForInput("Rename File", function(input)
					input = input:Trim()
					self.Name = input

					-- this is so we stay at the same tab size
					local new_len, old_len = #input, #self:GetText()
					if new_len ~= old_len then
						if new_len > old_len then
							self:SetText(input:sub(1, old_len - 3) .. "...")
						else
							local diff = old_len - new_len
							self:SetText(input .. (" "):rep(diff))
						end
					end
				end)
			end
			tab.Paint = function(tab, w, h)
				if tab == self.CodeTabs:GetActiveTab() then
					surface.SetDrawColor(blue_color)
					surface.DrawRect(0, 0, w, 20)
				end
			end
			local old_editor_paint = editor.Paint
			editor.Paint = function(editor, w, h)
				if not tab == self.CodeTabs:GetActiveTab() then return end

				surface.DisableClipping(true)
				surface.SetDrawColor(blue_color)
				surface.DrawRect(0, -2, w, 2)
				surface.DisableClipping(false)

				old_editor_paint(editor, w, h)
			end

			tab.Panel:RequestFocus()
		end,
		RegisterAction = function(self, type)
			local tab = self.CodeTabs:GetActiveTab()
			if not IsValid(tab) then return end

			self.LastAction = {
				Script = ("%s..."):format(tab.Name),
				Type = type,
				Time = os.date("%H:%M:%S")
			}

			local spacing = (" "):rep(3)
			local text = ("%s[%s] Ran %s on %s"):format(spacing, self.LastAction.Time, tab.Name, self.LastAction.Type)
			if #text == 0 then text = ("%sReady"):format(spacing) end
			self.LblRunStatus:SetText(text)
		end,
		SaveSession = function(self)
			if not file.Exists("easychat/lua_tab", "DATA") then
				file.CreateDir("easychat/lua_tab")
			end

			if not file.Exists(last_session_path, "DATA") then
				file.CreateDir(last_session_path)
			end

			-- get rid of existing files
			local existing_files, _ = file.Find(last_session_path .. "/*", "DATA")
			for _, f in pairs(existing_files) do
				local path = ("%s/%s"):format(last_session_path, f)
				file.Delete(path)
			end

			-- save current tabs code
			for i, item in pairs(self.CodeTabs:GetItems()) do
				local tab = item.Tab
				if tab.Code:Trim() ~= "" then
					local path = ("%s/%d.txt"):format(last_session_path, i)
					file.Write(path, tab.Code)
				end
			end
		end,
		LoadLastSession = function(self)
			local existing_files, _ = file.Find(last_session_path .. "/*", "DATA")
			for _, f in pairs(existing_files) do
				local path = ("%s/%s"):format(last_session_path, f)
				local contents = file.Read(path, "DATA")
				self:NewTab(contents)
				file.Delete(path)
			end
		end,
		GetCode = function(self)
			local tab = self.CodeTabs:GetActiveTab()
			if IsValid(tab) and tab.Code then
				return tab.Code
			end

			return ""
		end,
		Pastebin = function(self, succ_callback, err_callback)
			local code = self:GetCode()
			if #code == 0 then err_callback("no code") return end

			http.Post("https://pastebin.com/api/api_post.php", {
				api_dev_key = "58cf95ab426b33880fad5d9374afefea",
				api_paste_code = code,
				api_option = "paste",
				api_paste_format = "lua",
				api_paste_private = 1,
				api_paste_expire_date = "1D",
			}, succ_callback, err_callback)
		end,
		UploadCodeToPastebin = function(self)
			self:Pastebin(function(url)
				local msg = ("Uploaded code on pastebin: %s"):format(url)
				EasyChat.Print(msg)
				chat.AddText(color_white, msg)
				SetClipboardText(url)
			end, function(err)
				local err_msg = ("Pastebin error: %s"):format(err)
				EasyChat.Print(true, err_msg)
				notification.AddLegacy(err_msg, NOTIFY_ERROR, 5)
				surface.PlaySound("buttons/button11.wav")
			end)
		end,
		SendCode = function(self)
			local ply_menu = DermaMenu()
			for _, ply in ipairs(player.GetAll()) do
				if ply ~= LocalPlayer() then
					ply_menu:AddOption(EasyChat.GetProperNick(ply), function()
						self:Pastebin(function(url)
							net.Start(NET_LUA_SEND_CODE)
							net.WriteString(url)
							net.WriteEntity(ply)
							net.SendToServer()
						end, function()
							local err_msg = ("Failed to send code to %s"):format(ply)
							EasyChat.Print(true, err_msg)
							notification.AddLegacy(err_msg, NOTIFY_ERROR, 5)
							surface.PlaySound("buttons/button11.wav")
						end)
					end)
				end
			end

			ply_menu:Open()
		end,
		LoadCodeFromURL = function(self)
			EasyChat.AskForInput("Code URL", function(url)
				url = url
					:gsub("pastebin.com/", "pastebin.com/raw/")
					:gsub("hastebin.com/", "hastebin.com/raw/")
				http.Fetch(url, function(txt)
					if txt:match("%</html%>") then return end
					self:NewTab(txt)
					EasyChat.Print(("Loaded code from: %s"):format(url))
				end, function(err)
					local err_msg = ("Could not load code from: %s"):format(url)
					EasyChat.Print(true, err_msg)
					notification.AddLegacy(err_msg, NOTIFY_ERROR, 5)
					surface.PlaySound("buttons/button11.wav")
				end)
			end)
		end,
		Paint = function(self, w, h)
			surface.SetDrawColor(EasyChat.TabColor)
			surface.DrawRect(0, 0, w, h)
		end,
		PaintOver = function(self, w, h)
			surface.SetDrawColor(EasyChat.TabOutlineColor)
			surface.DrawOutlinedRect(0, 0, w, h)
		end
	}

	vgui.Register("ECLuaTab", LUA_TAB, "DPanel")

	local lua_tab = vgui.Create("ECLuaTab")
	EasyChat.AddTab("Lua", lua_tab, "icon16/page_edit.png")

	hook.Add("ECTabChanged", "EasyChatModuleLuaTab", function(_, new_tab_name)
		if new_tab_name ~= "Lua" then return end
		if not IsValid(lua_tab) then return end
		local active_code_tab = lua_tab.CodeTabs:GetActiveTab()
		if not IsValid(active_code_tab) then return end

		active_code_tab.m_pPanel:RequestFocus()
	end)

	net.Receive(NET_LUA_SEND_CODE, function()
		local url = net.ReadString()
		local sender = net.ReadEntity()
		if not IsValid(lua_tab) then return end

		local sender_nick = EasyChat.GetProperNick(sender)
		Derma_Query(("%s sent you code, open it?"):format(sender_nick), "Received Code", "Open", function()
			http.Fetch(url:gsub("pastebin.com/", "pastebin.com/raw/"), function(txt)
				if txt:match("%</html%>") then return end

				if EasyChat.Open() then
					EasyChat.OpenTab("Lua")
				end

				lua_tab:NewTab(txt)
			end, function()
				local err_msg = ("Could not load code from %s"):format(sender_nick)
				EasyChat.Print(true, err_msg)
				notification.AddLegacy(err_msg, NOTIFY_ERROR, 5)
				surface.PlaySound("buttons/button11.wav")
			end)
		end, "Dismiss", function() end)
	end)

	-- dont display it by default on small resolutions
	if not cookie.GetNumber("EasyChatSmallScreenLuaTab") and ScrW() < 1600 then
		local tab_data = EasyChat.GetTab("Lua")
		if tab_data and IsValid(tab_data.Tab) then
			tab_data.Tab:Hide()
		end

		cookie.Set("EasyChatSmallScreenLuaTab", "1")
	end

	hook.Add("ECFactoryReset", "EasyChatModuleLuaTab", function()
		cookie.Delete("EasyChatSmallScreenLuaTab")
		cookie.Delete("ECLuaTabTheme")
	end)

	lua_tab:LoadLastSession()

	local function save_hook()
		-- this can happen with disabled modules
		if not IsValid(lua_tab) then return end
		lua_tab:SaveSession()
	end

	hook.Add("ShutDown", "EasyChatModuleLuaTab", save_hook)
	hook.Add("ECPreDestroy", "EasyChatModuleLuaTab", save_hook)

	-- in case of crashes, have auto-saving
	timer.Create("EasyChatModuleLuaTabAutoSave", 300, 0, save_hook)
end

return "LuaTab"