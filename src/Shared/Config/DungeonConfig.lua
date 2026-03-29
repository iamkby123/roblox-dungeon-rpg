local DungeonConfig = {}

-- Grid-based dungeon with BRANCHING PATH layout
-- Each cell = 180 studs apart (120 room + 60 corridor gap)
DungeonConfig.GridSpacing = 180
DungeonConfig.CorridorWidth = 16
DungeonConfig.CorridorHeight = 16
DungeonConfig.StartOffset = Vector3.new(-270, 5, -200)

-- Layout (branching paths, miniboss keys, E to open doors):
--
--            [Entrance]
--               |
--      C0      C1      C2      C3
-- R0 [Rm16]-[Rm1]--[Rm2]--[Rm14]
--               |
-- R1  [Rm3]--[Rm4]--[Rm5]--[Rm15]
--      |🔒Iron          |🔒Gold
-- R2  [Rm6]--[Rm7]  [Rm8]--[Rm9]
--      |🔒Crimson        |🔒Emerald
-- R3 [Rm10]-[Rm11]-[Rm12]
--              |🔒Shadow×2
-- R4         [Rm18]
--              |
-- R5         [BOSS]
--
-- Rm16,Rm14,Rm15 = side rooms   |   Rm17 = Infernal Pit off Rm10
-- Miniboss in Rm3 drops Iron Key → opens Rm3→Rm6 door
-- Miniboss in Rm5 drops Gold Key → opens Rm5→Rm8 door
-- Miniboss in Rm6 drops Crimson Key → opens Rm6→Rm10 door
-- Miniboss in Rm8 drops Emerald Key → opens Rm8→Rm12 door
-- Miniboss in Rm10 drops Shadow Key #1
-- Miniboss in Rm12 drops Shadow Key #2
-- Both Shadow Keys → opens Rm11→Rm18 door → Rm18 → BOSS

DungeonConfig.KeyTypes = {
	Iron    = { Name = "Iron Key",    Color = Color3.fromRGB(180, 180, 190), BrickColor = BrickColor.new("Medium stone grey") },
	Gold    = { Name = "Gold Key",    Color = Color3.fromRGB(255, 215, 0),   BrickColor = BrickColor.new("Bright yellow") },
	Crimson = { Name = "Crimson Key", Color = Color3.fromRGB(200, 30, 30),   BrickColor = BrickColor.new("Bright red") },
	Emerald = { Name = "Emerald Key", Color = Color3.fromRGB(30, 200, 60),   BrickColor = BrickColor.new("Dark green") },
	Shadow  = { Name = "Shadow Key",  Color = Color3.fromRGB(120, 50, 200),  BrickColor = BrickColor.new("Bright violet") },
}

DungeonConfig.Rooms = {
	-- ============ ROW 0 ============
	{
		RoomId = 1, Grid = {1, 0}, Name = "Crypt Entrance",
		RoomType = "Combat", Size = Vector3.new(120, 22, 120),
		Enemies = {
			{ Id = "Skeleton", Count = 4 },
			{ Id = "Bat", Count = 3 },
			{ Id = "Zombie", Count = 2 },
		},
		FloorMaterial = Enum.Material.Cobblestone, WallMaterial = Enum.Material.Brick,
		FloorColor = BrickColor.new("Dark stone grey"), WallColor = BrickColor.new("Really black"),
		LightColor = Color3.fromRGB(200, 180, 150),
	},
	{
		RoomId = 2, Grid = {2, 0}, Name = "Forgotten Library",
		RoomType = "Combat", Size = Vector3.new(120, 22, 120),
		Enemies = {
			{ Id = "Wraith", Count = 3 },
			{ Id = "Mage", Count = 3 },
			{ Id = "Archer", Count = 2 },
		},
		FloorMaterial = Enum.Material.WoodPlanks, WallMaterial = Enum.Material.Brick,
		FloorColor = BrickColor.new("Brown"), WallColor = BrickColor.new("Really black"),
		LightColor = Color3.fromRGB(180, 160, 100),
	},
	{
		RoomId = 14, Grid = {3, 0}, Name = "Riddle Chamber",
		RoomType = "Puzzle", PuzzleVariant = "Trivia",
		Size = Vector3.new(120, 22, 120),
		Enemies = {},
		FloorMaterial = Enum.Material.Slate, WallMaterial = Enum.Material.Brick,
		FloorColor = BrickColor.new("Dark stone grey"), WallColor = BrickColor.new("Really black"),
		LightColor = Color3.fromRGB(200, 180, 100),
	},
	{
		RoomId = 16, Grid = {0, 0}, Name = "Forgotten Catacombs",
		RoomType = "Combat", Size = Vector3.new(120, 22, 120),
		Enemies = {
			{ Id = "Skeleton", Count = 4 },
			{ Id = "Zombie", Count = 3 },
			{ Id = "Bat", Count = 2 },
		},
		FloorMaterial = Enum.Material.Cobblestone, WallMaterial = Enum.Material.Brick,
		FloorColor = BrickColor.new("Dark stone grey"), WallColor = BrickColor.new("Really black"),
		LightColor = Color3.fromRGB(160, 140, 100),
	},

	-- ============ ROW 1 ============
	{
		RoomId = 3, Grid = {0, 1}, Name = "Spider Nest",
		RoomType = "Combat", Size = Vector3.new(120, 22, 120),
		Enemies = {
			{ Id = "Spider", Count = 3 },
			{ Id = "Bat", Count = 3 },
			{ Id = "Zombie", Count = 2 },
			{ Id = "IronKeeper", Count = 1, DropsKey = "Iron" }, -- MINIBOSS
		},
		FloorMaterial = Enum.Material.Slate, WallMaterial = Enum.Material.Brick,
		FloorColor = BrickColor.new("Dark stone grey"), WallColor = BrickColor.new("Really black"),
		LightColor = Color3.fromRGB(100, 180, 100),
	},
	{
		RoomId = 4, Grid = {1, 1}, Name = "Grand Hall",
		RoomType = "Combat", Size = Vector3.new(120, 22, 120),
		Enemies = {
			{ Id = "SkeletonKnight", Count = 3 },
			{ Id = "Archer", Count = 3 },
			{ Id = "Skeleton", Count = 2 },
		},
		FloorMaterial = Enum.Material.Cobblestone, WallMaterial = Enum.Material.Granite,
		FloorColor = BrickColor.new("Medium stone grey"), WallColor = BrickColor.new("Black"),
		LightColor = Color3.fromRGB(200, 180, 150),
	},
	{
		RoomId = 5, Grid = {2, 1}, Name = "Armory",
		RoomType = "Combat", Size = Vector3.new(120, 22, 120),
		Enemies = {
			{ Id = "SkeletonKnight", Count = 3 },
			{ Id = "Zombie", Count = 2 },
			{ Id = "Archer", Count = 2 },
			{ Id = "GoldGuardian", Count = 1, DropsKey = "Gold" }, -- MINIBOSS
		},
		FloorMaterial = Enum.Material.Cobblestone, WallMaterial = Enum.Material.Granite,
		FloorColor = BrickColor.new("Medium stone grey"), WallColor = BrickColor.new("Black"),
		LightColor = Color3.fromRGB(200, 150, 120),
	},
	{
		RoomId = 15, Grid = {3, 1}, Name = "Cursed Chapel",
		RoomType = "Combat", Size = Vector3.new(120, 22, 120),
		Enemies = {
			{ Id = "Wraith", Count = 3 },
			{ Id = "Mage", Count = 3 },
			{ Id = "Skeleton", Count = 2 },
		},
		FloorMaterial = Enum.Material.Cobblestone, WallMaterial = Enum.Material.Granite,
		FloorColor = BrickColor.new("Dark stone grey"), WallColor = BrickColor.new("Really black"),
		LightColor = Color3.fromRGB(160, 80, 200),
	},

	-- ============ ROW 2 ============
	{
		RoomId = 6, Grid = {0, 2}, Name = "Blood Altar",
		RoomType = "Combat", Size = Vector3.new(120, 22, 120),
		Enemies = {
			{ Id = "Zombie", Count = 3 },
			{ Id = "Wraith", Count = 2 },
			{ Id = "Mage", Count = 2 },
			{ Id = "CrimsonSentinel", Count = 1, DropsKey = "Crimson" }, -- MINIBOSS
		},
		FloorMaterial = Enum.Material.Basalt, WallMaterial = Enum.Material.Granite,
		FloorColor = BrickColor.new("Maroon"), WallColor = BrickColor.new("Really black"),
		LightColor = Color3.fromRGB(200, 30, 30),
	},
	{
		RoomId = 7, Grid = {1, 2}, Name = "Bomb Vault",
		RoomType = "Puzzle", PuzzleVariant = "BombDefuse",
		Size = Vector3.new(120, 22, 120),
		Enemies = {},
		FloorMaterial = Enum.Material.Cobblestone, WallMaterial = Enum.Material.Granite,
		FloorColor = BrickColor.new("Medium stone grey"), WallColor = BrickColor.new("Black"),
		LightColor = Color3.fromRGB(255, 100, 50),
	},
	{
		RoomId = 8, Grid = {2, 2}, Name = "Mage Tower",
		RoomType = "Combat", Size = Vector3.new(120, 22, 120),
		Enemies = {
			{ Id = "Mage", Count = 3 },
			{ Id = "Wraith", Count = 2 },
			{ Id = "SkeletonKnight", Count = 2 },
			{ Id = "EmeraldWarden", Count = 1, DropsKey = "Emerald" }, -- MINIBOSS
		},
		FloorMaterial = Enum.Material.SmoothPlastic, WallMaterial = Enum.Material.Granite,
		FloorColor = BrickColor.new("Dark indigo"), WallColor = BrickColor.new("Really black"),
		LightColor = Color3.fromRGB(100, 100, 255),
	},
	{
		RoomId = 9, Grid = {3, 2}, Name = "Frozen Passage",
		RoomType = "Puzzle", PuzzleVariant = "IceWalk",
		Size = Vector3.new(120, 22, 120),
		Enemies = {},
		FloorMaterial = Enum.Material.Ice, WallMaterial = Enum.Material.Granite,
		FloorColor = BrickColor.new("Cyan"), WallColor = BrickColor.new("Really black"),
		LightColor = Color3.fromRGB(100, 200, 255),
	},

	-- ============ ROW 3 ============
	{
		RoomId = 10, Grid = {0, 3}, Name = "Bone Pit",
		RoomType = "Combat", Size = Vector3.new(120, 22, 120),
		Enemies = {
			{ Id = "Skeleton", Count = 3 },
			{ Id = "SkeletonKnight", Count = 2 },
			{ Id = "Zombie", Count = 2 },
			{ Id = "ShadowChampion", Count = 1, DropsKey = "Shadow" }, -- MINIBOSS
		},
		FloorMaterial = Enum.Material.Limestone, WallMaterial = Enum.Material.Granite,
		FloorColor = BrickColor.new("Brick yellow"), WallColor = BrickColor.new("Really black"),
		LightColor = Color3.fromRGB(200, 200, 150),
	},
	{
		RoomId = 11, Grid = {1, 3}, Name = "Shadow Crypt",
		RoomType = "Combat", Size = Vector3.new(120, 22, 120),
		Enemies = {
			{ Id = "Wraith", Count = 4 },
			{ Id = "SkeletonKnight", Count = 3 },
			{ Id = "Mage", Count = 2 },
		},
		FloorMaterial = Enum.Material.Basalt, WallMaterial = Enum.Material.Granite,
		FloorColor = BrickColor.new("Black"), WallColor = BrickColor.new("Really black"),
		LightColor = Color3.fromRGB(80, 50, 120),
	},
	{
		RoomId = 12, Grid = {2, 3}, Name = "Knight's Barracks",
		RoomType = "Combat", Size = Vector3.new(120, 22, 120),
		Enemies = {
			{ Id = "SkeletonKnight", Count = 3 },
			{ Id = "Archer", Count = 2 },
			{ Id = "Mage", Count = 2 },
			{ Id = "ShadowChampion", Count = 1, DropsKey = "Shadow" }, -- MINIBOSS
		},
		FloorMaterial = Enum.Material.Cobblestone, WallMaterial = Enum.Material.Granite,
		FloorColor = BrickColor.new("Medium stone grey"), WallColor = BrickColor.new("Black"),
		LightColor = Color3.fromRGB(200, 150, 150),
	},
	{
		RoomId = 17, Grid = {0, 4}, Name = "Infernal Pit",
		RoomType = "Combat", Size = Vector3.new(120, 22, 120),
		Enemies = {
			{ Id = "SkeletonKnight", Count = 3 },
			{ Id = "Zombie", Count = 3 },
			{ Id = "Wraith", Count = 2 },
		},
		FloorMaterial = Enum.Material.Basalt, WallMaterial = Enum.Material.Granite,
		FloorColor = BrickColor.new("Really black"), WallColor = BrickColor.new("Really black"),
		LightColor = Color3.fromRGB(255, 80, 20),
	},

	-- ============ ROW 4 (pre-boss) ============
	{
		RoomId = 18, Grid = {1, 4}, Name = "Void Sanctum",
		RoomType = "Combat", Size = Vector3.new(120, 24, 120),
		Enemies = {
			{ Id = "SkeletonKnight", Count = 4 },
			{ Id = "Mage", Count = 3 },
			{ Id = "Wraith", Count = 2 },
		},
		FloorMaterial = Enum.Material.Basalt, WallMaterial = Enum.Material.Granite,
		FloorColor = BrickColor.new("Really black"), WallColor = BrickColor.new("Really black"),
		LightColor = Color3.fromRGB(100, 50, 180),
	},

	-- ============ ROW 5 (BOSS) ============
	{
		RoomId = 13, Grid = {1, 5}, Name = "Golem's Throne",
		RoomType = "Combat", Size = Vector3.new(120, 28, 120),
		Enemies = {
			{ Id = "BossGolem", Count = 1 },
			{ Id = "SkeletonKnight", Count = 4 },
			{ Id = "Skeleton", Count = 4 },
		},
		FloorMaterial = Enum.Material.Basalt, WallMaterial = Enum.Material.Granite,
		FloorColor = BrickColor.new("Black"), WallColor = BrickColor.new("Really black"),
		LightColor = Color3.fromRGB(255, 100, 50),
		IsBossRoom = true,
	},
}

-- CORRIDORS: Dir "Right" = +X, "Down" = -Z
DungeonConfig.Corridors = {
	-- Row 0 connections
	{ FromRoom = 16, ToRoom = 1,  Dir = "Right" },               -- Catacombs → Crypt
	{ FromRoom = 1,  ToRoom = 2,  Dir = "Right" },               -- Crypt → Library
	{ FromRoom = 2,  ToRoom = 14, Dir = "Right" },               -- Library → Rat Warren

	-- Row 0 → Row 1
	{ FromRoom = 1,  ToRoom = 4,  Dir = "Down" },                -- Crypt → Grand Hall

	-- Row 1 connections
	{ FromRoom = 3,  ToRoom = 4,  Dir = "Right" },               -- Spider Nest ← Grand Hall
	{ FromRoom = 4,  ToRoom = 5,  Dir = "Right" },               -- Grand Hall → Armory
	{ FromRoom = 5,  ToRoom = 15, Dir = "Right" },               -- Armory → Cursed Chapel

	-- Row 1 → Row 2 (LOCKED DOORS)
	{ FromRoom = 3,  ToRoom = 6,  Dir = "Down", DoorKey = "Iron" },     -- 🔒 Iron Door
	{ FromRoom = 5,  ToRoom = 8,  Dir = "Down", DoorKey = "Gold" },     -- 🔒 Gold Door

	-- Row 2 connections
	{ FromRoom = 6,  ToRoom = 7,  Dir = "Right" },               -- Blood Altar → Haunted Gallery
	{ FromRoom = 8,  ToRoom = 9,  Dir = "Right" },               -- Mage Tower → Crystal Cavern

	-- Row 2 → Row 3 (LOCKED DOORS)
	{ FromRoom = 6,  ToRoom = 10, Dir = "Down", DoorKey = "Crimson" },  -- 🔒 Crimson Door
	{ FromRoom = 8,  ToRoom = 12, Dir = "Down", DoorKey = "Emerald" },  -- 🔒 Emerald Door

	-- Row 3 connections
	{ FromRoom = 10, ToRoom = 11, Dir = "Right" },               -- Bone Pit → Shadow Crypt
	{ FromRoom = 11, ToRoom = 12, Dir = "Right" },               -- Shadow Crypt → Barracks

	-- Row 3 → Row 4
	{ FromRoom = 10, ToRoom = 17, Dir = "Down" },                -- Bone Pit → Infernal Pit

	-- Row 3 → Row 4 (LOCKED DOOR - requires both Shadow Keys)
	{ FromRoom = 11, ToRoom = 18, Dir = "Down", DoorKey = "Shadow", RequiresBothShadow = true },

	-- Row 4 → Row 5 (Boss)
	{ FromRoom = 18, ToRoom = 13, Dir = "Down" },                -- Void Sanctum → Boss
}

DungeonConfig.EntranceRoom = 1

DungeonConfig.LobbySpawn = Vector3.new(0, 5, 0)
DungeonConfig.PortalPosition = Vector3.new(0, 5, -30)

return DungeonConfig
