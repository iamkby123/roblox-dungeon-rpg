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

-- Build lobby hub — outdoor dungeon entrance with dirt, trees, and ruins
local function BuildLobby()
	local lobby = Instance.new("Folder")
	lobby.Name = "Lobby"
	lobby.Parent = workspace

	-- Remove default baseplate to prevent z-fighting
	local baseplate = workspace:FindFirstChild("Baseplate")
	if baseplate then baseplate:Destroy() end

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
		p.Shape = props.Shape or Enum.PartType.Block
		if props.Color then p.Color = props.Color end
		p.Parent = props.Parent or lobby
		return p
	end

	local function makeSign(pos, size, face, title, titleColor, body, bodyColor)
		local s = mp({Name="Sign", Size=size, Position=pos, Material=Enum.Material.Wood, BrickColor=BrickColor.new("Dark orange")})
		local sg = Instance.new("SurfaceGui"); sg.Face = face; sg.Parent = s
		if title then
			local tl = Instance.new("TextLabel")
			tl.Size = UDim2.new(1,0, body and 0.3 or 1, 0); tl.BackgroundTransparency = 1
			tl.Text = title; tl.TextColor3 = titleColor or Color3.fromRGB(255,200,50)
			tl.TextScaled = true; tl.Font = Enum.Font.GothamBold; tl.Parent = sg
		end
		if body then
			local bl = Instance.new("TextLabel")
			bl.Size = UDim2.new(0.9,0,0.65,0); bl.Position = UDim2.new(0.05,0,0.3,0)
			bl.BackgroundTransparency = 1; bl.Text = body
			bl.TextColor3 = bodyColor or Color3.fromRGB(220,220,200)
			bl.TextScaled = true; bl.TextWrapped = true; bl.Font = Enum.Font.Gotham; bl.Parent = sg
		end
		return s
	end

	-- Helper to build a simple tree (trunk + leafy sphere)
	local function makeTree(pos)
		local trunkH = math.random(10, 16)
		local leafR = math.random(8, 14)
		-- Trunk
		mp({Name="Trunk", Size=Vector3.new(3, trunkH, 3), Position=pos + Vector3.new(0, trunkH/2, 0),
			Material=Enum.Material.Wood, BrickColor=BrickColor.new("Dark orange")})
		-- Leaves (ball)
		local leaf = mp({Name="Leaves", Size=Vector3.new(leafR, leafR, leafR),
			Position=pos + Vector3.new(0, trunkH + leafR*0.3, 0),
			Material=Enum.Material.Grass, Color=Color3.fromRGB(30, 60 + math.random(0,30), 20),
			Shape=Enum.PartType.Ball})
		return leaf
	end

	-- Helper to build a rock cluster
	local function makeRock(pos, scale)
		scale = scale or 1
		local s = math.random(3,6) * scale
		mp({Name="Rock", Size=Vector3.new(s, s*0.6, s*0.8),
			Position=pos + Vector3.new(0, s*0.3, 0),
			Material=Enum.Material.Slate, BrickColor=BrickColor.new("Dark stone grey")})
	end

	-- ===== GROUND LAYERS (raised above Y=0 to avoid z-fighting) =====
	-- Large dirt ground
	mp({Name="DirtGround", Size=Vector3.new(250, 6, 250), Position=Vector3.new(0, -2.5, 0),
		Material=Enum.Material.Ground, Color=Color3.fromRGB(80, 55, 35)})
	-- Cobblestone path area (center, slightly raised)
	mp({Name="StonePath", Size=Vector3.new(50, 1, 80), Position=Vector3.new(0, 0.8, -10),
		Material=Enum.Material.Cobblestone, BrickColor=BrickColor.new("Dark stone grey")})
	-- Wider stone clearing around spawn
	mp({Name="SpawnClearing", Size=Vector3.new(70, 0.5, 40), Position=Vector3.new(0, 0.6, 15),
		Material=Enum.Material.Cobblestone, BrickColor=BrickColor.new("Medium stone grey")})

	-- Spawn location (slightly raised on the stone path)
	local spawn = Instance.new("SpawnLocation")
	spawn.Size = Vector3.new(8, 0.5, 8); spawn.Position = Vector3.new(0, 1.2, 15)
	spawn.Anchored = true; spawn.Material = Enum.Material.SmoothPlastic
	spawn.BrickColor = BrickColor.new("Bright blue"); spawn.Transparency = 0.5
	spawn.Duration = 0; spawn.Parent = lobby

	-- ===== DUNGEON ENTRANCE (cave/ruin style) =====
	-- Stone entrance frame — two heavy pillars + lintel
	local entranceZ = -50
	for _, xOff in ipairs({-10, 10}) do
		-- Main pillars (rough stone)
		mp({Name="EntrancePillar", Size=Vector3.new(6, 22, 6),
			Position=Vector3.new(xOff, 11.5, entranceZ),
			Material=Enum.Material.Slate, BrickColor=BrickColor.new("Dark stone grey")})
		-- Mossy accent at base
		mp({Size=Vector3.new(7, 4, 7),
			Position=Vector3.new(xOff, 2.5, entranceZ),
			Material=Enum.Material.Grass, Color=Color3.fromRGB(40, 65, 30)})
	end
	-- Lintel (top beam, cracked stone)
	mp({Name="Lintel", Size=Vector3.new(26, 4, 6),
		Position=Vector3.new(0, 23.5, entranceZ),
		Material=Enum.Material.Slate, BrickColor=BrickColor.new("Dark stone grey")})
	-- Extra rubble on top of lintel (looks crumbling)
	mp({Size=Vector3.new(8, 2, 4), Position=Vector3.new(-5, 26, entranceZ),
		Material=Enum.Material.Slate, BrickColor=BrickColor.new("Dark stone grey")})
	mp({Size=Vector3.new(5, 1.5, 3), Position=Vector3.new(6, 25.8, entranceZ),
		Material=Enum.Material.Slate, BrickColor=BrickColor.new("Medium stone grey")})

	-- Portal (neon glow inside the entrance)
	local portal = mp({Name="DungeonPortal", Size=Vector3.new(14, 20, 2),
		Position=Vector3.new(0, 11, entranceZ),
		Material=Enum.Material.Neon, BrickColor=BrickColor.new("Bright violet"), Transparency=0.3})

	-- Portal glow
	local portalLight = Instance.new("PointLight")
	portalLight.Color = Color3.fromRGB(150, 50, 255); portalLight.Range = 35
	portalLight.Brightness = 3; portalLight.Parent = portal
	-- Portal particles
	local particles = Instance.new("ParticleEmitter")
	particles.Color = ColorSequence.new(Color3.fromRGB(150, 50, 255), Color3.fromRGB(100, 0, 200))
	particles.Size = NumberSequence.new(0.5, 0); particles.Lifetime = NumberRange.new(1, 2)
	particles.Rate = 30; particles.Speed = NumberRange.new(1, 4); particles.Parent = portal

	-- Proximity prompt
	local prompt = Instance.new("ProximityPrompt")
	prompt.ObjectText = "Dungeon Entrance"; prompt.ActionText = "Enter Dungeon"
	prompt.MaxActivationDistance = 14; prompt.HoldDuration = 0.5; prompt.Parent = portal
	prompt.Triggered:Connect(function(player)
		DungeonService.StartDungeon(player)
	end)

	-- Skull/warning sign above entrance
	makeSign(
		Vector3.new(0, 27.5, entranceZ + 3.5), Vector3.new(16, 4, 0.5), Enum.NormalId.Front,
		"DUNGEON RPG", Color3.fromRGB(255, 200, 50),
		"Enter if you dare...", Color3.fromRGB(200, 80, 80)
	)

	-- ===== STONE WALLS flanking entrance (ruined walls) =====
	-- Left ruin wall
	mp({Size=Vector3.new(30, 10, 4), Position=Vector3.new(-35, 5.5, entranceZ),
		Material=Enum.Material.Brick, BrickColor=BrickColor.new("Dark stone grey")})
	mp({Size=Vector3.new(15, 6, 4), Position=Vector3.new(-42, 11, entranceZ),
		Material=Enum.Material.Brick, BrickColor=BrickColor.new("Dark stone grey")})
	-- Right ruin wall
	mp({Size=Vector3.new(30, 10, 4), Position=Vector3.new(35, 5.5, entranceZ),
		Material=Enum.Material.Brick, BrickColor=BrickColor.new("Dark stone grey")})
	mp({Size=Vector3.new(15, 6, 4), Position=Vector3.new(42, 11, entranceZ),
		Material=Enum.Material.Brick, BrickColor=BrickColor.new("Dark stone grey")})

	-- ===== TREES =====
	local treePositions = {
		-- Behind spawn (background forest)
		Vector3.new(-50, 0.5, 50), Vector3.new(-35, 0.5, 60), Vector3.new(-15, 0.5, 55),
		Vector3.new(20, 0.5, 58), Vector3.new(45, 0.5, 52), Vector3.new(60, 0.5, 45),
		Vector3.new(-60, 0.5, 40),
		-- Sides
		Vector3.new(-55, 0.5, 10), Vector3.new(-60, 0.5, -20), Vector3.new(-50, 0.5, -40),
		Vector3.new(55, 0.5, 10), Vector3.new(60, 0.5, -20), Vector3.new(50, 0.5, -40),
		-- Near entrance (framing it)
		Vector3.new(-65, 0.5, -55), Vector3.new(65, 0.5, -55),
		-- Far back
		Vector3.new(-70, 0.5, 70), Vector3.new(0, 0.5, 75), Vector3.new(70, 0.5, 70),
	}
	for _, pos in ipairs(treePositions) do
		makeTree(pos)
	end

	-- ===== ROCKS scattered around =====
	local rockPositions = {
		Vector3.new(-25, 0.5, -45), Vector3.new(22, 0.5, -48), Vector3.new(-8, 0.5, -55),
		Vector3.new(-40, 0.5, 25), Vector3.new(38, 0.5, 30),
		Vector3.new(-55, 0.5, -10), Vector3.new(52, 0.5, -5),
		Vector3.new(-15, 0.5, 40), Vector3.new(15, 0.5, 45),
		-- Rubble near entrance
		Vector3.new(-18, 0.5, -52), Vector3.new(16, 0.5, -47), Vector3.new(0, 0.5, -42),
	}
	for _, pos in ipairs(rockPositions) do
		makeRock(pos, 1 + math.random() * 0.5)
	end

	-- ===== TORCHES along the path =====
	for _, pos in ipairs({
		Vector3.new(-12, 0.5, 0), Vector3.new(12, 0.5, 0),
		Vector3.new(-12, 0.5, -25), Vector3.new(12, 0.5, -25),
	}) do
		-- Torch post
		local post = mp({Name="TorchPost", Size=Vector3.new(2, 8, 2), Position=pos + Vector3.new(0, 4, 0),
			Material=Enum.Material.Wood, BrickColor=BrickColor.new("Dark orange")})
		-- Flame
		local tl = Instance.new("PointLight"); tl.Color=Color3.fromRGB(255,160,50); tl.Range=25; tl.Brightness=2; tl.Parent=post
		local fi = Instance.new("Fire"); fi.Size=4; fi.Heat=6; fi.Parent=post
	end

	-- ===== INFO SIGNS (wooden, on the path) =====
	-- Controls sign post (left of path)
	mp({Size=Vector3.new(2, 6, 2), Position=Vector3.new(-22, 3.5, 5),
		Material=Enum.Material.Wood, BrickColor=BrickColor.new("Dark orange")})
	makeSign(
		Vector3.new(-22, 7.5, 5), Vector3.new(12, 6, 1), Enum.NormalId.Front,
		"CONTROLS", Color3.fromRGB(100, 200, 255),
		"Click = Attack\n[1-4] = Switch Items\n[Tab] = Stats\n[E] = Interact", Color3.fromRGB(220, 220, 200)
	)

	-- How to Play sign post (right of path)
	mp({Size=Vector3.new(2, 6, 2), Position=Vector3.new(22, 3.5, 5),
		Material=Enum.Material.Wood, BrickColor=BrickColor.new("Dark orange")})
	makeSign(
		Vector3.new(22, 7.5, 5), Vector3.new(12, 6, 1), Enum.NormalId.Front,
		"HOW TO PLAY", Color3.fromRGB(255, 150, 50),
		"Clear rooms of enemies\nCollect colored keys\nUnlock matching doors\nDefeat the BOSS!", Color3.fromRGB(220, 220, 200)
	)

	-- ===== INVISIBLE BOUNDARY (prevent falling off) =====
	for _, w in ipairs({
		{Size=Vector3.new(260, 40, 1), Pos=Vector3.new(0, 20, 130)},
		{Size=Vector3.new(260, 40, 1), Pos=Vector3.new(0, 20, -130)},
		{Size=Vector3.new(1, 40, 260), Pos=Vector3.new(130, 20, 0)},
		{Size=Vector3.new(1, 40, 260), Pos=Vector3.new(-130, 20, 0)},
	}) do
		mp({Size=w.Size, Position=w.Pos, Transparency=1, CanCollide=true, Name="Boundary"})
	end

	-- ===== AMBIENT LIGHTING (dark forest night) =====
	local lighting = game:GetService("Lighting")
	lighting.Ambient = Color3.fromRGB(20, 18, 25)
	lighting.OutdoorAmbient = Color3.fromRGB(25, 22, 30)
	lighting.Brightness = 0.3
	lighting.FogEnd = 500
	lighting.FogStart = 80
	lighting.FogColor = Color3.fromRGB(12, 10, 18)
	lighting.ClockTime = 21.5 -- late night, slight moonlight
	lighting.GlobalShadows = true
	lighting.ShadowSoftness = 0.3

	-- Atmosphere for depth/haze
	local atmosphere = Instance.new("Atmosphere")
	atmosphere.Density = 0.3
	atmosphere.Offset = 0.1
	atmosphere.Color = Color3.fromRGB(25, 20, 35)
	atmosphere.Decay = Color3.fromRGB(12, 10, 18)
	atmosphere.Glare = 0
	atmosphere.Haze = 5
	atmosphere.Parent = lighting
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
