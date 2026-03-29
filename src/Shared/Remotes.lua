local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Remotes = {}

local remoteEvents = {
	"UseSkill",
	"TakeDamage",
	"EnemyDamaged",
	"EnemyDied",
	"ItemPickup",
	"StatsUpdated",
	"DungeonStateChanged",
	"EnterDungeon",
	"ManaUpdated",
	"InventoryUpdated",
	"DungeonTimerSync",
	"PlayerDied",
	"PlayerRevived",
	"ChestOpened",
	"ClassSelected",
	"DungeonScore",
	"BossPhaseChanged",
	"RequestRespawn",
	"CatacombsLevelUp",
	"CatacombsXPSync",
}

local remoteFunctions = {
	"GetStats",
	"GetCatacombsProgression",
}

local isServer = RunService:IsServer()

local folder

if isServer then
	folder = Instance.new("Folder")
	folder.Name = "GameRemotes"
	folder.Parent = ReplicatedStorage

	for _, name in ipairs(remoteEvents) do
		local remote = Instance.new("RemoteEvent")
		remote.Name = name
		remote.Parent = folder
	end

	for _, name in ipairs(remoteFunctions) do
		local remote = Instance.new("RemoteFunction")
		remote.Name = name
		remote.Parent = folder
	end
else
	folder = ReplicatedStorage:WaitForChild("GameRemotes", 10)
end

function Remotes:GetEvent(name)
	if isServer then
		return folder:FindFirstChild(name)
	else
		return folder:WaitForChild(name, 10)
	end
end

function Remotes:GetFunction(name)
	if isServer then
		return folder:FindFirstChild(name)
	else
		return folder:WaitForChild(name, 10)
	end
end

return Remotes
