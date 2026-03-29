local Players = game:GetService("Players")
local DataStoreService = game:GetService("DataStoreService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage:WaitForChild("Remotes"))

local CatacombsProgression = {}

local PlayerDataService -- set via Init

--------------------------------------------------------------------------------
-- CONFIG
--------------------------------------------------------------------------------
local BASE_XP = 100
local EXPONENT = 1.15

local MOB_XP = 10
local KEEPER_XP = 50
local DUNGEON_CLEAR_BASE_XP = 150

local LEVEL_BONUS = {
	Health = 5,
	Defense = 2,
	Strength = 2,
}

--------------------------------------------------------------------------------
-- STATE
--------------------------------------------------------------------------------
local playerProgression = {} -- [player] = { XP = n, Level = n }
local dataStore = nil

pcall(function()
	dataStore = DataStoreService:GetDataStore("CatacombsProgression_v1")
end)

--------------------------------------------------------------------------------
-- XP CURVE
--------------------------------------------------------------------------------
function CatacombsProgression.XPForLevel(level)
	if level <= 0 then return 0 end
	return math.floor(BASE_XP * (EXPONENT ^ level))
end

--------------------------------------------------------------------------------
-- DATASTORE LOAD / SAVE
--------------------------------------------------------------------------------
local function loadData(player)
	if not dataStore then
		return { XP = 0, Level = 1 }
	end

	local success, data = pcall(function()
		return dataStore:GetAsync("player_" .. player.UserId)
	end)

	if success and data then
		return {
			XP = data.XP or 0,
			Level = data.Level or 1,
		}
	end

	return { XP = 0, Level = 1 }
end

local function saveData(player)
	if not dataStore then return end
	local prog = playerProgression[player]
	if not prog then return end

	pcall(function()
		dataStore:SetAsync("player_" .. player.UserId, {
			XP = prog.XP,
			Level = prog.Level,
		})
	end)
end

--------------------------------------------------------------------------------
-- INIT
--------------------------------------------------------------------------------
function CatacombsProgression.Init(playerDataSvc)
	PlayerDataService = playerDataSvc

	Players.PlayerAdded:Connect(function(player)
		local data = loadData(player)
		playerProgression[player] = data

		-- Apply existing level bonuses to stats
		if data.Level > 1 then
			CatacombsProgression._ApplyLevelBonuses(player, data.Level - 1)
		end

		-- Send initial progression to client
		CatacombsProgression._SyncToClient(player)
	end)

	Players.PlayerRemoving:Connect(function(player)
		saveData(player)
		playerProgression[player] = nil
	end)

	-- Handle already-connected players (in case Init runs late)
	for _, player in ipairs(Players:GetPlayers()) do
		if not playerProgression[player] then
			local data = loadData(player)
			playerProgression[player] = data
			if data.Level > 1 then
				CatacombsProgression._ApplyLevelBonuses(player, data.Level - 1)
			end
			CatacombsProgression._SyncToClient(player)
		end
	end

	-- Client can request their current progression
	local getProgRemote = Remotes:GetFunction("GetCatacombsProgression")
	if getProgRemote then
		getProgRemote.OnServerInvoke = function(player)
			local prog = playerProgression[player]
			if not prog then return nil end
			return {
				XP = prog.XP,
				Level = prog.Level,
				XPRequired = CatacombsProgression.XPForLevel(prog.Level),
			}
		end
	end
end

--------------------------------------------------------------------------------
-- AWARD XP
--------------------------------------------------------------------------------
function CatacombsProgression.AwardXP(player, amount)
	local prog = playerProgression[player]
	if not prog then return end

	prog.XP = prog.XP + amount

	-- Check for level-ups (may level multiple times at once)
	local leveled = false
	while prog.XP >= CatacombsProgression.XPForLevel(prog.Level) do
		prog.XP = prog.XP - CatacombsProgression.XPForLevel(prog.Level)
		prog.Level = prog.Level + 1
		leveled = true

		-- Apply stat bonuses for this level
		CatacombsProgression._ApplyLevelBonuses(player, 1)

		-- Fire level-up event to client
		local remote = Remotes:GetEvent("CatacombsLevelUp")
		if remote then
			remote:FireClient(player, {
				Level = prog.Level,
				Bonuses = LEVEL_BONUS,
			})
		end
	end

	-- Sync XP bar to client
	CatacombsProgression._SyncToClient(player)

	-- Save periodically on level-up
	if leveled then
		saveData(player)
	end
end

--------------------------------------------------------------------------------
-- XP HOOKS (called by DungeonService)
--------------------------------------------------------------------------------
function CatacombsProgression.OnMobKill(player, enemyId)
	local EnemyConfig = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("EnemyConfig"))
	local config = EnemyConfig.Enemies[enemyId]
	local xp = MOB_XP
	if config and config.XP then
		xp = config.XP
	end
	CatacombsProgression.AwardXP(player, xp)
end

function CatacombsProgression.OnKeeperKill(player, enemyId)
	local EnemyConfig = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("EnemyConfig"))
	local config = EnemyConfig.Enemies[enemyId]
	local xp = KEEPER_XP
	if config and config.XP then
		xp = config.XP
	end
	CatacombsProgression.AwardXP(player, xp)
end

function CatacombsProgression.OnDungeonClear(player, roomsCleared)
	local floorBonus = DUNGEON_CLEAR_BASE_XP * math.max(1, roomsCleared)
	CatacombsProgression.AwardXP(player, floorBonus)
	saveData(player)
end

--------------------------------------------------------------------------------
-- INTERNAL
--------------------------------------------------------------------------------
function CatacombsProgression._ApplyLevelBonuses(player, levelCount)
	if not PlayerDataService then return end
	local stats = PlayerDataService.GetStats(player)
	if not stats then return end

	for stat, bonus in pairs(LEVEL_BONUS) do
		if stats[stat] then
			stats[stat] = stats[stat] + bonus * levelCount
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
	end

	local remote = Remotes:GetEvent("StatsUpdated")
	if remote then
		remote:FireClient(player, stats)
	end
end

function CatacombsProgression._SyncToClient(player)
	local prog = playerProgression[player]
	if not prog then return end

	local remote = Remotes:GetEvent("CatacombsXPSync")
	if remote then
		remote:FireClient(player, {
			XP = prog.XP,
			Level = prog.Level,
			XPRequired = CatacombsProgression.XPForLevel(prog.Level),
		})
	end
end

function CatacombsProgression.GetProgression(player)
	return playerProgression[player]
end

return CatacombsProgression
