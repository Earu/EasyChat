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
	local blue_color = Color(0, 122, 204)

	local LUA_TAB = {
		LastAction = {
			Script = "",
			Type = "",
			Time = ""
		},
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
			--table.insert(options, self.MenuFile:AddOption("Load File (Ctrl + O)"))
			--table.insert(options, self.MenuFile:AddOption("Save (Ctrl + S)"))
			--table.insert(options, self.MenuFile:AddOption("Save As... (Ctrl + Shift + S)"))
			--self.MenuFile:AddSpacer()
			--table.insert(options, self.MenuFile:AddOption("Settings"))

			self.MenuRun = self.MenuBar:AddMenu("Run")
			table.insert(options, self.MenuRun:AddOption("On Self", function()
				local code = self:GetCode():Trim()
				if code == "" then return end

				lua.RunOnSelf(code, LocalPlayer())
				self:RegisterAction("self")
			end))

			table.insert(options, self.MenuRun:AddOption("On Clients", function()
				local code = self:GetCode():Trim()
				if code == "" then return end

				lua.RunOnClients(code, LocalPlayer())
				self:RegisterAction("clients")
			end))

			table.insert(options, self.MenuRun:AddOption("Shared", function()
				local code = self:GetCode():Trim()
				if code == "" then return end

				lua.RunOnShared(code, LocalPlayer())
				self:RegisterAction("shared")
			end))

			table.insert(options, self.MenuRun:AddOption("Server-side", function()
				local code = self:GetCode():Trim()
				if code == "" then return end

				lua.RunOnServer(code, LocalPlayer())
				self:RegisterAction("server")
			end))

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
			self.MenuRun.Paint = MenuPaint
			for _, option in ipairs(options) do
				option:SetTextColor(EasyChat.TextColor)
				option.Paint = OptionPaint
			end

			-- menu bar buttons changes
			for _, btn in pairs(self.MenuBar:GetChildren()) do
				btn:SetTextColor(EasyChat.TextColor)
				btn:SetSize(50, 25)
				btn.Paint = MenuButtonPaint
			end

			self.CodeTabs = self:Add("DPropertySheet")
			self.CodeTabs:SetPos(0, 25)
			self.CodeTabs:SetPadding(0)
			self.CodeTabs.Paint = function() end -- remove ugly grey background when no tab is opened
			self.CodeTabs.tabScroller.Paint = function() end
			self.CodeTabs.Think = function(code_tabs)
				code_tabs:SetSize(self:GetWide(), self:GetTall() - 50)
			end
			self.CodeTabs.OnActiveTabChanged = function(_, _, new_tab)
				new_tab.m_pPanel:RequestFocus()
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
		end,
		Shortcuts = {
			{
				Trigger = { KEY_LCONTROL, KEY_N },
				Callback = function(self) self:NewTab() end,
			},
			{
				Trigger = { KEY_LCONTROL, KEY_W },
				Callback = function(self) self:CloseCurrentTab() end,
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
		CloseCurrentTab = function(self)
			if #self.CodeTabs:GetItems() > 1 then
				local tab = self.CodeTabs:GetActiveTab()
				self.CodeTabs:CloseTab(tab, true)

				-- get new tab
				tab = self.CodeTabs:GetActiveTab()
				tab.m_pPanel:RequestFocus()
			end
		end,
		NewTab = function(self)
			local editor = vgui.Create("DHTML")
			local tab_name = ("Untitled%s"):format((" "):rep(5))
			local sheet = self.CodeTabs:AddSheet(tab_name, editor)
			local tab = sheet.Tab
			tab.Code = ""
			tab.Name = tab_name:Trim()

			editor:AddFunction("gmodinterface", "OnCode", function(code)
				tab.Code = code
			end)

			editor:AddFunction("gmodinterface", "OnReady", function()
				if tab == self.CodeTabs:GetActiveTab() then
					editor:RequestFocus()
				end
			end)

			editor:OpenURL("metastruct.github.io/lua_editor/")
			-- editor:OpenURL("metastruct.github.io/gmod-monaco/")
			--[[ editor:QueueJavascript([[
				window.onload = () => {
					let editor = document.getElementsByClassName('monaco-editor')[0];
					let model = editor.getModel();
					console.log(editor, model);

					let previousValue = "";
					model.onDidChangeContent = (_) => {
						let curValue = model.getValue();
						if (previousValue != curValue) {
							gmodinterface.OnCode(curValue);
							previousValue = curValue;
						}
					};

					gmodinterface.OnReady();
				};
			]]--)

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

			tab.Paint = function(tab, w, h)
				if tab == self.CodeTabs:GetActiveTab() then
					surface.SetDrawColor(blue_color)
					surface.DrawRect(0, 0, w, 20)

					surface.DisableClipping(true)
						local panel_x, _, panel_w, _ = sheet.Panel:GetBounds()
						local x, _ = tab:GetPos()
						surface.DrawRect(panel_x - x - 3, 18, panel_w - 1, 2)
					surface.DisableClipping(false)
				end
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
	end
end

return "LuaTab"