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
    ply:SetWalkSpeed(65)
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
        -- if IsValid(wep) then wep:SetHoldType("ar2") end
    else
        local speeds = defaultSpeeds[ply]
        ply:SetWalkSpeed(speeds.walk)
        ply:SetRunSpeed(speeds.run)
        local wep = ply:GetActiveWeapon()
        if IsValid(wep) then wep:SetHoldType("none") end
    end
end)

function GM:Move(ply, mv)
    -- Block all movement when in weapon ready (ADS) mode
    if ply.ERV_WeaponReady then
        mv:SetForwardSpeed(0)
        mv:SetSideSpeed(0)
        mv:SetUpSpeed(0)
        return true
    end

    -- Prevent walking off high ledges
    local heightThreshold = 96
    local pos = ply:GetPos()
    local fwd = mv:GetMoveAngles():Forward() * 20
    local checkPos = pos + fwd

    local tr = util.TraceLine({
        start = checkPos + Vector(0, 0, 5),
        endpos = checkPos - Vector(0, 0, heightThreshold),
        filter = ply
    })

    if not tr.Hit then
        -- Visual marker for drop point
        debugoverlay.Box(checkPos, Vector(-2, -2, -2), Vector(2, 2, 2), 0.1, Color(255, 0, 0))

        -- Try to draw a short line representing the edge (based on last valid trace)
        local lastGroundTrace = util.TraceLine({
            start = pos + Vector(0, 0, 5),
            endpos = pos - Vector(0, 0, heightThreshold),
            filter = ply
        })

        if lastGroundTrace.Hit then
            local edgeDir = lastGroundTrace.HitNormal:Cross(Vector(0, 0, 1)) * 20
            debugoverlay.Line(lastGroundTrace.HitPos - edgeDir, lastGroundTrace.HitPos + edgeDir, 0.1, Color(255, 255, 0), true)
        end

        -- Block movement
        mv:SetForwardSpeed(0)
        mv:SetSideSpeed(0)
        mv:SetUpSpeed(0)
        return true
    end

    -- Disable strafing while running
    local vel = mv:GetVelocity()
    local speed = vel:Length2D()

    local walkSpeed = ply:GetWalkSpeed()
    local runSpeed = ply:GetRunSpeed()

    local moving = speed > 1
    if moving and (speed >= walkSpeed + 5) then
        mv:SetSideSpeed(0)
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
    else
        return ACT_IDLE
    end
end

function GM:UpdateAnimation(ply, velocity, maxseqgroundspeed)
    if ply.ERV_WeaponReady then
        ply:SetPlaybackRate(0)
        return true
    end
end
