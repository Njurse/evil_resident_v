-- init.lua for erv_trigger_zone (server)
include("shared.lua")

function ENT:StartTouch(ent)
    if ent:IsPlayer() then
        net.Start("ERV_QTEStart")
        net.Send(ent)
    end
end
