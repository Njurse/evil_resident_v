-- erv_hud.lua
-- Client-side HUD: circular health display with start angle at 0°, shadow, weapon icon center

if CLIENT then
    print("[ERV HUD] Module with Start Angle 0° Loaded")

    -- Hide default HUD elements
    hook.Add("HUDShouldDraw", "ERV_HideDefaultHUD", function(name)
        if name == "CHudHealth" or name == "CHudBattery" or
           name == "CHudAmmo" or name == "CHudSecondaryAmmo" or
           name == "CHudCrosshair" then
            return false
        end
    end)

    -- Helper: draw an arc section as a quad
    local function DrawArcSection(cx, cy, r1, r2, ang1, ang2, col)
        local x1i, y1i = cx + math.cos(ang1) * r1, cy + math.sin(ang1) * r1
        local x1o, y1o = cx + math.cos(ang1) * r2, cy + math.sin(ang1) * r2
        local x2i, y2i = cx + math.cos(ang2) * r1, cy + math.sin(ang2) * r1
        local x2o, y2o = cx + math.cos(ang2) * r2, cy + math.sin(ang2) * r2
        surface.SetDrawColor(col)
        surface.DrawPoly({
            { x = x1i, y = y1i, u = 0, v = 0 },
            { x = x1o, y = y1o, u = 1, v = 0 },
            { x = x2o, y = y2o, u = 1, v = 1 },
            { x = x2i, y = y2i, u = 0, v = 1 },
        })
    end

    -- Draw enhanced circular health
    hook.Add("HUDPaint", "ERV_DrawCircularHealth", function()
        local ply = LocalPlayer()
        if not IsValid(ply) then return end

        -- Health ratio
        local hp = math.Clamp(ply:Health(), 0, ply:GetMaxHealth() or 100)
        local maxhp = ply:GetMaxHealth() or 100
        local ratio = hp / maxhp

        -- Angles (start at 0°)
        local startAng = 0
        local arcRange = math.rad(270)

        -- Position and sizes
        local w, h = ScrW(), ScrH()
        local centerX, centerY = w * 0.15, h - 150
        local radius = 100
        local thickness = 20
        local segments = 60

        -- Shadow ring
        for i = 0, segments - 1 do
            local ang1 = startAng + (arcRange / segments) * i
            local ang2 = startAng + (arcRange / segments) * (i + 1)
            DrawArcSection(centerX, centerY, radius + 5, radius + thickness + 5, ang1, ang2, Color(0, 0, 0, 180))
        end

        -- Background ring
        for i = 0, segments - 1 do
            local ang1 = startAng + (arcRange / segments) * i
            local ang2 = startAng + (arcRange / segments) * (i + 1)
            DrawArcSection(centerX, centerY, radius, radius + thickness, ang1, ang2, Color(50, 50, 50, 150))
        end

        -- Health ring
        for i = 0, math.floor(segments * ratio) - 1 do
            local ang1 = startAng + (arcRange / segments) * i
            local ang2 = startAng + (arcRange / segments) * (i + 1)
            DrawArcSection(centerX, centerY, radius, radius + thickness, ang1, ang2, Color(255, 50, 50, 200))
        end

        -- Draw weapon name/icon in center
        local wep = ply:GetActiveWeapon()
        local iconText = ""
        if IsValid(wep) then
            iconText = wep:GetPrintName() or wep.PrintName or ""
        end
        draw.SimpleText(iconText, "DermaLarge", centerX, centerY,
                       Color(255, 255, 255), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    end)
end
