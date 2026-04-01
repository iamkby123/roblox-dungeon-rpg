local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local DescentRegistry = require(ReplicatedStorage:WaitForChild("DescentRegistry"))

local HollowRoomBuilder = {}

--------------------------------------------------------------------------------
-- CONFIG
--------------------------------------------------------------------------------
local TILE_SIZE = 200 -- studs between room centers
local DOOR_TAG = "HollowDoor" -- CollectionService tag on door parts

--------------------------------------------------------------------------------
-- INTERNAL: Resolve direction from a door's name or orientation
--
-- Convention: doors are named with a directional suffix so the builder
-- knows which wall they belong to.  Accepted names:
--   "Door_North" / "Door_South" / "Door_East" / "Door_West"
-- Alternatively, if the part has a StringValue child named "Direction"
-- the builder reads that.
--
-- Returns one of "North", "South", "East", "West", or nil.
--------------------------------------------------------------------------------
local DIRECTION_MAP = {
	North = "North",
	South = "South",
	East  = "East",
	West  = "West",
	-- Aliases matching HollowBuilder conventions
	Front = "North",
	Back  = "South",
	Right = "East",
	Left  = "West",
}

local function getDoorDirection(doorPart)
	-- 1. Check for a Direction StringValue child
	local dirValue = doorPart:FindFirstChild("Direction")
	if dirValue and dirValue:IsA("StringValue") then
		local mapped = DIRECTION_MAP[dirValue.Value]
		if mapped then return mapped end
	end

	-- 2. Parse from the part name (e.g. "Door_North", "HollowDoor_East")
	for suffix, dir in pairs(DIRECTION_MAP) do
		if doorPart.Name:find(suffix) then
			return dir
		end
	end

	return nil
end

-- Direction → grid offset to the neighboring cell
local DIR_OFFSETS = {
	North = { Row = -1, Col =  0 },
	South = { Row =  1, Col =  0 },
	East  = { Row =  0, Col =  1 },
	West  = { Row =  0, Col = -1 },
}

-- Opposite direction lookup
local OPPOSITE = {
	North = "South",
	South = "North",
	East  = "West",
	West  = "East",
}

--------------------------------------------------------------------------------
-- BuildFromLayout(layout, parentFolder)
--
-- layout      : the result table from HollowLayout.GenerateGrid()
-- parentFolder: an Instance (Folder/Model) under which all rooms are placed.
--               If nil a new Folder named "ActiveHollow" is created in workspace.
--
-- For each cell in layout.Grid:
--   1. Resolve the room template's workspace folder via DescentRegistry.
--   2. Clone it and position it at (col * TILE_SIZE, 0, row * TILE_SIZE)
--      relative to the parentFolder's origin.
--   3. Scan the clone for parts tagged "HollowDoor".
--   4. Open doors that face an occupied neighbor, seal doors on map edges.
--
-- Returns {
--   Folder    = parentFolder,
--   RoomMap   = { [row][col] = clonedModel },
--   DoorMap   = { [row][col] = { [direction] = doorPart } },
-- }
--------------------------------------------------------------------------------
function HollowRoomBuilder.BuildFromLayout(layout, parentFolder)
	if not parentFolder then
		parentFolder = Instance.new("Folder")
		parentFolder.Name = "ActiveHollow"
		parentFolder.Parent = workspace
	end

	local n = layout.N
	local grid = layout.Grid

	local roomMap = {} -- [row][col] = cloned Instance
	local doorMap = {} -- [row][col] = { North = part, South = part, ... }

	------------------------------------------------------------
	-- 1. Clone and position each room
	------------------------------------------------------------
	for row = 1, n do
		roomMap[row] = {}
		doorMap[row] = {}
		for col = 1, n do
			local cell = grid[row][col]
			local template = cell.Template

			-- Resolve the pre-built model from workspace.RoomTemplates
			local sourceFolder = DescentRegistry.ResolveFolder(template)
			local clone
			if sourceFolder then
				clone = sourceFolder:Clone()
			else
				-- Fallback: create a placeholder platform so the grid is still navigable
				warn(string.format(
					"[HollowRoomBuilder] No model for '%s' at (%d,%d) — placing placeholder",
					template.Name, row, col
				))
				clone = Instance.new("Model")
				clone.Name = template.Name .. "_Placeholder"
				local floor = Instance.new("Part")
				floor.Name = "Floor"
				floor.Size = Vector3.new(TILE_SIZE * 0.8, 4, TILE_SIZE * 0.8)
				floor.Anchored = true
				floor.Material = Enum.Material.Cobblestone
				floor.BrickColor = BrickColor.new("Medium stone grey")
				floor.Parent = clone
				clone.PrimaryPart = floor
			end

			clone.Name = string.format("Room_%d_%d_%s", row, col, cell.RoomType)

			-- Compute world position: center of this tile
			local worldX = (col - 1) * TILE_SIZE
			local worldZ = (row - 1) * TILE_SIZE

			-- Position the clone
			if clone:IsA("Model") and clone.PrimaryPart then
				local currentPos = clone.PrimaryPart.Position
				local offset = Vector3.new(worldX, 0, worldZ) - currentPos
				clone:TranslateBy(offset)
			elseif clone:IsA("Model") then
				-- No PrimaryPart: try to center by bounding box
				local cf, size = clone:GetBoundingBox()
				local offset = Vector3.new(worldX, 0, worldZ) - cf.Position
				clone:TranslateBy(offset)
			else
				-- Single Instance (unlikely)
				clone.Position = Vector3.new(worldX, 0, worldZ)
			end

			clone.Parent = parentFolder
			roomMap[row][col] = clone

			-- Collect doors tagged with CollectionService
			doorMap[row][col] = {}
			for _, desc in ipairs(clone:GetDescendants()) do
				if desc:IsA("BasePart") and CollectionService:HasTag(desc, DOOR_TAG) then
					local dir = getDoorDirection(desc)
					if dir then
						doorMap[row][col][dir] = desc
					else
						warn(string.format(
							"[HollowRoomBuilder] Door '%s' in room (%d,%d) has no recognizable direction — skipping",
							desc:GetFullName(), row, col
						))
					end
				end
			end
		end
	end

	------------------------------------------------------------
	-- 2. Open / seal doors based on adjacency
	------------------------------------------------------------
	for row = 1, n do
		for col = 1, n do
			local doors = doorMap[row][col]
			for dir, doorPart in pairs(doors) do
				local offset = DIR_OFFSETS[dir]
				local neighborRow = row + offset.Row
				local neighborCol = col + offset.Col

				-- Check if the neighbor cell is within bounds and occupied
				local neighborExists = neighborRow >= 1 and neighborRow <= n
					and neighborCol >= 1 and neighborCol <= n
					and grid[neighborRow] and grid[neighborRow][neighborCol]

				if neighborExists then
					-- Open the door: make it non-collidable, transparent, and disable prompts
					HollowRoomBuilder.OpenDoor(doorPart)
				else
					-- Edge of map: seal the door
					HollowRoomBuilder.SealDoor(doorPart)
				end
			end
		end
	end

	return {
		Folder  = parentFolder,
		RoomMap = roomMap,
		DoorMap = doorMap,
	}
end

--------------------------------------------------------------------------------
-- OpenDoor(doorPart)
--
-- Makes the door passable. The part becomes non-collidable and fully
-- transparent. Any ProximityPrompt on it is disabled.
--------------------------------------------------------------------------------
function HollowRoomBuilder.OpenDoor(doorPart)
	if not doorPart or not doorPart.Parent then return end

	doorPart.CanCollide = false
	doorPart.Transparency = 1

	-- Hide any child visual parts (door panels, bars, etc.)
	for _, child in ipairs(doorPart:GetDescendants()) do
		if child:IsA("BasePart") then
			child.CanCollide = false
			child.Transparency = 1
		elseif child:IsA("ProximityPrompt") then
			child.Enabled = false
		elseif child:IsA("Decal") or child:IsA("Texture") or child:IsA("SurfaceGui") then
			child:Destroy()
		end
	end

	doorPart:SetAttribute("DoorState", "Open")
end

--------------------------------------------------------------------------------
-- SealDoor(doorPart)
--
-- Ensures the door is solid and impassable — a visible wall on the map edge.
-- Switches material to a heavy stone look so it reads as a dead end.
--------------------------------------------------------------------------------
function HollowRoomBuilder.SealDoor(doorPart)
	if not doorPart or not doorPart.Parent then return end

	doorPart.CanCollide = true
	doorPart.Transparency = 0
	doorPart.Material = Enum.Material.Slate
	doorPart.BrickColor = BrickColor.new("Dark stone grey")

	-- Disable interaction
	for _, child in ipairs(doorPart:GetDescendants()) do
		if child:IsA("ProximityPrompt") then
			child.Enabled = false
		end
	end

	doorPart:SetAttribute("DoorState", "Sealed")
end

--------------------------------------------------------------------------------
-- GetTileSize() — expose so other systems can query the spacing
--------------------------------------------------------------------------------
function HollowRoomBuilder.GetTileSize()
	return TILE_SIZE
end

return HollowRoomBuilder
