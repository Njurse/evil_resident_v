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

        -- Skip drawing if hold type is normal, knife, or passive
        local holdType = wep:GetHoldType()
        if holdType == "normal" or holdType == "knife" or holdType == "passive" then
            return
        end

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
            endpos = eyePos + aimDir * 8192,
            filter = ply
        })

        render.SetMaterial(beamMat)
        render.DrawBeam(startPos, trace.HitPos, 5.5, 0, 1, laserColor)
    end)
end
