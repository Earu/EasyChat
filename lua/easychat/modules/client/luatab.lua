local DoLuaTab = function()
    local luadev = requirex("luadev")
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
            script = string.len(script) > 50 and string.sub(script,1,50).."..." or script,
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
    bar.Paint = function(self,w,h)
        surface.SetDrawColor(EasyChat.TabColor)
        surface.DrawRect(0,0,w,h)
        surface.SetDrawColor(EasyChat.TabOutlineColor)
        surface.DrawOutlinedRect(0,0,w,h)
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
        luadev.RunOnClients(luaTab.code,LocalPlayer())
        RegisterAction(luaTab.code,"clients")
    end, 50, 60)
    bar.addButton("Clientside", "icon16/cog_go.png", function()
        luadev.RunOnSelf(luaTab.code,LocalPlayer())
        RegisterAction(luaTab.code,"self")
    end, 62, 50)
    bar.addButton("Shared", "icon16/world.png", function()
        luadev.RunOnShared(luaTab.code,LocalPlayer())
        RegisterAction(luaTab.code,"shared")
    end, 52, 40)
    bar.addButton("Server", "icon16/server.png", function()
        luadev.RunOnServer(luaTab.code,LocalPlayer())
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
    status.Paint = function(self,w,h)
        surface.SetDrawColor(EasyChat.TabColor)
        surface.DrawRect(0,0,w,h)
        surface.SetDrawColor(EasyChat.TabOutlineColor)
        surface.DrawOutlinedRect(0,0,w,h)
    end
    status.Think = function(self)
        self:SetText(lastAction.script ~= "" and (((" "):rep(3)).."["..lastAction.time.."] Ran ("..lastAction.script..") on "..lastAction.type) or "")
    end
end

if notagain and notagain.hasloaded then
    DoLuaTab()
else
    hook.Add("NotagainPostLoad","EasyChatModuleLuaTab",DoLuaTab)
end
