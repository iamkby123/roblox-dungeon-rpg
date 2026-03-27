local ClassConfig = {}

ClassConfig.Classes = {
	Berserker = {
		Name = "Berserker",
		Color = BrickColor.new("Bright red"),
		Description = "+15 STR, +0.3 CritDmg, +20 HP\nMelee damage x1.25",
		StatModifiers = { Strength = 15, CritDamage = 0.3, Health = 20 },
		WeaponBonuses = { MeleeAoE = 1.25 },
	},
	Mage = {
		Name = "Mage",
		Color = BrickColor.new("Bright violet"),
		Description = "+50 Mana, +5 STR\nProjectile damage x1.3",
		StatModifiers = { Mana = 50, Strength = 5 },
		WeaponBonuses = { Projectile = 1.3 },
	},
	Archer = {
		Name = "Archer",
		Color = BrickColor.new("Bright green"),
		Description = "+10% Crit, +4 Speed\nProjectile damage x1.2",
		StatModifiers = { CritChance = 0.10, Speed = 4 },
		WeaponBonuses = { Projectile = 1.2 },
	},
	Tank = {
		Name = "Tank",
		Color = BrickColor.new("Bright blue"),
		Description = "+80 HP, +20 DEF\nShield buff x1.3",
		StatModifiers = { Health = 80, Defense = 20 },
		WeaponBonuses = { Buff = 1.3 },
	},
}

ClassConfig.PedestalLayout = {
	{ ClassId = "Berserker", Offset = Vector3.new(-12, 0, 5) },
	{ ClassId = "Mage",      Offset = Vector3.new(-4,  0, 5) },
	{ ClassId = "Archer",    Offset = Vector3.new(4,   0, 5) },
	{ ClassId = "Tank",      Offset = Vector3.new(12,  0, 5) },
}

return ClassConfig
