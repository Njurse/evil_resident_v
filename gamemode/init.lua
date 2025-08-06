-- init.lua (server)
include("shared.lua")
AddCSLuaFile("cl_init.lua")
AddCSLuaFile("shared.lua")

-- Register network messages
util.AddNetworkString("ERV_QTEStart")
util.AddNetworkString("ERV_ReadyWeapon")

-- Ensure correct player model & animations
function GM:PlayerSetModel(ply)
    self.BaseClass.PlayerSetModel(self, ply)
end

-- Override loadout: give only pistol
function GM:PlayerLoadout(ply)
    ply:StripWeapons()
    ply:Give("weapon_pistol")
    return true
end

-- Disable physgun and toolgun
hook.Add("CanTool", "ERV_DisableTools", function() return false end)

-- Set movement speeds
function GM:PlayerSpawn(ply)
    self.BaseClass.PlayerSpawn(self, ply)
    ply:SetWalkSpeed(100)
    ply:SetRunSpeed(150)
    ply:SetJumpPower(0)
end

-- Detect trigger zone
function GM:OnEntityCreated(ent)
    if ent:GetClass() == "erv_trigger_zone" then
        print("[ERV] Trigger zone created.")
    end
end

-- Handle ADS toggle from client
local defaultSpeeds = {}
net.Receive("ERV_ReadyWeapon", function(len, ply)
    local ready = net.ReadBool()
    ply.ERV_WeaponReady = ready

    if not defaultSpeeds[ply] then
        defaultSpeeds[ply] = { walk = ply:GetWalkSpeed(), run = ply:GetRunSpeed() }
    end

    if ready then
        ply:SetWalkSpeed(0)
        ply:SetRunSpeed(0)
        local wep = ply:GetActiveWeapon()
        if IsValid(wep) then wep:SetHoldType("ar2") end
    else
        local speeds = defaultSpeeds[ply]
        ply:SetWalkSpeed(speeds.walk)
        ply:SetRunSpeed(speeds.run)
        local wep = ply:GetActiveWeapon()
        if IsValid(wep) then wep:SetHoldType("passive") end
    end
end)

-- Prevent movement when ADS
function GM:Move(ply, mv)
    if ply.ERV_WeaponReady then
        mv:SetForwardSpeed(0)
        mv:SetSideSpeed(0)
        mv:SetUpSpeed(0)
        return true
    end
end

-- Server-side animation control
function GM:CalcMainActivity(ply, velocity)
    if ply.ERV_WeaponReady then
        local wep = ply:GetActiveWeapon()
        local hold = IsValid(wep) and wep:GetHoldType() or ""
        local onehand = {pistol=true, smg=true, knife=true, melee=true, grenade=true, revolver=true}
        if onehand[hold] then
            return ACT_HL2MP_IDLE_PISTOL, -1
        else
            return ACT_HL2MP_IDLE_AR2, -1
        end
    end
end

function GM:UpdateAnimation(ply, velocity, maxseqgroundspeed)
    if ply.ERV_WeaponReady then
        ply:SetPlaybackRate(0)
        return true
    end
end
