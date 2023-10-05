if engine.ActiveGamemode() == "terrortown" then
	hook.Add("ECVoiceHUD", "EasyChatModuleTerrortown", function()
		return false -- DISABLED: TTT Voice HUD affects traitor voice mode
	end)
end

return "Terrortown Compat"
