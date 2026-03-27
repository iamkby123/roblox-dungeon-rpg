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

-- Build lobby hub
local function BuildLobby()
	local lobby = Instance.new("Folder")
	lobby.Name = "Lobby"
	lobby.Parent = workspace

	local function mp(props)
		local p = Instance.new("Part")
		p.Anchored = true
		p.Size = props.Size or Vector3.new(1,1,1)
		p.Position = props.Position or Vector3.new(0,0,0)
		p.Material = props.Material or Enum.Material.Cobblestone
		p.BrickColor = props.BrickColor or BrickColor.new("Medium stone grey")
		p.CanCollide = props.CanCollide ~= false
		p.Transparency = props.Transparency or 0
		p.Name = props.Name or "Part"
		p.Parent = props.Parent or lobby
		return p
	end

	local function makeSign(pos, size, face, title, titleColor, body, bodyColor)
		local s = mp({Name="Sign", Size=size, Position=pos, Material=Enum.Material.SmoothPlastic, BrickColor=BrickColor.new("Really black")})
		local sg = Instance.new("SurfaceGui"); sg.Face = face; sg.Parent = s
		if title then
			local tl = Instance.new("TextLabel")
			tl.Size = UDim2.new(1,0, body and 0.35 or 1, 0); tl.BackgroundTransparency = 1
			tl.Text = title; tl.TextColor3 = titleColor or Color3.fromRGB(255,200,50)
			tl.TextScaled = true; tl.Font = Enum.Font.GothamBold; tl.Parent = sg
		end
		if body then
			local bl = Instance.new("TextLabel")
			bl.Size = UDim2.new(1,0,0.65,0); bl.Position = UDim2.new(0,0,0.35,0)
			bl.BackgroundTransparency = 1; bl.Text = body
			bl.TextColor3 = bodyColor or Color3.fromRGB(200,200,200)
			bl.TextScaled = true; bl.TextWrapped = true; bl.Font = Enum.Font.Gotham; bl.Parent = sg
		end
		return s
	end

	-- ===== MAIN FLOOR =====
	-- Central stone floor
	mp({Name="LobbyFloor", Size=Vector3.new(160,4,160), Position=Vector3.new(0,-2,0), Material=Enum.Material.Cobblestone, BrickColor=BrickColor.new("Medium stone grey")})
	-- Decorative border ring
	mp({Size=Vector3.new(170,1,170), Position=Vector3.new(0,-0.5,0), Material=Enum.Material.Granite, BrickColor=BrickColor.new("Dark grey")})

	-- Spawn
	local spawn = Instance.new("SpawnLocation")
	spawn.Size = Vector3.new(8,1,8); spawn.Position = Vector3.new(0,0.5,10)
	spawn.Anchored = true; spawn.Material = Enum.Material.Neon; spawn.BrickColor = BrickColor.new("Bright blue")
	spawn.Duration = 0; spawn.Parent = lobby

	-- ===== PERIMETER WALLS (low stone walls, visible) =====
	local wallH = 8
	local wallMat = Enum.Material.Brick
	local wallCol = BrickColor.new("Dark stone grey")
	-- Back wall (+Z, behind spawn)
	mp({Size=Vector3.new(160,wallH,4), Position=Vector3.new(0,wallH/2,82), Material=wallMat, BrickColor=wallCol})
	-- Left wall (-X)
	mp({Size=Vector3.new(4,wallH,160), Position=Vector3.new(-82,wallH/2,0), Material=wallMat, BrickColor=wallCol})
	-- Right wall (+X)
	mp({Size=Vector3.new(4,wallH,160), Position=Vector3.new(82,wallH/2,0), Material=wallMat, BrickColor=wallCol})
	-- Front wall (-Z) with gap for portal
	mp({Size=Vector3.new(60,wallH,4), Position=Vector3.new(-50,wallH/2,-82), Material=wallMat, BrickColor=wallCol})
	mp({Size=Vector3.new(60,wallH,4), Position=Vector3.new(50,wallH/2,-82), Material=wallMat, BrickColor=wallCol})

	-- ===== CORNER PILLARS (4 big decorative pillars) =====
	for _, pos in ipairs({
		Vector3.new(-78, 8, -78), Vector3.new(78, 8, -78),
		Vector3.new(-78, 8, 78), Vector3.new(78, 8, 78),
	}) do
		local pillar = mp({Name="CornerPillar", Size=Vector3.new(6,16,6), Position=pos, Material=Enum.Material.Granite, BrickColor=BrickColor.new("Dark grey")})
		-- Cap
		mp({Size=Vector3.new(8,2,8), Position=pos+Vector3.new(0,9,0), Material=Enum.Material.Granite, BrickColor=BrickColor.new("Medium stone grey")})
		-- Torch on top
		local tl = Instance.new("PointLight"); tl.Color=Color3.fromRGB(255,180,80); tl.Range=25; tl.Brightness=1.5; tl.Parent=pillar
		local fi = Instance.new("Fire"); fi.Size=5; fi.Heat=8; fi.Parent=pillar
	end

	-- ===== PORTAL ARCHWAY =====
	-- Archway pillars
	for _, xOff in ipairs({-8, 8}) do
		mp({Name="ArchPillar", Size=Vector3.new(4,20,4), Position=Vector3.new(xOff,10,-40), Material=Enum.Material.Granite, BrickColor=BrickColor.new("Really black")})
	end
	-- Archway top beam
	mp({Name="ArchTop", Size=Vector3.new(20,3,4), Position=Vector3.new(0,21,-40), Material=Enum.Material.Granite, BrickColor=BrickColor.new("Really black")})

	-- Portal (neon, inside archway)
	local portal = mp({Name="DungeonPortal", Size=Vector3.new(12,18,2), Position=Vector3.new(0,10,-40), Material=Enum.Material.Neon, BrickColor=BrickColor.new("Bright violet"), Transparency=0.3})

	-- Portal glow
	local portalLight = Instance.new("PointLight"); portalLight.Color=Color3.fromRGB(150,50,255); portalLight.Range=30; portalLight.Brightness=3; portalLight.Parent=portal
	-- Portal particles
	local particles = Instance.new("ParticleEmitter")
	particles.Color = ColorSequence.new(Color3.fromRGB(150,50,255), Color3.fromRGB(100,0,200))
	particles.Size = NumberSequence.new(0.5,0); particles.Lifetime = NumberRange.new(1,2)
	particles.Rate = 30; particles.Speed = NumberRange.new(1,4); particles.Parent = portal

	-- Proximity prompt
	local prompt = Instance.new("ProximityPrompt")
	prompt.ObjectText = "Dungeon Portal"; prompt.ActionText = "Enter Dungeon"
	prompt.MaxActivationDistance = 14; prompt.HoldDuration = 0.5; prompt.Parent = portal
	prompt.Triggered:Connect(function(player)
		DungeonService.StartDungeon(player)
	end)

	-- ===== TITLE SIGN (above archway) =====
	makeSign(
		Vector3.new(0, 25, -39), Vector3.new(24, 6, 1), Enum.NormalId.Front,
		"DUNGEON RPG", Color3.fromRGB(255, 200, 50),
		"Approach the portal to begin!", Color3.fromRGB(200, 200, 200)
	)

	-- ===== INFO BOARDS =====
	-- Controls board (left side)
	makeSign(
		Vector3.new(-35, 6, -20), Vector3.new(14, 8, 1), Enum.NormalId.Front,
		"CONTROLS", Color3.fromRGB(100, 200, 255),
		"Click = Attack\n[1-4] = Switch Items\n[Tab] = Stats Panel\n[E] = Inventory", Color3.fromRGB(220, 220, 220)
	)

	-- How to Play board (right side)
	makeSign(
		Vector3.new(35, 6, -20), Vector3.new(14, 8, 1), Enum.NormalId.Front,
		"HOW TO PLAY", Color3.fromRGB(255, 150, 50),
		"Clear rooms of enemies\nCollect colored keys\nUnlock matching doors\nBoth branches lead to BOSS!", Color3.fromRGB(220, 220, 220)
	)

	-- ===== TORCHES along walls =====
	for _, pos in ipairs({
		Vector3.new(-40, 6, 78), Vector3.new(0, 6, 78), Vector3.new(40, 6, 78),
		Vector3.new(-78, 6, -40), Vector3.new(-78, 6, 0), Vector3.new(-78, 6, 40),
		Vector3.new(78, 6, -40), Vector3.new(78, 6, 0), Vector3.new(78, 6, 40),
	}) do
		local torch = mp({Name="WallTorch", Size=Vector3.new(1,2,1), Position=pos, Material=Enum.Material.Wood, BrickColor=BrickColor.new("Brown")})
		local tl = Instance.new("PointLight"); tl.Color=Color3.fromRGB(255,180,80); tl.Range=18; tl.Brightness=1; tl.Parent=torch
		local fi = Instance.new("Fire"); fi.Size=3; fi.Heat=5; fi.Parent=torch
	end

	-- ===== AMBIENT LIGHTING =====
	local lighting = game:GetService("Lighting")
	lighting.Ambient = Color3.fromRGB(40, 35, 50)
	lighting.OutdoorAmbient = Color3.fromRGB(40, 35, 50)
	lighting.Brightness = 0.5
	lighting.FogEnd = 800
	lighting.FogStart = 100
	lighting.FogColor = Color3.fromRGB(20, 15, 30)
	lighting.ClockTime = 0 -- midnight for dungeon atmosphere
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
