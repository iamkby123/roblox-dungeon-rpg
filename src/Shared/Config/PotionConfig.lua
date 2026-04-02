local PotionConfig = {}

PotionConfig.Potions = {
	HealthPotion = {
		Name = "Health Potion",
		Description = "Restores 50 HP instantly",
		Cost = 10,
		Color = Color3.fromRGB(220, 50, 50),
		Effect = "Heal",
		Value = 50,
	},
	ManaPotion = {
		Name = "Mana Potion",
		Description = "Restores 50 Mana instantly",
		Cost = 10,
		Color = Color3.fromRGB(50, 100, 255),
		Effect = "RestoreMana",
		Value = 50,
	},
	SpeedPotion = {
		Name = "Speed Potion",
		Description = "+6 Speed for 15 seconds",
		Cost = 10,
		Color = Color3.fromRGB(50, 220, 80),
		Effect = "BuffSpeed",
		Value = 6,
		Duration = 15,
	},
	StrengthPotion = {
		Name = "Strength Potion",
		Description = "+8 Strength for 15 seconds",
		Cost = 10,
		Color = Color3.fromRGB(255, 160, 30),
		Effect = "BuffStrength",
		Value = 8,
		Duration = 15,
	},
}

-- Ordered list for UI display
PotionConfig.DisplayOrder = { "HealthPotion", "ManaPotion", "SpeedPotion", "StrengthPotion" }

return PotionConfig
