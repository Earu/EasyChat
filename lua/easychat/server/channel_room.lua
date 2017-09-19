local MakeNumerical = function(tbl)
    local result = {}
    for _,v in pairs(tbl) do
        table.insert(result,v)
    end
    return result
end

local ROOM       = {}
ROOM.__index     = ROOM
ROOM.Name        = ""
ROOM.Owner       = NULL
ROOM.Players     = {}
ROOM.PlayerCount = 0
ROOM.ID          = -1
ROOM.Initialized = false

ROOM.AddPlayer = function(self,ply)
    self.Players[ply:SteamID()] = ply
    self.PlayerCount = self.PlayerCount + 1
end

ROOM.RemovePlayer = function(self,ply)
    self.Players[ply:SteamID()] = nil
    self.PlayerCount = self.PlayerCount - 1
end

ROOM.SetOwner = function(self,ply)
    self.Owner = ply
    self:AddPlayer(ply)
end

ROOM.IsValidRoom = function(self)
    if self.Initialized and self.ID ~= -1 and self.Owner:IsValid() then
        return true
    else
        return false
    end
end

ROOM.Initialize = function(self,id,owner,plys,name)
    local name = name or owner:Nick().."'s Room"
    self:SetOwner(owner)
    for _,ply in pairs(plys) do
        self:AddPlayer(ply)
    end
    self.Name = name
    self.ID = id
    self.Initialized = true
end

ROOM.GetPlayersNumerical = function(self)
    return MakeNumerical(self.Players)
end

return function()
    return setmetatable({},ROOM)
end