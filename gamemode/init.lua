-- init.lua (server)
include("shared.lua")
AddCSLuaFile("cl_init.lua")
AddCSLuaFile("shared.lua")

-- Register network messages
util.AddNetworkString("ERV_QTEStart")
util.AddNetworkString("ERV_ReadyWeapon")
weapons.Register(include("entities/weapons/weapon_erv_pistol.lua"), "weapon_erv_pistol")

-- Ensure correct player model & animations
function GM:PlayerSetModel(ply)
    self.BaseClass.PlayerSetModel(self, ply)
end

-- Override loadout: give only pistol
function GM:PlayerLoadout(ply)
    ply:StripWeapons()
    ply:Give("weapon_erv_pistol")
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
    ply.ERV_LedgeBlocked = false -- reset per frame

    -- Block all movement when in weapon ready (ADS) mode
    if ply.ERV_WeaponReady then
        mv:SetForwardSpeed(-10)
        mv:SetSideSpeed(0)
        local vel = mv:GetVelocity()
        vel.z = -200
        mv:SetVelocity(vel)
        return true
    end

    -- Prevent walking off high ledges
    local heightThreshold = 96
    local traceDistance = 32 -- Increased detection radius
    local pos = ply:GetPos()
    local fwd = mv:GetMoveAngles():Forward() * traceDistance
    local checkPos = pos + fwd

    local tr = util.TraceLine({
        start = checkPos + Vector(0, 0, 5),
        endpos = checkPos - Vector(0, 0, heightThreshold),
        filter = ply
    })

    if not tr.Hit then
        ply.ERV_LedgeBlocked = true -- state flag set

        -- Visual marker for drop point
        debugoverlay.Box(checkPos, Vector(-2, -2, -2), Vector(2, 2, 2), 0.1, Color(255, 0, 0))

        -- Use the wall or ledge surface to push the player along their movement direction
        local wallTrace = util.TraceLine({
            start = pos + Vector(0, 0, 5),
            endpos = pos - Vector(0, 0, heightThreshold),
            filter = ply
        })

        if wallTrace.Hit then
            local wallNormal = wallTrace.HitNormal:GetNormalized()
            local moveDir = mv:GetVelocity():GetNormalized()
            local slideDir = moveDir - wallNormal * moveDir:Dot(wallNormal)
            local pushVelocity = slideDir:GetNormalized() * 100
            pushVelocity.z = -100
            mv:SetVelocity(pushVelocity)

            local edgeDir = wallTrace.HitNormal:Cross(Vector(0, 0, 1)) * 20
            debugoverlay.Line(wallTrace.HitPos - edgeDir, wallTrace.HitPos + edgeDir, 0.1, Color(255, 255, 0), true)
        end

        mv:SetForwardSpeed(0)
        mv:SetSideSpeed(0)
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
    local wep = ply:GetActiveWeapon()
    local hold = IsValid(wep) and wep:GetHoldType() or ""

    -- Override hold type based on weapon ready state
    if IsValid(wep) then
        if ply.ERV_WeaponReady then
            wep:SetHoldType("ar2")
        else
            wep:SetHoldType("passive")
        end
    end

    -- Ledge-blocked idle animation
    if ply.ERV_LedgeBlocked then
        return ACT_HL2MP_IDLE_PASSIVE, -1
    end

    if ply.ERV_WeaponReady then
        local onehand = {pistol=true, smg=true, knife=true, melee=true, grenade=true, revolver=true}
        if onehand[hold] then
            return ACT_HL2MP_IDLE_PISTOL, -1
        else
            return ACT_HL2MP_IDLE_AR2, -1
        end
    end

    return ACT_HL2MP_IDLE_PASSIVE
end

function GM:UpdateAnimation(ply, velocity, maxseqgroundspeed)
    if ply.ERV_WeaponReady or velocity:Length2DSqr() < 1 or ply.ERV_LedgeBlocked then
        ply:SetPlaybackRate(0)
        return true
    end
end
