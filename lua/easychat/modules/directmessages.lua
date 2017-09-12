if CLIENT then
	local GLOBAL_PANEL = {
		Init = function(self)
		end,
		CreateNewPM = function(self,plys)
		end,
		Paint = function(self,w,h)
		end,
	}

	local PM_PANEL = {
		Players = {},
		Init = function(self)
		end,
		SendPM = function(self)
		end,
		Setup = function(self,plys)
			self.Players = plys
		end,
		AddPlayer = function(self,ply)
		end,
		RemovePlayer = function(self,ply)
		end,
	}

	vgui.Register("ECPMTab",GLOBAL_PANEL,"DPanel")
	vgui.Register("ECPMPanel",PM_PANEL,"DPanel")

	--local pmtab = vgui.Create("ECPMTab")
	--EasyChat.AddTab("PMs",pmtab)
end

return "Private Messages"