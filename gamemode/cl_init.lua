-- cl_init.lua (client)
include("shared.lua")

local QTEActive = false

-- Receive trigger zone activation
net.Receive("ERV_QTEStart", function()
    QTEActive = true
end)

-- Draw QTE HUD
hook.Add("HUDPaint", "ERV_QTEPrompt", function()
    if QTEActive then
        draw.SimpleText("Press SPACE to vault", "DermaLarge", ScrW()/2, ScrH()*0.8, Color(255,255,255), TEXT_ALIGN_CENTER)
    end
end)

-- Listen for space press to simulate vault
hook.Add("Think", "ERV_QTEInput", function()
    if QTEActive and input.IsKeyDown(KEY_SPACE) then
        QTEActive = false
        chat.AddText(Color(0,255,0), "Vault sequence started! (placeholder)")
    end
end)

-- Third-person camera with sway
hook.Add("CalcView", "ERV_ThirdPersonView", function(ply, pos, angles, fov)
    if not ply:Alive() then return end

    local view = {}
    local rightOffset = angles:Right() * 100
    local upOffset = Vector(0, 0, 50)
    local sway = Vector(
        math.sin(CurTime() * 5) * (ply:GetVelocity():Length() / 600),
        math.sin(CurTime() * 3) * (ply:GetVelocity():Length() / 600),
        0
    )
    view.origin = pos + rightOffset + upOffset + sway
    view.angles = angles
    view.fov = fov
    return view
end)
