local netluaclients = "EASY_CHAT_MODULE_LUA_CLIENTS"
local netluasv      = "EASY_CHAT_MODULE_LUA_SV"
local lua           = {}

if CLIENT then
    lua.RunOnClients = function(code,ply)
        net.Start(netluasv)
        net.WriteString(code)
        net.WriteString("clients")
        net.SendToServer()
    end

    lua.RunOnSelf = function(code,ply)
        if LocalPlayer():IsSuperAdmin() or GetConVar("sv_allowcslua"):GetBool() then
            CompileString(code,LocalPlayer():GetName())()
        end
    end

    lua.RunOnShared = function(code,ply)
        net.Start(netluasv)
        net.WriteString(code)
        net.WriteString("shared")
        net.SendToServer()
    end

    lua.RunOnServer = function(code,ply)
        net.Start(netluasv)
        net.WriteString(code)
        net.WriteString("server")
        net.SendToServer()
    end

    net.Receive(netluaclients,function(len)
        local code = net.ReadString()
        local ply = net.ReadEntity()
        if not IsValid(ply) then return end
        CompileString(code,ply:GetName())()
    end)

    if notagain and notagain.hasloaded then
        lua = notagain.loaded_libraries.luadev
    else
        if _G.luadev then
            lua = _G.luadev
        else
            hook.Add("NotagainPostLoad","EasyChatModuleLuaTab",function()
                lua = notagain.loaded_libraries.luadev
            end)
        end
    end
end

if SERVER then
    util.AddNetworkString(netluaclients)
    util.AddNetworkString(netluasv)

    net.Receive(netluasv,function(len,ply)
        if not IsValid(ply) then return end
        local code = net.ReadString()
        local mode = net.ReadString()
        if ply:IsSuperAdmin() then
            if string.match(mode,"server") then
                CompileString(code,ply:GetName())()
            elseif string.match(mode,"clients") then
                net.Start(netluaclients)
                net.WriteString(code)
                net.WriteEntity(ply)
                net.Broadcast()
            elseif string.match(mode,"shared") then
                CompileString(code,ply:GetName())()
                net.Start(netluaclients)
                net.WriteString(code)
                net.WriteEntity(ply)
                net.Broadcast()
            end
        end
    end)
end

if CLIENT then

    local lua_tab = {
        Code = "",
        LastAction = {
            Script = "",
            Type   = "",
            Time   = "",
        },
        Init = function(self)
            local frame = self

            self.MenuExec = self:Add("DMenuBar")
            self.MenuExec:Dock(NODOCK)
            self.MenuExec:DockPadding(5,0,0,0)
            self.MenuExec.Think = function(self)
                self:SetSize(frame:GetWide(),25)
            end

            if not EasyChat.UseDermaSkin then
                self.MenuExec.Paint = function(self,w,h)
                    surface.SetDrawColor(EasyChat.TabColor)
                    surface.DrawRect(0,0,w,h)
                    surface.SetDrawColor(EasyChat.TabOutlineColor)
                    surface.DrawOutlinedRect(0,0,w,h)
                end
            end

            self:AddExecButton("Clients","icon16/user.png",function()
                lua.RunOnClients(self.Code,LocalPlayer())
                self:RegisterAction(self.Code,"clients")
            end,50,60)

            self:AddExecButton("Self","icon16/cog_go.png", function()
                lua.RunOnSelf(self.Code,LocalPlayer())
                self:RegisterAction(self.Code,"self")
            end,40,50)

            self:AddExecButton("Shared","icon16/world.png", function()
                lua.RunOnShared(self.Code,LocalPlayer())
                self:RegisterAction(self.Code,"shared")
            end,52,40)

            self:AddExecButton("Server","icon16/server.png", function()
                lua.RunOnServer(self.Code,LocalPlayer())
                self:RegisterAction(self.Code,"server")
            end,40,20)

            self.HTMLIDE = self:Add("DHTML")
            self.HTMLIDE:SetPos(0,25)
            self.HTMLIDE:AddFunction("gmodinterface","OnReady",function()
                self.HTMLIDE:Call('SetContent("' .. string.JavascriptSafe(self.Code) .. '");')
            end)
            self.HTMLIDE:AddFunction("gmodinterface","OnCode",function(code)
                self.Code = code
            end)

            self.HTMLIDE.Think = function(self)
                self:SetSize(frame:GetWide(),frame:GetTall()-50)
            end
            self.HTMLIDE:OpenURL("metastruct.github.io/lua_editor/")

            self.LblRunStatus = self:Add("DLabel")
            self.LblRunStatus:SetTextColor(EasyChat.TextColor)
            self.LblRunStatus:Dock(BOTTOM)
            self.LblRunStatus:SetSize(self:GetWide(),25)
            if not EasyChat.UseDermaSkin then
                self.LblRunStatus.Paint = function(self,w,h)
                    surface.SetDrawColor(EasyChat.TabColor)
                    surface.DrawRect(0,0,w,h)
                    surface.SetDrawColor(EasyChat.TabOutlineColor)
                    surface.DrawOutlinedRect(0,0,w,h)
                end
            end
            self.LblRunStatus.Think = function(self)
                self:SetText(frame.LastAction.Script ~= "" and (((" "):rep(3)).."["..frame.LastAction.Time.."] Ran "..frame.LastAction.Script.." on "..frame.LastAction.Type) or "")
            end

        end,
        RegisterAction = function(self,script,type)
            self.LastAction = {
                Script = (string.gsub(string.Explode(" ",script)[1],"\n","")).."...",
                Type = type,
                Time = os.date("%H:%M:%S"),
            }
        end,
        AddExecButton = function(self,name,ico,callback,size,insert)
            self.MenuExec[name] = self.MenuExec:Add("DButton")
            local frame = self
            local btn = self.MenuExec[name]
            btn:SetText(name)
            btn:SetIcon(ico)
            btn:Dock(LEFT)
            btn:SetSize(32+(size or 0),self.MenuExec:GetTall())
            btn:SetTextInset(btn.m_Image:GetWide() + (insert or 0),0)
            btn:SetPaintBackground(false)
            btn:SetTextColor(EasyChat.TextColor)
            btn.DoClick = function(self)
                if string.TrimLeft(frame.Code) == "" then return end
                callback()
            end

        end,
    }

    vgui.Register("ECLuaTab",lua_tab,"DPanel")


    CreateConVar("easychat_luatab","1",FCVAR_ARCHIVE,"Display luatab or not")
    cvars.AddChangeCallback("easychat_luatab",function(name,old,new)
        RunConsoleCommand("easychat_reload")
    end)

    if GetConVar("easychat_luatab"):GetBool() then
        local luatab = vgui.Create("ECLuaTab")
        EasyChat.AddTab("LuaTab",luatab)
        EasyChat.SetFocusForOn("LuaTab",luatab.HTMLIDE)
    end

end

return "LuaTab"
