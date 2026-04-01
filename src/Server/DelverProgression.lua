local Players = game:GetService("Players")
local DataStoreService = game:GetService("DataStoreService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage:WaitForChild("Remotes"))

local DelverProgression = {}

local DelverDataService -- set via Init

--------------------------------------------------------------------------------
-- CONFIG
--------------------------------------------------------------------------------
local BASE_XP = 100
local EXPONENT = 1.15
local MAX_RANK = 50

local CREATURE_XP = 10
local WARDEN_XP = 50
local DESCENT_CLEAR_BASE_XP = 150

local RANK_BONUS = {
	Health = 5,
	Defense = 2,
	Strength = 2,
}

--------------------------------------------------------------------------------
-- STATE
--------------------------------------------------------------------------------
local delverProgression = {} -- [player] = { XP = n, Rank = n }
local dataStore = nil

pcall(function()
	dataStore = DataStoreService:GetDataStore("DelverProgression_v1")
end)

--------------------------------------------------------------------------------
-- XP CURVE
--------------------------------------------------------------------------------
function DelverProgression.XPForRank(rank)
	if rank <= 0 then return 0 end
	return math.floor(BASE_XP * (EXPONENT ^ rank))
end

--------------------------------------------------------------------------------
-- DATASTORE LOAD / SAVE
--------------------------------------------------------------------------------
local function loadData(player)
	if not dataStore then
		return { XP = 0, Rank = 1 }
	end

	local success, data = pcall(function()
		return dataStore:GetAsync("delver_" .. player.UserId)
	end)

	if success and data then
		return {
			XP = data.XP or 0,
			Rank = data.Rank or 1,
		}
	end

	return { XP = 0, Rank = 1 }
end

local function saveData(player)
	if not dataStore then return end
	local prog = delverProgression[player]
	if not prog then return end

	pcall(function()
		dataStore:SetAsync("delver_" .. player.UserId, {
			XP = prog.XP,
			Rank = prog.Rank,
		})
	end)
end

--------------------------------------------------------------------------------
-- INIT
--------------------------------------------------------------------------------
function DelverProgression.Init(delverDataSvc)
	DelverDataService = delverDataSvc

	Players.PlayerAdded:Connect(function(player)
		local data = loadData(player)
		delverProgression[player] = data

		if data.Rank > 1 then
			DelverProgression._ApplyRankBonuses(player, data.Rank - 1)
		end

		DelverProgression._SyncToClient(player)
	end)

	Players.PlayerRemoving:Connect(function(player)
		saveData(player)
		delverProgression[player] = nil
	end)

	for _, player in ipairs(Players:GetPlayers()) do
		if not delverProgression[player] then
			local data = loadData(player)
			delverProgression[player] = data
			if data.Rank > 1 then
				DelverProgression._ApplyRankBonuses(player, data.Rank - 1)
			end
			DelverProgression._SyncToClient(player)
		end
	end

	local getProgRemote = Remotes:GetFunction("GetDelverProgression")
	if getProgRemote then
		getProgRemote.OnServerInvoke = function(player)
			local prog = delverProgression[player]
			if not prog then return nil end
			return {
				XP = prog.XP,
				Rank = prog.Rank,
				XPRequired = DelverProgression.XPForRank(prog.Rank),
			}
		end
	end
end

--------------------------------------------------------------------------------
-- AWARD XP
--------------------------------------------------------------------------------
function DelverProgression.AwardXP(player, amount)
	local prog = delverProgression[player]
	if not prog then return end

	prog.XP = prog.XP + amount

	local ranked = false
	while prog.XP >= DelverProgression.XPForRank(prog.Rank) and prog.Rank < MAX_RANK do
		prog.XP = prog.XP - DelverProgression.XPForRank(prog.Rank)
		prog.Rank = prog.Rank + 1
		ranked = true

		DelverProgression._ApplyRankBonuses(player, 1)

		local remote = Remotes:GetEvent("RankUp")
		if remote then
			remote:FireClient(player, {
				Rank = prog.Rank,
				Bonuses = RANK_BONUS,
			})
		end
	end

	DelverProgression._SyncToClient(player)

	if ranked then
		saveData(player)
	end
end

--------------------------------------------------------------------------------
-- XP HOOKS (called by HollowBuilder)
--------------------------------------------------------------------------------
function DelverProgression.OnCreatureKill(player, creatureId)
	local CreatureConfig = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("CreatureConfig"))
	local config = CreatureConfig.Creatures[creatureId]
	local xp = CREATURE_XP
	if config and config.XP then
		xp = config.XP
	end
	DelverProgression.AwardXP(player, xp)
end

function DelverProgression.OnWardenKill(player, creatureId)
	local CreatureConfig = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("CreatureConfig"))
	local config = CreatureConfig.Creatures[creatureId]
	local xp = WARDEN_XP
	if config and config.XP then
		xp = config.XP
	end
	DelverProgression.AwardXP(player, xp)
end

function DelverProgression.OnDescentClear(player, chambersCleared)
	local floorBonus = DESCENT_CLEAR_BASE_XP * math.max(1, chambersCleared)
	DelverProgression.AwardXP(player, floorBonus)
	saveData(player)
end

--------------------------------------------------------------------------------
-- INTERNAL
--------------------------------------------------------------------------------
function DelverProgression._ApplyRankBonuses(player, rankCount)
	if not DelverDataService then return end
	local stats = DelverDataService.GetStats(player)
	if not stats then return end

	for stat, bonus in pairs(RANK_BONUS) do
		if stats[stat] then
			stats[stat] = stats[stat] + bonus * rankCount
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
	end

	local remote = Remotes:GetEvent("StatsUpdated")
	if remote then
		remote:FireClient(player, stats)
	end
end

function DelverProgression._SyncToClient(player)
	local prog = delverProgression[player]
	if not prog then return end

	local remote = Remotes:GetEvent("DelverXPSync")
	if remote then
		remote:FireClient(player, {
			XP = prog.XP,
			Rank = prog.Rank,
			XPRequired = DelverProgression.XPForRank(prog.Rank),
		})
	end
end

function DelverProgression.GetProgression(player)
	return delverProgression[player]
end

return DelverProgression
