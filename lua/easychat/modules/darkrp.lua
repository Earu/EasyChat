if gmod.GetGamemode().Name ~= "DarkRP" then return end

if CLIENT then
    hook.Add("ECPostInitialize","EasyChatModuleDarkRP",function()
        local EC_ENABLE = GetConVar("easychat_enable")
        local EC_TIMESTAMPS = GetConVar("easychat_timestamps")
        local EC_TEAMS = GetConVar("easychat_teams")
        local EC_TEAMS_COLOR = GetConVar("easychat_teams_colored")

        GAMEMODE.OnPlayerChat = function(self,ply,msg,isteam,isdead,prefixtext,col1,col2) -- this is for the best
            local tab = {}

            -- I don't trust this gamemode at all.
            local col1 = col1 or Color(255,255,255)
            local col2 = col2 or Color(255,255,255)

            table.insert(tab,Color(255,255,255)) -- we don't want previous colors to be used again

            if EC_ENABLE:GetBool() then
                if IsValid(ply) and EC_TEAMS:GetBool() then
                    if EC_TEAMS_COLOR:GetBool() then
                        local tcol = team.GetColor(ply:Team())
                        table.insert(tab,tcol)
                    end
                    table.insert(tab,"["..team.GetName(ply:Team()).."] - ")
                end
            end

            if isdead then
                table.insert(tab,Color(240,80,80))
                table.insert(tab,"*DEAD* " )
            end

            if prefixtext then
                if col1 == team.GetColor(ply:Team()) then -- Just prettier
                    col1 = Color(255,255,255)
                end

                table.insert(tab,col1)
                -- Remove the nick appened, use our own system.
                table.insert(tab,(string.gsub(prefixtext,string.PatternSafe(ply:Nick()),"")))
            end

            if IsValid(ply)  then
                table.insert(tab,ply)
            else
                table.insert(tab,Color(110,247,177))
                table.insert(tab,"???") -- console or weird stuff
            end

            table.insert(tab,Color(255,255,255))
            table.insert(tab,": ")
            table.insert(tab,col2)
            table.insert(tab,msg)

            chat.AddText(unpack(tab))

            return true
        end
    end)
end
