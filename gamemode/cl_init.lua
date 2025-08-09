-- cl_init.lua (client central)
-- NOTE: This is the central client file that stitches together HUD/Laser/Camera
-- and delegates movement and QTE logic to separate modules.

include("shared.lua")

-- Optional: these AddCSLuaFile calls only take effect serverside, but harmless here.
AddCSLuaFile("modules/client/erv_hud.lua")
AddCSLuaFile("modules/client/erv_laser.lua")
AddCSLuaFile("modules/client/erv_camera.lua")
AddCSLuaFile("modules/client/erv_movement.lua")
AddCSLuaFile("modules/client/erv_qte.lua")

-- Include visual modules
include("modules/client/erv_hud.lua")
include("modules/client/erv_laser.lua")

-- Camera is used by movement and QTE modules; keep it global so they can see it.
Camera = include("modules/client/erv_camera.lua")

-- (Client-side weapon registration is fine; server also registers)
-- If you don't want client-side registration, remove these two lines.
weapons.Register(include("entities/weapons/weapon_erv_pistol.lua"), "weapon_erv_pistol")
weapons.Register(include("entities/weapons/weapon_erv_knife.lua"),  "weapon_erv_knife")

-- Basic client setup
hook.Add("InitPostEntity", "ERV_HideViewModels", function()
    RunConsoleCommand("r_drawviewmodel", "0")
end)

hook.Add("ShouldDrawLocalPlayer", "ERV_DrawLocalPlayer", function()
    return true
end)

-- Include separated logic modules
include("modules/client/erv_movement.lua")
include("modules/client/erv_qte.lua")

---------------------------------------------------------------------
-- Lightweight debug HUD for state inspection
---------------------------------------------------------------------
CreateClientConVar("erv_debug_states", "1", true, false, "Show ERV debug state HUD")

surface.CreateFont("ERV_DebugFont", {
    font = "Tahoma",
    size = 16,
    weight = 600,
    antialias = true,
})

local function boolText(b) return b and "TRUE" or "FALSE" end

hook.Add("HUDPaint", "ERV_DrawPlayerStateDebug", function()
    if not GetConVar("erv_debug_states"):GetBool() then return end

    local ply = LocalPlayer()
    if not IsValid(ply) then return end

    local weaponReady   = ply:GetNWBool("erv_ready", ply.ERV_WeaponReady or false)
    local inQTE         = ply:GetNWBool("erv_in_qte",  ply.ERV_InQTE or false)
    local meleeActive   = ply:GetNWBool("ERV_MeleeAttack", false)

    local wep     = ply:GetActiveWeapon()
    local wepName = IsValid(wep) and (wep.PrintName or wep:GetClass()) or "None"

    local lines = {
        {"Weapon Type",      wepName},
        {"ERV Weapon Ready", boolText(weaponReady)},
        {"ERV In QTE",       boolText(inQTE)},
        {"ERV MeleeAttack",  boolText(meleeActive)},
    }

    local x, y = 18, 120
    local w = 320
    local h = (#lines * 22) + 16
    draw.RoundedBox(8, x - 8, y - 10, w, h, Color(0, 0, 0, 140))

    surface.SetFont("ERV_DebugFont")
    local labelColor = Color(200, 200, 200)
    local valueColor = Color(255, 255, 255)

    for _, kv in ipairs(lines) do
        local label, value = kv[1], kv[2]
        draw.SimpleTextOutlined(label .. ":", "ERV_DebugFont", x, y, labelColor, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP, 1, Color(0,0,0,220))
        draw.SimpleTextOutlined(value,       "ERV_DebugFont", x + 180, y, valueColor, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP, 1, Color(0,0,0,220))
        y = y + 22
    end
end)
