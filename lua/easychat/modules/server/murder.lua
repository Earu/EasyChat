if gmod.GetGamemode().Name ~= "Murder" then return "Murder Compat" end

hook.Add("PlayerSay","EasyChatMurderWorkaround",function(ply, msg)
	if ply:Team() ~= 2 or not ply:Alive() or GAMEMODE:GetRound() == 0 then
		return msg
	end
end)

return "Murder Compat"