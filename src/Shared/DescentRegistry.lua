--------------------------------------------------------------------------------
-- DescentRegistry
--
-- A catalog of pre-built chamber templates. Each entry describes a chamber that
-- exists as a physical Folder/Model inside workspace.HollowRooms.
--
-- FolderPath uses "/" as a separator and is rooted at workspace.
-- e.g. "HollowRooms/CryptEntrance" → workspace.HollowRooms.CryptEntrance
--
-- RoomType values:
--   "start"    – the first chamber delvers spawn into each descent
--   "hall"     – standard combat chamber
--   "shrine"   – challenge chamber with puzzle mechanics
--   "vault"    – hazard / trap chamber
--   "warden"   – chamber containing a warden creature
--   "sanctum"  – final chamber with the descent boss
--
-- Usage (server):
--   local Registry = require(ReplicatedStorage.DescentRegistry)
--   local template  = Registry.GetRandom("hall")
--   local folder    = Registry.ResolveFolder(template)  -- returns workspace Instance
--------------------------------------------------------------------------------

local DescentRegistry = {}

--------------------------------------------------------------------------------
-- TEMPLATE CATALOG
--------------------------------------------------------------------------------
local Templates = {

	------------------------------------------------------------
	-- START CHAMBERS (1 variant)
	------------------------------------------------------------
	{
		Name        = "Hollow Entrance",
		Type        = "start",
		FolderPath  = "HollowRooms/HollowEntrance",
		Description = "A torch-lit stone foyer. The way forward is barred by sealed gates.",
		Difficulty  = 0,
	},

	------------------------------------------------------------
	-- HALL CHAMBERS (8 variants)
	------------------------------------------------------------
	{
		Name        = "Crypt Entrance",
		Type        = "hall",
		FolderPath  = "HollowRooms/CryptEntrance",
		Description = "A gloomy crypt corridor lined with sealed burial alcoves.",
		Difficulty  = 1,
	},
	{
		Name        = "Forgotten Library",
		Type        = "hall",
		FolderPath  = "HollowRooms/ForgottenLibrary",
		Description = "Towering shelves of rotting tomes, animated by dark magic.",
		Difficulty  = 1,
	},
	{
		Name        = "Grand Hall",
		Type        = "hall",
		FolderPath  = "HollowRooms/GrandHall",
		Description = "A vast hall with crumbling pillars and a collapsed ceiling.",
		Difficulty  = 2,
	},
	{
		Name        = "Haunted Gallery",
		Type        = "hall",
		FolderPath  = "HollowRooms/HauntedGallery",
		Description = "Portraits whose eyes follow intruders, walls stained with spectral light.",
		Difficulty  = 2,
	},
	{
		Name        = "Rat Warren",
		Type        = "hall",
		FolderPath  = "HollowRooms/RatWarren",
		Description = "Low tunnels packed with nesting creatures and scattered bones.",
		Difficulty  = 1,
	},
	{
		Name        = "Armory",
		Type        = "hall",
		FolderPath  = "HollowRooms/Armory",
		Description = "Rusted weapon racks and crumbling stone soldiers spring to life.",
		Difficulty  = 2,
	},
	{
		Name        = "Crystal Cavern",
		Type        = "hall",
		FolderPath  = "HollowRooms/CrystalCavern",
		Description = "Glittering ice-blue crystals refract creature spells unpredictably.",
		Difficulty  = 3,
	},
	{
		Name        = "Shadow Crypt",
		Type        = "hall",
		FolderPath  = "HollowRooms/ShadowCrypt",
		Description = "Absolute darkness—creatures can hear every footstep.",
		Difficulty  = 3,
	},

	------------------------------------------------------------
	-- SHRINE CHAMBERS (4 variants)
	------------------------------------------------------------
	{
		Name        = "Pressure Plates",
		Type        = "shrine",
		FolderPath  = "HollowRooms/PressurePlates",
		Description = "Stand on all plates simultaneously to unseal the exit gate.",
		Difficulty  = 2,
	},
	{
		Name        = "Lever Maze",
		Type        = "shrine",
		FolderPath  = "HollowRooms/LeverMaze",
		Description = "Pull levers in the correct sequence to raise the portcullis.",
		Difficulty  = 2,
	},
	{
		Name        = "Torch Riddle",
		Type        = "shrine",
		FolderPath  = "HollowRooms/TorchRiddle",
		Description = "Light only the torches whose braziers match a hidden pattern.",
		Difficulty  = 3,
	},
	{
		Name        = "Rune Chamber",
		Type        = "shrine",
		FolderPath  = "HollowRooms/RuneChamber",
		Description = "Activate ancient rune pillars in the order they glow.",
		Difficulty  = 3,
	},

	------------------------------------------------------------
	-- VAULT CHAMBERS (4 variants)
	------------------------------------------------------------
	{
		Name        = "Spike Corridor",
		Type        = "vault",
		FolderPath  = "HollowRooms/SpikeCorridor",
		Description = "Floor spikes pulse in rhythmic waves. Time each crossing carefully.",
		Difficulty  = 2,
	},
	{
		Name        = "Crusher Hall",
		Type        = "vault",
		FolderPath  = "HollowRooms/CrusherHall",
		Description = "Massive stone slabs slam down from the ceiling at random intervals.",
		Difficulty  = 3,
	},
	{
		Name        = "Dart Gallery",
		Type        = "vault",
		FolderPath  = "HollowRooms/DartGallery",
		Description = "Wall-mounted dart launchers cover overlapping fields of fire.",
		Difficulty  = 2,
	},
	{
		Name        = "Infernal Pit",
		Type        = "vault",
		FolderPath  = "HollowRooms/InfernalPit",
		Description = "Narrow walkways over a lava pit, patrolled by floating fire elementals.",
		Difficulty  = 4,
	},

	------------------------------------------------------------
	-- WARDEN CHAMBERS (5 variants — one per seal type)
	------------------------------------------------------------
	{
		Name        = "Iron Keep",
		Type        = "warden",
		FolderPath  = "HollowRooms/IronKeep",
		Description = "The Iron Keeper patrols a fortified stone chamber. Defeat it for the Iron Seal.",
		Difficulty  = 3,
		DropsSeal   = "Iron",
	},
	{
		Name        = "Gold Vault",
		Type        = "warden",
		FolderPath  = "HollowRooms/GoldVault",
		Description = "The Gold Guardian stands over a hoard of cursed coins. Defeat it for the Gold Seal.",
		Difficulty  = 3,
		DropsSeal   = "Gold",
	},
	{
		Name        = "Blood Altar",
		Type        = "warden",
		FolderPath  = "HollowRooms/BloodAltar",
		Description = "The Crimson Sentinel performs dark rites at a sacrificial altar.",
		Difficulty  = 4,
		DropsSeal   = "Crimson",
	},
	{
		Name        = "Mage Tower",
		Type        = "warden",
		FolderPath  = "HollowRooms/MageTower",
		Description = "The Emerald Warden controls the arcane wards of this sorcerer's spire.",
		Difficulty  = 4,
		DropsSeal   = "Emerald",
	},
	{
		Name        = "Bone Pit",
		Type        = "warden",
		FolderPath  = "HollowRooms/BonePit",
		Description = "The Shadow Champion commands armies of the dead from a throne of skulls.",
		Difficulty  = 5,
		DropsSeal   = "Shadow",
	},

	------------------------------------------------------------
	-- SANCTUM CHAMBERS (1 variant)
	------------------------------------------------------------
	{
		Name        = "Golem's Throne",
		Type        = "sanctum",
		FolderPath  = "HollowRooms/GolemsThrone",
		Description = "The Stone Golem awakens. The Hollow shakes with every step.",
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

function DescentRegistry.GetAll()
	local copy = {}
	for _, t in ipairs(Templates) do
		table.insert(copy, t)
	end
	return copy
end

function DescentRegistry.GetByType(roomType)
	local list = byType[roomType]
	if not list then return {} end
	local copy = {}
	for _, t in ipairs(list) do
		table.insert(copy, t)
	end
	return copy
end

function DescentRegistry.GetByName(name)
	return byName[name]
end

function DescentRegistry.GetRandom(roomType)
	local list = byType[roomType]
	if not list or #list == 0 then
		warn("[DescentRegistry] No templates found for type: " .. tostring(roomType))
		return nil
	end
	return list[math.random(#list)]
end

function DescentRegistry.ResolveFolder(template)
	if not template or not template.FolderPath then
		warn("[DescentRegistry] ResolveFolder: invalid template")
		return nil
	end

	local segments = string.split(template.FolderPath, "/")
	local current = workspace
	for _, segment in ipairs(segments) do
		local child = current:FindFirstChild(segment)
		if not child then
			warn(string.format(
				"[DescentRegistry] ResolveFolder: could not find '%s' in '%s' (full path: %s)",
				segment, current:GetFullName(), template.FolderPath
			))
			return nil
		end
		current = child
	end
	return current
end

function DescentRegistry.FolderExists(template)
	return DescentRegistry.ResolveFolder(template) ~= nil
end

return DescentRegistry
