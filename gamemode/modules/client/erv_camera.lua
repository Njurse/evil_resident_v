
-- modules/client/erv_camera.lua
local IsWeaponReady = false
local camAng = Angle(0, 0, 0)
local minPitch, maxPitch = -65, 65

local CameraState = "default"

local function SetCameraState(state)
    CameraState = state
end

local function GetCameraState()
    return CameraState
end

hook.Add("CreateMove", "ERV_ThirdPersonCamControl", function(cmd)
    local ply = LocalPlayer()
    if not IsValid(ply) then return end

    if CameraState == "ads" then
        camAng.y = camAng.y + cmd:GetMouseX() * 0.022
        camAng.p = math.Clamp(camAng.p + cmd:GetMouseY() * 0.022, minPitch, maxPitch)
        cmd:SetViewAngles(camAng)
    else
        camAng = cmd:GetViewAngles()
    end

    local viewOrigin = ply:GetPos() + Vector(0, 0, 64)
    local yawAng = Angle(0, camAng.y, 0)
    local distBehind = CameraState == "ads" and 35 or 55
    local camOffset = yawAng:Forward() * -distBehind + yawAng:Right() * -25
    local camPos = viewOrigin + camOffset

    local trace = util.TraceLine({
        start = camPos,
        endpos = camPos + camAng:Forward() * 10000,
        filter = ply
    })

    local targetYaw = (trace.HitPos - ply:GetPos()):Angle().y
    local fixedAngle = Angle(0, targetYaw, 0)
    ply:SetEyeAngles(fixedAngle)
end)

return {
    SetCameraState = SetCameraState,
    GetCameraState = GetCameraState
}
