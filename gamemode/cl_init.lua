-- Make sure clients download our HUD, laser, and camera modules
AddCSLuaFile("modules/client/erv_hud.lua")
AddCSLuaFile("modules/client/erv_laser.lua")
AddCSLuaFile("modules/client/erv_camera.lua")

include("shared.lua")
include("modules/client/erv_hud.lua")
include("modules/client/erv_laser.lua")
local Camera = include("modules/client/erv_camera.lua")

-- (Client-side weapon registration is fine; server also registers)
weapons.Register(include("entities/weapons/weapon_erv_pistol.lua"), "weapon_erv_pistol")
weapons.Register(include("entities/weapons/weapon_erv_knife.lua"), "weapon_erv_knife")

-- Hide the first-person viewmodel
hook.Add("InitPostEntity", "ERV_HideViewModels", function()
    RunConsoleCommand("r_drawviewmodel", "0")
end)

-- Ensure local player model is drawn
hook.Add("ShouldDrawLocalPlayer", "ERV_DrawLocalPlayer", function()
    return true
end)

---------------------------------------------------------------------
-- QTE SYSTEM (unified) + MELEE (camera starts on key press)
---------------------------------------------------------------------
local QTEActive  = false
local QTEType    = nil
local QTETarget  = nil
local QTEKey     = KEY_SPACE
local QTEText    = ""
local QTEEndsAt  = 0 -- fallback timeout

local function StartQTE(qteType, target, opts)
    QTEType, QTETarget, QTEActive = qteType, target, true
    QTEEndsAt = CurTime() + (opts and opts.duration or 2.0)

    if qteType == "vault" then
        QTEKey, QTEText = KEY_SPACE, "Press SPACE to Vault"
        -- If you want a vault event camera immediately:
        Camera.SetCameraState("event", "vault", {
            duration      = opts and opts.duration or 0.8,
            blockMovement = false
        })
    elseif qteType == "melee" then
        QTEKey, QTEText = KEY_E, "Press E to Melee"
        -- IMPORTANT: do NOT start camera here – wait for key press
    else
        QTEKey, QTEText = KEY_SPACE, ""
    end
end

-- Draw prompt
hook.Add("HUDPaint", "ERV_QTEPrompt", function()
    if QTEActive and QTEText ~= "" then
        draw.SimpleTextOutlined(
            QTEText, "DermaLarge",
            ScrW()/2, ScrH()*0.8,
            Color(255,255,255),
            TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER,
            2, Color(0,0,0,150)
        )
    end
end)

-- Handle QTE key press
hook.Add("Think", "ERV_QTEInput", function()
    if not QTEActive then return end
    if CurTime() > QTEEndsAt then
        QTEActive = false
        QTEType, QTETarget = nil, nil
        return
    end

    if input.IsKeyDown(QTEKey) then
        if QTEType == "vault" then
            chat.AddText(Color(0,255,0), "Vault sequence started! (placeholder)")

        elseif QTEType == "melee" and IsValid(QTETarget) then
            -- Start the melee event camera NOW (on press)
            local dur = 1.2
            Camera.SetCameraState("event", "melee", {
                duration      = dur,
                -- Camera sits to the player's left; switch lookAt to "player" to look back at player chest
                offset        = Vector(35, -45, 0), -- Forward, Right, Up in player yaw-space (negative Right = left)
                lookAt        = "player",           -- "target" to track NPC; use "player" to track player's chest
                trackTarget   = QTETarget,          -- entity to track when lookAt == "target"
                blockMovement = true,               -- freeze movement during the melee
                mouseScale    = 0.0,                -- freeze look
                lockPitch     = false
            })

            -- Tell server to apply damage AND lock movement there too
            net.Start("ERV_MeleeAttack")
                net.WriteEntity(QTETarget)
                net.WriteFloat(dur) -- send duration so server can lock movement
            net.SendToServer()
        end

        QTEActive, QTEType, QTETarget = false, nil, nil
    end
end)

-- RE5-style melee detection (aim + range, prompt only)
local meleeRange = 100
local validMeleeNPCs = { ["npc_citizen"]=true, ["npc_zombie"]=true }

hook.Add("Think", "ERV_CheckMeleeQTE", function()
    local ply = LocalPlayer()
    if not IsValid(ply) or not ply:Alive() then return end
    if QTEActive then return end -- don't overwrite another QTE

    local trace = util.TraceLine({
        start = ply:EyePos(),
        endpos = ply:EyePos() + ply:GetAimVector() * meleeRange,
        filter = ply
    })

    local ent = trace.Entity
    if IsValid(ent) and ent:IsNPC() and validMeleeNPCs[ent:GetClass()] then
        StartQTE("melee", ent, { duration = 5.0 }) -- prompt lifetime only
    end
end)

---------------------------------------------------------------------
-- ADS and fire control
---------------------------------------------------------------------
local IsWeaponReady = false
local NormalFOV, ZoomFOV, CurrentFOV
local camAng = Angle(0,0,0)
local minPitch, maxPitch = -35, 60

hook.Add("PlayerBindPress", "ERV_ADS_and_FireControl", function(ply, bind, pressed)
    -- Knife special handling is injected below; this block remains for general ADS
    if bind == "+attack2" then
        IsWeaponReady = pressed
        net.Start("ERV_ReadyWeapon")
            net.WriteBool(pressed)
        net.SendToServer()
        return true
    end
    if bind == "+attack" and not IsWeaponReady then
        return true
    end
end)

---------------------------------------------------------------------
-- Knife toggle (Q) + knife-ready movement lock + RMB to hold ready, release to switch back
---------------------------------------------------------------------
local lastNonKnifeClass = nil
local KnifeMovementLock = false

local function ERV_SetReady(state)
    local ply = LocalPlayer()
    IsWeaponReady = state and true or false
    if IsWeaponReady then
    end
    net.Start("ERV_ReadyWeapon")
        net.WriteBool(IsWeaponReady)
    net.SendToServer()
end

local function ERV_SwitchTo(classname)
    if not classname or classname == "" then return end
    RunConsoleCommand("use", classname)
end

local function ERV_SwitchToKnife()
    local ply = LocalPlayer()
    if not IsValid(ply) then return end
    local wep = ply:GetActiveWeapon()
    if IsValid(wep) and wep:GetClass() ~= "weapon_erv_knife" then
        lastNonKnifeClass = wep:GetClass()
    end
    ERV_SwitchTo("weapon_erv_knife")
    -- Lock movement and enter ready mode while knife is up
    KnifeMovementLock = true
    ERV_SetReady(true)
end

local function ERV_SwitchBackFromKnife()
    -- Unlock and exit ready
    KnifeMovementLock = false
    ERV_SetReady(false)
    if lastNonKnifeClass then
        ERV_SwitchTo(lastNonKnifeClass)
    end
end

-- Q to swap between current weapon and knife
hook.Add("Think", "ERV_KnifeSwap", function()
    local ply = LocalPlayer()
    if not IsValid(ply) or not ply:Alive() then return end

    if input.IsKeyDown(KEY_Q) then
        if not ply._ervKnifeSwapPressed then
            ply._ervKnifeSwapPressed = true
            local wep = ply:GetActiveWeapon()
            if IsValid(wep) and wep:GetClass() == "weapon_erv_knife" then
                ERV_SwitchBackFromKnife()
            else
                ERV_SwitchToKnife()
            end
        end
    else
        ply._ervKnifeSwapPressed = false
    end
end)

---------------------------------------------------------------------
-- Camera handling (CreateMove + CalcView)
---------------------------------------------------------------------
-- persisted between frames:
local SmoothedPitch        = 0
local PitchSmoothingSpeed  = 2     -- lower = more sluggish follow
local PitchRotationFactor  = 0.3   -- 1.0 = full rotation; 0.5 = half as much
local SwayStrength         = 0     -- dynamic sway amount

hook.Add("CreateMove", "ERV_ThirdPersonCamControl", function(cmd)
    local ply = LocalPlayer()
    if not IsValid(ply) then return end

    -- Event camera (movement/aim damp) handled centrally by camera module
    if Camera and Camera.ApplyEventMove and Camera.ApplyEventMove(cmd, camAng) then
        return
    end

    -- ADS/non-event logic
    if IsWeaponReady then
        camAng.y = camAng.y + cmd:GetMouseX() * 0.022
        camAng.p = math.Clamp(camAng.p - cmd:GetMouseY() * 0.022, minPitch, maxPitch)
    else
        camAng = cmd:GetViewAngles()
    end
end)

hook.Add("CalcView", "ERV_ThirdPersonView", function(ply, pos, angles, fov)
    if not ply:Alive() then return end

    -- initialize FOV once
    if not NormalFOV then
        NormalFOV  = 60
        ZoomFOV    = NormalFOV * 1.0
        CurrentFOV = NormalFOV
    end
    CurrentFOV = Lerp(FrameTime() * 30, CurrentFOV, IsWeaponReady and ZoomFOV or NormalFOV)

    -- 1) smooth your real pitch...
    SmoothedPitch = Lerp(FrameTime() * PitchSmoothingSpeed, SmoothedPitch, angles.p)
    -- 2) then scale it down for the camera
    local CameraPitch = SmoothedPitch * PitchRotationFactor

    -- build yaw-based offsets
    local yawAng        = Angle(0, angles.y, 0)
    local distBehind    = IsWeaponReady and 50 or 55
    local forwardOffset = yawAng:Forward() * -distBehind
    local rightOffset   = yawAng:Right()   * -25

    -- vertical slide (also driven by the scaled pitch)
    local baseHeight    = -5
    local pitchNorm     = math.Clamp(CameraPitch / 35, -1, 1)
    local verticalSlide = pitchNorm * 5
    local upOffset      = Vector(0, 0, baseHeight + verticalSlide)

    -- sway (only when moving and not aiming), driven by bone position
    local velocity2D = ply:GetVelocity():Length2D()
    local isMoving   = velocity2D > 10 and not IsWeaponReady
    SwayStrength     = Lerp(FrameTime() * 5, SwayStrength, isMoving and 1 or 0)

    local swayOffset = Vector(0,0,0)
    if SwayStrength > 0 then
        local boneIndex = ply:LookupBone("ValveBiped.Bip01_Pelvis")
        if boneIndex then
            local bonePos    = ply:GetBonePosition(boneIndex)
            local localOffset= (bonePos - ply:GetPos())
            swayOffset       = Vector(localOffset.x, localOffset.y, 0) * 0.05 * SwayStrength
        end
    end

    -- Let the camera module override view for active events (tracks target or player's chest)
    if Camera and Camera.ApplyEventView then
        local v = Camera.ApplyEventView(ply, pos, CurrentFOV ~= nil and angles or angles, CurrentFOV or fov, yawAng, CameraPitch)
        if v then return v end
    end

    return {
        origin     = pos + forwardOffset + rightOffset + upOffset + swayOffset,
        angles     = Angle(CameraPitch, angles.y, angles.r),
        fov        = CurrentFOV or fov,
        drawviewer = true
    }
end)
