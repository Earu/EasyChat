local netstring = "EASY_CHAT_SERVER_INPUT"
hook.Remove("Think","EasyChatModuleEPOE")

if CLIENT then
    local panel = vgui.Create("DPanel")
    local loaded = false
    EasyChat.AddTab("Epoe",panel)

    local commandentry = panel:Add("DTextEntry")
    commandentry:Dock(BOTTOM)
    commandentry.OnKeyCodeTyped = function( self, code )
        if code == KEY_ENTER then
            if string.Trim( self:GetText() ) ~= "" then
                net.Start(netstring)
                net.WriteString(string.sub(self:GetText(),1,200))
                net.SendToServer()
                self:SetText("")
            end
        end
    end

    EasyChat.SetFocusForOn("Epoe",commandentry)

    local DoEpoeTab = function()
        epoe.GUI.old_think = epoe.GUI.old_think or epoe.GUI.Think
        epoe.GUI.Think = function(self)
            epoe.GUI.old_think(self)
            if not IsValid(panel) or not IsValid(commandentry) then return end
            local x,y,w,h = panel:GetBounds()
            self:SetPos(x,y)
            self:SetSize(w,h-commandentry:GetTall())
        end
    end

    hook.Add("Think","EasyChatModuleEPOE",function(self)
        if epoe and epoe.GUI and not loaded then
            DoEpoeTab()
            loaded = true
        end

        if loaded and epoe and not epoe.GUI then
            loaded = false
        end
    end)

end

if SERVER then
    util.AddNetworkString(netstring)

    net.Receive(netstring,function(len,ply)
        if ply:IsAdmin() then
            local cmd = net.ReadString()
            game.ConsoleCommand(cmd.."\n")
        end
    end)
end

return "EPOE"
