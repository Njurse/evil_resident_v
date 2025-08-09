-- modules/client/erv_movement.lua
-- Handles ADS/Fire control, knife swapping/locks, and third-person camera movement

-- Shared state
IsWeaponReady = IsWeaponReady or false
camAng        = camAng or Angle(0,0,0)

local minPitch, maxPitch = -35, 60

-- Ready state helper (also informs server)
function ERV_SetReady(state)
    local ply = LocalPlayer()
    IsWeaponReady = state and true or false
    net.Start("ERV_ReadyWeapon")
        net.WriteBool(IsWeaponReady)
    net.SendToServer()
end

-- Weapon switching helpers
local function ERV_SwitchTo(classname)
    if not classname or classname == "" then return end
    RunConsoleCommand("use", classname)
end

local lastNonKnifeClass = nil
local KnifeMovementLock = false

local function ERV_SwitchToKnife()
    local ply = LocalPlayer()
    if not IsValid(ply) then return end
    local wep = ply:GetActiveWeapon()
    if IsValid(wep) and wep:GetClass() ~= "weapon_erv_knife" then
        lastNonKnifeClass = wep:GetClass()
    end
    ERV_SwitchTo("weapon_erv_knife")
    KnifeMovementLock = true
    ERV_SetReady(true)
end

local function ERV_SwitchBackFromKnife()
    KnifeMovementLock = false
    ERV_SetReady(false)
    if lastNonKnifeClass then
        ERV_SwitchTo(lastNonKnifeClass)
    end
end

-- Bind handling: ADS on RMB, prevent fire when not ready
hook.Add("PlayerBindPress", "ERV_ADS_and_FireControl", function(ply, bind, pressed)
    if bind == "+attack2" then
        ERV_SetReady(pressed)
        return true
    end
    if bind == "+attack" and not IsWeaponReady then
        return true
    end
end)

-- Q to toggle knife
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
-- Third-person movement: CreateMove + CalcView
---------------------------------------------------------------------
local NormalFOV, ZoomFOV, CurrentFOV
local SmoothedPitch        = 0
local PitchSmoothingSpeed  = 2
local PitchRotationFactor  = 0.3
local SwayStrength         = 0

hook.Add("CreateMove", "ERV_ThirdPersonCamControl", function(cmd)
    local ply = LocalPlayer()
    if not IsValid(ply) then return end

    -- Event camera dampening (from Camera module)
    if Camera and Camera.ApplyEventMove and Camera.ApplyEventMove(cmd, camAng) then
        return
    end

    if IsWeaponReady then
        camAng.y = camAng.y + cmd:GetMouseX() * 0.022
        camAng.p = math.Clamp(camAng.p - cmd:GetMouseY() * 0.022, minPitch, maxPitch)
    else
        camAng = cmd:GetViewAngles()
    end
end)

hook.Add("CalcView", "ERV_ThirdPersonView", function(ply, pos, angles, fov)
    if not ply:Alive() then return end

    if not NormalFOV then
        NormalFOV  = 60
        ZoomFOV    = NormalFOV * 1.0
        CurrentFOV = NormalFOV
    end
    CurrentFOV = Lerp(FrameTime() * 30, CurrentFOV, IsWeaponReady and ZoomFOV or NormalFOV)

    -- Smooth/scale pitch
    SmoothedPitch = Lerp(FrameTime() * PitchSmoothingSpeed, SmoothedPitch, angles.p)
    local CameraPitch = SmoothedPitch * PitchRotationFactor

    local yawAng        = Angle(0, angles.y, 0)
    local distBehind    = IsWeaponReady and 50 or 55
    local forwardOffset = yawAng:Forward() * -distBehind
    local rightOffset   = yawAng:Right()   * -25

    local baseHeight    = -5
    local pitchNorm     = math.Clamp(CameraPitch / 35, -1, 1)
    local verticalSlide = pitchNorm * 5
    local upOffset      = Vector(0, 0, baseHeight + verticalSlide)

    -- Simple sway when walking and not aiming
    local velocity2D = ply:GetVelocity():Length2D()
    local isMoving   = velocity2D > 10 and not IsWeaponReady
    SwayStrength     = Lerp(FrameTime() * 5, SwayStrength, isMoving and 1 or 0)

    local swayOffset = vector_origin
    if SwayStrength > 0 then
        local boneIndex = ply:LookupBone("ValveBiped.Bip01_Pelvis")
        if boneIndex then
            local bonePos    = ply:GetBonePosition(boneIndex)
            local localOffset= (bonePos - ply:GetPos())
            swayOffset       = Vector(localOffset.x, localOffset.y, 0) * 0.05 * SwayStrength
        end
    end

    -- Let event camera override
    if Camera and Camera.ApplyEventView then
        local v = Camera.ApplyEventView(ply, pos, angles, CurrentFOV or fov, yawAng, CameraPitch)
        if v then return v end
    end

    return {
        origin     = pos + forwardOffset + rightOffset + upOffset + swayOffset,
        angles     = Angle(CameraPitch, angles.y, angles.r),
        fov        = CurrentFOV or fov,
        drawviewer = true
    }
end)
