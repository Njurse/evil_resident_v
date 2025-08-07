AddCSLuaFile()

SWEP.PrintName = "ERV Pistol"
SWEP.Author = "Nattdy"
SWEP.Instructions = "Left click to shoot."

SWEP.Spawnable = true
SWEP.AdminOnly = false

SWEP.Base = "weapon_base"
SWEP.Category = "Evil Resident V"

SWEP.UseHands = true
SWEP.ViewModel = "models/weapons/c_pistol.mdl"
SWEP.WorldModel = "models/weapons/w_pistol.mdl"
SWEP.ViewModelFOV = 54

SWEP.Primary.ClipSize = 12
SWEP.Primary.DefaultClip = 24
SWEP.Primary.Automatic = false
SWEP.Primary.Ammo = "Pistol"
SWEP.Primary.Delay = 0.4

SWEP.Secondary.ClipSize = -1
SWEP.Secondary.DefaultClip = -1
SWEP.Secondary.Automatic = false
SWEP.Secondary.Ammo = "none"

SWEP.HoldType = "pistol"

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
    -- Optional: trigger ADS or a mode toggle
end
