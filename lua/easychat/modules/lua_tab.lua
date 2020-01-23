local NET_LUA_CLIENTS = "EASY_CHAT_MODULE_LUA_CLIENTS"
local NET_LUA_SV = "EASY_CHAT_MODULE_LUA_SV"
local lua = {}

if CLIENT then
	function lua.RunOnClients(code, ply)
		net.Start(NET_LUA_SV)
		net.WriteString(code)
		net.WriteString("clients")
		net.SendToServer()
	end

	function lua.RunOnSelf(code, ply)
		if LocalPlayer():IsSuperAdmin() or GetConVar("sv_allowcslua"):GetBool() then
			CompileString(code, LocalPlayer():GetName())()
		end
	end

	function lua.RunOnShared(code, ply)
		net.Start(NET_LUA_SV)
		net.WriteString(code)
		net.WriteString("shared")
		net.SendToServer()
	end

	function lua.RunOnServer(code, ply)
		net.Start(NET_LUA_SV)
		net.WriteString(code)
		net.WriteString("server")
		net.SendToServer()
	end

	net.Receive(NET_LUA_CLIENTS, function()
		local code = net.ReadString()
		local ply = net.ReadEntity()
		if not IsValid(ply) then return end

		CompileString(code, ply:GetName())()
	end)

	-- ugly hack to get luadev from notagain
	if notagain and notagain.hasloaded and notagain.loaded_libraries.luadev then
		lua = notagain.loaded_libraries.luadev
	else
		if _G.luadev then
			lua = _G.luadev
		else
			hook.Add("NotagainPostLoad", "EasyChatModuleLuaTab", function()
				if notagain.loaded_libraries.luadev then
					lua = notagain.loaded_libraries.luadev
				end
			end)
		end
	end
end

if SERVER then
	-- add luacheck to clients
	for _, file_name in ipairs(file.Find("lua/includes/modules/luacheck*", "GAME")) do
		AddCSLuaFile("includes/modules/" .. file_name)
	end

	util.AddNetworkString(NET_LUA_CLIENTS)
	util.AddNetworkString(NET_LUA_SV)

	net.Receive(NET_LUA_SV, function(len, ply)
		if not IsValid(ply) then return end

		local code = net.ReadString()
		local mode = net.ReadString()
		if ply:IsSuperAdmin() then
			if string.match(mode, "server") then
				CompileString(code, ply:GetName())()
			elseif string.match(mode, "clients") then
				net.Start(NET_LUA_CLIENTS)
				net.WriteString(code)
				net.WriteEntity(ply)
				net.Broadcast()
			elseif string.match(mode, "shared") then
				CompileString(code, ply:GetName())()
				net.Start(NET_LUA_CLIENTS)
				net.WriteString(code)
				net.WriteEntity(ply)
				net.Broadcast()
			end
		end
	end)
end

if CLIENT then
	require("luacheck")

	local blue_color = Color(0, 122, 204)
	local green_color = Color(141, 210, 138)
	local red_color = Color(255, 0, 0)
	local orange_color = Color(255, 165, 0)
	local last_session_path = "easychat/lua_tab/last_session"

	local function ask_for_input(title, callback)
		local frame = vgui.Create("DFrame")
		frame:SetTitle(title)
		frame:SetSize(200,110)
		frame:Center()
		frame.Paint = function(self, w, h)
			Derma_DrawBackgroundBlur(self, 0)

			surface.SetDrawColor(EasyChat.OutlayColor)
			surface.DrawRect(0, 0, w, h)

			surface.SetDrawColor(EasyChat.TabColor)
			surface.DrawRect(0, 0, w, 25)
		end

		local text_entry = frame:Add("DTextEntry")
		text_entry:SetSize(180, 25)
		text_entry:SetPos(10, 40)
		text_entry.OnEnter = function(self)
			callback(self:GetText())
			frame:Close()
		end

		local btn = frame:Add("DButton")
		btn:SetText("Ok")
		btn:SetTextColor(EasyChat.TextColor)
		btn:SetSize(100, 25)
		btn:SetPos(50, 75)
		btn.DoClick = function()
			callback(text_entry:GetText())
			frame:Close()
		end
		btn.Paint = function(self, w, h)
			if self:IsHovered() then
				surface.SetDrawColor(blue_color)
			else
				surface.SetDrawColor(EasyChat.TabColor)
			end

			surface.DrawRect(0, 0, w, h)
		end

		frame:MakePopup()
		text_entry:RequestFocus()
	end

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
			self.MenuBar.Think = function(self)
				self:SetSize(frame:GetWide(), 25)
			end
			self.MenuBar.Paint = function(self, w, h)
				surface.SetDrawColor(EasyChat.TabColor)
				surface.DrawRect(0, 0, w, h)
			end

			local options = {}

			self.MenuFile = self.MenuBar:AddMenu("File")
			table.insert(options, self.MenuFile:AddOption("New (Ctrl + N)", function() self:NewTab() end))
			table.insert(options, self.MenuFile:AddOption("Close Current (Ctrl + W)", function() self:CloseCurrentTab() end))

			self.MenuEdit = self.MenuBar:AddMenu("Edit")
			table.insert(options, self.MenuEdit:AddOption("Rename Current (F2)", function() self:RenameCurrentTab() end))
			-- table.insert(options, self.MenuFile:AddOption("Load File (Ctrl + O)"))
			-- table.insert(options, self.MenuFile:AddOption("Save (Ctrl + S)"))
			-- table.insert(options, self.MenuFile:AddOption("Save As... (Ctrl + Shift + S)"))
			-- self.MenuFile:AddSpacer()
			-- table.insert(options, self.MenuFile:AddOption("Settings"))

			local function build_env_icon(mat_path)
				local img = vgui.Create("DImage")
				img:SetMaterial(Material(mat_path))

				return img
			end

			self.EnvSelector = self.MenuBar:Add("DComboBox")
			self.EnvSelector:SetSize(100, 20)
			self.EnvSelector:SetPos(200, 5)
			self.EnvSelector:SetTextColor(EasyChat.TextColor)
			self.EnvSelector:AddChoice("self", nil, true, "icon16/cog_go.png")
			self.EnvSelector:AddChoice("clients", nil, false, "icon16/user.png")
			self.EnvSelector:AddChoice("shared", nil, false, "icon16/world.png")
			self.EnvSelector:AddChoice("server", nil, false, "icon16/server.png")
			self.EnvSelector.OnSelect = function(_, _, value)
				self.Env = value
			end

			self.RunButton = self.MenuBar:Add("DButton")
			self.RunButton:SetText("")
			self.RunButton:SetTextColor(EasyChat.TextColor)
			self.RunButton:SetSize(40, 10)
			self.RunButton:SetPos(300, 5)
			self.RunButton.DoClick = function() self:RunCode() end

			local function MenuPaint(self, w, h)
				surface.SetDrawColor(EasyChat.OutlayColor)
				surface.DrawRect(0, 0, w, h)
			end

			local function OptionPaint(self, w, h)
				if self:IsHovered() then
					surface.SetDrawColor(EasyChat.TextColor)
					surface.DrawOutlinedRect(0, 0, w, h)
				end
			end

			local function MenuButtonPaint(self, w, h)
				if self:IsHovered() then
					surface.SetDrawColor(EasyChat.OutlayColor)
					surface.DrawRect(0, 0, w, h)
				end
			end

			self.MenuFile.Paint = MenuPaint
			self.MenuEdit.Paint = MenuPaint
			self.EnvSelector.Paint = MenuPaint
			self.EnvSelector.Think = function(self)
				if self:IsMenuOpen() and not self.Menu.CustomPainted then
					self.Menu.Paint = MenuPaint
					for i=1, self.Menu:ChildCount() do
						local option = self.Menu:GetChild(i)
						option:SetTextColor(EasyChat.TextColor)
						option.Paint = OptionPaint
					end
					self.Menu.CustomPainted = true
				end
			end

			for _, option in ipairs(options) do
				option:SetTextColor(EasyChat.TextColor)
				option.Paint = OptionPaint
			end

			-- menu bar buttons changes
			for _, panel in pairs(self.MenuBar:GetChildren()) do
				if panel.ClassName == "DButton" then
					panel:SetTextColor(EasyChat.TextColor)
					panel:SetSize(50, 25)
					panel.Paint = MenuButtonPaint
				end
			end

			local run_triangle = {
				{ x = 10, y = 15 },
				{ x = 10, y = 5 },
				{ x = 20, y = 10 }

			}
			self.RunButton.Paint = function(self, w_, h)
				surface.SetDrawColor(EasyChat.OutlayColor)
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
			self.CodeTabs.Paint = function() end -- remove ugly grey background when no tab is opened
			self.CodeTabs.tabScroller.Paint = function() end
			self.CodeTabs.OnActiveTabChanged = function(_, _, new_tab)
				new_tab.m_pPanel:RequestFocus()
				self:AnalyzeTab(new_tab, new_tab.m_pPanel)
			end

			self.LblRunStatus = self:Add("DLabel")
			self.LblRunStatus:SetTextColor(EasyChat.TextColor)
			self.LblRunStatus:Dock(BOTTOM)
			self.LblRunStatus:SetSize(self:GetWide(), 25)
			self.LblRunStatus:SetText(("%sReady"):format((" "):rep(3)))
			self.LblRunStatus.Paint = function(self, w, h)
				surface.SetDrawColor(blue_color)
				surface.DrawRect(0, 0, w, h)
			end

			self.ErrorList = self:Add("DCollapsibleCategory")
			self.ErrorList:Dock(BOTTOM)
			self.ErrorList:SetSize(self:GetWide(), 50)
			self.ErrorList:SetLabel("Error List")
			self.ErrorList.Paint = function(self, w, h)
				surface.SetDrawColor(blue_color)
				surface.DrawRect(0, 0, w, h)
			end

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

			local line_column = error_list:AddColumn("Line")
			line_column:SetFixedWidth(50)
			line_column.Header:SetTextColor(EasyChat.TextColor)
			line_column.Header.Paint = function(self, w, h)
				surface.SetDrawColor(EasyChat.OutlayColor)
				surface.DrawRect(0, 0, w, h)

				surface.SetDrawColor(EasyChat.TextColor)
				surface.DrawLine(0, h - 1, w, h - 1)
				surface.DrawLine(w - 1, 0, w - 1, h)
			end

			local code_column = error_list:AddColumn("Code")
			code_column:SetFixedWidth(50)
			code_column.Header:SetTextColor(EasyChat.TextColor)
			code_column.Header.Paint = function(self, w, h)
				surface.SetDrawColor(EasyChat.OutlayColor)
				surface.DrawRect(0, 0, w, h)

				surface.SetDrawColor(EasyChat.TextColor)
				surface.DrawLine(0, h - 1, w, h - 1)
				surface.DrawLine(w - 1, 0, w - 1, h)
			end

			local desc_column = error_list:AddColumn("Description")
			desc_column.Header:SetTextColor(EasyChat.TextColor)
			desc_column.Header.Paint = function(self, w, h)
				surface.SetDrawColor(EasyChat.OutlayColor)
				surface.DrawRect(0, 0, w, h)

				surface.SetDrawColor(EasyChat.TextColor)
				surface.DrawLine(0, h - 1, w, h - 1)
			end

			self.ErrorList:SetContents(error_list)
			self.ErrorList:SetExpanded(true)
			self.ErrorList.List = error_list

			self.CodeTabs.Think = function(code_tabs)
				code_tabs:SetSize(self:GetWide(), self:GetTall() - (60 + self.ErrorList:GetTall()))
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
						shortcut.Next = CurTime() + 0.1
					end
				end
			end
		end,
		RenameCurrentTab = function(self)
			local tab = self.CodeTabs:GetActiveTab()
			if IsValid(tab) then tab:DoDoubleClick() end
		end,
		RunCode = function(self)
			local code = self:GetCode():Trim()
			if code == "" then return end

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
				if not tab.Code or tab.Code:Trim() == "" then return end
				if tab ~= self.CodeTabs:GetActiveTab() then return end

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

						local js_object = ([[{ message: `%s`, isError: %s, line: %d, startColumn: %d, endColumn: %d }]]):format(msg, tostring(is_error), line, start_column, end_column)
						table.insert(js_objects, js_object)

						local line_panel = error_list:AddLine(line + 1, code, msg)
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
			code = code or ""

			local editor = vgui.Create("DHTML")
			local tab_name = ("Untitled%s"):format((" "):rep(20))
			local sheet = self.CodeTabs:AddSheet(tab_name, editor)
			local tab = sheet.Tab
			tab.Code = code
			tab.Name = tab_name:Trim()
			self.LblRunStatus:SetText(("%sLoading..."):format((" "):rep(3)))

			editor:AddFunction("gmodinterface", "OnCode", function(new_code)
				tab.Code = new_code
				self:AnalyzeTab(tab, editor)
			end)

			editor:AddFunction("gmodinterface", "OnReady", function()
				self.LblRunStatus:SetText(("%sReady"):format((" "):rep(3)))
				local safe_code = code:JavascriptSafe()
				editor:QueueJavascript([[gmodinterface.SetCode(`]] .. safe_code .. [[`);]])

				if tab == self.CodeTabs:GetActiveTab() then
					editor:RequestFocus()
					self:AnalyzeTab(tab, editor)
				end
			end)

			local url = "metastruct.github.io/gmod-monaco"
			editor:OpenURL(url)

			self.CodeTabs:SetActiveTab(tab)
			local tab_w = tab:GetWide()

			local close_btn = tab:Add("DButton")
			close_btn:SetPos(tab_w - 20, 0)
			close_btn:SetSize(20, 20)
			close_btn:SetText("x")
			close_btn:SetTextColor(EasyChat.TextColor)
			close_btn.Paint = function() end
			close_btn.DoClick = function()
				if #self.CodeTabs:GetItems() > 1 then
					self.CodeTabs:CloseTab(tab, true)
				end
			end

			tab.DoDoubleClick = function(self)
				ask_for_input("Rename File", function(input)
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
			if text == "" then text = ("%sReady"):format(spacing) end
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
		Paint = function(self, w, h)
			surface.SetDrawColor(EasyChat.TabColor)
			surface.DrawRect(0, 0, w, h)
		end
	}

	vgui.Register("ECLuaTab", LUA_TAB, "DPanel")

	local EC_LUA_TAB = CreateConVar("easychat_luatab", "1", FCVAR_ARCHIVE, "Display luatab or not")
	cvars.AddChangeCallback("easychat_luatab", function(name, old, new)
		RunConsoleCommand("easychat_reload")
	end)

	EasyChat.RegisterConvar(EC_LUA_TAB, "Display lua tab")

	if EC_LUA_TAB:GetBool() then
		local lua_tab = vgui.Create("ECLuaTab")
		EasyChat.AddTab("Lua", lua_tab)

		lua_tab:LoadLastSession()

		local function save_hook() lua_tab:SaveSession() end
		hook.Add("ShutDown", "EasyChatModuleLuaTab", save_hook)
		hook.Add("ECPreDestroy", "EasyChatModuleLuaTab", save_hook)

		-- in case of crashes, have auto-saving
		timer.Create("EasyChatModuleLuaTabAutoSave", 300, 0, save_hook)
	end
end

return "LuaTab"