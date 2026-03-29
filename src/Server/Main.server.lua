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
local CatacombsProgression = require(script.Parent:WaitForChild("CatacombsProgression"))
local MobSpawner = require(script.Parent:WaitForChild("MobSpawner"))
local PuzzleSystem = require(script.Parent:WaitForChild("PuzzleSystem"))

-- Initialize services with dependencies
PlayerDataService.Init()
CatacombsProgression.Init(PlayerDataService)
CombatService.Init(PlayerDataService, DungeonService, CatacombsProgression)
SkillService.Init(CombatService)
LootService.Init(PlayerDataService)
EnemyAI.Init(CombatService, DungeonService)
PuzzleSystem.Init(DungeonService)
DungeonService.Init(EnemyAI, LootService, PlayerDataService, CatacombsProgression, PuzzleSystem)
MobSpawner.Init(DungeonService, EnemyAI)

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
	mp({Name="DirtGround", Size=Vector3.new(300, 6, 300), Position=Vector3.new(0, -2.5, 0),
		Material=Enum.Material.Ground, Color=Color3.fromRGB(80, 55, 35)})
	-- Worn cobblestone path leading to cave
	mp({Name="StonePath", Size=Vector3.new(24, 0.5, 90), Position=Vector3.new(0, 0.8, -15),
		Material=Enum.Material.Cobblestone, BrickColor=BrickColor.new("Dark stone grey")})
	-- Wider clearing around spawn (campsite feel)
	mp({Name="SpawnClearing", Size=Vector3.new(60, 0.5, 50), Position=Vector3.new(0, 0.6, 20),
		Material=Enum.Material.Ground, Color=Color3.fromRGB(65, 50, 30)})
	-- Stone circle around campfire/spawn
	mp({Name="StoneCircle", Size=Vector3.new(20, 0.3, 20), Position=Vector3.new(0, 0.85, 20),
		Material=Enum.Material.Cobblestone, BrickColor=BrickColor.new("Medium stone grey")})

	-- Spawn location (hidden inside campsite)
	local spawn = Instance.new("SpawnLocation")
	spawn.Size = Vector3.new(8, 0.2, 8); spawn.Position = Vector3.new(0, 1.1, 20)
	spawn.Anchored = true; spawn.Material = Enum.Material.Cobblestone
	spawn.BrickColor = BrickColor.new("Medium stone grey"); spawn.Transparency = 1
	spawn.Duration = 0; spawn.Parent = lobby

	-- ===== CAMPFIRE at spawn =====
	-- Fire pit rocks (ring of small rocks)
	for i = 0, 7 do
		local angle = (i / 8) * math.pi * 2
		local rx, rz = math.cos(angle) * 3, math.sin(angle) * 3
		mp({Name="FirePitRock", Size=Vector3.new(1.5, 1, 1.5),
			Position=Vector3.new(rx, 1.2, 20 + rz),
			Material=Enum.Material.Slate, BrickColor=BrickColor.new("Dark stone grey")})
	end
	-- Campfire
	local campfire = mp({Name="Campfire", Size=Vector3.new(2, 1, 2), Position=Vector3.new(0, 1.2, 20),
		Material=Enum.Material.Wood, BrickColor=BrickColor.new("Reddish brown")})
	local cfLight = Instance.new("PointLight"); cfLight.Color=Color3.fromRGB(255,140,40)
	cfLight.Range=40; cfLight.Brightness=3; cfLight.Parent=campfire
	local cfFire = Instance.new("Fire"); cfFire.Size=8; cfFire.Heat=12; cfFire.Parent=campfire

	-- Sitting logs around campfire
	for _, logData in ipairs({
		{pos=Vector3.new(-5, 1, 18), size=Vector3.new(6,1.5,2)},
		{pos=Vector3.new(5, 1, 22), size=Vector3.new(6,1.5,2)},
		{pos=Vector3.new(0, 1, 25), size=Vector3.new(5,1.5,2)},
	}) do
		mp({Name="SittingLog", Size=logData.size, Position=logData.pos,
			Material=Enum.Material.Wood, BrickColor=BrickColor.new("Dark orange")})
	end

	-- ===== CAVE ENTRANCE with iron door =====
	local entranceZ = -55
	local caveW = 18 -- cave opening width
	local caveH = 16 -- cave opening height

	-- Cave rock face (big rock wall the cave is carved into)
	mp({Name="CaveFace", Size=Vector3.new(80, 30, 16), Position=Vector3.new(0, 15.5, entranceZ - 6),
		Material=Enum.Material.Slate, Color=Color3.fromRGB(50, 45, 40)})
	-- Top of cave face (rounded boulders on top)
	for _, bx in ipairs({-25, -10, 5, 18, 30}) do
		local bh = math.random(6, 12)
		mp({Size=Vector3.new(math.random(10,16), bh, 14), Position=Vector3.new(bx, 30 + bh/2, entranceZ - 6),
			Material=Enum.Material.Slate, Color=Color3.fromRGB(55, 50, 42)})
	end

	-- Cave opening (dark void behind door)
	mp({Name="CaveVoid", Size=Vector3.new(caveW, caveH, 8), Position=Vector3.new(0, caveH/2 + 0.5, entranceZ - 4),
		Material=Enum.Material.SmoothPlastic, Color=Color3.fromRGB(5, 3, 8)})

	-- Cave arch — rough stone framing the opening
	-- Left side
	mp({Name="CaveArchL", Size=Vector3.new(6, caveH + 4, 10), Position=Vector3.new(-caveW/2 - 1, caveH/2 + 0.5, entranceZ),
		Material=Enum.Material.Slate, Color=Color3.fromRGB(45, 40, 35)})
	-- Right side
	mp({Name="CaveArchR", Size=Vector3.new(6, caveH + 4, 10), Position=Vector3.new(caveW/2 + 1, caveH/2 + 0.5, entranceZ),
		Material=Enum.Material.Slate, Color=Color3.fromRGB(45, 40, 35)})
	-- Top arch
	mp({Name="CaveArchTop", Size=Vector3.new(caveW + 12, 6, 10), Position=Vector3.new(0, caveH + 3.5, entranceZ),
		Material=Enum.Material.Slate, Color=Color3.fromRGB(45, 40, 35)})
	-- Mossy drip on arch sides
	for _, xOff in ipairs({-caveW/2 - 1, caveW/2 + 1}) do
		mp({Size=Vector3.new(4, 5, 6), Position=Vector3.new(xOff, 2.5, entranceZ + 2),
			Material=Enum.Material.Grass, Color=Color3.fromRGB(35, 60, 25)})
	end

	-- ===== IRON DOOR =====
	local door = mp({Name="DungeonDoor", Size=Vector3.new(caveW, caveH, 1.5),
		Position=Vector3.new(0, caveH/2 + 0.5, entranceZ + 2),
		Material=Enum.Material.DiamondPlate, Color=Color3.fromRGB(60, 55, 50)})
	-- Door rivets/bars (horizontal iron bars across door)
	for _, barY in ipairs({4, 8, 12}) do
		mp({Name="DoorBar", Size=Vector3.new(caveW - 2, 0.8, 2),
			Position=Vector3.new(0, barY + 0.5, entranceZ + 3),
			Material=Enum.Material.Metal, Color=Color3.fromRGB(40, 38, 35)})
	end
	-- Door ring/handle
	mp({Name="DoorHandle", Size=Vector3.new(2, 2, 1), Position=Vector3.new(4, 8, entranceZ + 3.5),
		Material=Enum.Material.Metal, Color=Color3.fromRGB(80, 70, 55)})

	-- Proximity prompt on door handle (visible, not blocked by bars)
	local prompt = Instance.new("ProximityPrompt")
	prompt.ObjectText = "Iron Door"; prompt.ActionText = "Enter Dungeon"
	prompt.MaxActivationDistance = 20; prompt.HoldDuration = 0.5
	prompt.RequiresLineOfSight = false
	prompt.Parent = door
	prompt.Triggered:Connect(function(player)
		DungeonService.StartDungeon(player)
	end)

	-- Eerie glow seeping through door cracks
	local glowLight = Instance.new("PointLight")
	glowLight.Color = Color3.fromRGB(120, 40, 200); glowLight.Range = 20
	glowLight.Brightness = 1.5; glowLight.Parent = door
	-- Smoke/mist from cave
	local smoke = Instance.new("Smoke")
	smoke.Size = 6; smoke.Opacity = 0.15; smoke.RiseVelocity = 2
	smoke.Color = Color3.fromRGB(80, 60, 100); smoke.Parent = door

	-- Warning sign above cave
	makeSign(
		Vector3.new(0, caveH + 8, entranceZ + 5), Vector3.new(18, 4, 0.5), Enum.NormalId.Front,
		"DUNGEON RPG", Color3.fromRGB(255, 200, 50),
		"Enter if you dare...", Color3.fromRGB(200, 80, 80)
	)

	-- ===== CAVE WALLS flanking entrance (rock formations) =====
	-- Left rock formation
	mp({Size=Vector3.new(20, 12, 12), Position=Vector3.new(-30, 6.5, entranceZ - 2),
		Material=Enum.Material.Slate, Color=Color3.fromRGB(50, 45, 38)})
	mp({Size=Vector3.new(12, 8, 10), Position=Vector3.new(-38, 4.5, entranceZ),
		Material=Enum.Material.Slate, Color=Color3.fromRGB(55, 48, 40)})
	-- Right rock formation
	mp({Size=Vector3.new(20, 12, 12), Position=Vector3.new(30, 6.5, entranceZ - 2),
		Material=Enum.Material.Slate, Color=Color3.fromRGB(50, 45, 38)})
	mp({Size=Vector3.new(12, 8, 10), Position=Vector3.new(38, 4.5, entranceZ),
		Material=Enum.Material.Slate, Color=Color3.fromRGB(55, 48, 40)})

	-- ===== TREES (more, denser forest) =====
	local treePositions = {
		-- Behind spawn (dense background forest)
		Vector3.new(-50, 0.5, 50), Vector3.new(-35, 0.5, 60), Vector3.new(-15, 0.5, 55),
		Vector3.new(20, 0.5, 58), Vector3.new(45, 0.5, 52), Vector3.new(60, 0.5, 45),
		Vector3.new(-60, 0.5, 40), Vector3.new(-25, 0.5, 65), Vector3.new(35, 0.5, 68),
		Vector3.new(0, 0.5, 72), Vector3.new(-45, 0.5, 70), Vector3.new(55, 0.5, 65),
		-- Sides (thick tree line)
		Vector3.new(-55, 0.5, 10), Vector3.new(-60, 0.5, -10), Vector3.new(-50, 0.5, -30),
		Vector3.new(-65, 0.5, 25), Vector3.new(-48, 0.5, -15), Vector3.new(-58, 0.5, 0),
		Vector3.new(55, 0.5, 10), Vector3.new(60, 0.5, -10), Vector3.new(50, 0.5, -30),
		Vector3.new(65, 0.5, 25), Vector3.new(48, 0.5, -15), Vector3.new(58, 0.5, 0),
		-- Near cave entrance (framing it, overgrown)
		Vector3.new(-55, 0.5, -50), Vector3.new(55, 0.5, -50),
		Vector3.new(-48, 0.5, -60), Vector3.new(48, 0.5, -60),
		-- Far back
		Vector3.new(-70, 0.5, 75), Vector3.new(0, 0.5, 80), Vector3.new(70, 0.5, 75),
		Vector3.new(-80, 0.5, 55), Vector3.new(80, 0.5, 55),
	}
	for _, pos in ipairs(treePositions) do
		makeTree(pos)
	end

	-- ===== ROCKS scattered around =====
	local rockPositions = {
		-- Near cave
		Vector3.new(-20, 0.5, -48), Vector3.new(18, 0.5, -50), Vector3.new(-8, 0.5, -45),
		Vector3.new(8, 0.5, -42), Vector3.new(-15, 0.5, -58), Vector3.new(14, 0.5, -55),
		-- Around path
		Vector3.new(-16, 0.5, 0), Vector3.new(14, 0.5, -5), Vector3.new(-18, 0.5, -20),
		Vector3.new(16, 0.5, -18),
		-- Around campsite
		Vector3.new(-30, 0.5, 25), Vector3.new(28, 0.5, 28), Vector3.new(-25, 0.5, 12),
		Vector3.new(22, 0.5, 15), Vector3.new(-10, 0.5, 35), Vector3.new(12, 0.5, 38),
	}
	for _, pos in ipairs(rockPositions) do
		makeRock(pos, 1 + math.random() * 0.5)
	end

	-- ===== TORCHES (lots, well lit area) =====
	local function makeTorch(pos, range, size)
		range = range or 30
		size = size or 4
		local post = mp({Name="TorchPost", Size=Vector3.new(2, 8, 2), Position=pos + Vector3.new(0, 4, 0),
			Material=Enum.Material.Wood, BrickColor=BrickColor.new("Dark orange")})
		local tl = Instance.new("PointLight"); tl.Color=Color3.fromRGB(255,160,50)
		tl.Range=range; tl.Brightness=2.5; tl.Parent=post
		local fi = Instance.new("Fire"); fi.Size=size; fi.Heat=8; fi.Parent=post
		return post
	end

	-- Path torches (both sides, all the way to cave)
	makeTorch(Vector3.new(-14, 0.5, 35))     -- behind campfire
	makeTorch(Vector3.new(14, 0.5, 35))
	makeTorch(Vector3.new(-14, 0.5, 10))      -- near spawn
	makeTorch(Vector3.new(14, 0.5, 10))
	makeTorch(Vector3.new(-14, 0.5, -5))       -- mid path
	makeTorch(Vector3.new(14, 0.5, -5))
	makeTorch(Vector3.new(-14, 0.5, -20))      -- closer to cave
	makeTorch(Vector3.new(14, 0.5, -20))
	makeTorch(Vector3.new(-14, 0.5, -35))      -- near cave
	makeTorch(Vector3.new(14, 0.5, -35))

	-- Cave entrance torches (bright, flanking the door)
	makeTorch(Vector3.new(-12, 0.5, -48), 35, 5)
	makeTorch(Vector3.new(12, 0.5, -48), 35, 5)

	-- Campsite perimeter torches
	makeTorch(Vector3.new(-20, 0.5, 30))
	makeTorch(Vector3.new(20, 0.5, 30))
	makeTorch(Vector3.new(-20, 0.5, 10))
	makeTorch(Vector3.new(20, 0.5, 10))

	-- Extra forest edge torches for visibility
	makeTorch(Vector3.new(-35, 0.5, 20), 25)
	makeTorch(Vector3.new(35, 0.5, 20), 25)
	makeTorch(Vector3.new(-35, 0.5, -10), 25)
	makeTorch(Vector3.new(35, 0.5, -10), 25)
	makeTorch(Vector3.new(-35, 0.5, -40), 25)
	makeTorch(Vector3.new(35, 0.5, -40), 25)

	-- ===== INFO SIGNS (wooden, near campsite) =====
	-- Controls sign post (left of camp)
	mp({Size=Vector3.new(2, 6, 2), Position=Vector3.new(-18, 3.5, 8),
		Material=Enum.Material.Wood, BrickColor=BrickColor.new("Dark orange")})
	makeSign(
		Vector3.new(-18, 7.5, 8), Vector3.new(12, 6, 1), Enum.NormalId.Front,
		"CONTROLS", Color3.fromRGB(100, 200, 255),
		"Click = Attack\n[1-4] = Switch Items\n[Tab] = Stats\n[E] = Interact", Color3.fromRGB(220, 220, 200)
	)

	-- How to Play sign post (right of camp)
	mp({Size=Vector3.new(2, 6, 2), Position=Vector3.new(18, 3.5, 8),
		Material=Enum.Material.Wood, BrickColor=BrickColor.new("Dark orange")})
	makeSign(
		Vector3.new(18, 7.5, 8), Vector3.new(12, 6, 1), Enum.NormalId.Front,
		"HOW TO PLAY", Color3.fromRGB(255, 150, 50),
		"Clear rooms of enemies\nCollect colored keys\nUnlock matching doors\nDefeat the BOSS!", Color3.fromRGB(220, 220, 200)
	)

	-- ===== INVISIBLE BOUNDARY (prevent falling off) =====
	for _, w in ipairs({
		{Size=Vector3.new(300, 40, 1), Pos=Vector3.new(0, 20, 150)},
		{Size=Vector3.new(300, 40, 1), Pos=Vector3.new(0, 20, -150)},
		{Size=Vector3.new(1, 40, 300), Pos=Vector3.new(150, 20, 0)},
		{Size=Vector3.new(1, 40, 300), Pos=Vector3.new(-150, 20, 0)},
	}) do
		mp({Size=w.Size, Position=w.Pos, Transparency=1, CanCollide=true, Name="Boundary"})
	end

	-- ===== AMBIENT LIGHTING (torchlit forest night, brighter) =====
	local lighting = game:GetService("Lighting")
	lighting.Ambient = Color3.fromRGB(35, 30, 40)
	lighting.OutdoorAmbient = Color3.fromRGB(40, 35, 45)
	lighting.Brightness = 0.5
	lighting.FogEnd = 600
	lighting.FogStart = 120
	lighting.FogColor = Color3.fromRGB(15, 12, 22)
	lighting.ClockTime = 21.5 -- late night, slight moonlight
	lighting.GlobalShadows = true
	lighting.ShadowSoftness = 0.3

	-- Atmosphere for depth/haze
	local atmosphere = Instance.new("Atmosphere")
	atmosphere.Density = 0.25
	atmosphere.Offset = 0.1
	atmosphere.Color = Color3.fromRGB(30, 25, 40)
	atmosphere.Decay = Color3.fromRGB(15, 12, 20)
	atmosphere.Glare = 0
	atmosphere.Haze = 4
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
