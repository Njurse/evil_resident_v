-- modules/client/erv_qte.lua
-- Handles QTE prompts, input, melee trigger & detection

-- QTE state
local QTEActive  = false
local QTEType    = nil
local QTETarget  = nil
local QTEKey     = KEY_SPACE
local QTEText    = ""
local QTEEndsAt  = 0

local function StartQTE(qteType, target, opts)
    QTEType, QTETarget, QTEActive = qteType, target, true
    QTEEndsAt = CurTime() + (opts and opts.duration or 2.0)

    if qteType == "vault" then
        QTEKey, QTEText = KEY_SPACE, "Press SPACE to Vault"
        -- Optional: kick off an event cam for vaults
        if Camera and Camera.SetCameraState then
            Camera.SetCameraState("event", "vault", {
                duration      = opts and opts.duration or 0.8,
                blockMovement = false
            })
        end
    elseif qteType == "melee" then
        QTEKey, QTEText = KEY_E, "Press E to Melee"
    else
        QTEKey, QTEText = KEY_SPACE, ""
    end
end

-- Visual prompt
hook.Add("HUDPaint", "ERV_QTEPrompt", function()
    if QTEActive and QTEText ~= "" then
        draw.SimpleTextOutlined(
            QTEText, "DermaLarge",
            ScrW()/2, ScrH()*0.8,
            Color(255,255,255),
            TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER,
            2, Color(0,0,0,150)
        )
    end
end)

-- QTE input
hook.Add("Think", "ERV_QTEInput", function()
    if not QTEActive then return end
    if CurTime() > QTEEndsAt then
        QTEActive = false
        QTEType, QTETarget = nil, nil
        return
    end

    if input.IsKeyDown(QTEKey) then
        if QTEType == "vault" then
            chat.AddText(Color(0,255,0), "Vault sequence started! (placeholder)")

        elseif QTEType == "melee" and IsValid(QTETarget) then
            local dur = 1.2

            -- Event camera focused on player or target
            if Camera and Camera.SetCameraState then
                Camera.SetCameraState("event", "melee", {
                    duration      = dur,
                    offset        = Vector(35, -45, 0),
                    lookAt        = "player",  -- "target" to track NPC
                    trackTarget   = QTETarget,
                    blockMovement = true,
                    mouseScale    = 0.0,
                    lockPitch     = false
                })
            end

            -- Notify server
            net.Start("ERV_MeleeAttack")
                net.WriteEntity(QTETarget)
                net.WriteFloat(dur)
            net.SendToServer()
        end

        QTEActive, QTEType, QTETarget = false, nil, nil
    end
end)

-- Simple forward-trace detection for melee QTE prompt
local meleeRange = 100
local validMeleeNPCs = {
    ["npc_citizen"] = true,
    ["npc_zombie"]  = true
}

hook.Add("Think", "ERV_CheckMeleeQTE", function()
    if QTEActive then return end

    local ply = LocalPlayer()
    if not IsValid(ply) or not ply:Alive() then return end

    local trace = util.TraceLine({
        start = ply:EyePos(),
        endpos = ply:EyePos() + ply:GetAimVector() * meleeRange,
        filter = ply
    })

    local ent = trace.Entity
    if IsValid(ent) and ent:IsNPC() and validMeleeNPCs[ent:GetClass()] then
        StartQTE("melee", ent, { duration = 2.0 })
    end
end)
