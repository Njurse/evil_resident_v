-- erv_laser.lua
-- Client-side laser sight module for Evil Resident V

print("[ERV Laser] Module Loaded")

if CLIENT then
    local laserColor = Color(255, 0, 0, 255)
    local beamMat = Material("cable/physbeam")

    hook.Add("PostDrawTranslucentRenderables", "ERV_DrawLaser", function()
        local ply = LocalPlayer()
        if not IsValid(ply) or not ply:Alive() then return end
        local wep = ply:GetActiveWeapon()
        if not IsValid(wep) then return end

        -- Try to find the muzzle attachment
        local attachID = wep:LookupAttachment("muzzle") or wep:LookupAttachment("1") or 1
        local attach = wep:GetAttachment(attachID)
        if not attach then return end

        local startPos = attach.Pos
        local shootDir = attach.Ang:Forward()
        local targetPos = startPos + shootDir * 2048

        -- Trace to world
        local tr = util.TraceLine({
            start = startPos,
            endpos = targetPos,
            filter = {ply, wep},
            mask = MASK_SHOT_HULL
        })
        targetPos = tr.HitPos

        -- Draw the beam
        render.SetMaterial(beamMat)
        render.StartBeam(2)
            render.AddBeam(startPos, 1, 0, laserColor)
            render.AddBeam(targetPos, 1, 1, laserColor)
        render.EndBeam()
    end)
end
