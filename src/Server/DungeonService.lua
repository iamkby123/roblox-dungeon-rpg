local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local DungeonConfig = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("DungeonConfig"))
local EnemyConfig = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("EnemyConfig"))
local ClassConfig = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("ClassConfig"))
local ScoreConfig = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("ScoreConfig"))
local Remotes = require(ReplicatedStorage:WaitForChild("Remotes"))

local DungeonService = {}

local EnemyAI
local LootService
local PlayerDataService

local activeDungeons = {}

function DungeonService.Init(enemyAISvc, lootSvc, playerDataSvc)
	EnemyAI = enemyAISvc
	LootService = lootSvc
	PlayerDataService = playerDataSvc
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
	for _, r in ipairs(DungeonConfig.Rooms) do
		if r.RoomId == roomId then return r end
	end
	return nil
end

--------------------------------------------------------------------------------
-- HELPER: Get room array index by RoomId
--------------------------------------------------------------------------------
local function getRoomIndex(roomId)
	for i, r in ipairs(DungeonConfig.Rooms) do
		if r.RoomId == roomId then return i end
	end
	return nil
end

--------------------------------------------------------------------------------
-- GRID POSITION: compute world origin from Grid = {col, row}
--------------------------------------------------------------------------------
local function gridToWorld(col, row)
	local startOffset = DungeonConfig.StartOffset
	local spacing = DungeonConfig.GridSpacing
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
	for _, r in ipairs(DungeonConfig.Rooms) do
		openings[r.RoomId] = {}
	end

	-- Add "Front" opening to the entrance room (Room 1) for the entrance corridor
	local entranceRoomId = DungeonConfig.EntranceRoom or 1
	if openings[entranceRoomId] then
		openings[entranceRoomId]["Front"] = true
	end

	-- Derive openings from corridor definitions
	for _, corr in ipairs(DungeonConfig.Corridors) do
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
-- BUILD ENTRANCE ROOM
--------------------------------------------------------------------------------
function DungeonService.BuildEntranceRoom(parent, origin)
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
	local tl = Instance.new("TextLabel"); tl.Size=UDim2.new(1,0,0.5,0); tl.BackgroundTransparency=1; tl.Text="DUNGEON ENTRANCE"; tl.TextColor3=Color3.fromRGB(255,200,50); tl.TextScaled=true; tl.Font=Enum.Font.GothamBold; tl.Parent=sg
	local il = Instance.new("TextLabel"); il.Size=UDim2.new(1,0,0.5,0); il.Position=UDim2.new(0,0,0.5,0); il.BackgroundTransparency=1; il.Text="Collect keys to unlock doors!"; il.TextColor3=Color3.fromRGB(200,200,200); il.TextScaled=true; il.Font=Enum.Font.Gotham; il.Parent=sg

	-- Class pedestals
	for _, pedestalInfo in ipairs(ClassConfig.PedestalLayout) do
		local classData = ClassConfig.Classes[pedestalInfo.ClassId]
		if classData then
			local pedPos = origin + pedestalInfo.Offset
			local pedestal = Instance.new("Part")
			pedestal.Name = "Pedestal_" .. pedestalInfo.ClassId
			pedestal.Shape = Enum.PartType.Cylinder
			pedestal.Size = Vector3.new(1, 4, 4)
			pedestal.CFrame = CFrame.new(pedPos) * CFrame.Angles(0, 0, math.rad(90))
			pedestal.Anchored = true
			pedestal.BrickColor = classData.Color
			pedestal.Material = Enum.Material.SmoothPlastic
			pedestal.Parent = f

			local pillar = Instance.new("Part")
			pillar.Name = "Pedestal_Pillar_" .. pedestalInfo.ClassId
			pillar.Size = Vector3.new(0.5, 10, 0.5)
			pillar.Position = pedPos + Vector3.new(0, 6, 0)
			pillar.Anchored = true; pillar.CanCollide = false
			pillar.BrickColor = classData.Color; pillar.Material = Enum.Material.Neon; pillar.Transparency = 0.3
			pillar.Parent = f

			local signPart = Instance.new("Part")
			signPart.Name = "Pedestal_Sign_" .. pedestalInfo.ClassId
			signPart.Size = Vector3.new(6, 3, 0.2)
			signPart.Position = pedPos + Vector3.new(0, 4, -2)
			signPart.Anchored = true; signPart.CanCollide = false
			signPart.Material = Enum.Material.SmoothPlastic; signPart.BrickColor = BrickColor.new("Really black")
			signPart.Parent = f

			local signGui = Instance.new("SurfaceGui"); signGui.Face = Enum.NormalId.Back; signGui.Parent = signPart
			local nameLabel = Instance.new("TextLabel")
			nameLabel.Size = UDim2.new(1,0,0.4,0); nameLabel.BackgroundTransparency = 1
			nameLabel.Text = classData.Name
			nameLabel.TextColor3 = Color3.new(classData.Color.r, classData.Color.g, classData.Color.b)
			nameLabel.TextScaled = true; nameLabel.Font = Enum.Font.GothamBold; nameLabel.Parent = signGui
			local descLabel = Instance.new("TextLabel")
			descLabel.Size = UDim2.new(1,0,0.6,0); descLabel.Position = UDim2.new(0,0,0.4,0)
			descLabel.BackgroundTransparency = 1; descLabel.Text = classData.Description
			descLabel.TextColor3 = Color3.fromRGB(200,200,200); descLabel.TextScaled = true; descLabel.TextWrapped = true
			descLabel.Font = Enum.Font.Gotham; descLabel.Parent = signGui

			local prompt = Instance.new("ProximityPrompt")
			prompt.ActionText = "Select " .. classData.Name; prompt.ObjectText = classData.Name
			prompt.HoldDuration = 0.3; prompt.MaxActivationDistance = 8; prompt.Parent = pedestal
		end
	end

	return f
end

--------------------------------------------------------------------------------
-- BUILD ROOM -- configurable wall openings (receives openings table)
--------------------------------------------------------------------------------
function DungeonService.BuildRoom(parent, config, origin, roomIndex, openings)
	local roomFolder = Instance.new("Folder")
	roomFolder.Name = "Room_" .. roomIndex
	roomFolder.Parent = parent

	local size = config.Size
	local t = 4
	local cw = DungeonConfig.CorridorWidth + 4 -- opening slightly wider than corridor
	local ch = DungeonConfig.CorridorHeight

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

	-- Lighting (dimmer for dungeon atmosphere)
	local light = Instance.new("PointLight"); light.Color=config.LightColor; light.Range=size.X*0.5; light.Brightness=0.6; light.Parent=ceil

	-- Torches in corners (main light source, flickering)
	for _, offset in ipairs({
		Vector3.new(-size.X/3, size.Y*0.6, -size.Z/3),
		Vector3.new(size.X/3, size.Y*0.6, -size.Z/3),
		Vector3.new(-size.X/3, size.Y*0.6, size.Z/3),
		Vector3.new(size.X/3, size.Y*0.6, size.Z/3),
	}) do
		local torch = makePart({Name="Torch", Size=Vector3.new(1,2,1), Position=origin+offset, Material=Enum.Material.Wood, BrickColor=BrickColor.new("Brown"), Parent=roomFolder})
		local tl = Instance.new("PointLight"); tl.Color=Color3.fromRGB(255,150,50); tl.Range=18; tl.Brightness=0.7; tl.Parent=torch
		local fi = Instance.new("Fire"); fi.Size=2; fi.Heat=4; fi.Parent=torch
	end

	return roomFolder
end

--------------------------------------------------------------------------------
-- CORRIDOR BUILDER (grid-based, straight only)
--------------------------------------------------------------------------------
local CORRIDOR_OVERLAP = 10

-- Build a straight corridor segment along Z axis
-- Uses openingW (cw+4) to match room wall openings exactly
local function buildCorridorZ(parent, x, fromZ, toZ, originY, mat, col, floorCol)
	local cw = DungeonConfig.CorridorWidth
	local ow = cw + 4 -- match room opening width exactly
	local ch = DungeonConfig.CorridorHeight
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
	local cw = DungeonConfig.CorridorWidth
	local ow = cw + 4 -- match room opening width exactly
	local ch = DungeonConfig.CorridorHeight
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
function DungeonService.BuildGridCorridor(parent, roomAOrigin, roomASize, roomBOrigin, roomBSize, dir, originY, keyType)
	local mat = Enum.Material.Brick
	local col = BrickColor.new("Really black")
	local floorCol = BrickColor.new("Dark stone grey")
	local cw = DungeonConfig.CorridorWidth
	local ow = cw + 4 -- match room opening width
	local ch = DungeonConfig.CorridorHeight
	local t = 4

	if dir == "Right" then
		-- Corridor along X axis between horizontally adjacent rooms
		local fromX = roomAOrigin.X + roomASize.X / 2 - CORRIDOR_OVERLAP
		local toX = roomBOrigin.X - roomBSize.X / 2 + CORRIDOR_OVERLAP
		local z = roomAOrigin.Z -- same Z since they are on the same row
		buildCorridorX(parent, z, fromX, toX, originY, mat, col, floorCol)

		-- Door in the middle if keyType is specified
		if keyType then
			local centerX = (fromX + toX) / 2
			local doorPos = Vector3.new(centerX, originY + ch / 2, z)
			return DungeonService._BuildCorridorDoor(parent, doorPos, Vector3.new(4, ch, ow), keyType)
		end

	elseif dir == "Down" then
		-- Corridor along Z axis between vertically adjacent rooms
		local fromZ = roomAOrigin.Z - roomASize.Z / 2 + CORRIDOR_OVERLAP
		local toZ = roomBOrigin.Z + roomBSize.Z / 2 - CORRIDOR_OVERLAP
		local x = roomAOrigin.X -- same X since they are on the same column
		buildCorridorZ(parent, x, fromZ, toZ, originY, mat, col, floorCol)

		-- Door in the middle if keyType is specified
		if keyType then
			local centerZ = (fromZ + toZ) / 2
			local doorPos = Vector3.new(x, originY + ch / 2, centerZ)
			return DungeonService._BuildCorridorDoor(parent, doorPos, Vector3.new(ow, ch, 4), keyType)
		end
	end

	return nil
end

--------------------------------------------------------------------------------
-- INTERNAL: Build a corridor door at the given position with size and key type
--------------------------------------------------------------------------------
function DungeonService._BuildCorridorDoor(parent, doorPos, doorSize, keyType)
	local mat = Enum.Material.Brick
	local col = BrickColor.new("Really black")
	local cw = DungeonConfig.CorridorWidth
	local ch = DungeonConfig.CorridorHeight

	local keyData = DungeonConfig.KeyTypes[keyType]
	local doorColor = keyData and keyData.BrickColor or BrickColor.new("Medium stone grey")
	local doorGlowColor = keyData and keyData.Color or Color3.fromRGB(200, 200, 200)

	local door = makePart({
		Name = "CorridorDoor_" .. keyType,
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
		BrickColor = doorColor,
		CanCollide = false,
		Parent = door,
	})

	-- Glow
	local glow = Instance.new("PointLight")
	glow.Color = doorGlowColor
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
	lbl.Text = (keyData and keyData.Name or keyType) .. " Door"
	lbl.TextColor3 = doorGlowColor
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
function DungeonService.OpenSlidingDoor(door)
	if not door or not door.Parent then return end

	local ch = DungeonConfig.CorridorHeight
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
function DungeonService.StartDungeon(player)
	DungeonService.CleanupDungeon(player)

	local dungeonFolder = Instance.new("Folder")
	dungeonFolder.Name = "Dungeon"
	dungeonFolder.Parent = workspace

	local dungeonData = {
		Folder = dungeonFolder,
		CurrentRoom = 1,
		RoomStates = {},
		RoomEnemyCounts = {},
		RoomFolders = {},
		CorridorDoors = {}, -- [corridorIndex] = { Door = Part, KeyType = string }
		PlayerKeys = {}, -- { Iron = true, Gold = true, ... }
		ShadowKeysCollected = 0,
		Player = player,
		Deaths = 0,
		StartTime = os.clock(),
		TotalDamage = 0,
		RoomsCleared = 0,
	}

	local originY = DungeonConfig.StartOffset.Y
	local rooms = DungeonConfig.Rooms

	-- Compute world positions from grid coordinates
	local roomWorldOrigins = {}
	for _, roomConfig in ipairs(rooms) do
		local grid = roomConfig.Grid
		roomWorldOrigins[roomConfig.RoomId] = gridToWorld(grid[1], grid[2])
	end

	-- Auto-compute openings per room from corridor definitions
	local roomOpenings = computeRoomOpenings()

	-- Build entrance room connected to Room 1's Front (+Z wall)
	local entranceRoomId = DungeonConfig.EntranceRoom or 1
	local room1Origin = roomWorldOrigins[entranceRoomId]
	local room1Config = getRoomById(entranceRoomId)
	local room1Size = room1Config.Size
	local entranceOrigin = room1Origin + Vector3.new(0, 0, room1Size.Z / 2 + 30 + 25) -- 30 gap + 25 half entrance
	local entranceFolder = DungeonService.BuildEntranceRoom(dungeonFolder, entranceOrigin)
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
			roomFolder = DungeonService.BuildTrapRoom(dungeonFolder, roomConfig, worldOrigin, i, dungeonData, player, openings)
		else
			roomFolder = DungeonService.BuildRoom(dungeonFolder, roomConfig, worldOrigin, i, openings)
		end
		dungeonData.RoomFolders[i] = roomFolder
		dungeonData.RoomStates[i] = "Locked"
		dungeonData.RoomEnemyCounts[i] = 0
	end

	-- Build all corridors using BuildGridCorridor
	for ci, corr in ipairs(DungeonConfig.Corridors) do
		local fromConfig = getRoomById(corr.FromRoom)
		local toConfig = getRoomById(corr.ToRoom)
		if fromConfig and toConfig then
			local fromOrigin = roomWorldOrigins[corr.FromRoom]
			local toOrigin = roomWorldOrigins[corr.ToRoom]
			local door = DungeonService.BuildGridCorridor(
				dungeonFolder,
				fromOrigin, fromConfig.Size,
				toOrigin, toConfig.Size,
				corr.Dir, originY, corr.DoorKey
			)
			dungeonData.CorridorDoors[ci] = {
				Door = door,
				KeyType = corr.DoorKey,
				RequiresBothShadow = corr.RequiresBothShadow or false,
				FromRoom = corr.FromRoom,
				ToRoom = corr.ToRoom,
			}
		end
	end

	-- Add ProximityPrompts to locked doors (player presses E to open with key)
	for ci, corrData in pairs(dungeonData.CorridorDoors) do
		if corrData.Door and corrData.KeyType then
			local keyData = DungeonConfig.KeyTypes[corrData.KeyType]
			if keyData then
				local prompt = Instance.new("ProximityPrompt")
				prompt.ActionText = "Use " .. keyData.Name
				prompt.ObjectText = keyData.Name .. " Door"
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

					local kt = cd.KeyType
					-- Check if player has the required key
					if cd.RequiresBothShadow then
						if (dungeonData.ShadowKeysCollected or 0) < 2 then
							local r = Remotes:GetEvent("DungeonStateChanged")
							if r then r:FireClient(player, "DoorLocked", 0, "You need 2 Shadow Keys!") end
							return
						end
					else
						if not dungeonData.PlayerKeys[kt] then
							local r = Remotes:GetEvent("DungeonStateChanged")
							if r then r:FireClient(player, "DoorLocked", 0, "You need the " .. keyData.Name .. "!") end
							return
						end
					end

					-- Open the door
					DungeonService.OpenSlidingDoor(cd.Door)
					cd.Door = nil

					-- Activate destination room
					local toRoomIndex = getRoomIndex(cd.ToRoom)
					if toRoomIndex and dungeonData.RoomStates[toRoomIndex] ~= "Active" and dungeonData.RoomStates[toRoomIndex] ~= "Cleared" then
						dungeonData.RoomStates[toRoomIndex] = "Active"
						DungeonService.SpawnRoomEnemies(dungeonData, toRoomIndex)
						local r = Remotes:GetEvent("DungeonStateChanged")
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
	DungeonService.SpawnRoomEnemies(dungeonData, 1)

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
				local classId = pedestalPart.Name:gsub("Pedestal_", "")
				dungeonData.SelectedClass = classId
				PlayerDataService.ApplyClassModifiers(player, classId)

				local classRemote = Remotes:GetEvent("ClassSelected")
				if classRemote then classRemote:FireClient(player, classId) end

				local toDestroy = {}
				for _, child in ipairs(entranceFolder:GetChildren()) do
					if child.Name:find("Pedestal_") then table.insert(toDestroy, child) end
				end
				for _, obj in ipairs(toDestroy) do obj:Destroy() end
			end)
		end
	end

	-- Notify client
	local remote = Remotes:GetEvent("DungeonStateChanged")
	if remote then
		remote:FireClient(player, "DungeonStarted", 0, "Dungeon Entrance")
	end

	-- Death handler
	local function connectDeathHandler(char)
		local humanoid = char:WaitForChild("Humanoid", 5)
		if humanoid then
			humanoid.Died:Connect(function()
				if activeDungeons[player] then
					DungeonService.OnPlayerDied(player)
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
-- SPAWN ENEMIES
--------------------------------------------------------------------------------
function DungeonService.SpawnRoomEnemies(dungeonData, roomIndex)
	local roomConfig = DungeonConfig.Rooms[roomIndex]
	if not roomConfig then return end
	if roomConfig.RoomType == "Trap" then
		dungeonData.RoomEnemyCounts[roomIndex] = 0
		return
	end

	local roomFolder = dungeonData.RoomFolders[roomIndex]
	if not roomFolder then return end

	local roomOrigin = DungeonConfig.StartOffset
	local floorPart = roomFolder:FindFirstChild("Floor")
	if floorPart then
		roomOrigin = floorPart.Position + Vector3.new(0, floorPart.Size.Y/2, 0)
	end
	local roomSize = roomConfig.Size

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
			local model = DungeonService.SpawnSingleEnemy(enemyEntry.Id, roomOrigin + spawnOffset, roomFolder)
			if model and enemyEntry.DropsKey then
				model:SetAttribute("DropsKey", enemyEntry.DropsKey)
			end
		end
	end

	dungeonData.RoomEnemyCounts[roomIndex] = enemyIndex
end

function DungeonService.SpawnSingleEnemy(enemyId, spawnPos, parentFolder)
	local config = EnemyConfig.Enemies[enemyId]
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

	local humanoid = Instance.new("Humanoid")
	humanoid.MaxHealth = config.Health; humanoid.Health = config.Health
	humanoid.WalkSpeed = config.Speed; humanoid.Parent = model

	model.PrimaryPart = rootPart

	model:SetAttribute("IsEnemy", true); model:SetAttribute("IsDead", false)
	model:SetAttribute("EnemyId", enemyId); model:SetAttribute("CurrentHP", config.Health)
	model:SetAttribute("MaxHP", config.Health); model:SetAttribute("Defense", config.Defense)
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

	if EnemyAI then EnemyAI.RegisterEnemy(model, enemyId) end
	return model
end

--------------------------------------------------------------------------------
-- ENEMY DIED -> KEY SPAWN
--------------------------------------------------------------------------------
function DungeonService.OnEnemyDied(enemyModel)
	local enemyId = enemyModel:GetAttribute("EnemyId")
	local isBoss = enemyModel:GetAttribute("IsBoss")
	local dropsKey = enemyModel:GetAttribute("DropsKey")

	for player, data in pairs(activeDungeons) do
		for roomIndex, roomFolder in pairs(data.RoomFolders) do
			if enemyModel:IsDescendantOf(roomFolder) then
				if LootService then LootService.GrantLoot(player, enemyId, isBoss) end

				-- Miniboss drops its key on death
				if dropsKey then
					DungeonService.SpawnMinibossKey(player, data, roomIndex, enemyModel, dropsKey)
				end

				data.RoomEnemyCounts[roomIndex] = (data.RoomEnemyCounts[roomIndex] or 1) - 1

				if data.RoomEnemyCounts[roomIndex] <= 0 then
					DungeonService.RoomCleared(player, data, roomIndex)
				end
				return
			end
		end
	end
end

--------------------------------------------------------------------------------
-- SPAWN KEY FROM MINIBOSS DEATH
--------------------------------------------------------------------------------
function DungeonService.SpawnMinibossKey(player, data, roomIndex, enemyModel, keyTypeId)
	local keyData = DungeonConfig.KeyTypes[keyTypeId]
	if not keyData then return end

	local dropPos = Vector3.new(0, 5, 0)
	local rootPart = enemyModel:FindFirstChild("HumanoidRootPart")
	if rootPart then dropPos = rootPart.Position end

	local keyPos = dropPos + Vector3.new(0, 2, 0)

	local key = Instance.new("Part")
	key.Name = "Key_" .. keyTypeId
	key.Size = Vector3.new(2.5, 2.5, 2.5)
	key.Position = keyPos
	key.Anchored = true
	key.CanCollide = false
	key.Shape = Enum.PartType.Ball
	key.Material = Enum.Material.Neon
	key.BrickColor = keyData.BrickColor
	key.Parent = data.RoomFolders[roomIndex]

	-- Glow
	local light = Instance.new("PointLight")
	light.Color = keyData.Color; light.Range = 20; light.Brightness = 3; light.Parent = key

	-- Sparkles
	local sparkle = Instance.new("Sparkles")
	sparkle.SparkleColor = keyData.Color; sparkle.Parent = key

	-- Label
	local bb = Instance.new("BillboardGui")
	bb.Size = UDim2.new(0, 140, 0, 45)
	bb.StudsOffset = Vector3.new(0, 3, 0); bb.AlwaysOnTop = true; bb.Parent = key
	local lbl = Instance.new("TextLabel")
	lbl.Size = UDim2.new(1,0,1,0); lbl.BackgroundTransparency = 1
	lbl.Text = keyData.Name
	lbl.TextColor3 = keyData.Color
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
		data.PlayerKeys[keyTypeId] = true

		-- Track shadow keys
		if keyTypeId == "Shadow" then
			data.ShadowKeysCollected = (data.ShadowKeysCollected or 0) + 1
		end

		-- Notify client (key goes to inventory, does NOT auto-open doors)
		local remote = Remotes:GetEvent("DungeonStateChanged")
		if remote then
			remote:FireClient(player, "KeyPickedUp", roomIndex, keyData.Name, {keyData.Color.R, keyData.Color.G, keyData.Color.B})
		end

		key:Destroy()
	end)

	-- Notify client that key dropped
	local remote = Remotes:GetEvent("DungeonStateChanged")
	if remote then
		remote:FireClient(player, "KeySpawned", roomIndex, keyData.Name, {keyData.Color.R, keyData.Color.G, keyData.Color.B})
	end
end

--------------------------------------------------------------------------------
-- ROOM CLEARED
--------------------------------------------------------------------------------
function DungeonService.RoomCleared(player, data, roomIndex)
	data.RoomStates[roomIndex] = "Cleared"
	data.RoomsCleared = (data.RoomsCleared or 0) + 1

	local remote = Remotes:GetEvent("DungeonStateChanged")
	local roomConfig = DungeonConfig.Rooms[roomIndex]

	-- Boss room -> dungeon complete
	if roomConfig and roomConfig.IsBossRoom then
		local elapsed = os.clock() - (data.StartTime or os.clock())
		local timeScore = math.max(0, ScoreConfig.TimeBonus - math.floor(elapsed))
		local damageScore = math.floor((data.TotalDamage or 0) / ScoreConfig.DamagePerPoint)
		local roomScore = (data.RoomsCleared or 0) * ScoreConfig.RoomClearBonus
		local deathScore = (data.Deaths or 0) * ScoreConfig.DeathPenalty
		local totalScore = math.max(0, timeScore + damageScore + roomScore + deathScore)

		local grade = "D"
		local gradeColor = {1, 0.2, 0.2}
		for _, g in ipairs(ScoreConfig.Grades) do
			if totalScore >= g.MinScore then
				grade = g.Grade; gradeColor = {g.Color.R, g.Color.G, g.Color.B}; break
			end
		end

		local scoreRemote = Remotes:GetEvent("DungeonScore")
		if scoreRemote then
			scoreRemote:FireClient(player, {
				Grade = grade, GradeColor = gradeColor, Score = totalScore,
				Time = math.floor(elapsed), Deaths = data.Deaths or 0,
				DamageDealt = data.TotalDamage or 0, RoomsCleared = data.RoomsCleared or 0,
			})
		end

		if remote then remote:FireClient(player, "DungeonComplete", roomIndex, "Dungeon Complete!") end

		task.wait(8)
		DungeonService.TeleportToLobby(player)
		DungeonService.CleanupDungeon(player)
		PlayerDataService.ResetStats(player)
		return
	end

	-- Notify room cleared
	if remote then
		remote:FireClient(player, "RoomCleared", roomIndex, roomConfig and roomConfig.Name or "Room")
	end

	-- Spawn treasure chest
	local clearedRoomFolder = data.RoomFolders[roomIndex]
	local chestOrigin = DungeonConfig.StartOffset
	if clearedRoomFolder then
		local floorPart = clearedRoomFolder:FindFirstChild("Floor")
		if floorPart then chestOrigin = floorPart.Position + Vector3.new(0, floorPart.Size.Y/2, 0) end
	end
	DungeonService.SpawnChest(data, chestOrigin, roomIndex, player)

	-- Activate adjacent rooms connected without doors
	if roomConfig then
		local roomId = roomConfig.RoomId
		for _, corr in ipairs(DungeonConfig.Corridors) do
			if not corr.DoorKey then
				local neighborId = nil
				if corr.FromRoom == roomId then neighborId = corr.ToRoom end
				if corr.ToRoom == roomId then neighborId = corr.FromRoom end
				if neighborId then
					local neighborIndex = getRoomIndex(neighborId)
					if neighborIndex and data.RoomStates[neighborIndex] == "Locked" then
						data.RoomStates[neighborIndex] = "Active"
						DungeonService.SpawnRoomEnemies(data, neighborIndex)
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
function DungeonService.TeleportToLobby(player)
	local character = player.Character
	if character then
		local rootPart = character:FindFirstChild("HumanoidRootPart")
		if rootPart then rootPart.CFrame = CFrame.new(DungeonConfig.LobbySpawn + Vector3.new(0, 3, 0)) end
	end
end

local pendingRespawns = {}

function DungeonService.EnterGhostMode(player)
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
		for i = #DungeonConfig.Rooms, 1, -1 do
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

function DungeonService.ExitGhostMode(player, originalTransparencies)
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
		local pds = require(script.Parent:WaitForChild("PlayerDataService"))
		local stats = pds.GetStats(player)
		local maxHP = stats and stats.MaxHP or 100
		humanoid.MaxHealth = maxHP; humanoid.Health = maxHP * 0.5
	end

	if data and rootPart then
		for i = #DungeonConfig.Rooms, 1, -1 do
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

function DungeonService.OnPlayerDied(player)
	local data = activeDungeons[player]
	if not data then return end
	if data.IsGhost then return end

	data.Deaths = (data.Deaths or 0) + 1
	data.DeathTime = os.clock()
	data.IsGhost = true

	local originalTransparencies = DungeonService.EnterGhostMode(player)

	local diedRemote = Remotes:GetEvent("PlayerDied")
	if diedRemote then diedRemote:FireClient(player, data.Deaths, 5) end

	pendingRespawns[player] = true
	for i = 1, 50 do
		if not pendingRespawns[player] then break end
		task.wait(0.1)
	end
	pendingRespawns[player] = nil

	DungeonService.ExitGhostMode(player, originalTransparencies)
	data.IsGhost = false; data.DeathTime = nil

	local revivedRemote = Remotes:GetEvent("PlayerRevived")
	if revivedRemote then revivedRemote:FireClient(player) end
end

function DungeonService.RequestEarlyRespawn(player)
	local data = activeDungeons[player]
	if not data then return end
	if not data.DeathTime then return end
	if os.clock() - data.DeathTime < 3 then return end
	pendingRespawns[player] = nil
end

--------------------------------------------------------------------------------
-- CLEANUP
--------------------------------------------------------------------------------
function DungeonService.CleanupDungeon(player)
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
				EnemyAI.UnregisterEnemy(desc)
			end
		end
		data.Folder:Destroy()
	end

	activeDungeons[player] = nil
end

function DungeonService.CleanupPlayer(player) DungeonService.CleanupDungeon(player) end
function DungeonService.GetActiveDungeon(player) return activeDungeons[player] end
function DungeonService.AddDamageTracking(player, damage)
	local data = activeDungeons[player]
	if data then data.TotalDamage = (data.TotalDamage or 0) + damage end
end

--------------------------------------------------------------------------------
-- CHEST
--------------------------------------------------------------------------------
function DungeonService.SpawnChest(dungeonData, position, roomIndex, player)
	local roomFolder = dungeonData.RoomFolders[roomIndex]
	if not roomFolder then return end

	local tierName = "Common"
	if roomIndex >= 4 then tierName = "Legendary"
	elseif roomIndex >= 2 then tierName = "Rare" end

	local chest = Instance.new("Part")
	chest.Name = "TreasureChest"; chest.Size = Vector3.new(3, 2.5, 2.5)
	chest.Position = position + Vector3.new(0, 1.5, 0)
	chest.Anchored = true; chest.BrickColor = BrickColor.new("Brown"); chest.Material = Enum.Material.Wood
	chest.Parent = roomFolder

	local light = Instance.new("PointLight"); light.Color = Color3.fromRGB(255,215,0); light.Range = 15; light.Brightness = 2; light.Parent = chest
	local sparkles = Instance.new("ParticleEmitter")
	sparkles.Color = ColorSequence.new(Color3.fromRGB(255,215,0)); sparkles.Size = NumberSequence.new(0.3,0)
	sparkles.Lifetime = NumberRange.new(0.5,1); sparkles.Rate = 20; sparkles.Speed = NumberRange.new(2,4); sparkles.Parent = chest

	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Open Chest"; prompt.ObjectText = tierName .. " Chest"
	prompt.HoldDuration = 0.5; prompt.MaxActivationDistance = 10; prompt.Parent = chest

	prompt.Triggered:Connect(function(trigPlayer)
		if trigPlayer ~= player then return end
		LootService.GrantChestLoot(player, roomIndex)
		local remote = Remotes:GetEvent("ChestOpened")
		if remote then remote:FireClient(player, tierName) end
		chest:Destroy()
	end)
end

--------------------------------------------------------------------------------
-- TRAP ROOM
--------------------------------------------------------------------------------
function DungeonService.BuildTrapRoom(parent, config, origin, roomIndex, dungeonData, player, openings)
	local roomFolder = DungeonService.BuildRoom(parent, config, origin, roomIndex, openings)

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
				DungeonService.RoomCleared(touchPlayer, data, roomIndex)
				trigger:Destroy()
			end
		end
	end)

	return roomFolder
end

return DungeonService
