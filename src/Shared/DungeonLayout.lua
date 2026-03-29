--------------------------------------------------------------------------------
-- DungeonLayout
--
-- Generates a random NxN dungeon grid from templates in DungeonRoomRegistry.
--
-- PLACEMENT RULES
--   • Start room  → always top-left    cell (row 1, col 1)
--   • Boss room   → always bottom-right cell (row N, col N)
--   • Miniboss rooms → scattered across the inner mid-grid
--                      (rows 2..N-1, cols 2..N-1), evenly distributed
--   • Normal / puzzle / trap rooms → fill every remaining cell randomly
--
-- GRID CONVENTIONS (match existing DungeonConfig / DungeonService)
--   • Rows index from top (1) to bottom (N)
--   • Cols index from left (1) to right (N)
--   • "Right" corridor → same row, col+1
--   • "Down"  corridor → row+1, same col
--   • All adjacent pairs of filled cells receive a corridor (full grid graph)
--
-- RETURN VALUE of GenerateGrid(n, options)
--   {
--     N          = n,
--     Grid       = { [row][col] = Cell },
--     Corridors  = { CorridorEntry, ... },
--     StartPos   = { Row=1, Col=1 },
--     BossPos    = { Row=n, Col=n },
--     MinibossPositions = { {Row, Col}, ... },
--   }
--
-- Cell:
--   { Row, Col, RoomId, RoomType, Template }
--   RoomId is a sequential integer assigned in row-major order (1..N²).
--
-- CorridorEntry:
--   { FromRow, FromCol, ToRow, ToCol, Dir = "Right"|"Down" }
--
-- Usage:
--   local Registry = require(ReplicatedStorage.DungeonRoomRegistry)
--   local Layout   = require(ReplicatedStorage.DungeonLayout)
--   local result   = Layout.GenerateGrid(5, { Seed = 42 })
--
--   for row = 1, result.N do
--     for col = 1, result.N do
--       local cell = result.Grid[row][col]
--       print(row, col, cell.RoomType, cell.Template.Name)
--     end
--   end
--------------------------------------------------------------------------------

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local DungeonRoomRegistry = require(ReplicatedStorage:WaitForChild("DungeonRoomRegistry"))

local DungeonLayout = {}

--------------------------------------------------------------------------------
-- CONFIG
--------------------------------------------------------------------------------

-- Miniboss count per grid size.
-- For grids not listed, falls back to math.max(1, n - 2).
local MINIBOSS_COUNTS = {
	[3] = 1,
	[4] = 2,
	[5] = 3,
	[6] = 4,
	[7] = 5,
	[8] = 6,
}

-- Fill types for non-special cells, with weighted probability.
-- Each entry is { type, weight }.  Higher weight = more likely.
local FILL_TYPES = {
	{ type = "normal", weight = 5 },
	{ type = "trap",   weight = 2 },
	{ type = "puzzle", weight = 2 },
}

-- Pre-compute cumulative weights for O(1) weighted random pick.
local FILL_TOTAL_WEIGHT = 0
local FILL_CUMULATIVE = {}
for _, entry in ipairs(FILL_TYPES) do
	FILL_TOTAL_WEIGHT = FILL_TOTAL_WEIGHT + entry.weight
	table.insert(FILL_CUMULATIVE, { type = entry.type, cum = FILL_TOTAL_WEIGHT })
end

--------------------------------------------------------------------------------
-- INTERNAL HELPERS
--------------------------------------------------------------------------------

-- Weighted random pick from FILL_TYPES.
local function randomFillType()
	local roll = math.random() * FILL_TOTAL_WEIGHT
	for _, entry in ipairs(FILL_CUMULATIVE) do
		if roll <= entry.cum then
			return entry.type
		end
	end
	return FILL_TYPES[#FILL_TYPES].type
end

-- Fisher-Yates in-place shuffle of an array table.
local function shuffle(t)
	for i = #t, 2, -1 do
		local j = math.random(i)
		t[i], t[j] = t[j], t[i]
	end
end

-- Pick a template, falling back gracefully if the desired type has no entries.
local function pickTemplate(roomType, fallbackOrder)
	local t = DungeonRoomRegistry.GetRandom(roomType)
	if t then return t end
	-- Try fallbacks in order
	if fallbackOrder then
		for _, fb in ipairs(fallbackOrder) do
			t = DungeonRoomRegistry.GetRandom(fb)
			if t then
				warn(string.format(
					"[DungeonLayout] No templates for type '%s', falling back to '%s'",
					roomType, fb
				))
				return t
			end
		end
	end
	error(string.format("[DungeonLayout] No templates available for type '%s' (and no fallback succeeded)", roomType))
end

-- Build an evenly-distributed set of miniboss positions inside the mid-grid.
--
-- Strategy: divide the inner region into a (k × k) sub-grid and pick one
-- random cell per sub-grid quadrant, where k = ceil(sqrt(minibossCount)).
-- This prevents all minibosses clustering in one corner while still keeping
-- placement random.
local function computeMinibossPositions(n, count)
	-- Inner region: rows 2..n-1, cols 2..n-1
	local innerMin = 2
	local innerMax = n - 1
	local innerSize = innerMax - innerMin + 1 -- number of cells on each axis

	if innerSize <= 0 then
		-- Grid is too small for any inner region (n <= 2).
		return {}
	end

	-- If we want more minibosses than inner cells, cap.
	local innerCells = innerSize * innerSize
	count = math.min(count, innerCells)

	-- Build a list of all inner positions and shuffle them.
	local candidates = {}
	for row = innerMin, innerMax do
		for col = innerMin, innerMax do
			table.insert(candidates, { Row = row, Col = col })
		end
	end
	shuffle(candidates)

	-- Divide candidates into `count` roughly equal bands and pick one from each.
	-- This ensures geographic spread even with randomness.
	local positions = {}
	local bandSize = math.ceil(#candidates / count)
	for i = 1, count do
		local bandStart = (i - 1) * bandSize + 1
		local bandEnd   = math.min(i * bandSize, #candidates)
		-- Pick randomly within this band.
		local pick = candidates[math.random(bandStart, bandEnd)]
		table.insert(positions, pick)
	end

	return positions
end

--------------------------------------------------------------------------------
-- PUBLIC API
--------------------------------------------------------------------------------

--[[
	GenerateGrid(n, options) → LayoutResult

	n       : integer ≥ 3.  Grid will be n × n.  Default 5.
	options : optional table
	  Seed         : number   – seeds math.random for deterministic output.
	  MinibossCount: number   – override the default miniboss count for this n.

	Clamps n to [3, 10] to keep generation sane.
--]]
function DungeonLayout.GenerateGrid(n, options)
	n = math.clamp(math.floor(n or 5), 3, 10)
	options = options or {}

	-- Optional deterministic seed.
	if options.Seed then
		math.randomseed(options.Seed)
	end

	local minibossCount = options.MinibossCount
		or MINIBOSS_COUNTS[n]
		or math.max(1, n - 2)

	------------------------------------------------------------
	-- 1. Allocate an empty N×N grid.
	------------------------------------------------------------
	local grid = {}
	for row = 1, n do
		grid[row] = {}
	end

	------------------------------------------------------------
	-- 2. Decide which cells are miniboss cells.
	--    We do this before filling so normal cells can avoid them.
	------------------------------------------------------------
	local minibossPositions = computeMinibossPositions(n, minibossCount)
	local isMinibossCell = {}
	for _, pos in ipairs(minibossPositions) do
		isMinibossCell[pos.Row .. "," .. pos.Col] = true
	end

	------------------------------------------------------------
	-- 3. Pick miniboss templates (one per position, no repeats if possible).
	--    We shuffle the available miniboss templates and assign in order.
	------------------------------------------------------------
	local minibossPool = DungeonRoomRegistry.GetByType("miniboss")
	shuffle(minibossPool)
	-- If fewer templates than positions, wrap around.
	local function getMinibossTemplate(index)
		if #minibossPool == 0 then
			return pickTemplate("miniboss", { "normal" })
		end
		return minibossPool[((index - 1) % #minibossPool) + 1]
	end

	------------------------------------------------------------
	-- 4. Place all cells.
	------------------------------------------------------------
	local roomIdCounter = 0
	local function nextRoomId()
		roomIdCounter = roomIdCounter + 1
		return roomIdCounter
	end

	for row = 1, n do
		for col = 1, n do
			local roomType
			local template

			-- Top-left → start
			if row == 1 and col == 1 then
				roomType = "start"
				template = pickTemplate("start", { "normal" })

			-- Bottom-right → boss
			elseif row == n and col == n then
				roomType = "boss"
				template = pickTemplate("boss", { "normal" })

			-- Mid-grid miniboss positions
			elseif isMinibossCell[row .. "," .. col] then
				roomType = "miniboss"
				-- Count how many miniboss cells we've placed so far.
				local idx = 0
				for _, pos in ipairs(minibossPositions) do
					if pos.Row < row or (pos.Row == row and pos.Col <= col) then
						idx = idx + 1
					end
				end
				template = getMinibossTemplate(idx)

			-- Everything else → normal / trap / puzzle
			else
				roomType = randomFillType()
				template = pickTemplate(roomType, { "normal" })
			end

			grid[row][col] = {
				Row      = row,
				Col      = col,
				RoomId   = nextRoomId(),
				RoomType = roomType,
				Template = template,
			}
		end
	end

	------------------------------------------------------------
	-- 5. Generate corridors between every pair of adjacent cells.
	--    "Right" = (row, col) → (row, col+1)
	--    "Down"  = (row, col) → (row+1, col)
	------------------------------------------------------------
	local corridors = {}
	for row = 1, n do
		for col = 1, n do
			-- Right neighbour
			if col < n then
				table.insert(corridors, {
					FromRow = row, FromCol = col,
					ToRow   = row, ToCol   = col + 1,
					Dir     = "Right",
				})
			end
			-- Down neighbour
			if row < n then
				table.insert(corridors, {
					FromRow = row,     FromCol = col,
					ToRow   = row + 1, ToCol   = col,
					Dir     = "Down",
				})
			end
		end
	end

	------------------------------------------------------------
	-- 6. Package and return.
	------------------------------------------------------------
	return {
		N                 = n,
		Grid              = grid,
		Corridors         = corridors,
		StartPos          = { Row = 1, Col = 1 },
		BossPos           = { Row = n, Col = n },
		MinibossPositions = minibossPositions,
	}
end

--------------------------------------------------------------------------------
-- UTILITY: pretty-print a generated layout (useful in the output window).
--------------------------------------------------------------------------------
local TYPE_GLYPHS = {
	start    = "[S]",
	normal   = "[ ]",
	puzzle   = "[?]",
	trap     = "[T]",
	miniboss = "[M]",
	boss     = "[B]",
}

function DungeonLayout.PrintGrid(result)
	print(string.format("=== DungeonLayout  %dx%d ===", result.N, result.N))
	for row = 1, result.N do
		local line = {}
		for col = 1, result.N do
			local cell = result.Grid[row][col]
			table.insert(line, TYPE_GLYPHS[cell.RoomType] or "[?]")
		end
		print(table.concat(line, " "))
	end
	print(string.format(
		"Rooms: %d  |  Corridors: %d  |  Minibosses: %d",
		result.N * result.N, #result.Corridors, #result.MinibossPositions
	))
end

--------------------------------------------------------------------------------
-- UTILITY: convert a generated grid into a DungeonConfig-compatible Rooms
-- and Corridors table so the existing DungeonService can build it directly.
--
-- NOTE: visual properties (FloorMaterial, WallMaterial, etc.) are not set
-- here — they should be read from the room template's workspace model instead.
-- Stub values are inserted so the existing BuildRoom() won't error.
--------------------------------------------------------------------------------
function DungeonLayout.ToDungeonConfig(result)
	local rooms     = {}
	local corridors = {}

	-- Map (row, col) → RoomId for corridor lookup.
	local roomIdAt = {}
	for row = 1, result.N do
		roomIdAt[row] = {}
		for col = 1, result.N do
			roomIdAt[row][col] = result.Grid[row][col].RoomId
		end
	end

	-- Build rooms list.
	for row = 1, result.N do
		for col = 1, result.N do
			local cell = result.Grid[row][col]
			local t    = cell.Template
			table.insert(rooms, {
				RoomId        = cell.RoomId,
				Grid          = { col - 1, row - 1 }, -- DungeonConfig uses 0-based {col, row}
				Name          = t.Name,
				RoomType      = cell.RoomType == "trap" and "Trap" or "Combat",
				Size          = Vector3.new(120, 22, 120),
				Enemies       = {},                    -- populated by template model attributes
				FloorMaterial = Enum.Material.Cobblestone,
				WallMaterial  = Enum.Material.Brick,
				FloorColor    = BrickColor.new("Dark stone grey"),
				WallColor     = BrickColor.new("Really black"),
				LightColor    = Color3.fromRGB(200, 180, 150),
				IsBossRoom    = (cell.RoomType == "boss"),
				-- Store a reference back to the registry template for advanced builders.
				LayoutTemplate = t,
			})
		end
	end

	-- Build corridors list.
	for _, corr in ipairs(result.Corridors) do
		table.insert(corridors, {
			FromRoom = roomIdAt[corr.FromRow][corr.FromCol],
			ToRoom   = roomIdAt[corr.ToRow][corr.ToCol],
			Dir      = corr.Dir,
		})
	end

	return {
		GridSpacing    = 180,
		CorridorWidth  = 16,
		CorridorHeight = 16,
		StartOffset    = Vector3.new(-((result.N - 1) * 180) / 2, 5, -200),
		Rooms          = rooms,
		Corridors      = corridors,
		EntranceRoom   = result.Grid[1][1].RoomId,
		LobbySpawn     = Vector3.new(0, 5, 0),
		KeyTypes       = {}, -- inherit from the global DungeonConfig if needed
	}
end

return DungeonLayout
