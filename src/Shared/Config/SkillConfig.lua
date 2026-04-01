local SkillConfig = {}

-- Weapons are items the player equips. Each has an ability.
-- Press 1-4 to switch weapon, click to use it.
SkillConfig.Weapons = {
	Sword = {
		Name = "Iron Sword",
		Slot = 1,
		ManaCost = 0,
		Cooldown = 0.5,
		Multiplier = 1.0,
		Range = 10,
		Type = "MeleeAoE",
		Description = "Slash nearby enemies",
		Color = Color3.fromRGB(200, 200, 200),
	},
	Staff = {
		Name = "Fire Staff",
		Slot = 2,
		ManaCost = 20,
		Cooldown = 2.5,
		Multiplier = 2.5,
		Range = 60,
		Type = "Projectile",
		Speed = 80,
		AoERadius = 10,
		Description = "Launch a fireball",
		Color = Color3.fromRGB(255, 120, 30),
	},
	Wand = {
		Name = "Healing Wand",
		Slot = 3,
		ManaCost = 25,
		Cooldown = 6.0,
		Multiplier = 0,
		Range = 0,
		Type = "Self",
		HealPercent = 0.30,
		Description = "Restore 30% HP",
		Color = Color3.fromRGB(50, 255, 100),
	},
	Shield = {
		Name = "Guardian Shield",
		Slot = 4,
		ManaCost = 15,
		Cooldown = 10.0,
		Multiplier = 0,
		Range = 0,
		Type = "Buff",
		DefenseBonus = 50,
		Duration = 5.0,
		Description = "+50 Defense for 5s",
		Color = Color3.fromRGB(50, 150, 255),
	},
}

-- Map slot numbers to weapon IDs
SkillConfig.SlotToWeapon = {
	[1] = "Sword",
	[2] = "Staff",
	[3] = "Wand",
	[4] = "Shield",
}

-- Keep backward compat: Skills table maps weapon IDs to their data
SkillConfig.Skills = SkillConfig.Weapons

-- KeyBindings maps slot number to weapon ID (used by client)
SkillConfig.KeyBindings = SkillConfig.SlotToWeapon

return SkillConfig
