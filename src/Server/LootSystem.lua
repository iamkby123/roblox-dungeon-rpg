local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ItemConfig = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("ItemConfig"))
local Remotes = require(ReplicatedStorage:WaitForChild("Remotes"))

local LootSystem = {}

local DelverDataService -- set via Init

function LootSystem.Init(delverDataSvc)
	DelverDataService = delverDataSvc
end

function LootSystem.RollLoot(creatureConfigId, isBoss)
	local drops = {}

	-- Sanctum boss always drops legendary + one random
	if isBoss then
		table.insert(drops, ItemConfig.BossGuaranteedDrop)
		local randomItem = LootSystem.WeightedRandom()
		if randomItem then
			table.insert(drops, randomItem)
		end
		return drops
	end

	-- Normal creature: chance-based
	if math.random() <= ItemConfig.DropChance then
		local item = LootSystem.WeightedRandom()
		if item then
			table.insert(drops, item)
		end
	end

	return drops
end

function LootSystem.WeightedRandom()
	local totalWeight = 0
	local candidates = {}

	for itemId, data in pairs(ItemConfig.Items) do
		if data.DropWeight > 0 then
			totalWeight = totalWeight + data.DropWeight
			table.insert(candidates, { Id = itemId, Weight = data.DropWeight })
		end
	end

	if totalWeight == 0 then return nil end

	local roll = math.random() * totalWeight
	local cumulative = 0

	for _, candidate in ipairs(candidates) do
		cumulative = cumulative + candidate.Weight
		if roll <= cumulative then
			return candidate.Id
		end
	end

	return candidates[#candidates].Id
end

function LootSystem.GrantLoot(player, creatureConfigId, isBoss)
	local drops = LootSystem.RollLoot(creatureConfigId, isBoss)

	for _, itemId in ipairs(drops) do
		DelverDataService.ApplyItem(player, itemId)

		local itemData = ItemConfig.Items[itemId]
		local remote = Remotes:GetEvent("ItemPickup")
		if remote and itemData then
			remote:FireClient(player, {
				ItemId = itemId,
				Name = itemData.Name,
				Rarity = itemData.Rarity,
				StatBoosts = itemData.StatBoosts,
				Color = { itemData.Color.R, itemData.Color.G, itemData.Color.B },
			})
		end
	end
end

function LootSystem.GrantCacheLoot(player, roomIndex)
	local ItemConfig = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("ItemConfig"))

	local tierName = "Common"
	if roomIndex >= 4 then tierName = "Legendary"
	elseif roomIndex >= 2 then tierName = "Rare" end

	local tier = ItemConfig.ChestTiers[tierName]
	if not tier then return end

	local numItems = math.random(tier.MinItems, tier.MaxItems)

	for _ = 1, numItems do
		local itemId = LootSystem.WeightedRandomByRarity(tier.RarityWeights)
		if itemId then
			DelverDataService.ApplyItem(player, itemId)
			local itemData = ItemConfig.Items[itemId]
			local remote = Remotes:GetEvent("ItemPickup")
			if remote and itemData then
				remote:FireClient(player, {
					ItemId = itemId,
					Name = itemData.Name,
					Rarity = itemData.Rarity,
					StatBoosts = itemData.StatBoosts,
					Color = { itemData.Color.R, itemData.Color.G, itemData.Color.B },
				})
			end
		end
	end
end

function LootSystem.WeightedRandomByRarity(rarityWeights)
	local ItemConfig = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("ItemConfig"))
	local candidates = {}
	local totalWeight = 0

	for itemId, data in pairs(ItemConfig.Items) do
		local rarityWeight = rarityWeights[data.Rarity]
		if rarityWeight and rarityWeight > 0 then
			totalWeight = totalWeight + rarityWeight
			table.insert(candidates, { Id = itemId, Weight = rarityWeight })
		end
	end

	if totalWeight == 0 then return nil end

	local roll = math.random() * totalWeight
	local cumulative = 0
	for _, c in ipairs(candidates) do
		cumulative = cumulative + c.Weight
		if roll <= cumulative then return c.Id end
	end
	return candidates[#candidates].Id
end

return LootSystem
