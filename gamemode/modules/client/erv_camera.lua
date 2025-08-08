-- modules/client/erv_camera.lua
-- Centralized camera state + event camera logic (CalcView/CreateMove helpers)

local CameraState = "default"
local EventType = nil

-- Event-specific camera settings (defaults; can be overridden per-SetCameraState)
-- Offsets are in PLAYER YAW-SPACE: Forward*x + Right*y + Up*z
local EventCameraConfigs = {
    melee = {
        offset        = Vector(35, -45, 0), -- left shoulder: negative Right = left (we use player yaw-space)
        fov           = 78,
        lockPitch     = false,
        mouseScale    = 0.0, -- freeze look
        blockMovement = true,
        duration      = 1.2,
        lookAt        = "target",  -- "player" or "target"
        trackTarget   = nil        -- set to an entity to track for "target" mode
    },
    vault = {
        offset        = Vector(-20, -25, 18),
        fov           = 82,
        lockPitch     = false,
        mouseScale    = 0.2,
        blockMovement = false,
        duration      = 0.8,
        lookAt        = "player",
        trackTarget   = nil
    }
}

-- Utility: shallow-merge table src into dst
local function shallow_merge(dst, src)
    if not istable(dst) or not istable(src) then return end
    for k, v in pairs(src) do dst[k] = v end
end

-- Utility: best-effort chest position for an entity
local ChestBones = {
    "ValveBiped.Bip01_Spine2",
    "ValveBiped.Bip01_Spine4",
    "ValveBiped.Bip01_Spine1",
    "ValveBiped.Bip01_Spine"
}
local function GetChestPos(ent)
    if not IsValid(ent) then return nil end
    -- Prefer a spine bone if available
    if ent.LookupBone and ent.GetBonePosition then
        for _, bname in ipairs(ChestBones) do
            local idx = ent:LookupBone(bname)
            if idx then
                local pos = ent:GetBonePosition(idx)
                if pos then return pos end
            end
        end
    end
    -- Fallbacks
    if ent:IsPlayer() then
        -- approximate chest as base pos + ~56-64 up
        return ent:GetPos() + Vector(0, 0, 60)
    end
    -- For generic entities/NPCs
    return ent.WorldSpaceCenter and ent:WorldSpaceCenter() or ent:GetPos()
end

-- State setters/getters
local function SetCameraState(state, eventType, opts)
    CameraState = state or "default"
    EventType   = eventType

    if CameraState == "event" and EventType and EventCameraConfigs[EventType] then
        local cfg = table.Copy(EventCameraConfigs[EventType])
        if istable(opts) then
            -- Back-compat: if opts.lookAtPlayer boolean is used, map it to lookAt
            if opts.lookAtPlayer ~= nil and opts.lookAt == nil then
                opts.lookAt = opts.lookAtPlayer and "player" or "target"
                opts.lookAtPlayer = nil
            end
            shallow_merge(cfg, opts)
        end
        -- Stash the active config on the module for easy retrieval
        CameraState = "event"
        EventCameraConfigs.__active = cfg
        cfg.endTime = CurTime() + (cfg.duration or 1.0)
    elseif CameraState ~= "event" then
        EventCameraConfigs.__active = nil
    end
end

local function GetCameraState()
    return CameraState, EventType
end

local function GetActiveEventConfig()
    local cfg = EventCameraConfigs.__active
    if CameraState ~= "event" or not cfg then return nil end
    if cfg.endTime and CurTime() > cfg.endTime then
        -- auto reset
        EventCameraConfigs.__active = nil
        CameraState, EventType = "default", nil
        return nil
    end
    return cfg
end

-- Apply to CreateMove: handles input dampening + optional movement block
-- camAng is a mutable Angle you manage in cl_init (your existing variable)
local function ApplyEventMove(cmd, camAng)
    local cfg = GetActiveEventConfig()
    if not cfg then return false end

    if cfg.blockMovement then
        cmd:ClearMovement()
    end

    local ms = cfg.mouseScale or 0.0
    camAng.y = camAng.y + cmd:GetMouseX() * ms
    camAng.p = camAng.p - cmd:GetMouseY() * ms
    if cfg.lockPitch then camAng.p = 0 end
    cmd:SetViewAngles(camAng)

    return true -- handled
end

-- Apply to CalcView: returns a view table override or nil
-- Requires: player, pos, angles, fov, computed yawAng (Angle(0, angles.y, 0)), and a CameraPitch if you want fallback forward
local function ApplyEventView(ply, pos, angles, fov, yawAng, cameraPitch)
    local cfg = GetActiveEventConfig()
    if not cfg then return nil end

    local CurrentFOV = fov
    if cfg.fov then
        CurrentFOV = Lerp(FrameTime() * 20, fov, cfg.fov)
    end

    -- Compute camera origin in player yaw-space using offset
    local baseOrigin = ply:GetPos() + Vector(0, 0, 30) -- base at torso height
    local origin = baseOrigin
    if cfg.offset then
        origin = baseOrigin
            + yawAng:Forward() * cfg.offset.x
            + yawAng:Right()   * cfg.offset.y
            + Vector(0, 0, cfg.offset.z)
    end

    -- Compute what to look at
    local viewAngles
    local lookMode = cfg.lookAt or "player"
    if lookMode == "target" and IsValid(cfg.trackTarget) then
        local tpos = GetChestPos(cfg.trackTarget) or cfg.trackTarget:GetPos()
        viewAngles = (tpos - origin):Angle()
    elseif lookMode == "player" then
        local ppos = GetChestPos(ply) or ply:EyePos() -- chest instead of EyePos
        viewAngles = (ppos - origin):Angle()
    else
        -- Fallback: keep forward-ish
        viewAngles = Angle(cameraPitch or angles.p, angles.y, angles.r)
    end

    return {
        origin     = origin,
        angles     = viewAngles,
        fov        = CurrentFOV,
        drawviewer = true
    }
end

return {
    SetCameraState      = SetCameraState,
    GetCameraState      = GetCameraState,
    GetActiveEventConfig= GetActiveEventConfig,
    ApplyEventMove      = ApplyEventMove,
    ApplyEventView      = ApplyEventView,
    GetChestPos         = GetChestPos
}
