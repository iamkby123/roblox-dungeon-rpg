--------------------------------------------------------------------------------
-- HollowLayout
--
-- Generates a random NxN descent grid from templates in DescentRegistry.
--
-- PLACEMENT RULES
--   • Start chamber → always top-left    cell (row 1, col 1)
--   • Sanctum       → always bottom-right cell (row N, col N)
--   • Warden chambers → scattered across the inner mid-grid
--   • Hall / shrine / vault chambers → fill every remaining cell randomly
--
-- GRID CONVENTIONS (match existing HollowConfig / HollowBuilder)
--   • Rows index from top (1) to bottom (N)
--   • Cols index from left (1) to right (N)
--   • "Right" corridor → same row, col+1
--   • "Down"  corridor → row+1, same col
--   • All adjacent pairs of filled cells receive a corridor (full grid graph)
--------------------------------------------------------------------------------

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local DescentRegistry = require(ReplicatedStorage:WaitForChild("DescentRegistry"))

local HollowLayout = {}

--------------------------------------------------------------------------------
-- CONFIG
--------------------------------------------------------------------------------

local WARDEN_COUNTS = {
	[3] = 1,
	[4] = 2,
	[5] = 3,
	[6] = 4,
	[7] = 5,
	[8] = 6,
}

local FILL_TYPES = {
	{ type = "hall",   weight = 5 },
	{ type = "vault",  weight = 2 },
	{ type = "shrine", weight = 2 },
}

local FILL_TOTAL_WEIGHT = 0
local FILL_CUMULATIVE = {}
for _, entry in ipairs(FILL_TYPES) do
	FILL_TOTAL_WEIGHT = FILL_TOTAL_WEIGHT + entry.weight
	table.insert(FILL_CUMULATIVE, { type = entry.type, cum = FILL_TOTAL_WEIGHT })
end

--------------------------------------------------------------------------------
-- INTERNAL HELPERS
--------------------------------------------------------------------------------

local function randomFillType()
	local roll = math.random() * FILL_TOTAL_WEIGHT
	for _, entry in ipairs(FILL_CUMULATIVE) do
		if roll <= entry.cum then
			return entry.type
		end
	end
	return FILL_TYPES[#FILL_TYPES].type
end

local function shuffle(t)
	for i = #t, 2, -1 do
		local j = math.random(i)
		t[i], t[j] = t[j], t[i]
	end
end

local function pickTemplate(roomType, fallbackOrder)
	local t = DescentRegistry.GetRandom(roomType)
	if t then return t end
	if fallbackOrder then
		for _, fb in ipairs(fallbackOrder) do
			t = DescentRegistry.GetRandom(fb)
			if t then
				warn(string.format(
					"[HollowLayout] No templates for type '%s', falling back to '%s'",
					roomType, fb
				))
				return t
			end
		end
	end
	error(string.format("[HollowLayout] No templates available for type '%s' (and no fallback succeeded)", roomType))
end

local function computeWardenPositions(n, count)
	local innerMin = 2
	local innerMax = n - 1
	local innerSize = innerMax - innerMin + 1

	if innerSize <= 0 then
		return {}
	end

	local innerCells = innerSize * innerSize
	count = math.min(count, innerCells)

	local candidates = {}
	for row = innerMin, innerMax do
		for col = innerMin, innerMax do
			table.insert(candidates, { Row = row, Col = col })
		end
	end
	shuffle(candidates)

	local positions = {}
	local bandSize = math.ceil(#candidates / count)
	for i = 1, count do
		local bandStart = (i - 1) * bandSize + 1
		local bandEnd   = math.min(i * bandSize, #candidates)
		local pick = candidates[math.random(bandStart, bandEnd)]
		table.insert(positions, pick)
	end

	return positions
end

--------------------------------------------------------------------------------
-- PUBLIC API
--------------------------------------------------------------------------------

function HollowLayout.GenerateGrid(n, options)
	n = math.clamp(math.floor(n or 5), 3, 10)
	options = options or {}

	if options.Seed then
		math.randomseed(options.Seed)
	end

	local wardenCount = options.WardenCount
		or WARDEN_COUNTS[n]
		or math.max(1, n - 2)

	local grid = {}
	for row = 1, n do
		grid[row] = {}
	end

	local wardenPositions = computeWardenPositions(n, wardenCount)
	local isWardenCell = {}
	for _, pos in ipairs(wardenPositions) do
		isWardenCell[pos.Row .. "," .. pos.Col] = true
	end

	local wardenPool = DescentRegistry.GetByType("warden")
	shuffle(wardenPool)
	local function getWardenTemplate(index)
		if #wardenPool == 0 then
			return pickTemplate("warden", { "hall" })
		end
		return wardenPool[((index - 1) % #wardenPool) + 1]
	end

	local roomIdCounter = 0
	local function nextRoomId()
		roomIdCounter = roomIdCounter + 1
		return roomIdCounter
	end

	for row = 1, n do
		for col = 1, n do
			local roomType
			local template

			if row == 1 and col == 1 then
				roomType = "start"
				template = pickTemplate("start", { "hall" })

			elseif row == n and col == n then
				roomType = "sanctum"
				template = pickTemplate("sanctum", { "hall" })

			elseif isWardenCell[row .. "," .. col] then
				roomType = "warden"
				local idx = 0
				for _, pos in ipairs(wardenPositions) do
					if pos.Row < row or (pos.Row == row and pos.Col <= col) then
						idx = idx + 1
					end
				end
				template = getWardenTemplate(idx)

			else
				roomType = randomFillType()
				template = pickTemplate(roomType, { "hall" })
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

	local corridors = {}
	for row = 1, n do
		for col = 1, n do
			if col < n then
				table.insert(corridors, {
					FromRow = row, FromCol = col,
					ToRow   = row, ToCol   = col + 1,
					Dir     = "Right",
				})
			end
			if row < n then
				table.insert(corridors, {
					FromRow = row,     FromCol = col,
					ToRow   = row + 1, ToCol   = col,
					Dir     = "Down",
				})
			end
		end
	end

	return {
		N                = n,
		Grid             = grid,
		Corridors        = corridors,
		StartPos         = { Row = 1, Col = 1 },
		SanctumPos       = { Row = n, Col = n },
		WardenPositions  = wardenPositions,
	}
end

--------------------------------------------------------------------------------
-- UTILITY: pretty-print
--------------------------------------------------------------------------------
local TYPE_GLYPHS = {
	start   = "[S]",
	hall    = "[ ]",
	shrine  = "[?]",
	vault   = "[V]",
	warden  = "[W]",
	sanctum = "[B]",
}

function HollowLayout.PrintGrid(result)
	print(string.format("=== HollowLayout  %dx%d ===", result.N, result.N))
	for row = 1, result.N do
		local line = {}
		for col = 1, result.N do
			local cell = result.Grid[row][col]
			table.insert(line, TYPE_GLYPHS[cell.RoomType] or "[?]")
		end
		print(table.concat(line, " "))
	end
	print(string.format(
		"Chambers: %d  |  Corridors: %d  |  Wardens: %d",
		result.N * result.N, #result.Corridors, #result.WardenPositions
	))
end

--------------------------------------------------------------------------------
-- UTILITY: convert to HollowConfig-compatible format
--------------------------------------------------------------------------------
function HollowLayout.ToHollowConfig(result)
	local chambers  = {}
	local corridors = {}

	local roomIdAt = {}
	for row = 1, result.N do
		roomIdAt[row] = {}
		for col = 1, result.N do
			roomIdAt[row][col] = result.Grid[row][col].RoomId
		end
	end

	for row = 1, result.N do
		for col = 1, result.N do
			local cell = result.Grid[row][col]
			local t    = cell.Template
			table.insert(chambers, {
				RoomId        = cell.RoomId,
				Grid          = { col - 1, row - 1 },
				Name          = t.Name,
				RoomType      = cell.RoomType == "vault" and "Vault" or "Hall",
				Size          = Vector3.new(120, 22, 120),
				Enemies       = {},
				FloorMaterial = Enum.Material.Cobblestone,
				WallMaterial  = Enum.Material.Brick,
				FloorColor    = BrickColor.new("Dark stone grey"),
				WallColor     = BrickColor.new("Really black"),
				LightColor    = Color3.fromRGB(200, 180, 150),
				IsBossRoom    = (cell.RoomType == "sanctum"),
				LayoutTemplate = t,
			})
		end
	end

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
		Chambers       = chambers,
		Corridors      = corridors,
		EntranceRoom   = result.Grid[1][1].RoomId,
		LobbySpawn     = Vector3.new(0, 5, 0),
		SealTypes      = {},
	}
end

return HollowLayout
