-- init.lua (server)
include("shared.lua")
AddCSLuaFile("cl_init.lua")
AddCSLuaFile("shared.lua")

util.AddNetworkString("ERV_QTEStart")

-- Player spawn customization
function GM:PlayerSpawn(ply)
    self.BaseClass.PlayerSpawn(self, ply)
    ply:SetWalkSpeed(100)
    ply:SetRunSpeed(150)
    ply:SetJumpPower(0)
end

-- Trigger zone network
function GM:OnEntityCreated(ent)
    if ent:GetClass() == "erv_trigger_zone" then
        print("ERV Trigger Zone created.")
    end
end
