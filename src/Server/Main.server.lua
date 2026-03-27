local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Initialize remotes first (creates RemoteEvents/Functions)
local Remotes = require(ReplicatedStorage:WaitForChild("Remotes"))

-- Require all services
local PlayerDataService = require(script.Parent:WaitForChild("PlayerDataService"))
local CombatService = require(script.Parent:WaitForChild("CombatService"))
local SkillService = require(script.Parent:WaitForChild("SkillService"))
local LootService = require(script.Parent:WaitForChild("LootService"))
local EnemyAI = require(script.Parent:WaitForChild("EnemyAI"))
local DungeonService = require(script.Parent:WaitForChild("DungeonService"))

-- Initialize services with dependencies
PlayerDataService.Init()
CombatService.Init(PlayerDataService, DungeonService)
SkillService.Init(CombatService)
LootService.Init(PlayerDataService)
EnemyAI.Init(CombatService, DungeonService)
DungeonService.Init(EnemyAI, LootService, PlayerDataService)

-- Start enemy AI loop
EnemyAI.StartLoop()

-- Build lobby
local function BuildLobby()
	local lobby = Instance.new("Folder")
	lobby.Name = "Lobby"
	lobby.Parent = workspace

	-- Floor
	local floor = Instance.new("Part")
	floor.Name = "LobbyFloor"
	floor.Size = Vector3.new(100, 4, 100)
	floor.Position = Vector3.new(0, -2, 0)
	floor.Anchored = true
	floor.Material = Enum.Material.Cobblestone
	floor.BrickColor = BrickColor.new("Medium stone grey")
	floor.Parent = lobby

	-- Spawn location
	local spawn = Instance.new("SpawnLocation")
	spawn.Size = Vector3.new(6, 1, 6)
	spawn.Position = Vector3.new(0, 0.5, 0)
	spawn.Anchored = true
	spawn.Material = Enum.Material.SmoothPlastic
	spawn.BrickColor = BrickColor.new("Bright blue")
	spawn.Duration = 0 -- no forcefield/invincibility
	spawn.Parent = lobby

	-- Dungeon portal
	local portal = Instance.new("Part")
	portal.Name = "DungeonPortal"
	portal.Size = Vector3.new(8, 12, 2)
	portal.Position = Vector3.new(0, 6, -30)
	portal.Anchored = true
	portal.Material = Enum.Material.Neon
	portal.BrickColor = BrickColor.new("Bright violet")
	portal.Transparency = 0.3
	portal.Parent = lobby

	-- Portal glow
	local portalLight = Instance.new("PointLight")
	portalLight.Color = Color3.fromRGB(150, 50, 255)
	portalLight.Range = 20
	portalLight.Brightness = 2
	portalLight.Parent = portal

	-- Particle effect on portal
	local particles = Instance.new("ParticleEmitter")
	particles.Color = ColorSequence.new(Color3.fromRGB(150, 50, 255), Color3.fromRGB(100, 0, 200))
	particles.Size = NumberSequence.new(0.5, 0)
	particles.Lifetime = NumberRange.new(1, 2)
	particles.Rate = 20
	particles.Speed = NumberRange.new(1, 3)
	particles.Parent = portal

	-- Proximity prompt
	local prompt = Instance.new("ProximityPrompt")
	prompt.ObjectText = "Dungeon Portal"
	prompt.ActionText = "Enter Dungeon"
	prompt.MaxActivationDistance = 12
	prompt.HoldDuration = 0.5
	prompt.Parent = portal

	prompt.Triggered:Connect(function(player)
		DungeonService.StartDungeon(player)
	end)

	-- Portal pillars
	for _, xOffset in ipairs({ -5, 5 }) do
		local pillar = Instance.new("Part")
		pillar.Name = "Pillar"
		pillar.Size = Vector3.new(3, 14, 3)
		pillar.Position = Vector3.new(xOffset, 7, -30)
		pillar.Anchored = true
		pillar.Material = Enum.Material.Granite
		pillar.BrickColor = BrickColor.new("Dark grey")
		pillar.Parent = lobby

		local torchLight = Instance.new("PointLight")
		torchLight.Color = Color3.fromRGB(255, 180, 80)
		torchLight.Range = 15
		torchLight.Brightness = 1
		torchLight.Parent = pillar

		local fire = Instance.new("Fire")
		fire.Size = 4
		fire.Heat = 5
		fire.Parent = pillar
	end

	-- Invisible walls around lobby
	local wallHeight = 20
	local walls = {
		{ Size = Vector3.new(100, wallHeight, 1), Pos = Vector3.new(0, wallHeight / 2, 50) },
		{ Size = Vector3.new(100, wallHeight, 1), Pos = Vector3.new(0, wallHeight / 2, -50) },
		{ Size = Vector3.new(1, wallHeight, 100), Pos = Vector3.new(50, wallHeight / 2, 0) },
		{ Size = Vector3.new(1, wallHeight, 100), Pos = Vector3.new(-50, wallHeight / 2, 0) },
	}

	for _, wallData in ipairs(walls) do
		local wall = Instance.new("Part")
		wall.Size = wallData.Size
		wall.Position = wallData.Pos
		wall.Anchored = true
		wall.Transparency = 1
		wall.CanCollide = true
		wall.Parent = lobby
	end

	-- Title sign
	local sign = Instance.new("Part")
	sign.Name = "TitleSign"
	sign.Size = Vector3.new(20, 6, 1)
	sign.Position = Vector3.new(0, 15, -28)
	sign.Anchored = true
	sign.Material = Enum.Material.SmoothPlastic
	sign.BrickColor = BrickColor.new("Really black")
	sign.Parent = lobby

	local signGui = Instance.new("SurfaceGui")
	signGui.Face = Enum.NormalId.Front
	signGui.Parent = sign

	local titleLabel = Instance.new("TextLabel")
	titleLabel.Size = UDim2.new(1, 0, 0.6, 0)
	titleLabel.BackgroundTransparency = 1
	titleLabel.Text = "DUNGEON RPG"
	titleLabel.TextColor3 = Color3.fromRGB(255, 200, 50)
	titleLabel.TextScaled = true
	titleLabel.Font = Enum.Font.GothamBold
	titleLabel.Parent = signGui

	local subtitleLabel = Instance.new("TextLabel")
	subtitleLabel.Size = UDim2.new(1, 0, 0.4, 0)
	subtitleLabel.Position = UDim2.new(0, 0, 0.6, 0)
	subtitleLabel.BackgroundTransparency = 1
	subtitleLabel.Text = "Walk to the portal to begin"
	subtitleLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
	subtitleLabel.TextScaled = true
	subtitleLabel.Font = Enum.Font.Gotham
	subtitleLabel.Parent = signGui
end

BuildLobby()

-- Listen for early respawn requests
local requestRespawn = Remotes:GetEvent("RequestRespawn")
if requestRespawn then
	requestRespawn.OnServerEvent:Connect(function(player)
		DungeonService.RequestEarlyRespawn(player)
	end)
end

-- Cleanup on player leaving
Players.PlayerRemoving:Connect(function(player)
	DungeonService.CleanupPlayer(player)
	CombatService.CleanupPlayer(player)
end)

print("[DungeonRPG] Server initialized!")
