local VocationSystem = {}

VocationSystem.Vocations = {
	Ironclad = {
		Name = "Ironclad",
		Color = BrickColor.new("Bright blue"),
		Description = "+80 HP, +20 DEF\nShield buff x1.3",
		StatModifiers = { MaxHP = 80, Defense = 20 },
		WeaponBonuses = { Buff = 1.3 },
	},
	Hexblade = {
		Name = "Hexblade",
		Color = BrickColor.new("Bright red"),
		Description = "+15 STR, +0.3 CritDmg, +20 HP\nMelee damage x1.25",
		StatModifiers = { Strength = 15, CritDamage = 0.3, MaxHP = 20 },
		WeaponBonuses = { MeleeAoE = 1.25 },
	},
	Ranger = {
		Name = "Ranger",
		Color = BrickColor.new("Bright green"),
		Description = "+10% Crit, +4 Speed\nProjectile damage x1.2",
		StatModifiers = { CritChance = 0.10, Speed = 4 },
		WeaponBonuses = { Projectile = 1.2 },
	},
	Warden = {
		Name = "Warden",
		Color = BrickColor.new("Bright violet"),
		Description = "+50 Mana, +5 STR\nProjectile damage x1.3",
		StatModifiers = { Mana = 50, Strength = 5 },
		WeaponBonuses = { Projectile = 1.3 },
	},
	Hexer = {
		Name = "Hexer",
		Color = BrickColor.new("Dark indigo"),
		Description = "+30 Arcana, +5 STR\nDebuff potency x1.2",
		StatModifiers = { Arcana = 30, Strength = 5 },
		WeaponBonuses = { Debuff = 1.2 },
	},
}

VocationSystem.PedestalLayout = {
	{ VocationId = "Ironclad", Offset = Vector3.new(-16, 0, 5) },
	{ VocationId = "Hexblade", Offset = Vector3.new(-8,  0, 5) },
	{ VocationId = "Ranger",   Offset = Vector3.new(0,   0, 5) },
	{ VocationId = "Warden",   Offset = Vector3.new(8,   0, 5) },
	{ VocationId = "Hexer",    Offset = Vector3.new(16,  0, 5) },
}

return VocationSystem
