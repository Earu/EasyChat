local NET_SEND_PM 	    = "EASY_CHAT_MODULE_PM_SEND"
local NET_BROADCAST_PM  = "EASY_CHAT_MODULE_PM_BROADCAST"
local NET_ADD_PLAYER    = "EASY_CHAT_MODULE_PM_ADD_PLAYER"
local NET_REMOVE_PLAYER = "EASY_CHAT_MODULE_PM_REMOVE_PLAYER"
local NET_CREATE_ROOM	= "EASY_CHAT_MODULE_PM_CREATE_ROOM"
local NET_REMOVE_ROOM	= "EASY_CHAT_MODULE_PM_REMOVE_ROOM"

if SERVER then
	util.AddNetworkString(NET_SEND_PM)
	util.AddNetworkString(NET_BROADCAST_PM)
	util.AddNetworkString(NET_ADD_PLAYER)
	util.AddNetworkString(NET_REMOVE_PLAYER)
	util.AddNetworkString(NET_CREATE_ROOM)
	util.AddNetworkString(NET_REMOVE_ROOM)

	local Rooms = {}
	local CreateRoom = function(owner,plys)
		local room = {}
		local id = table.insert(Rooms,room)
		
		room.Owner = owner
		room.Players = {}
		for k,v in pairs(plys) do
			room.Players[v:SteamID()] = v
			v.Rooms = v.Rooms or {}
			table.insert(v.Rooms,id)
		end

		owner.OwnedRooms = owner.OwnedRooms or {}
		owner.Rooms = owner.Rooms or {}
		table.insert(owner.OwnedRooms,id)
		table.insert(owner.Rooms,id)
		
		net.Start(NET_CREATE_ROOM)
		net.WriteInt(id,32)
		net.WriteEntity(owner)
		net.WriteTable(plys)
		net.Send(plys)
	end

	local MakeNumerical = function(tbl)
		local numerical = {}
		for _,v in pairs(tbl) do
			table.insert(numerical,v)
		end
		return numerical
	end

	local AddToRoom = function(id,ply)
		if not Rooms[id] then return end
		local room = Rooms[id]
		room.Players[ply:SteamID()] = ply
		ply.Rooms = ply.Rooms or {}
		table.insert(ply.Rooms,id)
		
		net.Start(NET_ADD_PLAYER)
		net.WriteInt(id,32)
		net.WriteEntity(ply)
		net.Send(MakeNumerical(room.Players))
	end

	local RemoveFromRoom = function(id,ply)
		if not Rooms[id] then return end
		local room = Rooms[id]
		room.Players[ply:SteamID()] = nil
		ply.Rooms[id] = nil

		if table.Count(room.Players) > 0 then
			net.Start(NET_REMOVE_PLAYER)
			net.WriteInt(id,32)
			net.WriteEntity(ply)
			net.Send(MakeNumerical(room.Players))
		end
	end

end

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
		SendPM = function(self,txt)
			net.Start(NET_SEND_PM)
			net.WriteTable(self.Players)
			net.WriteString(txt)
			net.SendToServer()
		end,
		UpdatePlayers = function(self,plys)
			self.Players = {}
			for k,v in pairs(plys) do
				self.Players[v:SteamID()] = v
			end
		end,
		AddPlayer = function(self,ply)
			self.Players[ply:SteamID()] = ply
		end,
		RemovePlayer = function(self,ply)
			self.Players[ply:SteamID()] = nil
		end,
	}

	vgui.Register("ECPMTab",GLOBAL_PANEL,"DPanel")
	vgui.Register("ECPMPanel",PM_PANEL,"DPanel")

	local pmtab = vgui.Create("ECPMTab")
	EasyChat.AddTab("PMs",pmtab)
end

return "Private Messages"