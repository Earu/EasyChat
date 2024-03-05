local TAG = "EasyChatModuleIndicate"

if CLIENT then
    local EC_INDICATIONS = CreateConVar("easychat_indications", "1", FCVAR_ARCHIVE, "Allows you to indicate objects in the chat by pressing mouse3 and shift")
    local EC_INDICATIONS_SHOW = CreateConVar("easychat_indications_show", "1", FCVAR_ARCHIVE, "Should we show indications or not")
    local EC_INDICATIONS_TEAM = CreateConVar("easychat_indications_team", "1", FCVAR_ARCHIVE, "Show your indications only to your team")
    EasyChat.RegisterConvar(EC_INDICATIONS, "Indicates objects when pressing mouse3 and shift")
    EasyChat.RegisterConvar(EC_INDICATIONS_SHOW, "Shows indications from other players")
    EasyChat.RegisterConvar(EC_INDICATIONS_TEAM, "Show your indications only to your team")

    local function categorize_object(obj)
        local t = type(obj)
        if t == "Entity" then
            if obj:IsVehicle() then
                return "vehicle"
            elseif obj:IsWeapon() then
                return "weapon"
            elseif obj:IsNPC() then
                return "npc"
            elseif obj == game.GetWorld() then
                return "world"
            elseif not IsValid(obj) then -- handle before GetClass, otherwise it errors
                return "null"
            elseif obj:GetClass():match("^prop_") then
                return "prop"
            else
                return "entity"
            end
        end

        return t:lower()
    end

    local object_handles = {
        vehicle = function(obj)
            return {
                Name = language.GetPhrase(obj:GetClass()),
                Entity = obj,
            }
        end,
        weapon = function(obj)
            return {
                Name = language.GetPhrase(obj:GetClass()),
                Entity = obj,
            }
        end,
        npc = function(obj)
            return {
                Name = language.GetPhrase(obj:GetClass()),
                Entity = obj,
            }
        end,
        world = function(obj)
            return {
                Name = game.GetMap(),
                WorldPos = LocalPlayer():GetEyeTrace().HitPos
            }
        end,
        prop = function(obj)
            return {
                Name = obj:GetModel(),
                Material = obj:GetMaterial(),
                Entity = obj,
            }
        end,
        entity = function(obj)
            return {
                Model = obj:GetModel(),
                Name = language.GetPhrase(obj:GetClass()),
                Entity = obj,
            }
        end,
        player = function(obj)
            return {
                Name = obj:Nick(),
                Entity = obj,
            }
        end,
        panel = function(obj)
            local x, y = obj:GetPos()
            return {
                Name = obj.ClassName,
                Size = { Width = obj:GetWide(), Height = obj:GetTall() },
                Position = { X = x, Y = y },
            }
        end,
    }

    local INDICATION_DURATION = 5
    local INDICATION_TEXT = " has indicated "
    local green_color = Color(100, 230, 100)
    local gray_color = Color(200, 200, 200)
    local white_color = Color(255, 255, 255)
    local indicated_ents = {}
    net.Receive(TAG, function()
        if not EC_INDICATIONS_SHOW:GetBool() then return end

        local ply = net.ReadEntity()
        local category = net.ReadString()
        local data = net.ReadTable()

        if not IsValid(ply) then return end

        local ent = data.Entity
        local indicate_pos
        local is_ent_pos = false
        if IsValid(ent) then
            table.insert(indicated_ents, ent)
            ent.IndicationEndTime = CurTime() + INDICATION_DURATION
            indicate_pos = ent:WorldSpaceCenter()
            is_ent_pos = true

            if ent:IsPlayer() then
                chat.AddText(ply, green_color, INDICATION_TEXT, ent)
                if ent == LocalPlayer() then
                    system.FlashWindow()
                end

                return
            end
        end

        local ply_name = ply:Nick()
        local hook_name = TAG .. ply_name
        indicate_pos = data.WorldPos and data.WorldPos or indicate_pos
        if indicate_pos then
            timer.Simple(INDICATION_DURATION, function() hook.Remove("HUDPaint", hook_name) end)
            hook.Add("HUDPaint", hook_name, function()
                local screen_pos = indicate_pos:ToScreen()
                if is_ent_pos and IsValid(ent) then
                    screen_pos = ent:WorldSpaceCenter():ToScreen()
                end

                if not screen_pos.visible then return end

                surface.SetTextColor(white_color)
                surface.SetFont("DermaLarge")
                local tw, th = surface.GetTextSize(ply_name)

                surface.SetDrawColor(EasyChat.OutlayColor)
                surface.DrawRect(screen_pos.x - tw / 2 - 5, screen_pos.y - th / 2 - 31, tw + 10, th + 2)

                surface.SetTextPos(screen_pos.x - tw / 2, screen_pos.y - th / 2 - 30)
                surface.DrawText(ply_name)

                surface.DrawCircle(screen_pos.x, screen_pos.y, 4, EasyChat.OutlayColor)
                surface.DrawCircle(screen_pos.x, screen_pos.y, 5, green_color)
                surface.DrawCircle(screen_pos.x, screen_pos.y, 6, green_color)
                surface.DrawCircle(screen_pos.x, screen_pos.y, 7, green_color)
                surface.DrawCircle(screen_pos.x, screen_pos.y, 8, EasyChat.OutlayColor)
            end)
        end

        local text = ("[Object: %s]"):format(category)
        if data.Name then
            text = ("[Object: %s, Name: %s]"):format(category, data.Name)
        end

        if data.WorldPos then
            text = "a position"
        end

        local interaction = EasyChat.CreateTextInteraction(text,  function()
            if IsValid(ent) then
                local lp = LocalPlayer()
                lp:SetEyeAngles((ent:WorldSpaceCenter() - lp:EyePos()):Angle())
            end

            local frame = EasyChat.CreateFrame()
            frame:SetTitle(text)
            frame:SetWide(400)

            data["Indicated By"] = ply

            for k, v in pairs(data) do
                local line = frame:Add("DPanel")
                line:Dock(TOP)
                line:SetTall(25)
                line.Paint = function() end

                local lbl_key = line:Add("DLabel")
                lbl_key:Dock(LEFT)
                lbl_key:DockMargin(5, 0, 0, 0)
                lbl_key:SetTextColor(green_color)
                lbl_key:SetFont("DermaDefault")
                lbl_key:SetText(tostring(k))
                lbl_key:SetTall(25)
                lbl_key:SetWide(100)

                local lbl_value = line:Add("DLabel")
                lbl_value:Dock(LEFT)
                lbl_value:SetWrap(true)
                lbl_value:SetFont("DermaDefault")
                lbl_value:SetText(tostring(v))
                lbl_value:SetTall(25)
                lbl_value:SetWide(300)

                if not EasyChat.UseDermaSkin then
                    lbl_value:SetTextColor(white_color)
                end
            end

            local ok_btn = frame:Add("DButton")
            ok_btn:Dock(TOP)
            ok_btn:SetTall(25)
            ok_btn:SetText("OK")
            ok_btn.DoClick = function()
                frame:Close()
            end

            if not EasyChat.UseDermaSkin then
                ok_btn:SetTextColor(white_color)
                ok_btn.Paint = function(self, w, h)
                    local prim_color, sec_color = EasyChat.OutlayColor, EasyChat.TabOutlineColor
                    if self:IsHovered() then
                        prim_color = Color(prim_color.r + 50, prim_color.g + 50, prim_color.b + 50, prim_color.a + 50)
                        sec_color = Color(255 - sec_color.r, 255 - sec_color.g, 255 - sec_color.b, 255 - sec_color.a)
                    end

                    surface.SetDrawColor(prim_color)
                    surface.DrawRect(0, 0, w, h)
                    surface.SetDrawColor(sec_color)
                    surface.DrawOutlinedRect(0, 0, w, h)
                end
            end

            frame:InvalidateChildren(true)
            frame:SizeToChildren(true, true)
            frame:Center()
            frame:MakePopup()
        end)

        chat.AddText(ply, green_color, INDICATION_TEXT, gray_color, interaction)
    end)

    local function handle_object(obj)
        local category = categorize_object(obj)
        local data = { Name = tostring(obj) }
        local handler = object_handles[category]
        if handler then
            data = handler(obj) or { Name = tostring(obj) }
        end

        net.Start(TAG)
        net.WriteString(category)
        net.WriteTable(data)
        net.SendToServer()

        return true, category
    end

    local function indicate_faced_object()
        local tr = LocalPlayer():GetEyeTrace()
        if IsValid(tr.Entity) then
            handle_object(tr.Entity)
        elseif tr.HitWorld then
            handle_object(game.GetWorld())
        end
    end

    local using = false
    concommand.Add("+ec_indicate", function() using = true end)
    concommand.Add("-ec_indicate", function()
        using = false
        indicate_faced_object()
    end)

    local next_check = 0
    hook.Add("PreDrawHalos", TAG, function()
        halo.Add(indicated_ents, green_color)

        if using then
            local tr = LocalPlayer():GetEyeTrace()
            if IsValid(tr.Entity) then
                halo.Add({ tr.Entity }, white_color)
            end
        end

        if CurTime() >= next_check then
            for i, ent in pairs(indicated_ents) do
                if not IsValid(ent) or CurTime() >= ent.IndicationEndTime then
                    table.remove(indicated_ents, i)
                end
            end
            next_check = CurTime() + 1
        end
    end)

    local was_pressed = false
    hook.Add("Think", TAG, function()
        if input.LookupBinding("+ec_indicate", true) then return end
        if not EC_INDICATIONS:GetBool() then return end
        if input.LookupKeyBinding(MOUSE_MIDDLE) then
            EC_INDICATIONS:SetBool(false)
            return
        end

        if (input.IsKeyDown(KEY_LSHIFT) or input.IsKeyDown(KEY_RSHIFT)) and input.IsMouseDown(MOUSE_MIDDLE) then
            using = true
            was_pressed = true
        else
            if was_pressed then
                was_pressed = false
                using = false
                indicate_faced_object()
            end
        end
    end)

    DumpObject = handle_object
end

if SERVER then
    util.AddNetworkString(TAG)

    local MAX_PASSENGERS_CHECK = 10
    local data_refiners = {
        vehicle = function(_, data)
            local obj = data.Entity
            if IsValid(obj) then
                local passengers = {}
                if obj.GetPassenger then
                    for i = 1, MAX_PASSENGERS_CHECK do
                        local passenger = obj:GetPassenger(i)
                        if IsValid(passenger) then
                            table.insert(passengers, passenger)
                        end
                    end
                end

                local vel = Vector(0, 0, 0)
                local phys = obj:GetPhysicsObject()
                if IsValid(phys) then
                    vel = phys:GetVelocity()
                end


                data.Owner = obj.CPPIGetOwner and obj:CPPIGetOwner()
                data.Driver = obj.GetDriver and obj:GetDriver()
                data.Passengers = passengers
                data.Velocity = vel
                data.Position = obj:GetPos()
            end

            return data
        end,
        weapon = function(_, data)
            local obj = data.Entity
            if IsValid(obj) then
                data.Owner = obj.Owner
                data.HeldBy = obj:GetOwner()
                data.Clip1 = obj:Clip1()
                data.MaxClip1 = obj:GetMaxClip1()
                data.Clip2 = obj:Clip2()
                data.MaxClip2 = obj:GetMaxClip2()
                data.Position = obj:GetPos()
            end

            return data
        end,
        world = function(_, data)
            data.Name = game.GetMap()
            data.Gamemode = (GM or GAMEMODE).Name or "Unknown"
            data.Players = player.GetCount()
            data.MaxPlayers = game.MaxPlayers()
            data.Uptime = string.NiceTime(CurTime())
            data.Hostname = GetHostName()
            data.IP = game.GetIPAddress()

            return data
        end,
        prop = function(_, data)
            local obj = data.Entity
            if IsValid(obj) then
                data.Owner = obj.CPPIGetOwner and obj:CPPIGetOwner()
                data.Position = obj:GetPos()
            end

            return data
        end,
        entity = function(_, data)
            local obj = data.Entity
            if IsValid(obj) then
                data.Owner = obj.CPPIGetOwner and obj:CPPIGetOwner()
                data.Position = obj:GetPos()
            end

            return data
        end,
        player = function(_, data)
            return data
        end,
        npc = function(ply, data)
            local obj = data.Entity
            if IsValid(obj) then
                data.Owner = obj.CPPIGetOwner and obj:CPPIGetOwner()
                data.Position = obj:GetPos()
                data.IsHostile = obj.Disposition and obj:Disposition(ply) == 1 or false
                data.Health = obj.Health and obj:Health() or -1
                data.Weapon = obj.GetActiveWeapon and obj:GetActiveWeapon()
            end

            return data
        end,
    }

    local RATE_LIMIT = 4
    net.Receive(TAG, function(_, ply)
        if CurTime() <= (ply.NextAIC or 0) then return end
        local ret = EasyChat.SafeHookRun("ECCanIndicate", ply)
        if ret == false then return end

        ply.NextAIC = CurTime() + RATE_LIMIT

        local category = net.ReadString()
        local data = net.ReadTable()

        local refiner = data_refiners[category]
        if refiner then
            data = refiner(ply, data)
        end

        EasyChat.RunOnNextFrame(function()
            local filter = {}
            if ply:GetInfoNum("easychat_indications_team", 1) >= 1 then
                for _, p in ipairs(player.GetHumans()) do
                    if p:Team() == ply:Team() then
                        table.insert(filter, p)
                    end
                end
            end

            net.Start(TAG)
            net.WriteEntity(ply)
            net.WriteString(category)
            net.WriteTable(data)

            if #filter == 0 then
                net.SendPVS(ply:GetPos())
            else
                net.Send(filter)
            end
        end)
    end)
end

return "Indicate"
