local ItemConfig = {}

ItemConfig.Items = {
	IronSword = {
		Name = "Iron Sword",
		Rarity = "Common",
		DropWeight = 30,
		StatBoosts = { Strength = 5 },
		Color = Color3.fromRGB(200, 200, 200),
	},
	HealthAmulet = {
		Name = "Health Amulet",
		Rarity = "Common",
		DropWeight = 25,
		StatBoosts = { Health = 30 },
		Color = Color3.fromRGB(255, 100, 100),
	},
	MageRing = {
		Name = "Mage Ring",
		Rarity = "Uncommon",
		DropWeight = 20,
		StatBoosts = { Mana = 25, CritDamage = 0.1 },
		Color = Color3.fromRGB(100, 100, 255),
	},
	ShieldCharm = {
		Name = "Shield Charm",
		Rarity = "Uncommon",
		DropWeight = 20,
		StatBoosts = { Defense = 10 },
		Color = Color3.fromRGB(255, 200, 50),
	},
	SpeedBoots = {
		Name = "Speed Boots",
		Rarity = "Rare",
		DropWeight = 15,
		StatBoosts = { Speed = 3, CritChance = 0.03 },
		Color = Color3.fromRGB(50, 255, 50),
	},
	BossLegendary = {
		Name = "Golem Heart",
		Rarity = "Legendary",
		DropWeight = 0, -- boss-only drop
		StatBoosts = { Strength = 10, Health = 50, CritChance = 0.05 },
		Color = Color3.fromRGB(255, 170, 0),
	},
}

ItemConfig.DropChance = 0.40 -- 40% chance normal enemies drop anything
ItemConfig.BossGuaranteedDrop = "BossLegendary"

ItemConfig.ChestTiers = {
	Common = { MinItems = 1, MaxItems = 1, RarityWeights = { Common = 70, Uncommon = 25, Rare = 5 } },
	Rare = { MinItems = 1, MaxItems = 2, RarityWeights = { Common = 30, Uncommon = 40, Rare = 25, Legendary = 5 } },
	Legendary = { MinItems = 2, MaxItems = 3, RarityWeights = { Uncommon = 20, Rare = 40, Legendary = 40 } },
}

-- ===== POTIONS (consumable, bought from shop) =====
ItemConfig.Potions = {
	HealthPotion = {
		Name = "Health Potion",
		Description = "Restores 50 HP instantly.",
		Effect = "Heal",
		Value = 50,
		Price = 15,
		Color = Color3.fromRGB(255, 80, 80),
	},
	GreaterHealthPotion = {
		Name = "Greater Health Potion",
		Description = "Restores 120 HP instantly.",
		Effect = "Heal",
		Value = 120,
		Price = 35,
		Color = Color3.fromRGB(255, 40, 40),
	},
	ManaPotion = {
		Name = "Mana Potion",
		Description = "Restores 40 Mana instantly.",
		Effect = "Mana",
		Value = 40,
		Price = 15,
		Color = Color3.fromRGB(80, 120, 255),
	},
	ShieldElixir = {
		Name = "Shield Elixir",
		Description = "+30 Defense for 10 seconds.",
		Effect = "Shield",
		Value = 30,
		Duration = 10,
		Price = 25,
		Color = Color3.fromRGB(255, 215, 0),
	},
	SwiftnessPotion = {
		Name = "Swiftness Potion",
		Description = "+8 Speed for 12 seconds.",
		Effect = "Speed",
		Value = 8,
		Duration = 12,
		Price = 20,
		Color = Color3.fromRGB(80, 255, 120),
	},
}

return ItemConfig
