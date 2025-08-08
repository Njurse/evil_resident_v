AddCSLuaFile()

local SWEP = {}

SWEP.PrintName      = "ERV Knife"
SWEP.Author         = "Nattdy"
SWEP.Instructions   = "Light slash (LMB). Heavy stab (RMB)."

SWEP.Spawnable      = true
SWEP.AdminOnly      = false
SWEP.NoLaser        = true                 -- hide laser for this weapon
SWEP.Base           = "weapon_base"
SWEP.Category       = "Evil Resident V"

SWEP.UseHands       = true
SWEP.ViewModel      = "models/weapons/c_knife_t.mdl"
SWEP.WorldModel     = "models/weapons/w_knife_t.mdl"
SWEP.ViewModelFOV   = 54

SWEP.HoldType       = "knife"

-- Melee timings & ranges
SWEP.Primary = {
    Automatic   = false,
    Delay       = 0.35,
    Damage      = 28,
    Range       = 64,      -- trace length
    Hull        = 16       -- trace hull half-size
}

SWEP.Secondary = {
    Automatic   = false,
    Delay       = 0.8,
    Damage      = 55,
    Range       = 48,
    Hull        = 14
}

-- Sounds (use HL2 defaults to avoid CSS dependency)
local SND_Swing     = "Weapon_Crowbar.Single"
local SND_HitWorld  = "Weapon_Crowbar.Melee_Hit"
local SND_HitFlesh  = "Flesh.ImpactHard"

function SWEP:Initialize()
    self:SetHoldType(self.HoldType)
end

function SWEP:Deploy()
    self:SetHoldType(self.HoldType)
    return true
end

function SWEP:CanPrimaryAttack()
    return true -- melee has no ammo
end

local function DoMeleeTrace(owner, range, hull)
    local startPos = owner:EyePos()
    local endPos   = startPos + owner:GetAimVector() * range

    local tr = util.TraceHull({
        start  = startPos,
        endpos = endPos,
        mins   = Vector(-hull, -hull, -hull),
        maxs   = Vector( hull,  hull,  hull),
        filter = function(ent)
            if ent == owner then return false end
            -- hit NPCs/Players/Props/World
            return true
        end
    })

    -- If hull miss, try a line trace for precision
    if (not tr.Hit) then
        tr = util.TraceLine({
            start  = startPos,
            endpos = endPos,
            filter = owner
        })
    end

    return tr
end

local function ApplyMeleeDamage(self, owner, tr, dmgAmount)
    if not tr.Hit then return false end

    local hitEnt = tr.Entity
    if IsValid(hitEnt) then
        -- Flesh hit
        local dmg = DamageInfo()
        dmg:SetAttacker(owner)
        dmg:SetInflictor(self)
        dmg:SetDamageType(DMG_SLASH)
        dmg:SetDamage(dmgAmount)

        -- Scale headshots a bit (simple check)
        if tr.HitGroup == HITGROUP_HEAD then
            dmg:ScaleDamage(1.25)
        end

        hitEnt:TakeDamageInfo(dmg)

        -- Blood effect for organic targets
        if hitEnt:IsNPC() or hitEnt:IsPlayer() then
            local eff = EffectData()
            eff:SetOrigin(tr.HitPos)
            eff:SetNormal(tr.HitNormal)
            util.Effect("BloodImpact", eff, true, true)
            sound.Play(SND_HitFlesh, tr.HitPos, 75, 100, 0.9)
        else
            -- World/prop impact
            util.Decal("ManhackCut", tr.HitPos + tr.HitNormal, tr.HitPos - tr.HitNormal)
            sound.Play(SND_HitWorld, tr.HitPos, 70, 100, 0.8)
        end

        return true
    else
        -- Hit world
        util.Decal("ManhackCut", tr.HitPos + tr.HitNormal, tr.HitPos - tr.HitNormal)
        sound.Play(SND_HitWorld, tr.HitPos, 70, 100, 0.8)
        return true
    end
end

function SWEP:DoMelee(dmg, range, hull, isHeavy)
    local owner = self:GetOwner()
    if not IsValid(owner) then return end

    if IsFirstTimePredicted() then
        -- swing sound & animations
        sound.Play(SND_Swing, owner:GetShootPos(), 70, isHeavy and 95 or 105, 0.75)
        self:SendWeaponAnim(isHeavy and ACT_VM_HITCENTER2 or ACT_VM_HITCENTER)
        owner:SetAnimation(PLAYER_ATTACK1)
        owner:ViewPunch(Angle(0, math.Rand(-1.5, 1.5), 0))
    end

    if SERVER then owner:LagCompensation(true) end
    local tr = DoMeleeTrace(owner, range, hull)
    if SERVER then owner:LagCompensation(false) end

    local hit = ApplyMeleeDamage(self, owner, tr, dmg)

    -- tiny hitstop feel
    if hit and IsFirstTimePredicted() then
        owner:ViewPunch(Angle(-1, 0, 0))
    end
end

function SWEP:PrimaryAttack()
    if not self:CanPrimaryAttack() then return end
    self:SetNextPrimaryFire(CurTime() + self.Primary.Delay)
    self:DoMelee(self.Primary.Damage, self.Primary.Range, self.Primary.Hull, false)
end

function SWEP:SecondaryAttack()
    if self:GetNextSecondaryFire() > CurTime() then return end
    self:SetNextSecondaryFire(CurTime() + self.Secondary.Delay)
    self:DoMelee(self.Secondary.Damage, self.Secondary.Range, self.Secondary.Hull, true)
end

function SWEP:Reload()
    -- no reload for melee
end

-- Optional: turn off laser for this weapon from your laser module
function SWEP:GetHoldType()
    return self.HoldType
end

return SWEP
