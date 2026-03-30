local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local HollowConfig = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("HollowConfig"))
local CreatureConfig = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("CreatureConfig"))
local VocationSystem = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("VocationSystem"))
local RunGrading = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("RunGrading"))
local Remotes = require(ReplicatedStorage:WaitForChild("Remotes"))

local HollowBuilder = {}

local CreatureAI
local LootSystem
local DelverDataService
local DelverProgression
local PuzzleEncounters

local activeDungeons = {}

function HollowBuilder.Init(enemyAISvc, lootSvc, playerDataSvc, catacombsSvc, puzzleSvc)
	CreatureAI = enemyAISvc
	LootSystem = lootSvc
	DelverDataService = playerDataSvc
	DelverProgression = catacombsSvc
	PuzzleEncounters = puzzleSvc
end

--------------------------------------------------------------------------------
-- HELPER: Create a part
--------------------------------------------------------------------------------
local function makePart(props)
	local part = Instance.new("Part")
	part.Anchored = true
	part.Size = props.Size or Vector3.new(1,1,1)
	part.Position = props.Position or Vector3.new(0,0,0)
	part.Material = props.Material or Enum.Material.Cobblestone
	part.BrickColor = props.BrickColor or BrickColor.new("Medium stone grey")
	part.CanCollide = props.CanCollide ~= false
	part.Transparency = props.Transparency or 0
	part.Name = props.Name or "Part"
	if props.CFrame then part.CFrame = props.CFrame end
	part.Parent = props.Parent
	return part
end

--------------------------------------------------------------------------------
-- HELPER: Get room config by ID
--------------------------------------------------------------------------------
local function getRoomById(roomId)
	for _, r in ipairs(HollowConfig.Chambers) do
		if r.RoomId == roomId then return r end
	end
	return nil
end

--------------------------------------------------------------------------------
-- HELPER: Get room array index by RoomId
--------------------------------------------------------------------------------
local function getRoomIndex(roomId)
	for i, r in ipairs(HollowConfig.Chambers) do
		if r.RoomId == roomId then return i end
	end
	return nil
end

--------------------------------------------------------------------------------
-- GRID POSITION: compute world origin from Grid = {col, row}
--------------------------------------------------------------------------------
local function gridToWorld(col, row)
	local startOffset = HollowConfig.StartOffset
	local spacing = HollowConfig.GridSpacing
	return Vector3.new(
		startOffset.X + col * spacing,
		startOffset.Y,
		startOffset.Z - row * spacing -- negative Z = deeper
	)
end

--------------------------------------------------------------------------------
-- AUTO-COMPUTE ROOM OPENINGS FROM CORRIDORS
--------------------------------------------------------------------------------
local function computeRoomOpenings()
	local openings = {} -- openings[roomId] = { Front=true, Right=true, ... }

	-- Initialize empty tables for all rooms
	for _, r in ipairs(HollowConfig.Chambers) do
		openings[r.RoomId] = {}
	end

	-- Add "Front" opening to the entrance room (Room 1) for the entrance corridor
	local entranceRoomId = HollowConfig.EntranceRoom or 1
	if openings[entranceRoomId] then
		openings[entranceRoomId]["Front"] = true
	end

	-- Derive openings from corridor definitions
	for _, corr in ipairs(HollowConfig.Corridors) do
		if corr.Dir == "Right" then
			-- FromRoom gets "Right" opening, ToRoom gets "Left" opening
			if openings[corr.FromRoom] then openings[corr.FromRoom]["Right"] = true end
			if openings[corr.ToRoom] then openings[corr.ToRoom]["Left"] = true end
		elseif corr.Dir == "Down" then
			-- FromRoom gets "Back" opening, ToRoom gets "Front" opening
			if openings[corr.FromRoom] then openings[corr.FromRoom]["Back"] = true end
			if openings[corr.ToRoom] then openings[corr.ToRoom]["Front"] = true end
		end
	end

	return openings
end

--------------------------------------------------------------------------------
-- MINIMAP HELPERS: fire discovery/clear events to the client minimap
--------------------------------------------------------------------------------
local function fireMinimapDiscover(player, roomIndex)
	local roomConfig = HollowConfig.Chambers[roomIndex]
	if not roomConfig then return end
	local discoverRemote = Remotes:GetEvent("RoomDiscovered")
	if discoverRemote then
		local row1 = roomConfig.Grid[2] + 1
		local col1 = roomConfig.Grid[1] + 1
		discoverRemote:FireClient(player, row1, col1)
	end
end

local function fireMinimapCleared(player, roomIndex)
	local roomConfig = HollowConfig.Chambers[roomIndex]
	if not roomConfig then return end
	local clearRemote = Remotes:GetEvent("MinimapRoomCleared")
	if clearRemote then
		local row1 = roomConfig.Grid[2] + 1
		local col1 = roomConfig.Grid[1] + 1
		clearRemote:FireClient(player, row1, col1)
	end
end

--------------------------------------------------------------------------------
-- BUILD ENTRANCE ROOM
--------------------------------------------------------------------------------
function HollowBuilder.BuildEntranceRoom(parent, origin)
	local f = Instance.new("Folder")
	f.Name = "Entrance"
	f.Parent = parent

	local w, h, d, t = 50, 18, 50, 4
	local mat = Enum.Material.Brick
	local col = BrickColor.new("Dark stone grey")

	makePart({Name="Floor", Size=Vector3.new(w,t,d), Position=origin-Vector3.new(0,t/2,0), Material=Enum.Material.Cobblestone, BrickColor=BrickColor.new("Medium stone grey"), Parent=f})
	local ceil = makePart({Name="Ceiling", Size=Vector3.new(w,t,d), Position=origin+Vector3.new(0,h+t/2,0), Material=mat, BrickColor=col, Parent=f})

	-- Walls: solid left, right, back. Front is open (connects to Room 1)
	makePart({Size=Vector3.new(t,h,d), Position=origin+Vector3.new(-w/2-t/2,h/2,0), Material=mat, BrickColor=col, Parent=f})
	makePart({Size=Vector3.new(t,h,d), Position=origin+Vector3.new(w/2+t/2,h/2,0), Material=mat, BrickColor=col, Parent=f})
	makePart({Size=Vector3.new(w+t*2,h,t), Position=origin+Vector3.new(0,h/2,d/2+t/2), Material=mat, BrickColor=col, Parent=f})

	-- Lighting (dimmer entrance)
	local light = Instance.new("PointLight"); light.Color=Color3.fromRGB(255,200,120); light.Range=35; light.Brightness=0.8; light.Parent=ceil

	-- Torches
	for _, xOff in ipairs({-w/4, w/4}) do
		local torch = makePart({Name="Torch", Size=Vector3.new(1,2,1), Position=origin+Vector3.new(xOff,h*0.6,0), Material=Enum.Material.Wood, BrickColor=BrickColor.new("Brown"), Parent=f})
		local tl = Instance.new("PointLight"); tl.Color=Color3.fromRGB(255,150,50); tl.Range=12; tl.Brightness=0.7; tl.Parent=torch
		local fi = Instance.new("Fire"); fi.Size=2; fi.Heat=4; fi.Parent=torch
	end

	-- Info sign
	local sign = makePart({Name="InfoSign", Size=Vector3.new(12,5,1), Position=origin+Vector3.new(0,10,d/2-1), Material=Enum.Material.SmoothPlastic, BrickColor=BrickColor.new("Really black"), Parent=f})
	local sg = Instance.new("SurfaceGui"); sg.Face=Enum.NormalId.Front; sg.Parent=sign
	local tl = Instance.new("TextLabel"); tl.Size=UDim2.new(1,0,0.5,0); tl.BackgroundTransparency=1; tl.Text="HOLLOW ENTRANCE"; tl.TextColor3=Color3.fromRGB(255,200,50); tl.TextScaled=true; tl.Font=Enum.Font.GothamBold; tl.Parent=sg
	local il = Instance.new("TextLabel"); il.Size=UDim2.new(1,0,0.5,0); il.Position=UDim2.new(0,0,0.5,0); il.BackgroundTransparency=1; il.Text="Collect seals to unlock passages!"; il.TextColor3=Color3.fromRGB(200,200,200); il.TextScaled=true; il.Font=Enum.Font.Gotham; il.Parent=sg

	-- Class pedestals
	for _, pedestalInfo in ipairs(VocationSystem.PedestalLayout) do
		local vocationData = VocationSystem.Vocations[pedestalInfo.VocationId]
		if vocationData then
			local pedPos = origin + pedestalInfo.Offset
			local pedestal = Instance.new("Part")
			pedestal.Name = "Pedestal_" .. pedestalInfo.VocationId
			pedestal.Shape = Enum.PartType.Cylinder
			pedestal.Size = Vector3.new(1, 4, 4)
			pedestal.CFrame = CFrame.new(pedPos) * CFrame.Angles(0, 0, math.rad(90))
			pedestal.Anchored = true
			pedestal.BrickColor = vocationData.Color
			pedestal.Material = Enum.Material.SmoothPlastic
			pedestal.Parent = f

			local pillar = Instance.new("Part")
			pillar.Name = "Pedestal_Pillar_" .. pedestalInfo.VocationId
			pillar.Size = Vector3.new(0.5, 10, 0.5)
			pillar.Position = pedPos + Vector3.new(0, 6, 0)
			pillar.Anchored = true; pillar.CanCollide = false
			pillar.BrickColor = vocationData.Color; pillar.Material = Enum.Material.Neon; pillar.Transparency = 0.3
			pillar.Parent = f

			local signPart = Instance.new("Part")
			signPart.Name = "Pedestal_Sign_" .. pedestalInfo.VocationId
			signPart.Size = Vector3.new(6, 3, 0.2)
			signPart.Position = pedPos + Vector3.new(0, 3, 4)
			signPart.Anchored = true; signPart.CanCollide = false
			signPart.Material = Enum.Material.SmoothPlastic; signPart.BrickColor = BrickColor.new("Really black")
			signPart.Parent = f

			local signGui = Instance.new("SurfaceGui"); signGui.Face = Enum.NormalId.Back; signGui.Parent = signPart
			local nameLabel = Instance.new("TextLabel")
			nameLabel.Size = UDim2.new(1,0,0.4,0); nameLabel.BackgroundTransparency = 1
			nameLabel.Text = vocationData.Name
			nameLabel.TextColor3 = Color3.new(vocationData.Color.r, vocationData.Color.g, vocationData.Color.b)
			nameLabel.TextScaled = true; nameLabel.Font = Enum.Font.GothamBold; nameLabel.Parent = signGui
			local descLabel = Instance.new("TextLabel")
			descLabel.Size = UDim2.new(1,0,0.6,0); descLabel.Position = UDim2.new(0,0,0.4,0)
			descLabel.BackgroundTransparency = 1; descLabel.Text = vocationData.Description
			descLabel.TextColor3 = Color3.fromRGB(200,200,200); descLabel.TextScaled = true; descLabel.TextWrapped = true
			descLabel.Font = Enum.Font.Gotham; descLabel.Parent = signGui

			local prompt = Instance.new("ProximityPrompt")
			prompt.ActionText = "Select " .. vocationData.Name; prompt.ObjectText = vocationData.Name
			prompt.HoldDuration = 0.3; prompt.MaxActivationDistance = 8; prompt.Parent = pedestal
		end
	end

	return f
end

--------------------------------------------------------------------------------
-- BUILD ROOM -- configurable wall openings (receives openings table)
--------------------------------------------------------------------------------
function HollowBuilder.BuildRoom(parent, config, origin, roomIndex, openings)
	local roomFolder = Instance.new("Folder")
	roomFolder.Name = "Room_" .. roomIndex
	roomFolder.Parent = parent

	local size = config.Size
	local t = 4
	local cw = HollowConfig.CorridorWidth + 4 -- opening slightly wider than corridor
	local ch = HollowConfig.CorridorHeight

	-- openings is a table like { Front=true, Right=true, Back=true, Left=true }
	openings = openings or {}

	-- Floor
	makePart({Name="Floor", Size=Vector3.new(size.X,t,size.Z), Position=origin-Vector3.new(0,t/2,0), Material=config.FloorMaterial, BrickColor=config.FloorColor, Parent=roomFolder})
	-- Ceiling
	local ceil = makePart({Name="Ceiling", Size=Vector3.new(size.X,t,size.Z), Position=origin+Vector3.new(0,size.Y+t/2,0), Material=config.WallMaterial, BrickColor=config.WallColor, Parent=roomFolder})

	-- Helper: build a wall with optional corridor opening
	local function buildWall(wallSide)
		local hasOpening = openings[wallSide]
		local wallMat = config.WallMaterial
		local wallCol = config.WallColor

		if wallSide == "Left" then -- -X wall
			if hasOpening then
				local sideD = (size.Z - cw) / 2
				makePart({Size=Vector3.new(t,size.Y,sideD), Position=origin+Vector3.new(-size.X/2-t/2, size.Y/2, (cw+sideD)/2), Material=wallMat, BrickColor=wallCol, Parent=roomFolder})
				makePart({Size=Vector3.new(t,size.Y,sideD), Position=origin+Vector3.new(-size.X/2-t/2, size.Y/2, -(cw+sideD)/2), Material=wallMat, BrickColor=wallCol, Parent=roomFolder})
			else
				makePart({Name="LeftWall", Size=Vector3.new(t,size.Y,size.Z), Position=origin+Vector3.new(-size.X/2-t/2, size.Y/2, 0), Material=wallMat, BrickColor=wallCol, Parent=roomFolder})
			end

		elseif wallSide == "Right" then -- +X wall
			if hasOpening then
				local sideD = (size.Z - cw) / 2
				makePart({Size=Vector3.new(t,size.Y,sideD), Position=origin+Vector3.new(size.X/2+t/2, size.Y/2, (cw+sideD)/2), Material=wallMat, BrickColor=wallCol, Parent=roomFolder})
				makePart({Size=Vector3.new(t,size.Y,sideD), Position=origin+Vector3.new(size.X/2+t/2, size.Y/2, -(cw+sideD)/2), Material=wallMat, BrickColor=wallCol, Parent=roomFolder})
			else
				makePart({Name="RightWall", Size=Vector3.new(t,size.Y,size.Z), Position=origin+Vector3.new(size.X/2+t/2, size.Y/2, 0), Material=wallMat, BrickColor=wallCol, Parent=roomFolder})
			end

		elseif wallSide == "Front" then -- +Z wall
			if hasOpening then
				local sideW = (size.X - cw) / 2
				makePart({Size=Vector3.new(sideW,size.Y,t), Position=origin+Vector3.new(-(cw+sideW)/2, size.Y/2, size.Z/2+t/2), Material=wallMat, BrickColor=wallCol, Parent=roomFolder})
				makePart({Size=Vector3.new(sideW,size.Y,t), Position=origin+Vector3.new((cw+sideW)/2, size.Y/2, size.Z/2+t/2), Material=wallMat, BrickColor=wallCol, Parent=roomFolder})
			else
				makePart({Name="FrontWall", Size=Vector3.new(size.X+t*2,size.Y,t), Position=origin+Vector3.new(0, size.Y/2, size.Z/2+t/2), Material=wallMat, BrickColor=wallCol, Parent=roomFolder})
			end

		elseif wallSide == "Back" then -- -Z wall
			if hasOpening then
				local sideW = (size.X - cw) / 2
				makePart({Size=Vector3.new(sideW,size.Y,t), Position=origin+Vector3.new(-(cw+sideW)/2, size.Y/2, -size.Z/2-t/2), Material=wallMat, BrickColor=wallCol, Parent=roomFolder})
				makePart({Size=Vector3.new(sideW,size.Y,t), Position=origin+Vector3.new((cw+sideW)/2, size.Y/2, -size.Z/2-t/2), Material=wallMat, BrickColor=wallCol, Parent=roomFolder})
			else
				makePart({Name="BackWall", Size=Vector3.new(size.X+t*2,size.Y,t), Position=origin+Vector3.new(0, size.Y/2, -size.Z/2-t/2), Material=wallMat, BrickColor=wallCol, Parent=roomFolder})
			end
		end
	end

	buildWall("Left")
	buildWall("Right")
	buildWall("Front")
	buildWall("Back")

	-- Ceiling ambient light (dim warm fill — torches are the primary light)
	local light = Instance.new("PointLight"); light.Color=config.LightColor or Color3.fromRGB(200,140,70); light.Range=size.X*0.5; light.Brightness=0.4; light.Parent=ceil

	-- Wall-mounted torches (two per wall, evenly spaced — primary room lighting)
	local wallTorchY = size.Y * 0.6
	local wallInset = 1 -- how far from the wall surface
	local torchPositions = {
		-- Left wall (-X)
		Vector3.new(-size.X/2 + wallInset, wallTorchY, -size.Z/4),
		Vector3.new(-size.X/2 + wallInset, wallTorchY, size.Z/4),
		-- Right wall (+X)
		Vector3.new(size.X/2 - wallInset, wallTorchY, -size.Z/4),
		Vector3.new(size.X/2 - wallInset, wallTorchY, size.Z/4),
		-- Back wall (-Z)
		Vector3.new(-size.X/4, wallTorchY, -size.Z/2 + wallInset),
		Vector3.new(size.X/4, wallTorchY, -size.Z/2 + wallInset),
		-- Front wall (+Z)
		Vector3.new(-size.X/4, wallTorchY, size.Z/2 - wallInset),
		Vector3.new(size.X/4, wallTorchY, size.Z/2 - wallInset),
	}
	for _, offset in ipairs(torchPositions) do
		local torch = makePart({Name="WallTorch", Size=Vector3.new(1,3,1), Position=origin+offset, Material=Enum.Material.Wood, BrickColor=BrickColor.new("Brown"), Parent=roomFolder})
		local tl = Instance.new("PointLight"); tl.Color=Color3.fromRGB(255,160,60); tl.Range=35; tl.Brightness=1.8; tl.Parent=torch
		local fi = Instance.new("Fire"); fi.Size=4; fi.Heat=6; fi.Parent=torch
	end

	return roomFolder
end

--------------------------------------------------------------------------------
-- ROOM DECORATION: themed props based on room name
--------------------------------------------------------------------------------
local DECO_PRESETS = {
	["Crypt Entrance"] = {
		{ Name="Coffin1", Size=Vector3.new(3,2,6), Mat=Enum.Material.Wood, Col=BrickColor.new("Brown"), Offset=Vector3.new(-25,1,-20), Rot=CFrame.Angles(0,math.rad(15),0) },
		{ Name="Coffin2", Size=Vector3.new(3,2,6), Mat=Enum.Material.Wood, Col=BrickColor.new("Reddish brown"), Offset=Vector3.new(28,1,18), Rot=CFrame.Angles(0,math.rad(-30),0) },
		{ Name="BonePile1", Size=Vector3.new(4,1.5,4), Mat=Enum.Material.Limestone, Col=BrickColor.new("Institutional white"), Offset=Vector3.new(-40,0.75,35) },
		{ Name="BonePile2", Size=Vector3.new(3,1,3), Mat=Enum.Material.Limestone, Col=BrickColor.new("Institutional white"), Offset=Vector3.new(38,0.5,-30) },
		{ Name="Pillar1", Size=Vector3.new(4,18,4), Mat=Enum.Material.Cobblestone, Col=BrickColor.new("Dark stone grey"), Offset=Vector3.new(-20,9,0) },
		{ Name="Pillar2", Size=Vector3.new(4,18,4), Mat=Enum.Material.Cobblestone, Col=BrickColor.new("Dark stone grey"), Offset=Vector3.new(20,9,0) },
		{ Name="CrackedSlab", Size=Vector3.new(8,0.5,8), Mat=Enum.Material.Slate, Col=BrickColor.new("Medium stone grey"), Offset=Vector3.new(0,0.25,25) },
	},
	["Forgotten Library"] = {
		{ Name="Bookshelf1", Size=Vector3.new(2,12,10), Mat=Enum.Material.Wood, Col=BrickColor.new("Dark orange"), Offset=Vector3.new(-48,6,0) },
		{ Name="Bookshelf2", Size=Vector3.new(2,12,10), Mat=Enum.Material.Wood, Col=BrickColor.new("Dark orange"), Offset=Vector3.new(-48,6,20) },
		{ Name="Bookshelf3", Size=Vector3.new(2,12,10), Mat=Enum.Material.Wood, Col=BrickColor.new("Dark orange"), Offset=Vector3.new(-48,6,-20) },
		{ Name="ReadingDesk", Size=Vector3.new(6,3,4), Mat=Enum.Material.Wood, Col=BrickColor.new("Brown"), Offset=Vector3.new(10,1.5,0) },
		{ Name="FallenBooks", Size=Vector3.new(5,1,4), Mat=Enum.Material.SmoothPlastic, Col=BrickColor.new("Maroon"), Offset=Vector3.new(15,0.5,15) },
		{ Name="Candelabra", Size=Vector3.new(1,5,1), Mat=Enum.Material.Metal, Col=BrickColor.new("Gold"), Offset=Vector3.new(10,2.5,0), Light={Color=Color3.fromRGB(255,200,100),Range=12,Brightness=0.6} },
		{ Name="GlobeStand", Size=Vector3.new(3,4,3), Mat=Enum.Material.Wood, Col=BrickColor.new("Brown"), Offset=Vector3.new(35,2,-25) },
	},
	["Forgotten Catacombs"] = {
		{ Name="SkullPile", Size=Vector3.new(5,2,5), Mat=Enum.Material.Limestone, Col=BrickColor.new("Institutional white"), Offset=Vector3.new(-35,1,30) },
		{ Name="Urn1", Size=Vector3.new(2,3,2), Mat=Enum.Material.Cobblestone, Col=BrickColor.new("Nougat"), Offset=Vector3.new(30,1.5,-25) },
		{ Name="Urn2", Size=Vector3.new(2,3,2), Mat=Enum.Material.Cobblestone, Col=BrickColor.new("Nougat"), Offset=Vector3.new(35,1.5,-20) },
		{ Name="BrokenUrn", Size=Vector3.new(3,1.5,3), Mat=Enum.Material.Cobblestone, Col=BrickColor.new("Nougat"), Offset=Vector3.new(-20,0.75,-35) },
		{ Name="Sarcophagus", Size=Vector3.new(4,3,8), Mat=Enum.Material.Slate, Col=BrickColor.new("Dark stone grey"), Offset=Vector3.new(0,1.5,30), Rot=CFrame.Angles(0,math.rad(10),0) },
		{ Name="MossPatch", Size=Vector3.new(6,0.2,6), Mat=Enum.Material.Grass, Col=BrickColor.new("Earth green"), Offset=Vector3.new(-30,0.1,-10) },
	},
	["Spider Nest"] = {
		{ Name="WebCluster1", Size=Vector3.new(8,6,1), Mat=Enum.Material.SmoothPlastic, Col=BrickColor.new("White"), Offset=Vector3.new(-40,12,-45), Trans=0.5 },
		{ Name="WebCluster2", Size=Vector3.new(1,8,8), Mat=Enum.Material.SmoothPlastic, Col=BrickColor.new("White"), Offset=Vector3.new(45,10,30), Trans=0.5 },
		{ Name="EggSac1", Size=Vector3.new(3,2,3), Mat=Enum.Material.SmoothPlastic, Col=BrickColor.new("Institutional white"), Offset=Vector3.new(-30,1,20) },
		{ Name="EggSac2", Size=Vector3.new(2,1.5,2), Mat=Enum.Material.SmoothPlastic, Col=BrickColor.new("Institutional white"), Offset=Vector3.new(25,0.75,-15) },
		{ Name="Cocoon", Size=Vector3.new(2,5,2), Mat=Enum.Material.Fabric, Col=BrickColor.new("White"), Offset=Vector3.new(40,5,-40), Trans=0.2 },
		{ Name="DeadAdventurer", Size=Vector3.new(4,1,2), Mat=Enum.Material.Fabric, Col=BrickColor.new("Brown"), Offset=Vector3.new(-15,0.5,-30) },
	},
	["Grand Hall"] = {
		{ Name="Pillar1", Size=Vector3.new(5,20,5), Mat=Enum.Material.Granite, Col=BrickColor.new("Medium stone grey"), Offset=Vector3.new(-30,10,25) },
		{ Name="Pillar2", Size=Vector3.new(5,20,5), Mat=Enum.Material.Granite, Col=BrickColor.new("Medium stone grey"), Offset=Vector3.new(30,10,25) },
		{ Name="Pillar3", Size=Vector3.new(5,20,5), Mat=Enum.Material.Granite, Col=BrickColor.new("Medium stone grey"), Offset=Vector3.new(-30,10,-25) },
		{ Name="Pillar4", Size=Vector3.new(5,20,5), Mat=Enum.Material.Granite, Col=BrickColor.new("Medium stone grey"), Offset=Vector3.new(30,10,-25) },
		{ Name="BannerStand1", Size=Vector3.new(1,10,0.5), Mat=Enum.Material.Fabric, Col=BrickColor.new("Maroon"), Offset=Vector3.new(-48,5,0), NC=true },
		{ Name="BannerStand2", Size=Vector3.new(1,10,0.5), Mat=Enum.Material.Fabric, Col=BrickColor.new("Navy blue"), Offset=Vector3.new(48,5,0), NC=true },
		{ Name="BrokenChandelier", Size=Vector3.new(6,2,6), Mat=Enum.Material.Metal, Col=BrickColor.new("Gold"), Offset=Vector3.new(5,1,10) },
		{ Name="RedCarpet", Size=Vector3.new(8,0.3,40), Mat=Enum.Material.Fabric, Col=BrickColor.new("Crimson"), Offset=Vector3.new(0,0.15,0) },
	},
	["Armory"] = {
		{ Name="WeaponRack1", Size=Vector3.new(2,8,6), Mat=Enum.Material.Wood, Col=BrickColor.new("Brown"), Offset=Vector3.new(-48,4,15) },
		{ Name="WeaponRack2", Size=Vector3.new(2,8,6), Mat=Enum.Material.Wood, Col=BrickColor.new("Brown"), Offset=Vector3.new(-48,4,-15) },
		{ Name="ArmorStand", Size=Vector3.new(2,6,2), Mat=Enum.Material.Metal, Col=BrickColor.new("Medium stone grey"), Offset=Vector3.new(35,3,30) },
		{ Name="ShieldWall", Size=Vector3.new(0.5,5,5), Mat=Enum.Material.Metal, Col=BrickColor.new("Dark stone grey"), Offset=Vector3.new(48,5,-20), NC=true },
		{ Name="Anvil", Size=Vector3.new(3,2,2), Mat=Enum.Material.Metal, Col=BrickColor.new("Dark stone grey"), Offset=Vector3.new(15,1,-30) },
		{ Name="Grindstone", Size=Vector3.new(2,3,2), Mat=Enum.Material.Cobblestone, Col=BrickColor.new("Medium stone grey"), Offset=Vector3.new(20,1.5,-35) },
		{ Name="CratePile", Size=Vector3.new(5,4,5), Mat=Enum.Material.Wood, Col=BrickColor.new("Brown"), Offset=Vector3.new(-25,2,35) },
	},
	["Cursed Chapel"] = {
		{ Name="Pew1", Size=Vector3.new(3,3,8), Mat=Enum.Material.Wood, Col=BrickColor.new("Dark orange"), Offset=Vector3.new(-15,1.5,10) },
		{ Name="Pew2", Size=Vector3.new(3,3,8), Mat=Enum.Material.Wood, Col=BrickColor.new("Dark orange"), Offset=Vector3.new(15,1.5,10) },
		{ Name="Pew3", Size=Vector3.new(3,3,8), Mat=Enum.Material.Wood, Col=BrickColor.new("Dark orange"), Offset=Vector3.new(-15,1.5,-10) },
		{ Name="Pew4", Size=Vector3.new(3,3,8), Mat=Enum.Material.Wood, Col=BrickColor.new("Dark orange"), Offset=Vector3.new(15,1.5,-10) },
		{ Name="Altar", Size=Vector3.new(6,4,3), Mat=Enum.Material.Marble, Col=BrickColor.new("Medium stone grey"), Offset=Vector3.new(0,2,-40) },
		{ Name="CursedCandle1", Size=Vector3.new(1,3,1), Mat=Enum.Material.SmoothPlastic, Col=BrickColor.new("Institutional white"), Offset=Vector3.new(-5,4,-40), Light={Color=Color3.fromRGB(160,80,200),Range=10,Brightness=0.8} },
		{ Name="CursedCandle2", Size=Vector3.new(1,3,1), Mat=Enum.Material.SmoothPlastic, Col=BrickColor.new("Institutional white"), Offset=Vector3.new(5,4,-40), Light={Color=Color3.fromRGB(160,80,200),Range=10,Brightness=0.8} },
		{ Name="StainedFrame", Size=Vector3.new(0.5,8,6), Mat=Enum.Material.Glass, Col=BrickColor.new("Bright violet"), Offset=Vector3.new(0,10,-48), Trans=0.3, NC=true },
	},
	["Blood Altar"] = {
		{ Name="CentralAltar", Size=Vector3.new(8,3,8), Mat=Enum.Material.Basalt, Col=BrickColor.new("Really black"), Offset=Vector3.new(0,1.5,0) },
		{ Name="AltarTop", Size=Vector3.new(7,0.5,7), Mat=Enum.Material.Neon, Col=BrickColor.new("Crimson"), Offset=Vector3.new(0,3.25,0), Light={Color=Color3.fromRGB(200,30,30),Range=15,Brightness=1} },
		{ Name="BloodPool1", Size=Vector3.new(10,0.2,10), Mat=Enum.Material.Neon, Col=BrickColor.new("Crimson"), Offset=Vector3.new(-25,0.1,25), Trans=0.4 },
		{ Name="BloodPool2", Size=Vector3.new(6,0.2,8), Mat=Enum.Material.Neon, Col=BrickColor.new("Crimson"), Offset=Vector3.new(30,0.1,-20), Trans=0.4 },
		{ Name="RitualCandle1", Size=Vector3.new(1,4,1), Mat=Enum.Material.SmoothPlastic, Col=BrickColor.new("Institutional white"), Offset=Vector3.new(-10,2,10), Light={Color=Color3.fromRGB(255,50,30),Range=8,Brightness=0.5} },
		{ Name="RitualCandle2", Size=Vector3.new(1,4,1), Mat=Enum.Material.SmoothPlastic, Col=BrickColor.new("Institutional white"), Offset=Vector3.new(10,2,-10), Light={Color=Color3.fromRGB(255,50,30),Range=8,Brightness=0.5} },
		{ Name="Chain1", Size=Vector3.new(0.5,12,0.5), Mat=Enum.Material.Metal, Col=BrickColor.new("Dark stone grey"), Offset=Vector3.new(-35,6,-35), NC=true },
		{ Name="Chain2", Size=Vector3.new(0.5,12,0.5), Mat=Enum.Material.Metal, Col=BrickColor.new("Dark stone grey"), Offset=Vector3.new(35,6,35), NC=true },
	},
	["Mage Tower"] = {
		{ Name="CrystalPillar1", Size=Vector3.new(2,10,2), Mat=Enum.Material.Neon, Col=BrickColor.new("Cyan"), Offset=Vector3.new(-30,5,30), Trans=0.3 },
		{ Name="CrystalPillar2", Size=Vector3.new(2,10,2), Mat=Enum.Material.Neon, Col=BrickColor.new("Cyan"), Offset=Vector3.new(30,5,-30), Trans=0.3 },
		{ Name="ArcaneCircle", Size=Vector3.new(20,0.2,20), Mat=Enum.Material.Neon, Col=BrickColor.new("Bright violet"), Offset=Vector3.new(0,0.1,0), Trans=0.5 },
		{ Name="RuneStone1", Size=Vector3.new(3,4,1), Mat=Enum.Material.Granite, Col=BrickColor.new("Medium stone grey"), Offset=Vector3.new(-35,2,0), Light={Color=Color3.fromRGB(100,100,255),Range=8,Brightness=0.5} },
		{ Name="RuneStone2", Size=Vector3.new(3,4,1), Mat=Enum.Material.Granite, Col=BrickColor.new("Medium stone grey"), Offset=Vector3.new(35,2,0), Light={Color=Color3.fromRGB(100,100,255),Range=8,Brightness=0.5} },
		{ Name="FloatingBook", Size=Vector3.new(2,0.3,1.5), Mat=Enum.Material.SmoothPlastic, Col=BrickColor.new("Maroon"), Offset=Vector3.new(0,8,0), NC=true },
	},
	["Bone Pit"] = {
		{ Name="BoneMound1", Size=Vector3.new(8,3,8), Mat=Enum.Material.Limestone, Col=BrickColor.new("Institutional white"), Offset=Vector3.new(-25,1.5,20) },
		{ Name="BoneMound2", Size=Vector3.new(6,2,6), Mat=Enum.Material.Limestone, Col=BrickColor.new("Institutional white"), Offset=Vector3.new(30,1,-25) },
		{ Name="RibcageArch", Size=Vector3.new(2,8,10), Mat=Enum.Material.Limestone, Col=BrickColor.new("Light stone grey"), Offset=Vector3.new(0,4,0), Trans=0.1, NC=true },
		{ Name="SkullTotem", Size=Vector3.new(3,8,3), Mat=Enum.Material.Limestone, Col=BrickColor.new("Institutional white"), Offset=Vector3.new(-40,4,-30) },
		{ Name="FemurFence1", Size=Vector3.new(0.5,3,8), Mat=Enum.Material.Limestone, Col=BrickColor.new("Light stone grey"), Offset=Vector3.new(40,1.5,0) },
	},
	["Shadow Crypt"] = {
		{ Name="DarkObelisk1", Size=Vector3.new(3,12,3), Mat=Enum.Material.Basalt, Col=BrickColor.new("Really black"), Offset=Vector3.new(-25,6,25) },
		{ Name="DarkObelisk2", Size=Vector3.new(3,12,3), Mat=Enum.Material.Basalt, Col=BrickColor.new("Really black"), Offset=Vector3.new(25,6,-25) },
		{ Name="ShadowPool", Size=Vector3.new(12,0.2,12), Mat=Enum.Material.Neon, Col=BrickColor.new("Bright violet"), Offset=Vector3.new(0,0.1,0), Trans=0.6 },
		{ Name="FloatingOrb", Size=Vector3.new(2,2,2), Mat=Enum.Material.Neon, Col=BrickColor.new("Bright violet"), Offset=Vector3.new(0,12,0), NC=true, Shape="Ball", Light={Color=Color3.fromRGB(120,50,200),Range=20,Brightness=1} },
		{ Name="CrackedMirror", Size=Vector3.new(5,6,0.5), Mat=Enum.Material.Glass, Col=BrickColor.new("Medium stone grey"), Offset=Vector3.new(-48,5,0), Trans=0.3, NC=true },
	},
	["Knight's Barracks"] = {
		{ Name="WeaponRack", Size=Vector3.new(2,8,8), Mat=Enum.Material.Wood, Col=BrickColor.new("Brown"), Offset=Vector3.new(-48,4,0) },
		{ Name="Cot1", Size=Vector3.new(4,1.5,7), Mat=Enum.Material.Fabric, Col=BrickColor.new("Sand blue"), Offset=Vector3.new(30,0.75,30) },
		{ Name="Cot2", Size=Vector3.new(4,1.5,7), Mat=Enum.Material.Fabric, Col=BrickColor.new("Sand blue"), Offset=Vector3.new(30,0.75,-30) },
		{ Name="TrainingDummy", Size=Vector3.new(2,5,2), Mat=Enum.Material.Wood, Col=BrickColor.new("Brown"), Offset=Vector3.new(-20,2.5,-25) },
		{ Name="Table", Size=Vector3.new(6,3,4), Mat=Enum.Material.Wood, Col=BrickColor.new("Dark orange"), Offset=Vector3.new(10,1.5,0) },
		{ Name="FlagPole", Size=Vector3.new(0.5,10,0.5), Mat=Enum.Material.Wood, Col=BrickColor.new("Brown"), Offset=Vector3.new(45,5,40) },
	},
	["Infernal Pit"] = {
		{ Name="LavaPool1", Size=Vector3.new(12,0.3,12), Mat=Enum.Material.Neon, Col=BrickColor.new("Bright orange"), Offset=Vector3.new(-25,0.15,20), Trans=0.2 },
		{ Name="LavaPool2", Size=Vector3.new(8,0.3,8), Mat=Enum.Material.Neon, Col=BrickColor.new("Bright orange"), Offset=Vector3.new(30,0.15,-15), Trans=0.2 },
		{ Name="ObsidianSpike1", Size=Vector3.new(2,8,2), Mat=Enum.Material.Basalt, Col=BrickColor.new("Really black"), Offset=Vector3.new(-35,4,-30), Rot=CFrame.Angles(0,0,math.rad(5)) },
		{ Name="ObsidianSpike2", Size=Vector3.new(1.5,6,1.5), Mat=Enum.Material.Basalt, Col=BrickColor.new("Really black"), Offset=Vector3.new(40,3,25), Rot=CFrame.Angles(0,0,math.rad(-8)) },
		{ Name="Chain1", Size=Vector3.new(0.5,14,0.5), Mat=Enum.Material.Metal, Col=BrickColor.new("Dark stone grey"), Offset=Vector3.new(-15,7,35), NC=true },
		{ Name="Chain2", Size=Vector3.new(0.5,14,0.5), Mat=Enum.Material.Metal, Col=BrickColor.new("Dark stone grey"), Offset=Vector3.new(15,7,-35), NC=true },
		{ Name="EmberGlow", Size=Vector3.new(1,1,1), Mat=Enum.Material.Neon, Col=BrickColor.new("Bright orange"), Offset=Vector3.new(0,1,0), Trans=1, Light={Color=Color3.fromRGB(255,80,20),Range=30,Brightness=1.5} },
	},
	["Void Sanctum"] = {
		{ Name="VoidCrystal1", Size=Vector3.new(3,8,3), Mat=Enum.Material.Neon, Col=BrickColor.new("Bright violet"), Offset=Vector3.new(-30,4,0), Trans=0.3 },
		{ Name="VoidCrystal2", Size=Vector3.new(2,6,2), Mat=Enum.Material.Neon, Col=BrickColor.new("Bright violet"), Offset=Vector3.new(30,3,0), Trans=0.3 },
		{ Name="CrackedPillar1", Size=Vector3.new(5,14,5), Mat=Enum.Material.Granite, Col=BrickColor.new("Dark stone grey"), Offset=Vector3.new(-25,7,25), Rot=CFrame.Angles(0,0,math.rad(4)) },
		{ Name="CrackedPillar2", Size=Vector3.new(5,14,5), Mat=Enum.Material.Granite, Col=BrickColor.new("Dark stone grey"), Offset=Vector3.new(25,7,-25), Rot=CFrame.Angles(0,0,math.rad(-3)) },
		{ Name="FloatingDebris1", Size=Vector3.new(3,2,3), Mat=Enum.Material.Slate, Col=BrickColor.new("Medium stone grey"), Offset=Vector3.new(-10,10,15), NC=true },
		{ Name="FloatingDebris2", Size=Vector3.new(2,1.5,2), Mat=Enum.Material.Slate, Col=BrickColor.new("Medium stone grey"), Offset=Vector3.new(12,12,-10), NC=true },
		{ Name="VoidPortal", Size=Vector3.new(8,8,0.5), Mat=Enum.Material.Neon, Col=BrickColor.new("Really black"), Offset=Vector3.new(0,6,-45), Trans=0.4, NC=true, Light={Color=Color3.fromRGB(100,50,180),Range=20,Brightness=1.2} },
	},
	["Golem's Throne"] = {
		{ Name="Throne", Size=Vector3.new(8,12,6), Mat=Enum.Material.Granite, Col=BrickColor.new("Dark stone grey"), Offset=Vector3.new(0,6,-45) },
		{ Name="Brazier1", Size=Vector3.new(3,4,3), Mat=Enum.Material.Metal, Col=BrickColor.new("Dark stone grey"), Offset=Vector3.new(-35,2,35), Light={Color=Color3.fromRGB(255,100,50),Range=20,Brightness=1.5} },
		{ Name="Brazier2", Size=Vector3.new(3,4,3), Mat=Enum.Material.Metal, Col=BrickColor.new("Dark stone grey"), Offset=Vector3.new(35,2,35), Light={Color=Color3.fromRGB(255,100,50),Range=20,Brightness=1.5} },
		{ Name="Brazier3", Size=Vector3.new(3,4,3), Mat=Enum.Material.Metal, Col=BrickColor.new("Dark stone grey"), Offset=Vector3.new(-35,2,-35), Light={Color=Color3.fromRGB(255,100,50),Range=20,Brightness=1.5} },
		{ Name="Brazier4", Size=Vector3.new(3,4,3), Mat=Enum.Material.Metal, Col=BrickColor.new("Dark stone grey"), Offset=Vector3.new(35,2,-35), Light={Color=Color3.fromRGB(255,100,50),Range=20,Brightness=1.5} },
		{ Name="ArenaPillar1", Size=Vector3.new(6,22,6), Mat=Enum.Material.Granite, Col=BrickColor.new("Medium stone grey"), Offset=Vector3.new(-40,11,0) },
		{ Name="ArenaPillar2", Size=Vector3.new(6,22,6), Mat=Enum.Material.Granite, Col=BrickColor.new("Medium stone grey"), Offset=Vector3.new(40,11,0) },
		{ Name="ArenaCircle", Size=Vector3.new(40,0.2,40), Mat=Enum.Material.Neon, Col=BrickColor.new("Bright orange"), Offset=Vector3.new(0,0.1,0), Trans=0.6 },
	},
}

function HollowBuilder.DecorateRoom(roomFolder, config, origin)
	local preset = DECO_PRESETS[config.Name]
	if not preset then return end

	for _, deco in ipairs(preset) do
		local part = makePart({
			Name = deco.Name,
			Size = deco.Size,
			Position = origin + deco.Offset,
			Material = deco.Mat,
			BrickColor = deco.Col,
			CanCollide = deco.NC and false or true,
			Transparency = deco.Trans or 0,
			Parent = roomFolder,
		})

		if deco.Shape == "Ball" then
			part.Shape = Enum.PartType.Ball
		end

		if deco.Rot then
			part.CFrame = CFrame.new(origin + deco.Offset) * deco.Rot
		end

		if deco.Light then
			local l = Instance.new("PointLight")
			l.Color = deco.Light.Color
			l.Range = deco.Light.Range
			l.Brightness = deco.Light.Brightness
			l.Parent = part
		end
	end
end

--------------------------------------------------------------------------------
-- ROOM SECRETS: hidden interactables that award bonus dungeon score
--------------------------------------------------------------------------------
local SECRET_TYPES = {
	{ Name = "Ancient Rune",       Desc = "A glowing rune carved into stone",     Points = 75,  Size = Vector3.new(2,2,0.5),  Mat = Enum.Material.Neon,          Col = BrickColor.new("Bright orange"), Trans = 0.3 },
	{ Name = "Buried Relic",       Desc = "A relic half-buried in rubble",         Points = 100, Size = Vector3.new(1.5,1,1.5), Mat = Enum.Material.Metal,         Col = BrickColor.new("Gold") },
	{ Name = "Ancient Inscription",Desc = "Faded writing on the wall",             Points = 50,  Size = Vector3.new(3,2,0.3),  Mat = Enum.Material.Slate,          Col = BrickColor.new("Medium stone grey"), Trans = 0.2 },
	{ Name = "Hidden Cache",       Desc = "A small chest tucked behind debris",    Points = 125, Size = Vector3.new(2,1.5,1.5), Mat = Enum.Material.Wood,          Col = BrickColor.new("Dark orange") },
	{ Name = "Spirit Orb",         Desc = "A ghostly orb pulses with energy",      Points = 75,  Size = Vector3.new(1.5,1.5,1.5), Mat = Enum.Material.Neon,        Col = BrickColor.new("Cyan"), Shape = "Ball", Trans = 0.4 },
}

-- Each room gets 1 secret placed at a semi-hidden offset
local SECRET_OFFSETS = {
	Vector3.new(-48, 2, -45),   -- back-left corner
	Vector3.new(48, 2, -45),    -- back-right corner
	Vector3.new(-48, 2, 45),    -- front-left corner
	Vector3.new(48, 2, 45),     -- front-right corner
	Vector3.new(-48, 8, 0),     -- left wall high
	Vector3.new(48, 8, 0),      -- right wall high
	Vector3.new(0, 1, -48),     -- back wall low
	Vector3.new(0, 1, 48),      -- front wall low
}

function HollowBuilder.SpawnRoomSecrets(dungeonData, roomFolder, roomConfig, origin, roomIndex, player)
	if roomConfig.RoomType == "Trap" or roomConfig.RoomType == "Puzzle" or roomConfig.RoomType == "Shrine" then
		return -- puzzles/traps have their own scoring
	end

	-- Pick a random secret type and offset
	local secretDef = SECRET_TYPES[math.random(#SECRET_TYPES)]
	local offsetChoice = SECRET_OFFSETS[math.random(#SECRET_OFFSETS)]
	-- Clamp offset inside room bounds
	local halfX = (roomConfig.Size.X / 2) - 5
	local halfZ = (roomConfig.Size.Z / 2) - 5
	local clampedOffset = Vector3.new(
		math.clamp(offsetChoice.X, -halfX, halfX),
		offsetChoice.Y,
		math.clamp(offsetChoice.Z, -halfZ, halfZ)
	)

	local secretPos = origin + clampedOffset
	local secret = makePart({
		Name = "Secret_" .. secretDef.Name:gsub(" ", ""),
		Size = secretDef.Size,
		Position = secretPos,
		Material = secretDef.Mat,
		BrickColor = secretDef.Col,
		CanCollide = false,
		Transparency = secretDef.Trans or 0,
		Parent = roomFolder,
	})

	if secretDef.Shape == "Ball" then
		secret.Shape = Enum.PartType.Ball
	end

	-- Subtle glow
	local glow = Instance.new("PointLight")
	glow.Color = Color3.new(secret.BrickColor.r, secret.BrickColor.g, secret.BrickColor.b)
	glow.Range = 8
	glow.Brightness = 0.5
	glow.Parent = secret

	-- Sparkle hint
	local sparkle = Instance.new("ParticleEmitter")
	sparkle.Color = ColorSequence.new(Color3.new(secret.BrickColor.r, secret.BrickColor.g, secret.BrickColor.b))
	sparkle.Size = NumberSequence.new(0.2, 0)
	sparkle.Lifetime = NumberRange.new(0.5, 1)
	sparkle.Rate = 5
	sparkle.Speed = NumberRange.new(1, 2)
	sparkle.Parent = secret

	-- ProximityPrompt to discover
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Examine"
	prompt.ObjectText = secretDef.Name
	prompt.HoldDuration = 0.8
	prompt.MaxActivationDistance = 8
	prompt.RequiresLineOfSight = true
	prompt.Parent = secret

	-- BillboardGui label (hidden until discovered)
	local bb = Instance.new("BillboardGui")
	bb.Size = UDim2.new(0, 120, 0, 40)
	bb.StudsOffset = Vector3.new(0, 2, 0)
	bb.AlwaysOnTop = false
	bb.Enabled = false
	bb.Parent = secret

	local lbl = Instance.new("TextLabel")
	lbl.Size = UDim2.new(1, 0, 1, 0)
	lbl.BackgroundTransparency = 1
	lbl.Text = secretDef.Name
	lbl.TextColor3 = Color3.fromRGB(255, 215, 0)
	lbl.TextStrokeTransparency = 0
	lbl.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
	lbl.TextScaled = true
	lbl.Font = Enum.Font.GothamBold
	lbl.Parent = bb

	prompt.Triggered:Connect(function(trigPlayer)
		if trigPlayer ~= player then return end
		if secret:GetAttribute("Found") then return end
		secret:SetAttribute("Found", true)

		-- Award score
		dungeonData.SecretScore = (dungeonData.SecretScore or 0) + secretDef.Points

		-- Visual feedback: flash bright then fade
		prompt:Destroy()
		bb.Enabled = true
		sparkle.Rate = 30
		glow.Brightness = 3
		glow.Range = 15

		-- Notify client
		local remote = Remotes:GetEvent("SecretFound")
		if remote then
			remote:FireClient(player, secretDef.Name, secretDef.Points, secretDef.Desc)
		end

		-- Fade out after 3 seconds
		task.delay(3, function()
			if secret and secret.Parent then
				local fadeOut = TweenService:Create(secret, TweenInfo.new(1), { Transparency = 1 })
				fadeOut:Play()
				fadeOut.Completed:Connect(function()
					if secret and secret.Parent then secret:Destroy() end
				end)
			end
		end)
	end)
end

--------------------------------------------------------------------------------
-- CORRIDOR BUILDER (grid-based, straight only)
--------------------------------------------------------------------------------
local CORRIDOR_OVERLAP = 2

-- Build a straight corridor segment along Z axis
-- Uses openingW (cw+4) to match room wall openings exactly
local function buildCorridorZ(parent, x, fromZ, toZ, originY, mat, col, floorCol)
	local cw = HollowConfig.CorridorWidth
	local ow = cw + 4 -- match room opening width exactly
	local ch = HollowConfig.CorridorHeight
	local t = 4
	local length = math.abs(fromZ - toZ)
	local centerZ = (fromZ + toZ) / 2

	local f = Instance.new("Folder"); f.Name = "CorridorZ"; f.Parent = parent
	makePart({Name="Floor", Size=Vector3.new(ow,t,length), Position=Vector3.new(x, originY-t/2, centerZ), Material=Enum.Material.Cobblestone, BrickColor=floorCol, Parent=f})
	makePart({Name="Ceiling", Size=Vector3.new(ow,t,length), Position=Vector3.new(x, originY+ch+t/2, centerZ), Material=mat, BrickColor=col, Parent=f})
	makePart({Size=Vector3.new(t,ch,length), Position=Vector3.new(x-ow/2-t/2, originY+ch/2, centerZ), Material=mat, BrickColor=col, Parent=f})
	makePart({Size=Vector3.new(t,ch,length), Position=Vector3.new(x+ow/2+t/2, originY+ch/2, centerZ), Material=mat, BrickColor=col, Parent=f})

	-- Torch
	local torch = makePart({Name="Torch", Size=Vector3.new(1,2,1), Position=Vector3.new(x, originY+ch*0.7, centerZ), Material=Enum.Material.Wood, BrickColor=BrickColor.new("Brown"), Parent=f})
	local tl = Instance.new("PointLight"); tl.Color=Color3.fromRGB(255,130,40); tl.Range=14; tl.Brightness=0.6; tl.Parent=torch
	local fi = Instance.new("Fire"); fi.Size=2; fi.Heat=3; fi.Parent=torch
	return f
end

-- Build a straight corridor segment along X axis
-- Uses openingW (cw+4) to match room wall openings exactly
local function buildCorridorX(parent, z, fromX, toX, originY, mat, col, floorCol)
	local cw = HollowConfig.CorridorWidth
	local ow = cw + 4 -- match room opening width exactly
	local ch = HollowConfig.CorridorHeight
	local t = 4
	local length = math.abs(fromX - toX)
	local centerX = (fromX + toX) / 2

	local f = Instance.new("Folder"); f.Name = "CorridorX"; f.Parent = parent
	makePart({Name="Floor", Size=Vector3.new(length,t,ow), Position=Vector3.new(centerX, originY-t/2, z), Material=Enum.Material.Cobblestone, BrickColor=floorCol, Parent=f})
	makePart({Name="Ceiling", Size=Vector3.new(length,t,ow), Position=Vector3.new(centerX, originY+ch+t/2, z), Material=mat, BrickColor=col, Parent=f})
	makePart({Size=Vector3.new(length,ch,t), Position=Vector3.new(centerX, originY+ch/2, z-ow/2-t/2), Material=mat, BrickColor=col, Parent=f})
	makePart({Size=Vector3.new(length,ch,t), Position=Vector3.new(centerX, originY+ch/2, z+ow/2+t/2), Material=mat, BrickColor=col, Parent=f})

	-- Torch
	local torch = makePart({Name="Torch", Size=Vector3.new(1,2,1), Position=Vector3.new(centerX, originY+ch*0.7, z), Material=Enum.Material.Wood, BrickColor=BrickColor.new("Brown"), Parent=f})
	local tl = Instance.new("PointLight"); tl.Color=Color3.fromRGB(255,130,40); tl.Range=14; tl.Brightness=0.6; tl.Parent=torch
	local fi = Instance.new("Fire"); fi.Size=2; fi.Heat=3; fi.Parent=torch
	return f
end

--------------------------------------------------------------------------------
-- BUILD GRID CORRIDOR between two adjacent rooms
-- Dir: "Right" = along +X, "Down" = along -Z
-- Returns the door Part (or nil if no key)
--------------------------------------------------------------------------------
function HollowBuilder.BuildGridCorridor(parent, roomAOrigin, roomASize, roomBOrigin, roomBSize, dir, originY, sealType)
	local mat = Enum.Material.Brick
	local col = BrickColor.new("Really black")
	local floorCol = BrickColor.new("Dark stone grey")
	local cw = HollowConfig.CorridorWidth
	local ow = cw + 4 -- match room opening width
	local ch = HollowConfig.CorridorHeight
	local t = 4

	if dir == "Right" then
		-- Corridor along X axis between horizontally adjacent rooms
		local fromX = roomAOrigin.X + roomASize.X / 2 - CORRIDOR_OVERLAP
		local toX = roomBOrigin.X - roomBSize.X / 2 + CORRIDOR_OVERLAP
		local z = roomAOrigin.Z -- same Z since they are on the same row
		buildCorridorX(parent, z, fromX, toX, originY, mat, col, floorCol)

		-- Door in the middle if sealType is specified
		if sealType then
			local centerX = (fromX + toX) / 2
			local doorPos = Vector3.new(centerX, originY + ch / 2, z)
			return HollowBuilder._BuildCorridorDoor(parent, doorPos, Vector3.new(4, ch, ow), sealType)
		end

	elseif dir == "Down" then
		-- Corridor along Z axis between vertically adjacent rooms
		local fromZ = roomAOrigin.Z - roomASize.Z / 2 + CORRIDOR_OVERLAP
		local toZ = roomBOrigin.Z + roomBSize.Z / 2 - CORRIDOR_OVERLAP
		local x = roomAOrigin.X -- same X since they are on the same column
		buildCorridorZ(parent, x, fromZ, toZ, originY, mat, col, floorCol)

		-- Door in the middle if sealType is specified
		if sealType then
			local centerZ = (fromZ + toZ) / 2
			local doorPos = Vector3.new(x, originY + ch / 2, centerZ)
			return HollowBuilder._BuildCorridorDoor(parent, doorPos, Vector3.new(ow, ch, 4), sealType)
		end
	end

	return nil
end

--------------------------------------------------------------------------------
-- INTERNAL: Build a corridor door at the given position with size and key type
--------------------------------------------------------------------------------
function HollowBuilder._BuildCorridorDoor(parent, doorPos, doorSize, sealType)
	local mat = Enum.Material.Brick
	local col = BrickColor.new("Really black")
	local cw = HollowConfig.CorridorWidth
	local ch = HollowConfig.CorridorHeight

	local sealData = HollowConfig.SealTypes[sealType]
	local sealColor = sealData and sealData.BrickColor or BrickColor.new("Medium stone grey")
	local sealGlowColor = sealData and sealData.Color or Color3.fromRGB(200, 200, 200)

	local door = makePart({
		Name = "CorridorSeal_" .. sealType,
		Size = doorSize,
		Position = doorPos,
		Material = mat,
		BrickColor = col,
		Parent = parent,
	})

	-- Colored neon trim strip on the door
	local trimSize = Vector3.new(doorSize.X + 0.2, 2, doorSize.Z + 0.2)
	local trimPos = doorPos + Vector3.new(0, ch / 2 - 1, 0)
	makePart({
		Name = "DoorTrim",
		Size = trimSize,
		Position = trimPos,
		Material = Enum.Material.Neon,
		BrickColor = sealColor,
		CanCollide = false,
		Parent = door,
	})

	-- Glow
	local glow = Instance.new("PointLight")
	glow.Color = sealGlowColor
	glow.Range = 15
	glow.Brightness = 2
	glow.Parent = door

	-- Label
	local bb = Instance.new("BillboardGui")
	bb.Size = UDim2.new(0, 150, 0, 50)
	bb.StudsOffset = Vector3.new(0, ch / 2 + 2, 0)
	bb.AlwaysOnTop = true
	bb.Parent = door

	local lbl = Instance.new("TextLabel")
	lbl.Size = UDim2.new(1, 0, 1, 0)
	lbl.BackgroundTransparency = 1
	lbl.Text = (sealData and sealData.Name or sealType) .. " Door"
	lbl.TextColor3 = sealGlowColor
	lbl.TextStrokeTransparency = 0
	lbl.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
	lbl.TextScaled = true
	lbl.Font = Enum.Font.GothamBold
	lbl.Parent = bb

	return door
end

--------------------------------------------------------------------------------
-- OPEN SLIDING DOOR
--------------------------------------------------------------------------------
function HollowBuilder.OpenSlidingDoor(door)
	if not door or not door.Parent then return end

	local ch = HollowConfig.CorridorHeight
	door.CanCollide = false

	local slideUp = TweenService:Create(door, TweenInfo.new(1.5, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {
		Position = door.Position + Vector3.new(0, ch + 4, 0),
	})
	slideUp:Play()
	slideUp.Completed:Connect(function()
		door:Destroy()
	end)
end

--------------------------------------------------------------------------------
-- START DUNGEON -- grid-based construction
--------------------------------------------------------------------------------
function HollowBuilder.StartDungeon(player)
	HollowBuilder.CleanupDungeon(player)

	-- Hide entire lobby so it doesn't overlap with dungeon rooms
	local lobby = workspace:FindFirstChild("Lobby")
	if lobby then
		for _, desc in ipairs(lobby:GetDescendants()) do
			if desc:IsA("BasePart") then
				desc.Transparency = 1
				desc.CanCollide = false
			elseif desc:IsA("PointLight") or desc:IsA("Fire") or desc:IsA("ParticleEmitter") or desc:IsA("Sparkles") then
				desc:Destroy()
			elseif desc:IsA("ProximityPrompt") then
				desc.Enabled = false
			end
		end
	end

	local dungeonFolder = Instance.new("Folder")
	dungeonFolder.Name = "ActiveHollow"
	dungeonFolder.Parent = workspace

	local dungeonData = {
		Folder = dungeonFolder,
		CurrentRoom = 1,
		RoomStates = {},
		RoomEnemyCounts = {},
		RoomFolders = {},
		CorridorDoors = {}, -- [corridorIndex] = { Door = Part, SealType = string }
		PlayerSeals = {}, -- { Iron = true, Gold = true, ... }
		ShadowSealsCollected = 0,
		Player = player,
		Deaths = 0,
		StartTime = os.clock(),
		TotalDamage = 0,
		RoomsCleared = 0,
	}

	local originY = HollowConfig.StartOffset.Y
	local rooms = HollowConfig.Chambers

	-- Compute world positions from grid coordinates
	local roomWorldOrigins = {}
	for _, roomConfig in ipairs(rooms) do
		local grid = roomConfig.Grid
		roomWorldOrigins[roomConfig.RoomId] = gridToWorld(grid[1], grid[2])
	end

	-- Auto-compute openings per room from corridor definitions
	local roomOpenings = computeRoomOpenings()

	-- Build entrance room connected to Room 1's Front (+Z wall)
	local entranceRoomId = HollowConfig.EntranceRoom or 1
	local room1Origin = roomWorldOrigins[entranceRoomId]
	local room1Config = getRoomById(entranceRoomId)
	local room1Size = room1Config.Size
	local entranceOrigin = room1Origin + Vector3.new(0, 0, room1Size.Z / 2 + 30 + 25) -- 30 gap + 25 half entrance
	local entranceFolder = HollowBuilder.BuildEntranceRoom(dungeonFolder, entranceOrigin)
	dungeonData.EntranceFolder = entranceFolder

	-- Build corridor from entrance to Room 1 (always open, no door)
	local entFromZ = entranceOrigin.Z - 25 -- front of entrance
	local entToZ = room1Origin.Z + room1Size.Z / 2 -- front of Room 1
	buildCorridorZ(dungeonFolder, room1Origin.X, entFromZ, entToZ, originY, Enum.Material.Brick, BrickColor.new("Really black"), BrickColor.new("Dark stone grey"))

	-- Build all rooms
	for i, roomConfig in ipairs(rooms) do
		local worldOrigin = roomWorldOrigins[roomConfig.RoomId]
		local openings = roomOpenings[roomConfig.RoomId] or {}
		local roomFolder
		if roomConfig.RoomType == "Trap" then
			roomFolder = HollowBuilder.BuildTrapRoom(dungeonFolder, roomConfig, worldOrigin, i, dungeonData, player, openings)
		else
			roomFolder = HollowBuilder.BuildRoom(dungeonFolder, roomConfig, worldOrigin, i, openings)
		end
		-- Build puzzle inside puzzle-type rooms
		if roomConfig.RoomType == "Puzzle" and PuzzleEncounters then
			PuzzleEncounters.BuildPuzzle(roomFolder, worldOrigin, roomConfig.Size, dungeonData, i, player, roomConfig.PuzzleVariant)
		end
		-- Add themed decorations
		HollowBuilder.DecorateRoom(roomFolder, roomConfig, worldOrigin)
		-- Spawn hidden secret
		HollowBuilder.SpawnRoomSecrets(dungeonData, roomFolder, roomConfig, worldOrigin, i, player)

		dungeonData.RoomFolders[i] = roomFolder
		dungeonData.RoomStates[i] = "Locked"
		dungeonData.RoomEnemyCounts[i] = 0
	end

	-- Build all corridors using BuildGridCorridor
	for ci, corr in ipairs(HollowConfig.Corridors) do
		local fromConfig = getRoomById(corr.FromRoom)
		local toConfig = getRoomById(corr.ToRoom)
		if fromConfig and toConfig then
			local fromOrigin = roomWorldOrigins[corr.FromRoom]
			local toOrigin = roomWorldOrigins[corr.ToRoom]
			local door = HollowBuilder.BuildGridCorridor(
				dungeonFolder,
				fromOrigin, fromConfig.Size,
				toOrigin, toConfig.Size,
				corr.Dir, originY, corr.SealKey
			)
			dungeonData.CorridorDoors[ci] = {
				Door = door,
				SealType = corr.SealKey,
				RequiresBothShadow = corr.RequiresBothShadow or false,
				FromRoom = corr.FromRoom,
				ToRoom = corr.ToRoom,
			}
		end
	end

	-- Add ProximityPrompts to locked doors (player presses E to open with key)
	for ci, corrData in pairs(dungeonData.CorridorDoors) do
		if corrData.Door and corrData.SealType then
			local sealData = HollowConfig.SealTypes[corrData.SealType]
			if sealData then
				local prompt = Instance.new("ProximityPrompt")
				prompt.ActionText = "Use " .. sealData.Name
				prompt.ObjectText = sealData.Name .. " Door"
				prompt.KeyboardKeyCode = Enum.KeyCode.E
				prompt.HoldDuration = 0.3
				prompt.MaxActivationDistance = 15
				prompt.RequiresLineOfSight = false
				prompt.Parent = corrData.Door

				local capturedCi = ci
				prompt.Triggered:Connect(function(trigPlayer)
					if trigPlayer ~= player then return end
					local cd = dungeonData.CorridorDoors[capturedCi]
					if not cd or not cd.Door or not cd.Door.Parent then return end

					local kt = cd.SealType
					-- Check if player has the required key
					if cd.RequiresBothShadow then
						if (dungeonData.ShadowSealsCollected or 0) < 2 then
							local r = Remotes:GetEvent("DescentStateChanged")
							if r then r:FireClient(player, "DoorLocked", 0, "You need 2 Shadow Keys!") end
							return
						end
					else
						if not dungeonData.PlayerSeals[kt] then
							local r = Remotes:GetEvent("DescentStateChanged")
							if r then r:FireClient(player, "DoorLocked", 0, "You need the " .. sealData.Name .. "!") end
							return
						end
					end

					-- Open the door
					HollowBuilder.OpenSlidingDoor(cd.Door)
					cd.Door = nil

					-- Activate destination room
					local toRoomIndex = getRoomIndex(cd.ToRoom)
					if toRoomIndex and dungeonData.RoomStates[toRoomIndex] ~= "Active" and dungeonData.RoomStates[toRoomIndex] ~= "Cleared" then
						dungeonData.RoomStates[toRoomIndex] = "Active"
						HollowBuilder.SpawnRoomEnemies(dungeonData, toRoomIndex)
						fireMinimapDiscover(player, toRoomIndex)
						local r = Remotes:GetEvent("DescentStateChanged")
						if r then
							local rc = getRoomById(cd.ToRoom)
							r:FireClient(player, "RoomActivated", toRoomIndex, rc and rc.Name or "Room")
						end
					end
				end)
			end
		end
	end

	-- Unlock first room and spawn enemies only in Room 1
	dungeonData.RoomStates[1] = "Active"
	HollowBuilder.SpawnRoomEnemies(dungeonData, 1)

	-- Teleport player to entrance
	local character = player.Character
	if character then
		local rootPart = character:FindFirstChild("HumanoidRootPart")
		if rootPart then
			local spawnPos = entranceOrigin + Vector3.new(0, 3, 15)
			rootPart.CFrame = CFrame.new(spawnPos, spawnPos + Vector3.new(0, 0, -1))
		end
	end

	activeDungeons[player] = dungeonData

	-- Class selection handler
	dungeonData.SelectedClass = nil
	for _, desc in ipairs(entranceFolder:GetDescendants()) do
		if desc:IsA("ProximityPrompt") then
			desc.Triggered:Connect(function(trigPlayer)
				if trigPlayer ~= player then return end
				if dungeonData.SelectedClass then return end

				local pedestalPart = desc.Parent
				local vocationId = pedestalPart.Name:gsub("Pedestal_", "")
				dungeonData.SelectedClass = vocationId
				DelverDataService.ApplyVocationModifiers(player, vocationId)

				local classRemote = Remotes:GetEvent("VocationSelected")
				if classRemote then classRemote:FireClient(player, vocationId) end

				local toDestroy = {}
				for _, child in ipairs(entranceFolder:GetChildren()) do
					if child.Name:find("Pedestal_") then table.insert(toDestroy, child) end
				end
				for _, obj in ipairs(toDestroy) do obj:Destroy() end
			end)
		end
	end

	-- Notify client
	local remote = Remotes:GetEvent("DescentStateChanged")
	if remote then
		remote:FireClient(player, "DungeonStarted", 0, "Dungeon Entrance")
	end

	-- Send minimap data to client
	local minimapRemote = Remotes:GetEvent("MinimapInit")
	if minimapRemote then
		-- Convert HollowConfig's 0-based {col, row} grid into 1-based grid[row][col]
		local maxCol, maxRow = 0, 0
		for _, rc in ipairs(rooms) do
			local c, r = rc.Grid[1], rc.Grid[2]
			if c > maxCol then maxCol = c end
			if r > maxRow then maxRow = r end
		end
		local n = math.max(maxCol, maxRow) + 1 -- grid dimension

		local minimapGrid = {}
		for r = 1, n do
			minimapGrid[r] = {}
		end

		-- Room type mapping (HollowConfig uses "Combat"/"Trap", minimap expects "normal"/"trap"/etc.)
		local function resolveRoomType(rc)
			if rc.IsBossRoom then return "boss" end
			-- Check if room has a miniboss enemy
			if rc.Enemies then
				for _, e in ipairs(rc.Enemies) do
					if e.DropsKey then return "miniboss" end
				end
			end
			if rc.RoomType == "Trap" then return "trap" end
			return "normal"
		end

		for _, rc in ipairs(rooms) do
			local col1 = rc.Grid[1] + 1 -- to 1-based
			local row1 = rc.Grid[2] + 1
			if row1 >= 1 and row1 <= n and col1 >= 1 and col1 <= n then
				minimapGrid[row1][col1] = {
					RoomType = resolveRoomType(rc),
					Name = rc.Name,
					RoomId = rc.RoomId,
				}
			end
		end

		-- Build corridor data for minimap connectors
		local minimapCorridors = {}
		for _, corr in ipairs(HollowConfig.Corridors) do
			local fromConfig = getRoomById(corr.FromRoom)
			local toConfig = getRoomById(corr.ToRoom)
			if fromConfig and toConfig then
				table.insert(minimapCorridors, {
					FromRow = fromConfig.Grid[2] + 1,
					FromCol = fromConfig.Grid[1] + 1,
					ToRow = toConfig.Grid[2] + 1,
					ToCol = toConfig.Grid[1] + 1,
					Dir = corr.Dir,
					SealKey = corr.SealKey,
				})
			end
		end

		minimapRemote:FireClient(player, {
			Grid = minimapGrid,
			TileSize = HollowConfig.GridSpacing,
			Corridors = minimapCorridors,
			StartOffset = { X = HollowConfig.StartOffset.X, Z = HollowConfig.StartOffset.Z },
		})
	end

	-- Death handler
	local function connectDeathHandler(char)
		local humanoid = char:WaitForChild("Humanoid", 5)
		if humanoid then
			humanoid.Died:Connect(function()
				if activeDungeons[player] then
					HollowBuilder.OnPlayerDied(player)
				end
			end)
		end
	end

	if character then connectDeathHandler(character) end

	dungeonData.CharAddedConn = player.CharacterAdded:Connect(function(newChar)
		if activeDungeons[player] then
			connectDeathHandler(newChar)
		else
			if dungeonData.CharAddedConn then
				dungeonData.CharAddedConn:Disconnect()
				dungeonData.CharAddedConn = nil
			end
		end
	end)
end

--------------------------------------------------------------------------------
-- HP SCALING: enemies get tougher the deeper the room (based on grid row)
-- Row 0 = 1.0×, each subsequent row adds 15% HP.
--------------------------------------------------------------------------------
local HP_SCALE_PER_ROW = 0.15

local function getHPScale(roomConfig)
	local row = roomConfig.Grid and roomConfig.Grid[2] or 0
	return 1 + row * HP_SCALE_PER_ROW
end

--------------------------------------------------------------------------------
-- SPAWN ENEMIES
--------------------------------------------------------------------------------
function HollowBuilder.SpawnRoomEnemies(dungeonData, roomIndex)
	local roomConfig = HollowConfig.Chambers[roomIndex]
	if not roomConfig then return end
	if roomConfig.RoomType == "Trap" or roomConfig.RoomType == "Puzzle" then
		dungeonData.RoomEnemyCounts[roomIndex] = 0
		return
	end

	local roomFolder = dungeonData.RoomFolders[roomIndex]
	if not roomFolder then return end

	local roomOrigin = HollowConfig.StartOffset
	local floorPart = roomFolder:FindFirstChild("Floor")
	if floorPart then
		roomOrigin = floorPart.Position + Vector3.new(0, floorPart.Size.Y/2, 0)
	end
	local roomSize = roomConfig.Size
	local hpScale = getHPScale(roomConfig)

	-- Count total enemies for even circular distribution
	local totalCount = 0
	for _, e in ipairs(roomConfig.Enemies) do totalCount = totalCount + e.Count end

	local enemyIndex = 0
	for _, enemyEntry in ipairs(roomConfig.Enemies) do
		for i = 1, enemyEntry.Count do
			enemyIndex = enemyIndex + 1
			local angle = (enemyIndex / totalCount) * math.pi * 2
			local radius = roomSize.X * 0.3
			local spawnOffset = Vector3.new(math.cos(angle) * radius, 3, math.sin(angle) * radius * 0.5)
			local model = HollowBuilder.SpawnSingleEnemy(enemyEntry.Id, roomOrigin + spawnOffset, roomFolder, hpScale)
			if model and enemyEntry.DropsKey then
				model:SetAttribute("DropsKey", enemyEntry.DropsKey)
			end
		end
	end

	dungeonData.RoomEnemyCounts[roomIndex] = enemyIndex
end

function HollowBuilder.SpawnSingleEnemy(enemyId, spawnPos, parentFolder, hpScale)
	local config = CreatureConfig.Creatures[enemyId]
	if not config then return end

	local model = Instance.new("Model")
	model.Name = config.Name

	local scaleX = config.BodySize.X / 2
	local scaleY = config.BodySize.Y / 3
	local scaleZ = config.BodySize.Z / 1.5

	local function makeEnemyPart(name, size)
		local part = Instance.new("Part")
		part.Name = name; part.Size = size
		part.BrickColor = config.BodyColor; part.Material = Enum.Material.SmoothPlastic
		part.CanCollide = false; part.Anchored = false; part.Parent = model
		return part
	end

	local function makeMotor6D(name, part0, part1, c0, c1)
		local motor = Instance.new("Motor6D")
		motor.Name = name; motor.Part0 = part0; motor.Part1 = part1
		motor.C0 = c0; motor.C1 = c1; motor.Parent = part0
	end

	local rootPart = Instance.new("Part")
	rootPart.Name = "HumanoidRootPart"
	rootPart.Size = Vector3.new(2*scaleX, 2*scaleY, 1*scaleZ)
	rootPart.Transparency = 1; rootPart.CanCollide = false; rootPart.Anchored = false
	rootPart.Position = spawnPos; rootPart.Parent = model

	local torso = makeEnemyPart("Torso", Vector3.new(2*scaleX, 2*scaleY, 1*scaleZ))
	makeMotor6D("RootJoint", rootPart, torso, CFrame.new(), CFrame.new())

	local headSize = config.HeadSize
	local head = Instance.new("Part")
	head.Name = "Head"; head.Size = Vector3.new(headSize.X, headSize.Y, headSize.Z)
	head.BrickColor = config.BodyColor; head.Material = Enum.Material.SmoothPlastic
	head.CanCollide = false; head.Anchored = false; head.Parent = model
	local face = Instance.new("Decal"); face.Name = "face"; face.Face = Enum.NormalId.Front; face.Parent = head
	makeMotor6D("Neck", torso, head, CFrame.new(0, 1*scaleY, 0), CFrame.new(0, -headSize.Y/2, 0))

	local leftArm = makeEnemyPart("Left Arm", Vector3.new(1*scaleX, 2*scaleY, 1*scaleZ))
	makeMotor6D("Left Shoulder", torso, leftArm, CFrame.new(-1*scaleX, 0.5*scaleY, 0), CFrame.new(0.5*scaleX, 0.5*scaleY, 0))
	local rightArm = makeEnemyPart("Right Arm", Vector3.new(1*scaleX, 2*scaleY, 1*scaleZ))
	makeMotor6D("Right Shoulder", torso, rightArm, CFrame.new(1*scaleX, 0.5*scaleY, 0), CFrame.new(-0.5*scaleX, 0.5*scaleY, 0))
	local leftLeg = makeEnemyPart("Left Leg", Vector3.new(1*scaleX, 2*scaleY, 1*scaleZ))
	makeMotor6D("Left Hip", torso, leftLeg, CFrame.new(-0.5*scaleX, -1*scaleY, 0), CFrame.new(0, 1*scaleY, 0))
	local rightLeg = makeEnemyPart("Right Leg", Vector3.new(1*scaleX, 2*scaleY, 1*scaleZ))
	makeMotor6D("Right Hip", torso, rightLeg, CFrame.new(0.5*scaleX, -1*scaleY, 0), CFrame.new(0, 1*scaleY, 0))

	hpScale = hpScale or 1
	local scaledHealth = math.floor(config.Health * hpScale)

	local humanoid = Instance.new("Humanoid")
	humanoid.MaxHealth = scaledHealth; humanoid.Health = scaledHealth
	humanoid.WalkSpeed = config.Speed; humanoid.Parent = model

	model.PrimaryPart = rootPart

	model:SetAttribute("IsEnemy", true); model:SetAttribute("IsDead", false)
	model:SetAttribute("EnemyId", enemyId); model:SetAttribute("CurrentHP", scaledHealth)
	model:SetAttribute("MaxHP", scaledHealth); model:SetAttribute("Defense", config.Defense)
	model:SetAttribute("IsBoss", config.Behavior == "Boss")

	local totalHeight = config.BodySize.Y + config.HeadSize.Y
	local billboard = Instance.new("BillboardGui")
	billboard.Name = "HealthBar"; billboard.Size = UDim2.new(4,0,0.5,0)
	billboard.StudsOffset = Vector3.new(0, totalHeight/2+1.5, 0); billboard.AlwaysOnTop = true
	billboard.Parent = rootPart

	local bg = Instance.new("Frame"); bg.Name = "Background"
	bg.Size = UDim2.new(1,0,1,0); bg.BackgroundColor3 = Color3.fromRGB(50,50,50); bg.BorderSizePixel = 0; bg.Parent = billboard
	local fill = Instance.new("Frame"); fill.Name = "Fill"
	fill.Size = UDim2.new(1,0,1,0)
	fill.BackgroundColor3 = config.Behavior == "Boss" and Color3.fromRGB(255,50,50) or Color3.fromRGB(0,200,0)
	fill.BorderSizePixel = 0; fill.Parent = bg
	local nameLabel = Instance.new("TextLabel"); nameLabel.Name = "NameLabel"
	nameLabel.Size = UDim2.new(1,0,1,0); nameLabel.BackgroundTransparency = 1
	nameLabel.Text = config.Name; nameLabel.TextColor3 = Color3.new(1,1,1)
	nameLabel.TextScaled = true; nameLabel.Font = Enum.Font.GothamBold; nameLabel.Parent = billboard

	model.Parent = parentFolder

	if CreatureAI then CreatureAI.RegisterEnemy(model, enemyId) end
	return model
end

--------------------------------------------------------------------------------
-- ENEMY DIED -> KEY SPAWN
--------------------------------------------------------------------------------
function HollowBuilder.OnEnemyDied(enemyModel)
	local enemyId = enemyModel:GetAttribute("EnemyId")
	local isBoss = enemyModel:GetAttribute("IsBoss")
	local dropsKey = enemyModel:GetAttribute("DropsKey")

	for player, data in pairs(activeDungeons) do
		for roomIndex, roomFolder in pairs(data.RoomFolders) do
			if enemyModel:IsDescendantOf(roomFolder) then
				if LootSystem then LootSystem.GrantLoot(player, enemyId, isBoss) end

				-- Miniboss drops its key on death
				if dropsKey then
					HollowBuilder.SpawnMinibossKey(player, data, roomIndex, enemyModel, dropsKey)
				end

				data.RoomEnemyCounts[roomIndex] = (data.RoomEnemyCounts[roomIndex] or 1) - 1

				if data.RoomEnemyCounts[roomIndex] <= 0 then
					HollowBuilder.RoomCleared(player, data, roomIndex)
				end
				return
			end
		end
	end
end

--------------------------------------------------------------------------------
-- SPAWN KEY FROM MINIBOSS DEATH
--------------------------------------------------------------------------------
function HollowBuilder.SpawnMinibossKey(player, data, roomIndex, enemyModel, sealTypeId)
	local sealData = HollowConfig.SealTypes[sealTypeId]
	if not sealData then return end

	local dropPos = Vector3.new(0, 5, 0)
	local rootPart = enemyModel:FindFirstChild("HumanoidRootPart")
	if rootPart then dropPos = rootPart.Position end

	local keyPos = dropPos + Vector3.new(0, 2, 0)

	local key = Instance.new("Part")
	key.Name = "Key_" .. sealTypeId
	key.Size = Vector3.new(2.5, 2.5, 2.5)
	key.Position = keyPos
	key.Anchored = true
	key.CanCollide = false
	key.Shape = Enum.PartType.Ball
	key.Material = Enum.Material.Neon
	key.BrickColor = sealData.BrickColor
	key.Parent = data.RoomFolders[roomIndex]

	-- Glow
	local light = Instance.new("PointLight")
	light.Color = sealData.Color; light.Range = 20; light.Brightness = 3; light.Parent = key

	-- Sparkles
	local sparkle = Instance.new("Sparkles")
	sparkle.SparkleColor = sealData.Color; sparkle.Parent = key

	-- Label
	local bb = Instance.new("BillboardGui")
	bb.Size = UDim2.new(0, 140, 0, 45)
	bb.StudsOffset = Vector3.new(0, 3, 0); bb.AlwaysOnTop = true; bb.Parent = key
	local lbl = Instance.new("TextLabel")
	lbl.Size = UDim2.new(1,0,1,0); lbl.BackgroundTransparency = 1
	lbl.Text = sealData.Name
	lbl.TextColor3 = sealData.Color
	lbl.TextStrokeTransparency = 0; lbl.TextStrokeColor3 = Color3.fromRGB(0,0,0)
	lbl.TextScaled = true; lbl.Font = Enum.Font.GothamBold; lbl.Parent = bb

	-- Bobbing
	local bobUp = TweenService:Create(key, TweenInfo.new(0.8, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), {
		Position = keyPos + Vector3.new(0, 2, 0)
	})
	bobUp:Play()

	-- Touch hitbox
	local hitbox = Instance.new("Part")
	hitbox.Name = "KeyHitbox"; hitbox.Size = Vector3.new(8, 8, 8)
	hitbox.Position = keyPos + Vector3.new(0, 2, 0)
	hitbox.Anchored = true; hitbox.CanCollide = false; hitbox.Transparency = 1
	hitbox.Parent = key

	hitbox.Touched:Connect(function(hit)
		local character = hit.Parent
		local humanoid = character and character:FindFirstChild("Humanoid")
		if not humanoid then return end
		local touchPlayer = Players:GetPlayerFromCharacter(character)
		if touchPlayer ~= player then return end
		if key:GetAttribute("PickedUp") then return end
		key:SetAttribute("PickedUp", true)

		-- Add key to player's collection
		data.PlayerSeals[sealTypeId] = true

		-- Track shadow keys
		if sealTypeId == "Shadow" then
			data.ShadowSealsCollected = (data.ShadowSealsCollected or 0) + 1
		end

		-- Notify client (key goes to inventory, does NOT auto-open doors)
		local remote = Remotes:GetEvent("DescentStateChanged")
		if remote then
			remote:FireClient(player, "KeyPickedUp", roomIndex, sealData.Name, {sealData.Color.R, sealData.Color.G, sealData.Color.B})
		end

		key:Destroy()
	end)

	-- Notify client that key dropped
	local remote = Remotes:GetEvent("DescentStateChanged")
	if remote then
		remote:FireClient(player, "KeySpawned", roomIndex, sealData.Name, {sealData.Color.R, sealData.Color.G, sealData.Color.B})
	end
end

--------------------------------------------------------------------------------
-- ROOM CLEARED
--------------------------------------------------------------------------------
function HollowBuilder.RoomCleared(player, data, roomIndex)
	data.RoomStates[roomIndex] = "Cleared"
	data.ChambersCleared = (data.ChambersCleared or 0) + 1
	fireMinimapCleared(player, roomIndex)

	local remote = Remotes:GetEvent("DescentStateChanged")
	local roomConfig = HollowConfig.Chambers[roomIndex]

	-- Boss room -> dungeon complete
	if roomConfig and roomConfig.IsBossRoom then
		local elapsed = os.clock() - (data.StartTime or os.clock())
		local timeScore = math.max(0, RunGrading.TimeBonus - math.floor(elapsed))
		local damageScore = math.floor((data.TotalDamage or 0) / RunGrading.DamagePerPoint)
		local roomScore = (data.ChambersCleared or 0) * RunGrading.RoomClearBonus
		local deathScore = (data.Deaths or 0) * RunGrading.DeathPenalty
		local puzzleScore = data.PuzzleScore or 0
		local secretScore = data.SecretScore or 0
		local totalScore = math.max(0, timeScore + damageScore + roomScore + deathScore + puzzleScore + secretScore)

		local grade = "D"
		local gradeColor = {1, 0.2, 0.2}
		for _, g in ipairs(RunGrading.Grades) do
			if totalScore >= g.MinScore then
				grade = g.Grade; gradeColor = {g.Color.R, g.Color.G, g.Color.B}; break
			end
		end

		local scoreRemote = Remotes:GetEvent("DescentScore")
		if scoreRemote then
			scoreRemote:FireClient(player, {
				Grade = grade, GradeColor = gradeColor, Score = totalScore,
				Time = math.floor(elapsed), Deaths = data.Deaths or 0,
				DamageDealt = data.TotalDamage or 0, RoomsCleared = data.ChambersCleared or 0,
			})
		end

		if remote then remote:FireClient(player, "DescentComplete", roomIndex, "Dungeon Complete!") end

		-- Award dungeon clear XP (scaled by rooms cleared as floor proxy)
		if DelverProgression then
			DelverProgression.OnDescentClear(player, data.ChambersCleared or 1)
		end

		task.wait(8)
		HollowBuilder.TeleportToLobby(player)
		HollowBuilder.CleanupDungeon(player)
		DelverDataService.ResetStats(player)
		return
	end

	-- Notify room cleared
	if remote then
		remote:FireClient(player, "RoomCleared", roomIndex, roomConfig and roomConfig.Name or "Room")
	end

	-- Spawn treasure chest
	local clearedRoomFolder = data.RoomFolders[roomIndex]
	local chestOrigin = HollowConfig.StartOffset
	if clearedRoomFolder then
		local floorPart = clearedRoomFolder:FindFirstChild("Floor")
		if floorPart then chestOrigin = floorPart.Position + Vector3.new(0, floorPart.Size.Y/2, 0) end
	end
	HollowBuilder.SpawnCache(data, chestOrigin, roomIndex, player)

	-- Activate adjacent rooms connected without doors
	if roomConfig then
		local roomId = roomConfig.RoomId
		for _, corr in ipairs(HollowConfig.Corridors) do
			if not corr.SealKey then
				local neighborId = nil
				if corr.FromRoom == roomId then neighborId = corr.ToRoom end
				if corr.ToRoom == roomId then neighborId = corr.FromRoom end
				if neighborId then
					local neighborIndex = getRoomIndex(neighborId)
					if neighborIndex and data.RoomStates[neighborIndex] == "Locked" then
						data.RoomStates[neighborIndex] = "Active"
						HollowBuilder.SpawnRoomEnemies(data, neighborIndex)
						fireMinimapDiscover(player, neighborIndex)
						if remote then
							local neighborConfig = getRoomById(neighborId)
							remote:FireClient(player, "RoomActivated", neighborIndex, neighborConfig and neighborConfig.Name or "Room")
						end
					end
				end
			end
		end
	end
end

--------------------------------------------------------------------------------
-- TELEPORT, GHOST MODE, DEATH, RESPAWN (unchanged logic)
--------------------------------------------------------------------------------
function HollowBuilder.TeleportToLobby(player)
	local character = player.Character
	if character then
		local rootPart = character:FindFirstChild("HumanoidRootPart")
		if rootPart then rootPart.CFrame = CFrame.new(HollowConfig.LobbySpawn + Vector3.new(0, 3, 0)) end
	end
end

local pendingRespawns = {}

function HollowBuilder.EnterGhostMode(player)
	local character = player.Character
	if not character then return end

	player:LoadCharacter()
	task.wait(0.5)
	character = player.Character
	if not character then return end

	local humanoid = character:WaitForChild("Humanoid", 5)
	local rootPart = character:FindFirstChild("HumanoidRootPart")
	if not humanoid or not rootPart then return end

	-- Teleport ghost to active room
	local data = activeDungeons[player]
	if data then
		for i = #HollowConfig.Chambers, 1, -1 do
			if data.RoomStates[i] == "Active" then
				local roomFolder = data.RoomFolders[i]
				if roomFolder then
					local floorPart = roomFolder:FindFirstChild("Floor")
					if floorPart then
						rootPart.CFrame = CFrame.new(floorPart.Position + Vector3.new(0, floorPart.Size.Y/2 + 5, 0))
					end
				end
				break
			end
		end
	end

	local originalTransparencies = {}
	for _, part in ipairs(character:GetDescendants()) do
		if part:IsA("BasePart") then
			originalTransparencies[part] = part.Transparency
			part.Transparency = 0.7; part.CanCollide = false
		end
	end

	local ghostHighlight = Instance.new("Highlight")
	ghostHighlight.Name = "GhostHighlight"
	ghostHighlight.FillColor = Color3.fromRGB(100, 150, 255); ghostHighlight.FillTransparency = 0.5
	ghostHighlight.OutlineColor = Color3.fromRGB(150, 200, 255); ghostHighlight.OutlineTransparency = 0.3
	ghostHighlight.Parent = character

	humanoid.MaxHealth = math.huge; humanoid.Health = math.huge
	character:SetAttribute("IsGhost", true)

	return originalTransparencies
end

function HollowBuilder.ExitGhostMode(player, originalTransparencies)
	local character = player.Character
	if not character then return end

	local humanoid = character:FindFirstChild("Humanoid")
	local rootPart = character:FindFirstChild("HumanoidRootPart")

	local highlight = character:FindFirstChild("GhostHighlight")
	if highlight then highlight:Destroy() end

	if originalTransparencies then
		for part, origTrans in pairs(originalTransparencies) do
			if part and part.Parent then part.Transparency = origTrans; part.CanCollide = true end
		end
	else
		for _, part in ipairs(character:GetDescendants()) do
			if part:IsA("BasePart") then
				part.Transparency = part.Name == "HumanoidRootPart" and 1 or 0
				part.CanCollide = true
			end
		end
	end

	character:SetAttribute("IsGhost", false)

	local data = activeDungeons[player]
	if humanoid then
		local pds = require(script.Parent:WaitForChild("DelverDataService"))
		local stats = pds.GetStats(player)
		local maxHP = stats and stats.MaxHP or 100
		humanoid.MaxHealth = maxHP; humanoid.Health = maxHP * 0.5
	end

	if data and rootPart then
		for i = #HollowConfig.Chambers, 1, -1 do
			if data.RoomStates[i] == "Active" then
				local roomFolder = data.RoomFolders[i]
				if roomFolder then
					local floorPart = roomFolder:FindFirstChild("Floor")
					if floorPart then
						rootPart.CFrame = CFrame.new(floorPart.Position + Vector3.new(0, floorPart.Size.Y/2 + 5, 0))
					end
				end
				break
			end
		end
	end
end

function HollowBuilder.OnPlayerDied(player)
	local data = activeDungeons[player]
	if not data then return end
	if data.IsGhost then return end

	data.Deaths = (data.Deaths or 0) + 1
	data.DeathTime = os.clock()
	data.IsGhost = true

	local originalTransparencies = HollowBuilder.EnterGhostMode(player)

	local diedRemote = Remotes:GetEvent("FallenState")
	if diedRemote then diedRemote:FireClient(player, data.Deaths, 5) end

	pendingRespawns[player] = true
	for i = 1, 50 do
		if not pendingRespawns[player] then break end
		task.wait(0.1)
	end
	pendingRespawns[player] = nil

	HollowBuilder.ExitGhostMode(player, originalTransparencies)
	data.IsGhost = false; data.DeathTime = nil

	local revivedRemote = Remotes:GetEvent("RevivePlayer")
	if revivedRemote then revivedRemote:FireClient(player) end
end

function HollowBuilder.RequestEarlyRespawn(player)
	local data = activeDungeons[player]
	if not data then return end
	if not data.DeathTime then return end
	if os.clock() - data.DeathTime < 3 then return end
	pendingRespawns[player] = nil
end

--------------------------------------------------------------------------------
-- CLEANUP
--------------------------------------------------------------------------------
function HollowBuilder.CleanupDungeon(player)
	local data = activeDungeons[player]
	if not data then return end

	if data.CharAddedConn then data.CharAddedConn:Disconnect(); data.CharAddedConn = nil end

	if data.TrapConnections then
		for _, conn in ipairs(data.TrapConnections) do
			if conn and conn.Connected then conn:Disconnect() end
		end
	end

	if data.Folder then
		for _, desc in ipairs(data.Folder:GetDescendants()) do
			if desc:IsA("Model") and desc:GetAttribute("IsEnemy") then
				CreatureAI.UnregisterEnemy(desc)
			end
		end
		data.Folder:Destroy()
	end

	activeDungeons[player] = nil
end

function HollowBuilder.CleanupPlayer(player) HollowBuilder.CleanupDungeon(player) end
function HollowBuilder.GetActiveDungeon(player) return activeDungeons[player] end
function HollowBuilder.AddDamageTracking(player, damage)
	local data = activeDungeons[player]
	if data then data.TotalDamage = (data.TotalDamage or 0) + damage end
end

--------------------------------------------------------------------------------
-- CHEST
--------------------------------------------------------------------------------
function HollowBuilder.SpawnCache(dungeonData, position, roomIndex, player)
	local roomFolder = dungeonData.RoomFolders[roomIndex]
	if not roomFolder then return end

	local tierName = "Common"
	if roomIndex >= 4 then tierName = "Legendary"
	elseif roomIndex >= 2 then tierName = "Rare" end

	local chest = Instance.new("Part")
	chest.Name = "TreasureCache"; chest.Size = Vector3.new(3, 2.5, 2.5)
	chest.Position = position + Vector3.new(0, 1.5, 0)
	chest.Anchored = true; chest.BrickColor = BrickColor.new("Brown"); chest.Material = Enum.Material.Wood
	chest.Parent = roomFolder

	local light = Instance.new("PointLight"); light.Color = Color3.fromRGB(255,215,0); light.Range = 15; light.Brightness = 2; light.Parent = chest
	local sparkles = Instance.new("ParticleEmitter")
	sparkles.Color = ColorSequence.new(Color3.fromRGB(255,215,0)); sparkles.Size = NumberSequence.new(0.3,0)
	sparkles.Lifetime = NumberRange.new(0.5,1); sparkles.Rate = 20; sparkles.Speed = NumberRange.new(2,4); sparkles.Parent = chest

	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Open Cache"; prompt.ObjectText = tierName .. " Cache"
	prompt.HoldDuration = 0.5; prompt.MaxActivationDistance = 10; prompt.Parent = chest

	prompt.Triggered:Connect(function(trigPlayer)
		if trigPlayer ~= player then return end
		LootSystem.GrantCacheLoot(player, roomIndex)
		local remote = Remotes:GetEvent("CacheOpened")
		if remote then remote:FireClient(player, tierName) end
		chest:Destroy()
	end)
end

--------------------------------------------------------------------------------
-- TRAP ROOM
--------------------------------------------------------------------------------
function HollowBuilder.BuildTrapRoom(parent, config, origin, roomIndex, dungeonData, player, openings)
	local roomFolder = HollowBuilder.BuildRoom(parent, config, origin, roomIndex, openings)

	local trapConfig = config.TrapConfig
	if not trapConfig then return roomFolder end

	local size = config.Size
	local obstacles = {}
	local obstacleCount = trapConfig.ObstacleCount or 6
	local speed = trapConfig.ObstacleSpeed or 2
	local killDebounce = {}

	for i = 1, obstacleCount do
		local zFraction = i / (obstacleCount + 1)
		local zOffset = size.Z / 2 - zFraction * size.Z
		local obstacleType = i % 3

		local obstacle = Instance.new("Part")
		obstacle.Name = "TrapObstacle_" .. i
		if obstacleType == 1 then
			obstacle.Size = Vector3.new(2, 8, 2)
			obstacle.Position = origin + Vector3.new(0, 4, zOffset)
		elseif obstacleType == 2 then
			obstacle.Size = Vector3.new(4, 4, 2)
			obstacle.Position = origin + Vector3.new(0, 4, zOffset)
		else
			obstacle.Size = Vector3.new(4, 4, 4)
			obstacle.Position = origin + Vector3.new(0, 2, zOffset)
		end

		obstacle.Anchored = true; obstacle.CanCollide = false
		obstacle.BrickColor = BrickColor.new("Bright red"); obstacle.Material = Enum.Material.Neon
		obstacle.Transparency = 0.1; obstacle.Parent = roomFolder

		local particles = Instance.new("ParticleEmitter")
		particles.Color = ColorSequence.new(Color3.fromRGB(255,50,50))
		particles.Size = NumberSequence.new(0.3,0); particles.Lifetime = NumberRange.new(0.3,0.6)
		particles.Rate = 20; particles.Speed = NumberRange.new(1,3); particles.Parent = obstacle

		obstacle.Touched:Connect(function(hit)
			local character = hit.Parent
			if not character then return end
			if character:GetAttribute("IsGhost") then return end
			local humanoid = character:FindFirstChildOfClass("Humanoid")
			if not humanoid then return end
			local touchPlayer = Players:GetPlayerFromCharacter(character)
			if not touchPlayer then return end
			if killDebounce[touchPlayer] then return end
			killDebounce[touchPlayer] = true
			humanoid.Health = 0
			task.delay(2, function() killDebounce[touchPlayer] = nil end)
		end)

		table.insert(obstacles, {Part = obstacle, BasePos = obstacle.Position, Phase = i * math.pi / 3, Index = i, Type = obstacleType})
	end

	local trapConn = RunService.Heartbeat:Connect(function()
		for _, o in ipairs(obstacles) do
			if o.Part and o.Part.Parent then
				if o.Type == 1 then
					local xOff = math.sin(os.clock() * speed + o.Phase) * (size.X / 2 - 4)
					o.Part.CFrame = CFrame.new(origin.X + xOff, o.BasePos.Y, o.BasePos.Z) * CFrame.Angles(0, os.clock() * speed * 2, 0)
				elseif o.Type == 2 then
					local xOff = math.sin(os.clock() * speed * 1.5 + o.Phase) * (size.X / 2 - 4)
					local yOff = math.abs(math.sin(os.clock() * speed * 0.8 + o.Phase)) * 4
					o.Part.Position = Vector3.new(origin.X + xOff, o.BasePos.Y + yOff, o.BasePos.Z)
				else
					local xOff = math.sin(os.clock() * speed * 0.7 + o.Phase) * (size.X / 2 - 4)
					o.Part.Position = Vector3.new(origin.X + xOff, o.BasePos.Y, o.BasePos.Z)
				end
			end
		end
	end)

	if not dungeonData.TrapConnections then dungeonData.TrapConnections = {} end
	table.insert(dungeonData.TrapConnections, trapConn)

	local trigger = Instance.new("Part")
	trigger.Name = "ClearTrigger"; trigger.Size = Vector3.new(size.X, size.Y, 4)
	trigger.Position = origin + Vector3.new(0, size.Y / 2, -size.Z / 2 + 4)
	trigger.Anchored = true; trigger.CanCollide = false; trigger.Transparency = 1; trigger.Parent = roomFolder

	trigger.Touched:Connect(function(hit)
		local touchPlayer = Players:GetPlayerFromCharacter(hit.Parent)
		if touchPlayer and touchPlayer == player then
			local data = activeDungeons[touchPlayer]
			if data and data.RoomStates[roomIndex] == "Active" then
				HollowBuilder.RoomCleared(touchPlayer, data, roomIndex)
				trigger:Destroy()
			end
		end
	end)

	return roomFolder
end

return HollowBuilder
