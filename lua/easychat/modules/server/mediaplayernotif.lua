hook.Add("MediaPlayerAddListener", "mediaplayer_listener_chatprint", function(mp, ply)
	for _, v in pairs(mp:GetListeners()) do
		if ply ~= v and v:IsValid() then
			v:ChatPrint(ply:Nick() .. " has subscribed to MediaPlayer[" ..mp.Entity:EntIndex().."]")
			ply:ChatPrint(v:Nick() .. " is subscribed to MediaPlayer[" ..mp.Entity:EntIndex().."]")
		end
	end
end)

hook.Add("MediaPlayerRemoveListener", "mediaplayer_listener_chatprint", function(mp, ply)
	for _, v in pairs(mp:GetListeners()) do
		if v:IsValid() then
			v:ChatPrint(ply:Nick() .. " has unsubscribed from MediaPlayer[" ..mp.Entity:EntIndex().."]")
		end
	end
end)
