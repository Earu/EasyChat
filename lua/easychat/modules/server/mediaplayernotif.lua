hook.Add("MediaPlayerAddListener", "mediaplayer_listener_chatprint", function(mp, ply)
	for _, v in pairs(mp:GetListeners()) do
		if ply ~= v and v:IsValid() then
			local owner = mp.Entity:CPPIGetOwner()
			v:ChatPrint(ply:Nick() .. " has subscribed to " ..owner:Nick().."'s MediaPlayer")
			ply:ChatPrint(v:Nick() .. " is subscribed to " ..owner:Nick().."'s MediaPlayer")
		end
	end
end)

hook.Add("MediaPlayerRemoveListener", "mediaplayer_listener_chatprint", function(mp, ply)
	for _, v in pairs(mp:GetListeners()) do
		if v:IsValid() then
			local owner = mp.Entity:CPPIGetOwner()
			v:ChatPrint(ply:Nick() .. " has unsubscribed from " ..owner:Nick().."'s MediaPlayer")
		end
	end
end)

return "MediaPlayer Notifications"