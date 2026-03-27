local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local StatConfig = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("StatConfig"))
local Remotes = require(ReplicatedStorage:WaitForChild("Remotes"))

local PlayerDataService = {}

local playerStats = {} -- [player] = { Health = ..., Mana = ..., ... }
local playerMana = {} -- [player] = current mana (tracked separately for regen)
local shieldBuffs = {} -- [player] = { DefenseBonus = 50, ExpiresAt = os.clock() + 5 }
local playerInventory = {} -- [player] = { {ItemId="IronSword", ...}, ... }
local playerClass = {} -- [player] = classId

function PlayerDataService.Init()
	Players.PlayerAdded:Connect(function(player)
		PlayerDataService.OnPlayerJoined(player)
	end)

	Players.PlayerRemoving:Connect(function(player)
		PlayerDataService.OnPlayerLeft(player)
	end)

	-- Mana regeneration loop
	RunService.Heartbeat:Connect(function(dt)
		for player, stats in pairs(playerStats) do
			if player.Parent then
				local currentMana = playerMana[player] or 0
				local maxMana = stats.Mana
				if currentMana < maxMana then
					currentMana = math.min(currentMana + StatConfig.ManaRegenPerSecond * dt, maxMana)
					playerMana[player] = currentMana
					-- Update attribute on character
					local char = player.Character
					if char then
						char:SetAttribute("CurrentMana", math.floor(currentMana))
						char:SetAttribute("MaxMana", maxMana)
					end
				end

				-- Check shield buff expiry
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
			return PlayerDataService.GetStats(player)
		end
	end
end

function PlayerDataService.OnPlayerJoined(player)
	-- Initialize stats from base
	local stats = {}
	for key, value in pairs(StatConfig.BaseStats) do
		stats[key] = value
	end
	playerStats[player] = stats
	playerMana[player] = stats.Mana
	playerInventory[player] = {}

	-- Apply stats when character spawns
	player.CharacterAdded:Connect(function(character)
		PlayerDataService.ApplyStatsToCharacter(player, character)
	end)

	-- Apply if character already exists
	if player.Character then
		PlayerDataService.ApplyStatsToCharacter(player, player.Character)
	end
end

function PlayerDataService.OnPlayerLeft(player)
	playerStats[player] = nil
	playerMana[player] = nil
	shieldBuffs[player] = nil
	playerInventory[player] = nil
	playerClass[player] = nil
end

function PlayerDataService.ApplyStatsToCharacter(player, character)
	local humanoid = character:WaitForChild("Humanoid", 5)
	if not humanoid then return end

	local stats = playerStats[player]
	if not stats then return end

	humanoid.MaxHealth = stats.Health
	humanoid.Health = stats.Health
	humanoid.WalkSpeed = stats.Speed

	character:SetAttribute("CurrentMana", stats.Mana)
	character:SetAttribute("MaxMana", stats.Mana)
	playerMana[player] = stats.Mana

	-- Send stats to client
	local remote = Remotes:GetEvent("StatsUpdated")
	if remote then
		remote:FireClient(player, stats)
	end
end

function PlayerDataService.GetStats(player)
	return playerStats[player]
end

function PlayerDataService.GetMana(player)
	return playerMana[player] or 0
end

function PlayerDataService.ConsumeMana(player, amount)
	local current = playerMana[player] or 0
	if current < amount then
		return false
	end
	playerMana[player] = current - amount

	local char = player.Character
	if char then
		char:SetAttribute("CurrentMana", math.floor(playerMana[player]))
	end
	return true
end

function PlayerDataService.GetEffectiveDefense(player)
	local stats = playerStats[player]
	if not stats then return 0 end

	local defense = stats.Defense
	local buff = shieldBuffs[player]
	if buff and os.clock() < buff.ExpiresAt then
		defense = defense + buff.DefenseBonus
	end
	return defense
end

function PlayerDataService.ApplyShieldBuff(player, defenseBonus, duration)
	shieldBuffs[player] = {
		DefenseBonus = defenseBonus,
		ExpiresAt = os.clock() + duration,
	}
end

function PlayerDataService.ApplyItem(player, itemId)
	local ItemConfig = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("ItemConfig"))
	local itemData = ItemConfig.Items[itemId]
	if not itemData then return end

	local stats = playerStats[player]
	if not stats then return end

	for stat, bonus in pairs(itemData.StatBoosts) do
		if stats[stat] then
			stats[stat] = stats[stat] + bonus
		end
	end

	-- Add to inventory
	if not playerInventory[player] then
		playerInventory[player] = {}
	end
	table.insert(playerInventory[player], {
		ItemId = itemId,
		Name = itemData.Name,
		Rarity = itemData.Rarity,
		StatBoosts = itemData.StatBoosts,
	})

	-- Re-apply health/speed to character
	local char = player.Character
	if char then
		local humanoid = char:FindFirstChild("Humanoid")
		if humanoid then
			local oldMaxHealth = humanoid.MaxHealth
			humanoid.MaxHealth = stats.Health
			-- Heal the bonus amount
			humanoid.Health = humanoid.Health + (stats.Health - oldMaxHealth)
			humanoid.WalkSpeed = stats.Speed
		end
		char:SetAttribute("MaxMana", stats.Mana)
	end

	-- Notify client of stats
	local remote = Remotes:GetEvent("StatsUpdated")
	if remote then
		remote:FireClient(player, stats)
	end

	-- Notify client of inventory
	local invRemote = Remotes:GetEvent("InventoryUpdated")
	if invRemote then
		invRemote:FireClient(player, playerInventory[player])
	end
end

function PlayerDataService.GetInventory(player)
	return playerInventory[player] or {}
end

function PlayerDataService.ResetStats(player)
	local stats = {}
	for key, value in pairs(StatConfig.BaseStats) do
		stats[key] = value
	end
	playerStats[player] = stats
	playerMana[player] = stats.Mana
	shieldBuffs[player] = nil
	playerInventory[player] = {}
	playerClass[player] = nil

	local char = player.Character
	if char then
		PlayerDataService.ApplyStatsToCharacter(player, char)
	end

	-- Notify client of cleared inventory
	local invRemote = Remotes:GetEvent("InventoryUpdated")
	if invRemote then
		invRemote:FireClient(player, {})
	end
end

function PlayerDataService.ApplyClassModifiers(player, classId)
	local ClassConfig = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("ClassConfig"))
	local classData = ClassConfig.Classes[classId]
	if not classData then return end

	local stats = playerStats[player]
	if not stats then return end

	playerClass[player] = classId

	for stat, bonus in pairs(classData.StatModifiers) do
		if stats[stat] then
			stats[stat] = stats[stat] + bonus
		end
	end

	-- Re-apply to character
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
		playerMana[player] = stats.Mana
	end

	local remote = Remotes:GetEvent("StatsUpdated")
	if remote then
		remote:FireClient(player, stats)
	end
end

function PlayerDataService.GetClass(player)
	return playerClass[player]
end

return PlayerDataService
