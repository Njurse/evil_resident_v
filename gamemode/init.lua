-- init.lua (server) — Organized, QTE‑safe holdtypes/animations and movement

--[[
Sections
1) Bootstrap / Net
2) QTE state helpers
3) Holdtype utilities
4) Player setup / loadout
5) Movement & ledge safety
6) Animation (CalcMainActivity / UpdateAnimation)
7) Combat (melee)
]]

-------------------------------
-- 1) Bootstrap / Net
-------------------------------
include("shared.lua")
AddCSLuaFile("cl_init.lua")
AddCSLuaFile("shared.lua")

util.AddNetworkString("ERV_QTEStart")     -- client -> server: start/stop (bool, duration)
util.AddNetworkString("ERV_MeleeAttack")  -- client -> server: request melee vs target
util.AddNetworkString("ERV_ReadyWeapon")  -- client -> server: ADS toggle

-- Weapons (keep your registrations)
weapons.Register(include("entities/weapons/weapon_erv_pistol.lua"), "weapon_erv_pistol")
weapons.Register(include("entities/weapons/weapon_erv_knife.lua"),  "weapon_erv_knife")


-------------------------------
-- 2) QTE state helpers
-------------------------------
local function _qteTimerName(ply) return "ERV_QTE_" .. ply:EntIndex() end

local function ERV_SetQTE(ply, enabled, duration)
    if not IsValid(ply) then return end
    ply.ERV_InQTE = enabled and true or false
    ply:SetNWBool("erv_in_qte", ply.ERV_InQTE)

    if enabled and duration and duration > 0 then
        timer.Create(_qteTimerName(ply), duration, 1, function()
            if IsValid(ply) then
                ply.ERV_InQTE = false
                ply:SetNWBool("erv_in_qte", false)
                -- After QTE, ensure proper holdtype is restored
                ERV_ApplyHoldType(ply, true)
            end
        end)
    else
        timer.Remove(_qteTimerName(ply))
    end
end

-- Allow client to toggle a timed QTE lock (e.g., when a prompt appears)
net.Receive("ERV_QTEStart", function(_, ply)
    local start = net.ReadBool()
    local dur   = net.ReadFloat() or 0
    ERV_SetQTE(ply, start, dur)
end)


-------------------------------
-- 3) Holdtype utilities
-------------------------------
local function ERV_DesiredHoldType(ply, wep, ready)
    if not IsValid(wep) then return ready and "ar2" or "normal" end
    local class = (wep.GetClass and wep:GetClass()) or ""
    if class == "weapon_erv_knife"  then return ready and "knife"  or "normal" end
    if class == "weapon_erv_pistol" then return ready and "pistol" or "normal" end
    return ready and "ar2" or "normal" -- fallback
end

function ERV_ApplyHoldType(ply, force)
    if ply.ERV_InQTE and not force then return end -- never stomp QTE anims
    local wep = IsValid(ply) and ply:GetActiveWeapon() or nil
    if not IsValid(wep) then return end
    local want = ERV_DesiredHoldType(ply, wep, ply.ERV_WeaponReady)
    if wep:GetHoldType() ~= want then
        wep:SetHoldType(want)
    end
end

-- Re-apply when weapon changes
hook.Add("PlayerSwitchWeapon", "ERV_HoldtypeOnSwitch", function(ply, old, new)
    timer.Simple(0, function()
        if IsValid(ply) then ERV_ApplyHoldType(ply, false) end
    end)
end)


-------------------------------
-- 4) Player setup / loadout
-------------------------------
function GM:PlayerSetModel(ply)
    self.BaseClass.PlayerSetModel(self, ply)
end

function GM:PlayerLoadout(ply)
    ply:StripWeapons()
    ply:Give("weapon_erv_pistol")
    ply:Give("weapon_erv_knife")
    return true
end

hook.Add("CanTool", "ERV_DisableTools", function() return false end)

function GM:PlayerSpawn(ply)
    self.BaseClass.PlayerSpawn(self, ply)
    ply:SetWalkSpeed(65)
    ply:SetRunSpeed(150)
    ply:SetJumpPower(0)
end

function GM:OnEntityCreated(ent)
    if ent:GetClass() == "erv_trigger_zone" then
        print("[ERV] Trigger zone created.")
    end
end

-- ADS/Ready handling
local _defaultSpeeds = {}
net.Receive("ERV_ReadyWeapon", function(_, ply)
    if ply.ERV_InQTE then return end -- ignore toggles during QTE
    local ready = net.ReadBool()
    ply.ERV_WeaponReady = ready
    ply:SetNWBool("erv_ready", ready)

    if not _defaultSpeeds[ply] then
        _defaultSpeeds[ply] = { walk = ply:GetWalkSpeed(), run = ply:GetRunSpeed() }
    end

    if ready then
        ply:SetWalkSpeed(0)
        ply:SetRunSpeed(0)
    else
        local s = _defaultSpeeds[ply]
        if s then
            ply:SetWalkSpeed(s.walk)
            ply:SetRunSpeed(s.run)
        end
    end

    ERV_ApplyHoldType(ply, false)
end)


-------------------------------
-- 5) Movement & ledge safety
-------------------------------
function GM:Move(ply, mv)
    ply.ERV_LedgeBlocked = false

    -- Do not impose ADS locks while in QTE
    if ply.ERV_InQTE then return end

    -- ADS movement lock
    if ply.ERV_WeaponReady then
        mv:SetForwardSpeed(-10)
        mv:SetSideSpeed(0)
        local vel = mv:GetVelocity()
        vel.z = -200
        mv:SetVelocity(vel)
        return true
    end

    -- Ledge check
    local heightThreshold = 32
    local traceDistance   = 32
    local pos  = ply:GetPos()
    local fwd  = mv:GetMoveAngles():Forward() * traceDistance
    local spot = pos + fwd

    local tr = util.TraceHull({
        start  = spot + Vector(0, 0, 10),
        endpos = spot - Vector(0, 0, heightThreshold),
        mins   = Vector(-8, -8, 0),
        maxs   = Vector(8, 8, 1),
        filter = ply
    })

    if not tr.Hit then
        ply.ERV_LedgeBlocked = true

        debugoverlay.Box(spot, Vector(-2,-2,-2), Vector(2,2,2), 0.1, Color(255,0,0))

        local wallTrace = util.TraceHull({
            start  = pos + Vector(0,0,5),
            endpos = pos - Vector(0,0, heightThreshold),
            mins   = Vector(-8,-8,0),
            maxs   = Vector(8,8,1),
            filter = ply
        })

        if wallTrace.Hit then
            local wallNormal = wallTrace.HitNormal:GetNormalized()
            local moveDir    = mv:GetVelocity():GetNormalized()
            local slideDir   = moveDir - wallNormal * moveDir:Dot(wallNormal)
            local pushVelocity = slideDir:GetNormalized() * 100
            pushVelocity.z   = -100
            mv:SetVelocity(pushVelocity)

            local edgeDir = wallTrace.HitNormal:Cross(Vector(0,0,1)) * 20
            debugoverlay.Line(wallTrace.HitPos - edgeDir, wallTrace.HitPos + edgeDir, 0.1, Color(255,255,0), true)
        end

        mv:SetForwardSpeed(0)
        mv:SetSideSpeed(0)
        return true
    end

    -- Disable strafing at higher speeds
    local vel = mv:GetVelocity()
    local speed = vel:Length2D()
    local walkSpeed = ply:GetWalkSpeed()
    if speed > walkSpeed + 5 then
        mv:SetSideSpeed(0)
    end
end


-------------------------------
-- 6) Animation
-------------------------------
function GM:CalcMainActivity(ply, velocity)
    -- Keep hands off during QTE to let gestures/sequences play
    if ply.ERV_InQTE then return end

    -- Keep holdtype synced (but never inside QTE)
    ERV_ApplyHoldType(ply, false)

    -- Optional ledge print (throttled)
    if ply.ERV_LedgeBlocked and (ply._erv_lastLedgePrint or 0) < CurTime() - 0.25 then
        ply._erv_lastLedgePrint = CurTime()
        print("[ERV] Ledge detected for", ply)
    end

    -- Choose a reasonable idle
    if ply.ERV_WeaponReady then
        return ACT_HL2MP_IDLE_PISTOL, -1
    end
    return ACT_HL2MP_IDLE_PASSIVE, -1
end

function GM:UpdateAnimation(ply, velocity, maxseqgroundspeed)
    -- Freeze playback during QTE so QTE gestures control animation timing
    if ply.ERV_InQTE then return true end

    -- Idle freeze when aiming or nearly stationary (and not on a ledge slide)
    if ply.ERV_WeaponReady or velocity:Length2DSqr() < 1 or ply.ERV_LedgeBlocked then
        ply:SetPlaybackRate(0)
        -- Pose params belong here, not in CalcMainActivity
        if ply.ERV_WeaponReady then
            ply:SetPoseParameter("move_x", 0)
            ply:SetPoseParameter("move_y", 0)
        end
        return true
    end
end


-------------------------------
-- 7) Combat (melee)
-------------------------------
net.Receive("ERV_MeleeAttack", function(_, ply)
    local target = net.ReadEntity()
    if not IsValid(target) or not target:IsNPC() then return end
    if ply:GetPos():Distance(target:GetPos()) > 100 then return end

    -- Start a short QTE window to protect the gesture from overrides
    ERV_SetQTE(ply, true, 0.8)

    -- Play a melee gesture that layers on top of base activity
    ply:AnimRestartGesture(GESTURE_SLOT_ATTACK_AND_RELOAD, ACT_HL2MP_GESTURE_RANGE_ATTACK_MELEE2, true)

    -- Damage
    local dmg = DamageInfo()
    dmg:SetAttacker(ply)
    dmg:SetInflictor(ply:GetActiveWeapon() or ply)
    dmg:SetDamage(50)
    dmg:SetDamageType(DMG_CLUB)
    target:TakeDamageInfo(dmg)

    -- Knockback
    local dir = (target:GetPos() - ply:GetPos()):GetNormalized()
    target:SetVelocity(dir * 300 + Vector(0, 0, 40))
end)
