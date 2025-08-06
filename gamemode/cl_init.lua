-- Make sure clients download our HUD & laser modules
AddCSLuaFile("modules/client/erv_hud.lua")
AddCSLuaFile("modules/client/erv_laser.lua")

-- Then run them on the client
include("modules/client/erv_hud.lua")
include("modules/client/erv_laser.lua")

include("shared.lua")



-- Hide the first-person viewmodel
hook.Add("InitPostEntity", "ERV_HideViewModels", function()
    RunConsoleCommand("r_drawviewmodel", "0")
end)

-- Ensure local player model is drawn
hook.Add("ShouldDrawLocalPlayer", "ERV_DrawLocalPlayer", function()
    return true
end)

-- QTE prompts
local QTEActive = false
net.Receive("ERV_QTEStart", function() QTEActive = true end)

hook.Add("HUDPaint", "ERV_QTEPrompt", function()
    if QTEActive then
        draw.SimpleText("Press SPACE to vault", "DermaLarge", ScrW()/2, ScrH()*0.8, Color(255,255,255), TEXT_ALIGN_CENTER)
    end
end)

hook.Add("Think", "ERV_QTEInput", function()
    if QTEActive and input.IsKeyDown(KEY_SPACE) then
        QTEActive = false
        chat.AddText(Color(0,255,0), "Vault sequence started! (placeholder)")
    end
end)

-- ADS and fire control
local IsWeaponReady = false
local NormalFOV, ZoomFOV, CurrentFOV
local camAng = Angle(0,0,0)
local minPitch, maxPitch = -25, 25

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
        camAng.y = camAng.y + cmd:GetMouseX() * 0.022
        camAng.p = math.Clamp(camAng.p - cmd:GetMouseY() * 0.022, minPitch, maxPitch)
        cmd:SetViewAngles(camAng)
    else
        camAng = cmd:GetViewAngles()
    end
end)

-- Third-person camera → horizontal orbit + reduced vertical slide
hook.Add("CalcView", "ERV_ThirdPersonView", function(ply, pos, angles, fov)
    if not ply:Alive() then return end

    if not NormalFOV then
        NormalFOV  = 70
        ZoomFOV    = NormalFOV * 0.9
        CurrentFOV = NormalFOV
    end
    CurrentFOV = Lerp(FrameTime() * 10, CurrentFOV, IsWeaponReady and ZoomFOV or NormalFOV)

    local yawAng = Angle(0, angles.y, 0)
    local distBehind = IsWeaponReady and 15 or 55
    local forwardOffset = yawAng:Forward() * -distBehind
    local rightOffset = yawAng:Right() * -25

    local baseHeight = -5
    local pitchNorm = math.Clamp(angles.p / 25, -1, 1)
    local verticalSlide = pitchNorm * 5

    local upOffset = Vector(0, 0, baseHeight + verticalSlide)

    local speedFactor = ply:GetVelocity():Length() / 600
    local sway = Vector(
        math.sin(CurTime() * 15) * speedFactor,
        math.sin(CurTime() * 13) * speedFactor,
        0
    )

    return {
        origin     = pos + forwardOffset + rightOffset + upOffset + sway,
        angles     = angles,
        fov        = CurrentFOV,
        drawviewer = true
    }
end)
