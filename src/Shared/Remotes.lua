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
	"DescentStateChanged",
	"EnterHollow",
	"ManaUpdated",
	"InventoryUpdated",
	"DescentTimerSync",
	"FallenState",
	"RevivePlayer",
	"CacheOpened",
	"VocationSelected",
	"DescentScore",
	"BossPhaseChanged",
	"RequestRespawn",
	"RankUp",
	"DelverXPSync",
	"RoomDiscovered",
	"MinimapRoomCleared",
	"MinimapInit",
	"PuzzleSolved",
	"SealUnlocked",
	"UseVocation",
	"VocationUsed",
	"BossDefeated",
	"CacheNearby",
	"DescentComplete",
	"HazardHit",
	"AllWardensFelled",
	"SecretFound",
	"OpenPotionShop",
	"CoinsUpdated",
}

local remoteFunctions = {
	"GetStats",
	"GetDelverProgression",
	"BuyPotion",
	"UsePotion",
}

local isServer = RunService:IsServer()

local folder

if isServer then
	folder = Instance.new("Folder")
	folder.Name = "HollowRemotes"
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
	folder = ReplicatedStorage:WaitForChild("HollowRemotes", 10)
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
