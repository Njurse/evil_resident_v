-- erv_hud.lua
-- Client-side HUD: circular health display for Evil Resident V

print("[ERV HUD] Module Loaded")

if CLIENT then
    -- Hide default HUD elements
    hook.Add("HUDShouldDraw", "ERV_HideDefaultHUD", function(name)
        if name == "CHudHealth" or name == "CHudBattery" or name == "CHudAmmo" or name == "CHudSecondaryAmmo" or name == "CHudCrosshair" then
            return false
        end
    end)

    -- Draw circular health
    hook.Add("HUDPaint", "ERV_DrawCircularHealth", function()
        local ply = LocalPlayer()
        if not IsValid(ply) then return end

        -- Health ratio
        local hp = ply:Health()
        local maxhp = ply:GetMaxHealth() or 100
        local ratio = math.Clamp(hp / maxhp, 0, 1)

        -- Angles (start at 90°, end at 360°)
        local startAng = math.rad(90)
        local endAng = startAng + math.rad(270) * ratio

        -- Position and style
        local w, h = ScrW(), ScrH()
        local centerX, centerY = w * 0.5, h - 100
        local radius = 50
        local segments = 60

        -- Draw background arc (full 270° range)
        surface.SetDrawColor(50, 50, 50, 150)
        for i = 0, segments - 1 do
            local angle1 = startAng + (math.rad(270) / segments) * i
            local angle2 = startAng + (math.rad(270) / segments) * (i + 1)
            local x1 = centerX + math.cos(angle1) * radius
            local y1 = centerY + math.sin(angle1) * radius
            local x2 = centerX + math.cos(angle2) * radius
            local y2 = centerY + math.sin(angle2) * radius
            surface.DrawLine(x1, y1, x2, y2)
        end

        -- Draw health arc
        surface.SetDrawColor(255, 50, 50, 200)
        for i = 0, math.floor(segments * ratio) - 1 do
            local angle1 = startAng + (math.rad(270) / segments) * i
            local angle2 = startAng + (math.rad(270) / segments) * (i + 1)
            local x1 = centerX + math.cos(angle1) * radius
            local y1 = centerY + math.sin(angle1) * radius
            local x2 = centerX + math.cos(angle2) * radius
            local y2 = centerY + math.sin(angle2) * radius
            surface.DrawLine(x1, y1, x2, y2)
        end

        -- Draw health percentage text
        draw.SimpleText(math.floor(ratio * 100) .. "%", "DermaLarge", centerX, centerY, Color(255, 255, 255), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    end)
end
