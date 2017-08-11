local netluaclients = "EASY_CHAT_MODULE_LUA_CLIENTS"
local netluasv = "EASY_CHAT_MODULE_LUA_SV"
local lua = {}

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
    CreateConVar("easychat_luatab","1",FCVAR_ARCHIVE,"Display luatab or not")
    cvars.AddChangeCallback("easychat_luatab",function(name,old,new)
        LocalPlayer():ConCommand("easychat_reload")
    end)

    if not GetConVar("easychat_luatab"):GetBool() then return "LuaTab" end

    local luaTab = vgui.Create( "DPanel")
    EasyChat.AddTab("LuaTab",luaTab)
    luaTab.code = ""

    local lastAction = {
        script = "",
        type = "",
        time = "",
    }

    local RegisterAction = function(script,type)
        lastAction = {
            script = string.Explode(" ",script)[1].."...",
            type = type,
            time = os.date("%H:%M:%S"),
        }
    end

    luaTab.bar = vgui.Create("DMenuBar", luaTab)
    local bar = luaTab.bar
    bar:Dock( NODOCK )
    bar:DockPadding( 5, 0, 0, 0 )
    bar.Think = function( self )
        self:SetSize(luaTab:GetWide(), 25 )
    end
    if not EasyChat.UseDermaSkin then
        bar.Paint = function(self,w,h)
            surface.SetDrawColor(EasyChat.TabColor)
            surface.DrawRect(0,0,w,h)
            surface.SetDrawColor(EasyChat.TabOutlineColor)
            surface.DrawOutlinedRect(0,0,w,h)
        end
    end
    bar.addButton = function(name, icon, cb, size, insert)
        local b = bar:Add( "DButton" )
        b:SetText( name )
        b:SetIcon(icon)
        b:Dock( LEFT )
        b:SetSize(32+(size or 0), bar:GetTall())
        b:SetTextInset( b.m_Image:GetWide() + (insert or 0), 0 )
        b:SetPaintBackground( false )
        b:SetTextColor(EasyChat.TextColor)
        b.DoClick = function()
            cb()
        end
    end

    bar.addButton("Clients", "icon16/user.png", function()
        if string.TrimLeft(luaTab.code) == "" then return end
        lua.RunOnClients(luaTab.code,LocalPlayer())
        RegisterAction(luaTab.code,"clients")
    end, 50, 60)
    bar.addButton("Clientside", "icon16/cog_go.png", function()
        if string.TrimLeft(luaTab.code) == "" then return end
        lua.RunOnSelf(luaTab.code,LocalPlayer())
        RegisterAction(luaTab.code,"self")
    end, 62, 50)
    bar.addButton("Shared", "icon16/world.png", function()
        if string.TrimLeft(luaTab.code) == "" then return end
        lua.RunOnShared(luaTab.code,LocalPlayer())
        RegisterAction(luaTab.code,"shared")
    end, 52, 40)
    bar.addButton("Server", "icon16/server.png", function()
        if string.TrimLeft(luaTab.code) == "" then return end
        lua.RunOnServer(luaTab.code,LocalPlayer())
        RegisterAction(luaTab.code,"server")
    end, 40, 20)

    local html = vgui.Create( "DHTML" , luaTab )
    html:SetPos(0,25)


    html:AddFunction("gmodinterface", "OnReady", function(  )
        html:Call('SetContent("' .. string.JavascriptSafe(luaTab.code) .. '");')
    end)

    html:AddFunction("gmodinterface", "OnCode", function( code )
        luaTab.code = code
    end)

    html.Think = function( self )
        self:SetSize(luaTab:GetWide(),luaTab:GetTall()-50)
    end
    html:OpenURL("metastruct.github.io/lua_editor/")

    local status = vgui.Create("DLabel",luaTab)
    status:SetTextColor(EasyChat.TextColor)
    status:Dock(BOTTOM)
    status:SetSize(luaTab:GetWide(),25)
    if not EasyChat.UseDermaSkin then
        status.Paint = function(self,w,h)
            surface.SetDrawColor(EasyChat.TabColor)
            surface.DrawRect(0,0,w,h)
            surface.SetDrawColor(EasyChat.TabOutlineColor)
            surface.DrawOutlinedRect(0,0,w,h)
        end
    end
    status.Think = function(self)
        self:SetText(lastAction.script ~= "" and (((" "):rep(3)).."["..lastAction.time.."] Ran "..lastAction.script.." on "..lastAction.type) or "")
    end

    EasyChat.SetFocusForOn("LuaTab",html)

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

return "LuaTab"
