local Players = game:GetService("Players")
local DataStoreService = game:GetService("DataStoreService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage:WaitForChild("Remotes"))

local CatacombsProgression = {}

local PlayerDataService -- injected via Init

local progressionStore = DataStoreService:GetDataStore("CatacombsProgression_v1")

-- In-memory cache: [player] = { XP = number, Level = number }
local playerProgression = {}

--------------------------------------------------------------------------------
-- CONFIG
--------------------------------------------------------------------------------
local BASE_XP = 100
local GROWTH_RATE = 1.15

-- XP awards
local MOB_XP_BASE = 10        -- small: regular mob kill
local KEEPER_XP_BASE = 50     -- medium: miniboss/keeper kill
local DUNGEON_CLEAR_BASE = 200 -- large: dungeon clear (scaled by floor)

-- Stat bonus per level
local LEVEL_BONUS = {
	Health = 5,
	Defense = 2,
	Strength = 2,
}

-- Keeper enemy IDs (minibosses)
local KEEPER_IDS = {
	IronKeeper = true,
	GoldGuardian = true,
	CrimsonSentinel = true,
	EmeraldWarden = true,
	ShadowChampion = true,
}

--------------------------------------------------------------------------------
-- XP CURVE
--------------------------------------------------------------------------------
local function xpForLevel(level)
	return math.floor(BASE_XP * (GROWTH_RATE ^ level))
end

--------------------------------------------------------------------------------
-- DATASTORE HELPERS
--------------------------------------------------------------------------------
local function loadProgression(player)
	local success, data = pcall(function()
		return progressionStore:GetAsync("player_" .. player.UserId)
	end)
	if success and data then
		return { XP = data.XP or 0, Level = data.Level or 1 }
	end
	return { XP = 0, Level = 1 }
end

local function saveProgression(player)
	local data = playerProgression[player]
	if not data then return end
	pcall(function()
		progressionStore:SetAsync("player_" .. player.UserId, {
			XP = data.XP,
			Level = data.Level,
		})
	end)
end

--------------------------------------------------------------------------------
-- LEVEL UP
--------------------------------------------------------------------------------
local function checkLevelUp(player)
	local data = playerProgression[player]
	if not data then return end

	local leveled = false
	while data.XP >= xpForLevel(data.Level) do
		data.XP = data.XP - xpForLevel(data.Level)
		data.Level = data.Level + 1
		leveled = true

		-- Apply flat stat bonus
		if PlayerDataService then
			local stats = PlayerDataService.GetStats(player)
			if stats then
				for stat, bonus in pairs(LEVEL_BONUS) do
					if stats[stat] then
						stats[stat] = stats[stat] + bonus
					end
				end

				-- Re-apply health/speed to character
				local char = player.Character
				if char then
					local humanoid = char:FindFirstChild("Humanoid")
					if humanoid then
						local oldMax = humanoid.MaxHealth
						humanoid.MaxHealth = stats.Health
						humanoid.Health = humanoid.Health + (stats.Health - oldMax)
					end
				end

				-- Notify client of updated stats
				local statsRemote = Remotes:GetEvent("StatsUpdated")
				if statsRemote then
					statsRemote:FireClient(player, stats)
				end
			end
		end

		-- Fire level-up event to client
		local levelUpRemote = Remotes:GetEvent("CatacombsLevelUp")
		if levelUpRemote then
			levelUpRemote:FireClient(player, {
				Level = data.Level,
				BonusHealth = LEVEL_BONUS.Health,
				BonusDefense = LEVEL_BONUS.Defense,
				BonusStrength = LEVEL_BONUS.Strength,
			})
		end
	end

	return leveled
end

--------------------------------------------------------------------------------
-- PUBLIC API
--------------------------------------------------------------------------------
function CatacombsProgression.Init(playerDataSvc)
	PlayerDataService = playerDataSvc

	Players.PlayerAdded:Connect(function(player)
		local data = loadProgression(player)
		playerProgression[player] = data

		-- Apply accumulated level bonuses to base stats
		if PlayerDataService and data.Level > 1 then
			-- Wait for PlayerDataService to have stats ready
			task.defer(function()
				local stats = PlayerDataService.GetStats(player)
				if stats then
					local bonusLevels = data.Level - 1
					for stat, bonus in pairs(LEVEL_BONUS) do
						if stats[stat] then
							stats[stat] = stats[stat] + (bonus * bonusLevels)
						end
					end

					local char = player.Character
					if char then
						local humanoid = char:FindFirstChild("Humanoid")
						if humanoid then
							humanoid.MaxHealth = stats.Health
							humanoid.Health = stats.Health
						end
					end

					local statsRemote = Remotes:GetEvent("StatsUpdated")
					if statsRemote then
						statsRemote:FireClient(player, stats)
					end
				end
			end)
		end

		-- Send initial progression data
		local xpRemote = Remotes:GetEvent("CatacombsXPGained")
		if xpRemote then
			xpRemote:FireClient(player, {
				XP = data.XP,
				Level = data.Level,
				XPRequired = xpForLevel(data.Level),
			})
		end
	end)

	Players.PlayerRemoving:Connect(function(player)
		saveProgression(player)
		playerProgression[player] = nil
	end)

	-- Also re-apply level bonuses on respawn
	Players.PlayerAdded:Connect(function(player)
		player.CharacterAdded:Connect(function()
			local data = playerProgression[player]
			if not data or data.Level <= 1 then return end
			task.defer(function()
				local stats = PlayerDataService and PlayerDataService.GetStats(player)
				if not stats then return end
				local bonusLevels = data.Level - 1
				for stat, bonus in pairs(LEVEL_BONUS) do
					if stats[stat] then
						stats[stat] = stats[stat] + (bonus * bonusLevels)
					end
				end
				local char = player.Character
				if char then
					local humanoid = char:FindFirstChild("Humanoid")
					if humanoid then
						humanoid.MaxHealth = stats.Health
						humanoid.Health = stats.Health
					end
				end
				local statsRemote = Remotes:GetEvent("StatsUpdated")
				if statsRemote then
					statsRemote:FireClient(player, stats)
				end
			end)
		end)
	end)
end

-- Called when any enemy dies. Determines XP based on enemy type.
function CatacombsProgression.OnEnemyKilled(player, enemyId, isBoss)
	local data = playerProgression[player]
	if not data then return end

	local xpGain = MOB_XP_BASE
	if isBoss then
		xpGain = DUNGEON_CLEAR_BASE -- boss kill = large reward
	elseif KEEPER_IDS[enemyId] then
		xpGain = KEEPER_XP_BASE
	end

	data.XP = data.XP + xpGain
	checkLevelUp(player)

	-- Notify client of XP gain
	local xpRemote = Remotes:GetEvent("CatacombsXPGained")
	if xpRemote then
		xpRemote:FireClient(player, {
			XP = data.XP,
			Level = data.Level,
			XPRequired = xpForLevel(data.Level),
			XPGained = xpGain,
		})
	end
end

-- Called when dungeon is fully cleared (boss room done). Floor number scales bonus.
function CatacombsProgression.OnDungeonCleared(player, floorNumber)
	local data = playerProgression[player]
	if not data then return end

	local floor = floorNumber or 1
	local xpGain = math.floor(DUNGEON_CLEAR_BASE * (1 + (floor - 1) * 0.5))

	data.XP = data.XP + xpGain
	checkLevelUp(player)

	local xpRemote = Remotes:GetEvent("CatacombsXPGained")
	if xpRemote then
		xpRemote:FireClient(player, {
			XP = data.XP,
			Level = data.Level,
			XPRequired = xpForLevel(data.Level),
			XPGained = xpGain,
		})
	end

	-- Auto-save on dungeon clear
	saveProgression(player)
end

function CatacombsProgression.GetProgression(player)
	local data = playerProgression[player]
	if not data then return nil end
	return {
		XP = data.XP,
		Level = data.Level,
		XPRequired = xpForLevel(data.Level),
	}
end

return CatacombsProgression
