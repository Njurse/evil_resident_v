AddCSLuaFile()

local SWEP = {}

SWEP.PrintName = "ERV Knife"
SWEP.Author = "Nattdy"
SWEP.Instructions = "To do: implement"

SWEP.Spawnable = true
SWEP.AdminOnly = false
SWEP.NoLaser = false
SWEP.Base = "weapon_base"
SWEP.Category = "Evil Resident V"

SWEP.UseHands = true
SWEP.ViewModel = "models/weapons/c_pistol.mdl"
SWEP.WorldModel = "models/weapons/w_pistol.mdl"
SWEP.ViewModelFOV = 54

SWEP.HoldType = "knife"

SWEP.Primary = {
    ClipSize = 12,
    DefaultClip = 24,
    Automatic = false,
    Ammo = "Pistol",
    Delay = 0.4
}

SWEP.Secondary = {
    ClipSize = -1,
    DefaultClip = -1,
    Automatic = false,
    Ammo = "none"
}

function SWEP:Initialize()
    self:SetHoldType(self.HoldType)
end

function SWEP:PrimaryAttack()
    if not self:CanPrimaryAttack() then return end

    self:ShootBullet(12, 1, 0.02)
    self:EmitSound("Weapon_Pistol.Single")
    self:TakePrimaryAmmo(1)
    self:SetNextPrimaryFire(CurTime() + self.Primary.Delay)
end

function SWEP:SecondaryAttack()
    -- Optional: ADS or alternate function
end

return SWEP
