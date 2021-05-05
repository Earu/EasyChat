local TAG = "AnythingInChat"

if CLIENT then
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
            return { Name = game.GetMap() }
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
            local friendship = obj:GetFriendStatus()
            local is_blocked = friendship == "blocked"
            local is_friend = friendship == "friend"
            local nick = EasyChat.GetProperNick(LocalPlayer())

            return {
                Name = EasyChat.GetProperNick(obj),
                FriendStatus = is_blocked and ("Blocked by " .. nick) or is_friend and ("Friend with " .. nick) or "",
                Model = obj:GetModel(),
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
    local EC_ENABLE = GetConVar("easychat_enable")
    local green_color = Color(100, 230, 100)
    local gray_color = Color(200, 200, 200)
    local white_color = Color(255, 255, 255)
    local indicated_ents = {}
    net.Receive(TAG, function()
        local ply = net.ReadEntity()
        local category = net.ReadString()
        local data = net.ReadTable()

        local ent = data.Entity
        if IsValid(ent) then
            table.insert(indicated_ents, ent)
            ent.IndicationEndTime = CurTime() + INDICATION_DURATION
        end

        if not EC_ENABLE:GetBool() then
            chat.AddText(ply, green_color, " indicates ", gray_color, util.TableToJSON(data, true))
            return
        end

        local panel = EasyChat.GUI and EasyChat.GUI.RichText
        local chathud = EasyChat.ChatHUD
        if IsValid(panel) and chathud then

            local text = ("[Object: %s]"):format(category)
            if data.Name then
                text = ("[Object: %s, Name: %s]"):format(category, data.Name)
            end

            chathud:AddText(ply, green_color, " indicates ", gray_color, text)

            EasyChat.AddText(panel, ply, green_color, " indicates ", gray_color)
            panel:AppendClickableText(text, function()
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
        end
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

    local EC_INDICATIONS = CreateConVar("easychat_indications", "1", FCVAR_ARCHIVE, "Allows you to indicate objects in the chat by pressing mouse3 and shift")
	EasyChat.RegisterConvar(EC_INDICATIONS, "Indicates objects when pressing mouse3 and shift")

    local was_pressed = false
    hook.Add("Think", TAG, function()
        if input.LookupBinding("+ec_indicate", true) then return end
        if not EC_INDICATIONS:GetBool() then return end

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
                for i = 1, MAX_PASSENGERS_CHECK do
                    local passenger = obj:GetPassenger(i)
                    if IsValid(passenger) then
                        table.insert(passengers, passenger)
                    end
                end

                local vel = Vector(0, 0, 0)
                local phys = obj:GetPhysicsObject()
                if IsValid(phys) then
                    vel = phys:GetVelocity()
                end


                data.Owner = obj.CPPIGetOwner and obj:CPPIGetOwner()
                data.Driver = obj:GetDriver()
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
            local obj = data.Entity
            if IsValid(obj) then
                data.SteamID = obj:SteamID()
                data.Team = team.GetName(obj:Team())
                data.Weapon = obj:GetActiveWeapon()
                data.Health = obj:Health()
                data.Armor = obj:Armor()
                data.Position = obj:GetPos()
            end

            return data
        end,
        npc = function(ply, data)
            local obj = data.Entity
            if IsValid(obj) then
                data.Owner = obj.CPPIGetOwner and obj:CPPIGetOwner()
                data.Position = obj:GetPos()
                data.IsHostile = data.Entity:Disposition(ply) == 1
                data.Health = obj.Health and obj:Health() or -1
                data.Weapon = obj.GetActiveWeapon and obj:GetActiveWeapon()
            end

            return data
        end,
    }

    local RATE_LIMIT = 4
    net.Receive(TAG, function(_, ply)
        if CurTime() <= (ply.NextAIC or 0) then return end

        ply.NextAIC = CurTime() + RATE_LIMIT

        local category = net.ReadString()
        local data = net.ReadTable()

        local refiner = data_refiners[category]
        if refiner then
            data = refiner(ply, data)
        end

        EasyChat.RunOnNextFrame(function()
            net.Start(TAG)
            net.WriteEntity(ply)
            net.WriteString(category)
            net.WriteTable(data)
            net.Broadcast()
        end)
    end)
end

return "Anything In Chat"