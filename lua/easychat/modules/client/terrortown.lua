if gmod.GetGamemode().Name ~= "terrortown" then return "Terrortown Compat" end

hook.Add("ECVoiceHUD", "EasyChatModuleTerrortown", function()
	return false -- DISABLED: TTT Voice HUD affects traitor voice mode
end)

return "Terrortown Compat"
