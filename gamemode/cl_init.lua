-- Make sure clients download our HUD & laser modules
AddCSLuaFile("modules/client/erv_hud.lua")
AddCSLuaFile("modules/client/erv_laser.lua")

include("shared.lua")
include("modules/client/erv_hud.lua")
include("modules/client/erv_laser.lua")

weapons.Register(include("entities/weapons/weapon_erv_pistol.lua"), "weapon_erv_pistol")

-- Hide the first-person viewmodel
hook.Add("InitPostEntity", "ERV_HideViewModels", function()
    RunConsoleCommand("r_drawviewmodel", "0")
end)

-- Ensure local player model is drawn
hook.Add("ShouldDrawLocalPlayer", "ERV_DrawLocalPlayer", function()
    return true
end)

-- QTE unified system (clientside only)
local QTEActive = false
local QTEType = nil
local QTETarget = nil
local QTEKey = KEY_SPACE
local QTEText = ""

local function StartQTE(qteType, target)
    QTEType = qteType
    QTETarget = target
    QTEActive = true

    if qteType == "vault" then
        QTEKey = KEY_SPACE
        QTEText = "Press SPACE to Vault"
    elseif qteType == "melee" then
        QTEKey = KEY_E
        QTEText = "Press E to Melee"
    else
        QTEKey = KEY_SPACE
        QTEText = ""
    end
end

hook.Add("HUDPaint", "ERV_QTEPrompt", function()
    if QTEActive and QTEText ~= "" then
        draw.SimpleTextOutlined(
            QTEText,
            "DermaLarge",
            ScrW()/2,
            ScrH()*0.8,
            Color(255,255,255),
            TEXT_ALIGN_CENTER,
            TEXT_ALIGN_CENTER,
            2,
            Color(0,0,0,150)
        )
    end
end)

hook.Add("Think", "ERV_QTEInput", function()
    if QTEActive and input.IsKeyDown(QTEKey) then
        if QTEType == "vault" then
            chat.AddText(Color(0,255,0), "Vault sequence started! (placeholder)")
        elseif QTEType == "melee" and IsValid(QTETarget) then
            net.Start("ERV_MeleeAttack")
            net.WriteEntity(QTETarget)
            net.SendToServer()
        end
        QTEActive = false
        QTEType = nil
        QTETarget = nil
    end
end)

-- Client-side melee detection for RE5-style prompt
local meleeRange = 100
local validMeleeNPCs = {
    ["npc_citizen"] = true,
    ["npc_zombie"] = true
}

hook.Add("Think", "ERV_CheckMeleeQTE", function()
    local ply = LocalPlayer()
    if not IsValid(ply) or not ply:Alive() then return end
    if QTEActive then return end -- Don't overwrite another QTE

    local trace = util.TraceLine({
        start = ply:EyePos(),
        endpos = ply:EyePos() + ply:GetAimVector() * meleeRange,
        filter = ply
    })

    if IsValid(trace.Entity) and trace.Entity:IsNPC() and validMeleeNPCs[trace.Entity:GetClass()] then
        StartQTE("melee", trace.Entity)
    end
end)

-- ADS and fire control
local IsWeaponReady = false
local NormalFOV, ZoomFOV, CurrentFOV
local camAng = Angle(0,0,0)
local minPitch, maxPitch = -65, 65

hook.Add("PlayerBindPress", "ERV_ADS_and_FireControl", function(ply, bind, pressed)
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

hook.Add("CreateMove", "ERV_ThirdPersonCamControl", function(cmd)
    local ply = LocalPlayer()
    if not IsValid(ply) then return end

    if IsWeaponReady then
        -- Custom camera rotation while aiming
        camAng.y = camAng.y + cmd:GetMouseX() * 0.022
        camAng.p = math.Clamp(camAng.p - cmd:GetMouseY() * 0.022, minPitch, maxPitch)
    else
        -- Reset camAng when not aiming to stay in sync
        camAng = cmd:GetViewAngles()
    end
end)

-- persisted between frames:
local SmoothedPitch        = 0
local PitchSmoothingSpeed  = 3     -- lower = more sluggish follow
local PitchRotationFactor  = 0.5   -- 1.0 = full rotation; 0.5 = half as much
local SwayStrength         = 0     -- dynamic sway amount

hook.Add("CalcView", "ERV_ThirdPersonView", function(ply, pos, angles, fov)
    if not ply:Alive() then return end

    -- initialize FOV once
    if not NormalFOV then
        NormalFOV  = 70
        ZoomFOV    = NormalFOV * 0.95
        CurrentFOV = NormalFOV
    end
    CurrentFOV = Lerp(FrameTime() * 30, CurrentFOV, IsWeaponReady and ZoomFOV or NormalFOV)

    -- 1) smooth your real pitch...
    SmoothedPitch = Lerp(FrameTime() * PitchSmoothingSpeed, SmoothedPitch, angles.p)
    -- 2) then scale it down for the camera
    local CameraPitch = SmoothedPitch * PitchRotationFactor

    -- build yaw-based offsets
    local yawAng       = Angle(0, angles.y, 0)
    local distBehind   = IsWeaponReady and 35 or 55
    local forwardOffset = yawAng:Forward() * -distBehind
    local rightOffset   = yawAng:Right()   * -25

    -- vertical slide (also driven by the scaled pitch)
    local baseHeight   = -5
    local pitchNorm    = math.Clamp(CameraPitch / 35, -1, 1)
    local verticalSlide= pitchNorm * 5
    local upOffset     = Vector(0, 0, baseHeight + verticalSlide)

    -- sway (only when moving and not aiming), driven by bone position
    local velocity2D = ply:GetVelocity():Length2D()
    local isMoving = velocity2D > 10 and not IsWeaponReady
    SwayStrength = Lerp(FrameTime() * 5, SwayStrength, isMoving and 1 or 0)

    local swayOffset = Vector(0,0,0)
    if SwayStrength > 0 then
        local boneIndex = ply:LookupBone("ValveBiped.Bip01_Pelvis")
        if boneIndex then
            local bonePos = ply:GetBonePosition(boneIndex)
            local localOffset = bonePos - ply:GetPos()
            swayOffset = Vector(localOffset.x, localOffset.y, 0) * 0.05 * SwayStrength
        end
    end

    return {
        origin     = pos + forwardOffset + rightOffset + upOffset + swayOffset,
        angles     = Angle(CameraPitch, angles.y, angles.r),
        fov        = CurrentFOV,
        drawviewer = true
    }
end)
