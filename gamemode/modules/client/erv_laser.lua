-- erv_laser.lua
-- Client-side laser sight module for Evil Resident V

print("[ERV Laser] Module Loaded")

if CLIENT then
    local beamMat = Material("effects/laser1")
    local laserColor = Color(255, 0, 0, 255)
    hook.Add("PostDrawTranslucentRenderables", "ERV_DrawLaser", function()
        local ply = LocalPlayer()
        if not IsValid(ply) or not ply:Alive() then return end
        local wep = ply:GetActiveWeapon()
        if not IsValid(wep) then return end

        -- Get muzzle position
        local attachID = wep:LookupAttachment("muzzle") or wep:LookupAttachment("1") or 1
        local attach = wep:GetAttachment(attachID)
        if not attach then return end

        local startPos = attach.Pos

        -- Trace from camera (eye position) in view direction
        local eyePos = ply:EyePos()
        local aimDir = ply:EyeAngles():Forward()

        local trace = util.TraceLine({
            start = eyePos,
            endpos = eyePos + aimDir * 10000,
            filter = ply,
            mask = MASK_SHOT_HULL
        })

        local targetPos = trace.HitPos

        -- Draw laser from muzzle to aim point
        render.SetMaterial(beamMat)
        render.StartBeam(2)
            render.AddBeam(startPos, 1, 0, laserColor)
            render.AddBeam(targetPos, 1, 1, laserColor)
        render.EndBeam()
    end)

end
