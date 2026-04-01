local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local StatSystem = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("StatSystem"))
local Remotes = require(ReplicatedStorage:WaitForChild("Remotes"))

local DelverDataService = {}

local delverStats = {} -- [player] = { MaxHP = ..., Mana = ..., ... }
local delverMana = {} -- [player] = current mana (tracked separately for regen)
local shieldBuffs = {} -- [player] = { DefenseBonus = 50, ExpiresAt = os.clock() + 5 }
local delverInventory = {} -- [player] = { {ItemId="IronSword", ...}, ... }
local delverVocation = {} -- [player] = vocationId
local delverCoins = {} -- [player] = number
local delverPotions = {} -- [player] = { {PotionId="HealthPotion", ...}, ... }

function DelverDataService.Init()
	Players.PlayerAdded:Connect(function(player)
		DelverDataService.OnPlayerJoined(player)
	end)

	Players.PlayerRemoving:Connect(function(player)
		DelverDataService.OnPlayerLeft(player)
	end)

	-- Mana regeneration loop
	RunService.Heartbeat:Connect(function(dt)
		for player, stats in pairs(delverStats) do
			if player.Parent then
				local currentMana = delverMana[player] or 0
				local maxMana = stats.Mana
				if currentMana < maxMana then
					currentMana = math.min(currentMana + StatSystem.ManaRegenPerSecond * dt, maxMana)
					delverMana[player] = currentMana
					local char = player.Character
					if char then
						char:SetAttribute("CurrentMana", math.floor(currentMana))
						char:SetAttribute("MaxMana", maxMana)
					end
				end

				local buff = shieldBuffs[player]
				if buff and os.clock() >= buff.ExpiresAt then
					shieldBuffs[player] = nil
				end
			end
		end
	end)

	-- Handle GetStats remote
	local getStatsRemote = Remotes:GetFunction("GetStats")
	if getStatsRemote then
		getStatsRemote.OnServerInvoke = function(player)
			return DelverDataService.GetStats(player)
		end
	end
end

function DelverDataService.OnPlayerJoined(player)
	local stats = {}
	for key, value in pairs(StatSystem.BaseStats) do
		stats[key] = value
	end
	-- Map MaxHP to Health for Humanoid compatibility
	stats.Health = stats.MaxHP
	delverStats[player] = stats
	delverMana[player] = stats.Mana
	delverInventory[player] = {}
	delverCoins[player] = 0
	delverPotions[player] = {}

	player.CharacterAdded:Connect(function(character)
		DelverDataService.ApplyStatsToCharacter(player, character)
	end)

	if player.Character then
		DelverDataService.ApplyStatsToCharacter(player, player.Character)
	end
end

function DelverDataService.OnPlayerLeft(player)
	delverStats[player] = nil
	delverMana[player] = nil
	shieldBuffs[player] = nil
	delverInventory[player] = nil
	delverVocation[player] = nil
	delverCoins[player] = nil
	delverPotions[player] = nil
end

function DelverDataService.ApplyStatsToCharacter(player, character)
	local humanoid = character:WaitForChild("Humanoid", 5)
	if not humanoid then return end

	local stats = delverStats[player]
	if not stats then return end

	humanoid.MaxHealth = stats.Health
	humanoid.Health = stats.Health
	humanoid.WalkSpeed = stats.Speed

	character:SetAttribute("CurrentMana", stats.Mana)
	character:SetAttribute("MaxMana", stats.Mana)
	delverMana[player] = stats.Mana

	local remote = Remotes:GetEvent("StatsUpdated")
	if remote then
		remote:FireClient(player, stats)
	end
end

function DelverDataService.GetStats(player)
	return delverStats[player]
end

function DelverDataService.GetMana(player)
	return delverMana[player] or 0
end

function DelverDataService.ConsumeMana(player, amount)
	local current = delverMana[player] or 0
	if current < amount then
		return false
	end
	delverMana[player] = current - amount

	local char = player.Character
	if char then
		char:SetAttribute("CurrentMana", math.floor(delverMana[player]))
	end
	return true
end

function DelverDataService.GetEffectiveDefense(player)
	local stats = delverStats[player]
	if not stats then return 0 end

	local defense = stats.Defense
	local buff = shieldBuffs[player]
	if buff and os.clock() < buff.ExpiresAt then
		defense = defense + buff.DefenseBonus
	end
	return defense
end

function DelverDataService.ApplyShieldBuff(player, defenseBonus, duration)
	shieldBuffs[player] = {
		DefenseBonus = defenseBonus,
		ExpiresAt = os.clock() + duration,
	}
end

function DelverDataService.ApplyItem(player, itemId)
	local ItemConfig = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("ItemConfig"))
	local itemData = ItemConfig.Items[itemId]
	if not itemData then return end

	local stats = delverStats[player]
	if not stats then return end

	for stat, bonus in pairs(itemData.StatBoosts) do
		if stats[stat] then
			stats[stat] = stats[stat] + bonus
		end
	end

	if not delverInventory[player] then
		delverInventory[player] = {}
	end
	table.insert(delverInventory[player], {
		ItemId = itemId,
		Name = itemData.Name,
		Rarity = itemData.Rarity,
		StatBoosts = itemData.StatBoosts,
	})

	local char = player.Character
	if char then
		local humanoid = char:FindFirstChild("Humanoid")
		if humanoid then
			local oldMaxHealth = humanoid.MaxHealth
			humanoid.MaxHealth = stats.Health
			humanoid.Health = humanoid.Health + (stats.Health - oldMaxHealth)
			humanoid.WalkSpeed = stats.Speed
		end
		char:SetAttribute("MaxMana", stats.Mana)
	end

	local remote = Remotes:GetEvent("StatsUpdated")
	if remote then
		remote:FireClient(player, stats)
	end

	local invRemote = Remotes:GetEvent("InventoryUpdated")
	if invRemote then
		invRemote:FireClient(player, delverInventory[player])
	end
end

function DelverDataService.GetInventory(player)
	return delverInventory[player] or {}
end

function DelverDataService.ResetStats(player)
	local stats = {}
	for key, value in pairs(StatSystem.BaseStats) do
		stats[key] = value
	end
	stats.Health = stats.MaxHP
	delverStats[player] = stats
	delverMana[player] = stats.Mana
	shieldBuffs[player] = nil
	delverInventory[player] = {}
	delverVocation[player] = nil

	local char = player.Character
	if char then
		DelverDataService.ApplyStatsToCharacter(player, char)
	end

	local invRemote = Remotes:GetEvent("InventoryUpdated")
	if invRemote then
		invRemote:FireClient(player, {})
	end
end

function DelverDataService.ApplyVocationModifiers(player, vocationId)
	local VocationSystem = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("VocationSystem"))
	local vocationData = VocationSystem.Vocations[vocationId]
	if not vocationData then return end

	local stats = delverStats[player]
	if not stats then return end

	delverVocation[player] = vocationId

	for stat, bonus in pairs(vocationData.StatModifiers) do
		if stats[stat] then
			stats[stat] = stats[stat] + bonus
		end
	end

	local char = player.Character
	if char then
		local humanoid = char:FindFirstChild("Humanoid")
		if humanoid then
			local oldMaxHealth = humanoid.MaxHealth
			humanoid.MaxHealth = stats.Health
			humanoid.Health = humanoid.Health + (stats.Health - oldMaxHealth)
			humanoid.WalkSpeed = stats.Speed
		end
		char:SetAttribute("MaxMana", stats.Mana)
		delverMana[player] = stats.Mana
	end

	local remote = Remotes:GetEvent("StatsUpdated")
	if remote then
		remote:FireClient(player, stats)
	end
end

function DelverDataService.GetVocation(player)
	return delverVocation[player]
end

-- ===== COIN SYSTEM =====

function DelverDataService.GetCoins(player)
	return delverCoins[player] or 0
end

function DelverDataService.AddCoins(player, amount)
	delverCoins[player] = (delverCoins[player] or 0) + amount
	local remote = Remotes:GetEvent("CoinsUpdated")
	if remote then
		remote:FireClient(player, delverCoins[player])
	end
end

function DelverDataService.SpendCoins(player, amount)
	local current = delverCoins[player] or 0
	if current < amount then
		return false
	end
	delverCoins[player] = current - amount
	local remote = Remotes:GetEvent("CoinsUpdated")
	if remote then
		remote:FireClient(player, delverCoins[player])
	end
	return true
end

-- ===== POTION SYSTEM =====

function DelverDataService.GetPotions(player)
	return delverPotions[player] or {}
end

function DelverDataService.AddPotion(player, potionId)
	local ItemConfig = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("ItemConfig"))
	local potionData = ItemConfig.Potions[potionId]
	if not potionData then return end

	if not delverPotions[player] then
		delverPotions[player] = {}
	end

	-- Stack potions: increment count if already owned
	for _, entry in ipairs(delverPotions[player]) do
		if entry.PotionId == potionId then
			entry.Count = entry.Count + 1
			local remote = Remotes:GetEvent("PotionsUpdated")
			if remote then remote:FireClient(player, delverPotions[player]) end
			return
		end
	end

	table.insert(delverPotions[player], {
		PotionId = potionId,
		Name = potionData.Name,
		Count = 1,
	})

	local remote = Remotes:GetEvent("PotionsUpdated")
	if remote then remote:FireClient(player, delverPotions[player]) end
end

function DelverDataService.UsePotion(player, potionId)
	local ItemConfig = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("ItemConfig"))
	local potionData = ItemConfig.Potions[potionId]
	if not potionData then return false end

	local potions = delverPotions[player]
	if not potions then return false end

	-- Find and consume one potion
	for i, entry in ipairs(potions) do
		if entry.PotionId == potionId then
			entry.Count = entry.Count - 1
			if entry.Count <= 0 then
				table.remove(potions, i)
			end

			-- Apply potion effect
			local stats = delverStats[player]
			local char = player.Character
			local humanoid = char and char:FindFirstChild("Humanoid")

			if potionData.Effect == "Heal" and humanoid and stats then
				humanoid.Health = math.min(humanoid.Health + potionData.Value, stats.Health)
			elseif potionData.Effect == "Mana" and stats then
				delverMana[player] = math.min((delverMana[player] or 0) + potionData.Value, stats.Mana)
				if char then
					char:SetAttribute("CurrentMana", math.floor(delverMana[player]))
				end
			elseif potionData.Effect == "Shield" then
				DelverDataService.ApplyShieldBuff(player, potionData.Value, potionData.Duration or 10)
			elseif potionData.Effect == "Speed" and stats and humanoid then
				local originalSpeed = stats.Speed
				humanoid.WalkSpeed = originalSpeed + potionData.Value
				task.delay(potionData.Duration or 10, function()
					if humanoid and humanoid.Parent then
						humanoid.WalkSpeed = originalSpeed
					end
				end)
			end

			local remote = Remotes:GetEvent("PotionsUpdated")
			if remote then remote:FireClient(player, potions) end
			return true
		end
	end

	return false
end

return DelverDataService
