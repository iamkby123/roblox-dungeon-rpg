--------------------------------------------------------------------------------
-- DungeonRoomRegistry
--
-- A catalog of pre-built room templates. Each entry describes a room that
-- exists as a physical Folder/Model inside workspace.RoomTemplates.
--
-- FolderPath uses "/" as a separator and is rooted at workspace.
-- e.g. "RoomTemplates/CryptEntrance" → workspace.RoomTemplates.CryptEntrance
--
-- RoomType values:
--   "start"    – the first room players spawn into each run
--   "normal"   – standard combat room
--   "puzzle"   – challenge room with mechanics (switches, pressure plates, etc.)
--   "trap"     – obstacle / hazard room
--   "miniboss" – room containing a keeper/miniboss enemy
--   "boss"     – final room with the dungeon boss
--
-- Usage (server):
--   local Registry = require(ReplicatedStorage.DungeonRoomRegistry)
--   local template  = Registry.GetRandom("normal")
--   local folder    = Registry.ResolveFolder(template)  -- returns workspace Instance
--------------------------------------------------------------------------------

local DungeonRoomRegistry = {}

--------------------------------------------------------------------------------
-- TEMPLATE CATALOG
-- Add entries here for every pre-built room model in workspace.RoomTemplates.
--------------------------------------------------------------------------------
local Templates = {

	------------------------------------------------------------
	-- START ROOMS (1 variant)
	------------------------------------------------------------
	{
		Name        = "Dungeon Entrance",
		Type        = "start",
		FolderPath  = "RoomTemplates/DungeonEntrance",
		Description = "A torch-lit stone foyer. The way forward is barred by iron gates.",
		Difficulty  = 0,
	},

	------------------------------------------------------------
	-- NORMAL ROOMS (8 variants)
	------------------------------------------------------------
	{
		Name        = "Crypt Entrance",
		Type        = "normal",
		FolderPath  = "RoomTemplates/CryptEntrance",
		Description = "A gloomy crypt corridor lined with sealed burial alcoves.",
		Difficulty  = 1,
	},
	{
		Name        = "Forgotten Library",
		Type        = "normal",
		FolderPath  = "RoomTemplates/ForgottenLibrary",
		Description = "Towering shelves of rotting tomes, animated by dark magic.",
		Difficulty  = 1,
	},
	{
		Name        = "Grand Hall",
		Type        = "normal",
		FolderPath  = "RoomTemplates/GrandHall",
		Description = "A vast hall with crumbling pillars and a collapsed ceiling.",
		Difficulty  = 2,
	},
	{
		Name        = "Haunted Gallery",
		Type        = "normal",
		FolderPath  = "RoomTemplates/HauntedGallery",
		Description = "Portraits whose eyes follow intruders, walls stained with spectral light.",
		Difficulty  = 2,
	},
	{
		Name        = "Rat Warren",
		Type        = "normal",
		FolderPath  = "RoomTemplates/RatWarren",
		Description = "Low tunnels packed with nesting monsters and scattered bones.",
		Difficulty  = 1,
	},
	{
		Name        = "Armory",
		Type        = "normal",
		FolderPath  = "RoomTemplates/Armory",
		Description = "Rusted weapon racks and crumbling stone soldiers spring to life.",
		Difficulty  = 2,
	},
	{
		Name        = "Crystal Cavern",
		Type        = "normal",
		FolderPath  = "RoomTemplates/CrystalCavern",
		Description = "Glittering ice-blue crystals refract enemy spells unpredictably.",
		Difficulty  = 3,
	},
	{
		Name        = "Shadow Crypt",
		Type        = "normal",
		FolderPath  = "RoomTemplates/ShadowCrypt",
		Description = "Absolute darkness—enemies can hear every footstep.",
		Difficulty  = 3,
	},

	------------------------------------------------------------
	-- PUZZLE ROOMS (4 variants)
	------------------------------------------------------------
	{
		Name        = "Pressure Plates",
		Type        = "puzzle",
		FolderPath  = "RoomTemplates/PressurePlates",
		Description = "Stand on all plates simultaneously to unseal the exit gate.",
		Difficulty  = 2,
	},
	{
		Name        = "Lever Maze",
		Type        = "puzzle",
		FolderPath  = "RoomTemplates/LeverMaze",
		Description = "Pull levers in the correct sequence to raise the portcullis.",
		Difficulty  = 2,
	},
	{
		Name        = "Torch Riddle",
		Type        = "puzzle",
		FolderPath  = "RoomTemplates/TorchRiddle",
		Description = "Light only the torches whose braziers match a hidden pattern.",
		Difficulty  = 3,
	},
	{
		Name        = "Rune Chamber",
		Type        = "puzzle",
		FolderPath  = "RoomTemplates/RuneChamber",
		Description = "Activate ancient rune pillars in the order they glow.",
		Difficulty  = 3,
	},

	------------------------------------------------------------
	-- TRAP ROOMS (4 variants)
	------------------------------------------------------------
	{
		Name        = "Spike Corridor",
		Type        = "trap",
		FolderPath  = "RoomTemplates/SpikeCorridor",
		Description = "Floor spikes pulse in rhythmic waves. Time each crossing carefully.",
		Difficulty  = 2,
	},
	{
		Name        = "Crusher Hall",
		Type        = "trap",
		FolderPath  = "RoomTemplates/CrusherHall",
		Description = "Massive stone slabs slam down from the ceiling at random intervals.",
		Difficulty  = 3,
	},
	{
		Name        = "Dart Gallery",
		Type        = "trap",
		FolderPath  = "RoomTemplates/DartGallery",
		Description = "Wall-mounted dart launchers cover overlapping fields of fire.",
		Difficulty  = 2,
	},
	{
		Name        = "Infernal Pit",
		Type        = "trap",
		FolderPath  = "RoomTemplates/InfernalPit",
		Description = "Narrow walkways over a lava pit, patrolled by floating fire elementals.",
		Difficulty  = 4,
	},

	------------------------------------------------------------
	-- MINIBOSS ROOMS (5 variants — one per key type)
	------------------------------------------------------------
	{
		Name        = "Iron Keep",
		Type        = "miniboss",
		FolderPath  = "RoomTemplates/IronKeep",
		Description = "The Iron Keeper patrols a fortified stone chamber. Defeat it for the Iron Key.",
		Difficulty  = 3,
		DropsKey    = "Iron",
	},
	{
		Name        = "Gold Vault",
		Type        = "miniboss",
		FolderPath  = "RoomTemplates/GoldVault",
		Description = "The Gold Guardian stands over a hoard of cursed coins. Defeat it for the Gold Key.",
		Difficulty  = 3,
		DropsKey    = "Gold",
	},
	{
		Name        = "Blood Altar",
		Type        = "miniboss",
		FolderPath  = "RoomTemplates/BloodAltar",
		Description = "The Crimson Sentinel performs dark rites at a sacrificial altar.",
		Difficulty  = 4,
		DropsKey    = "Crimson",
	},
	{
		Name        = "Mage Tower",
		Type        = "miniboss",
		FolderPath  = "RoomTemplates/MageTower",
		Description = "The Emerald Warden controls the arcane wards of this sorcerer's spire.",
		Difficulty  = 4,
		DropsKey    = "Emerald",
	},
	{
		Name        = "Bone Pit",
		Type        = "miniboss",
		FolderPath  = "RoomTemplates/BonePit",
		Description = "The Shadow Champion commands armies of the dead from a throne of skulls.",
		Difficulty  = 5,
		DropsKey    = "Shadow",
	},

	------------------------------------------------------------
	-- BOSS ROOMS (1 variant)
	------------------------------------------------------------
	{
		Name        = "Golem's Throne",
		Type        = "boss",
		FolderPath  = "RoomTemplates/GolemsThrone",
		Description = "The Stone Golem awakens. The dungeon shakes with every step.",
		Difficulty  = 6,
	},
}

--------------------------------------------------------------------------------
-- INTERNAL: build lookup tables on first require (O(1) access thereafter)
--------------------------------------------------------------------------------
local byType = {} -- [type] = { template, ... }
local byName = {} -- [name] = template

for _, t in ipairs(Templates) do
	if not byType[t.Type] then
		byType[t.Type] = {}
	end
	table.insert(byType[t.Type], t)
	byName[t.Name] = t
end

--------------------------------------------------------------------------------
-- PUBLIC API
--------------------------------------------------------------------------------

-- Returns a shallow copy of the full template list.
function DungeonRoomRegistry.GetAll()
	local copy = {}
	for _, t in ipairs(Templates) do
		table.insert(copy, t)
	end
	return copy
end

-- Returns all templates whose Type matches roomType (case-sensitive).
-- Returns an empty table if none found.
function DungeonRoomRegistry.GetByType(roomType)
	local list = byType[roomType]
	if not list then return {} end
	local copy = {}
	for _, t in ipairs(list) do
		table.insert(copy, t)
	end
	return copy
end

-- Returns the first template whose Name matches exactly, or nil.
function DungeonRoomRegistry.GetByName(name)
	return byName[name]
end

-- Returns a random template of the given type, or nil if none exist.
function DungeonRoomRegistry.GetRandom(roomType)
	local list = byType[roomType]
	if not list or #list == 0 then
		warn("[DungeonRoomRegistry] No templates found for type: " .. tostring(roomType))
		return nil
	end
	return list[math.random(#list)]
end

-- Resolves template.FolderPath to a live workspace Instance.
-- Traverses the path segments using FindFirstChild.
-- Returns the Instance on success, nil (with a warning) on failure.
--
-- NOTE: call this only at runtime (after workspace is populated).
-- Templates live under workspace.RoomTemplates by convention.
function DungeonRoomRegistry.ResolveFolder(template)
	if not template or not template.FolderPath then
		warn("[DungeonRoomRegistry] ResolveFolder: invalid template")
		return nil
	end

	local segments = string.split(template.FolderPath, "/")
	local current = workspace
	for _, segment in ipairs(segments) do
		local child = current:FindFirstChild(segment)
		if not child then
			warn(string.format(
				"[DungeonRoomRegistry] ResolveFolder: could not find '%s' in '%s' (full path: %s)",
				segment, current:GetFullName(), template.FolderPath
			))
			return nil
		end
		current = child
	end
	return current
end

-- Returns whether a template's workspace folder currently exists.
-- Useful for validation / editor tooling.
function DungeonRoomRegistry.FolderExists(template)
	return DungeonRoomRegistry.ResolveFolder(template) ~= nil
end

return DungeonRoomRegistry
